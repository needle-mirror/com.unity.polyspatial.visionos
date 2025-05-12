import Combine
import Foundation
import RealityKit
import UIKit

extension PolySpatialRealityKit {
    typealias ModifyPartsFunctionHandler = (PolySpatialAssetID, UnsafePointer<PolySpatialMesh>?, inout MeshResource.Part) -> Void

    // The available vertex semantics in the order they should appear in.  We seem to encounter mesh corruption
    // issues when we use arbitrary attribute orders (e.g., hash order).
    static let orderedVertexSemantics: [LowLevelMesh.VertexSemantic] = [
        .position, .normal, .tangent, .bitangent, .color, .uv0, .uv1, .uv2, .uv3, .uv4, .uv5, .uv6, .uv7]

    // A single frame within a blend shape.  It contains the weight associated with the frame (shapes can have multiple
    // frames with increasing weights, and adjacent frames will be blended together) and the Metal buffers containing
    // delta values for vertices, normals, and tangents (which are scaled and added to the values of the base mesh).
    class BlendShapeFrame {
        let weight: Float
        let deltaVertices: [simd_float3]
        let deltaNormals: [simd_float3]
        let deltaTangents: [simd_float3]

        init(
            _ weight: Float, _ deltaVertices: [simd_float3], _ deltaNormals: [simd_float3],
            _ deltaTangents: [simd_float3]) {

            self.weight = weight
            self.deltaVertices = deltaVertices
            self.deltaNormals = deltaNormals
            self.deltaTangents = deltaTangents
        }

        // Checks whether the deltas at the specified index are all (approximately) zero.
        func indexIsZero(_ index: Int) -> Bool {
            index >= deltaVertices.count ||
            (simd_norm_one(deltaVertices[index]).approximatelyEqual(0) &&
            simd_norm_one(deltaNormals[index]).approximatelyEqual(0) &&
            simd_norm_one(deltaTangents[index]).approximatelyEqual(0))
        }
    }

    // A single blend shape within a mesh.  Meshes can have arbitrary numbers of blend shapes (each with a name and
    // a set of frames), and SkinnedMeshRenderers using the mesh provide coefficients for each blend shape, which
    // are used to blend the frames onto the base mesh.
    class BlendShape {
        let name: String
        let frames: [BlendShapeFrame]

        init(_ name: String, _ frames: [BlendShapeFrame]) {
            self.name = name
            self.frames = frames
        }
    }

    // Wrapper for mesh resource, also stores data associated with a mesh resource that could potentially be otherwise difficult to obtain once the meshResource is generated.
    @MainActor
    class MeshAsset {
        // We store the contents separately from the MeshResource because obtaining the contents from the MeshResource
        // omits the jointInfluences.  We've reported this to Apple as FB13687224.
        private(set) var contents: MeshResource.Contents

        // A version number that is incremented each time the contents are updated.
        private(set) var version = 0

        // The total number of vertices in the mesh as obtained by adding the counts from all parts.
        private var vertexCount = 0

        // The total number of triangle indices in the mesh as obtained by summing the counts from all parts.
        private var indexCount = 0

        // The total number of blend shape frames.
        private var blendShapeFrameCount = 0

        // The number of joint influences for each vertex.
        private var jointInfluencesPerVertex = 0

        // The total number of joints, as determined by their influence indices.
        private var jointCount = 0

        // The number of UV sets used in the mesh.
        private(set) var numUVSets: Int

        // The blend shapes associated with the mesh, if any.
        private(set) var blendShapes: [BlendShape]

        // The buffer containing the base vertices (interleaved position/normal/tangents).
        private var baseVertices: MTLBuffer?

        // The buffer containing the blend shape vertices (indices for each vertex, then shape vertex data).
        private var blendShapeVertices: MTLBuffer?

        // The buffer containing joint influences for all vertices.
        private var jointInfluences: MTLBuffer?

        // The RealityKit mesh resource created for the mesh.
        private(set) var mesh: MeshResource

        // The vertex ranges corresponding to each part of the LowLevelMesh, if any.
        private(set) var lowLevelMeshVertexRanges: [Range<Int>]

        // The cached convex shape resource for the mesh, if any (for synchronous access).
        private var cachedConvexShape: ShapeResource?

        // The cached future that will resolve asynchronously to the convex shape.
        private var cachedConvexShapeFuture: Future<ShapeResource, Error>?

        // The cached future that will resolve asynchronously to the static shape.
        private var cachedStaticMeshShapeFuture: Future<ShapeResource, Error>?

        // Synchronously obtains the shared convex shape through the cache.  Note that this could lead to a redundant
        // result if called alongside convexShapeFuture, but synchronous generation is only used for testing, so
        // it shouldn't be a big deal.
        var convexShape: ShapeResource {
            if let cachedConvexShape {
                return cachedConvexShape
            }
            let newConvexShape = generateConvexShape(mesh)
            cachedConvexShape = newConvexShape
            return newConvexShape
        }

        // Returns a future that will resolve asynchronously to the shared convex shape.
        var convexShapeFuture: Future<ShapeResource, Error> {
            if let cachedConvexShapeFuture {
                return cachedConvexShapeFuture
            }
            let newConvexShapeFuture = Future<ShapeResource, Error> { promise in
                // If we already have a synchronous result, we can return immediately.
                if let cachedConvexShape = self.cachedConvexShape {
                    promise(.success(cachedConvexShape))
                    return
                }
                let mesh = self.mesh
                Task { @MainActor in
                    do {
                        promise(.success(try await generateConvexShape(mesh)))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
            cachedConvexShapeFuture = newConvexShapeFuture
            return newConvexShapeFuture
        }

        // Returns a future that will resolve asynchronously to the shared static shape.
        var staticMeshShapeFuture: Future<ShapeResource, Error> {
            if let cachedStaticMeshShapeFuture {
                return cachedStaticMeshShapeFuture
            }
            let newStaticMeshShapeFuture = Future<ShapeResource, Error> { promise in
                let mesh = self.mesh
                Task { @MainActor in
                    do {
                        promise(.success(try await generateStaticMeshShape(mesh)))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
            cachedStaticMeshShapeFuture = newStaticMeshShapeFuture
            return newStaticMeshShapeFuture
        }

        // The part (if any) from which we obtain the attribute buffers, which are shared between all parts.
        // Refer to GenerateParts for how parts/buffers are initialized.
        var bufferPart: MeshResource.Part? {
            contents.models.first?.parts.first
        }

        init(_ contents: MeshResource.Contents, _ numUVSets: Int = 0, _ blendShapes: [BlendShape] = []) {
            self.contents = contents
            self.numUVSets = numUVSets
            self.blendShapes = blendShapes
            self.mesh = try! .generate(from: contents)
            self.lowLevelMeshVertexRanges = []
            updateCounts()
            updateBaseBuffers()
        }

        init(_ lowLevelMesh: LowLevelMesh, _ numUVSets: Int, _ vertexRanges: [Range<Int>]) async {
            self.contents = .init()
            self.numUVSets = numUVSets
            self.blendShapes = []
            self.mesh = try! await .init(from: lowLevelMesh)
            self.lowLevelMeshVertexRanges = vertexRanges
        }

        init(_ lowLevelMesh: LowLevelMesh, _ numUVSets: Int, _ vertexRanges: [Range<Int>]) {
            self.contents = .init()
            self.numUVSets = numUVSets
            self.blendShapes = []
            self.mesh = try! .init(from: lowLevelMesh)
            self.lowLevelMeshVertexRanges = vertexRanges
        }

        func replace(_ contents: MeshResource.Contents, _ numUVSets: Int = 0, _ blendShapes: [BlendShape] = []) {
            try! mesh.replace(with: contents)
            self.contents = contents
            self.numUVSets = numUVSets
            self.blendShapes = blendShapes
            updateCounts()
            updateBaseBuffers()

            // Invalidate the cache.
            cachedConvexShape = nil
            cachedConvexShapeFuture = nil
            cachedStaticMeshShapeFuture = nil

            version += 1
        }

        // Notes that the contents of the LowLevelMesh were changed.
        func replace(_ lowLevelMeshVertexRanges: [Range<Int>]) {
            self.lowLevelMeshVertexRanges = lowLevelMeshVertexRanges

            // Invalidate the cache.
            cachedConvexShape = nil
            cachedConvexShapeFuture = nil
            cachedStaticMeshShapeFuture = nil

            version += 1
        }

        // Updates the vertex and index counts across all models/parts.
        func updateCounts() {
            vertexCount = bufferPart?.positions.count ?? 0
            indexCount = contents.models.flatMap { $0.parts }.map { $0.triangleIndices?.count ?? 0 }.reduce(0, +)
            blendShapeFrameCount = blendShapes.map { $0.frames.count }.reduce(0, +)

            jointInfluencesPerVertex = 0

            if let jointInfluences = bufferPart?.jointInfluences {
                jointInfluencesPerVertex = jointInfluences.influences.count / vertexCount
            }
        }

        // Updates the MTLBuffers that store the original (pre-blending) vertices, normals, and tangents.
        func updateBaseBuffers() {
            // If there are no blend shapes, clear out the Metal buffer references.
            guard let part = bufferPart, !blendShapes.isEmpty else {
                baseVertices = nil
                blendShapeVertices = nil
                jointInfluences = nil
                return
            }

            // Create the buffer for the base vertex data.  Each base vertex contains a float3 position, a
            // float3 normal, and a float4 tangent (in the format used by Unity: the w component indicates the
            // direction of the bitangent).
            let mtlDevice = PolySpatialRealityKit.instance.mtlDevice!
            let baseVertexStride = MemoryLayout<simd_float3>.size * 2 + MemoryLayout<simd_float4>.size
            baseVertices = mtlDevice.makeBuffer(length: vertexCount * baseVertexStride, options: [])
            let vertexAddress = baseVertices!.contents()

            // Populate the interleaved base vertex data.
            var positionAddress = vertexAddress
            for position in part.positions {
                positionAddress.storeBytes(of: position, as: simd_float3.self)
                positionAddress += baseVertexStride
            }
            var normalAddress = vertexAddress + MemoryLayout<simd_float3>.size
            if let normals = part.normals {
                for normal in normals {
                    normalAddress.storeBytes(of: normal, as: simd_float3.self)
                    normalAddress += baseVertexStride
                }
            }
            var tangentAddress = vertexAddress + MemoryLayout<simd_float3>.size * 2
            if let tangents = part.tangents {
                if let normals = part.normals, let bitangents = part.bitangents {
                    for (normal, (tangent, bitangent)) in zip(normals, zip(tangents, bitangents)) {
                        // The w component of the tangent is the sign of the bitangent
                        // relative to the cross product of normal and tangent.
                        tangentAddress.storeBytes(
                            of: .init(tangent, sign(simd_dot(simd_cross(normal, tangent), bitangent))),
                            as: simd_float4.self)
                        tangentAddress += baseVertexStride
                    }
                } else {
                    for tangent in tangents {
                        tangentAddress.storeBytes(of: .init(tangent, 1), as: simd_float4.self)
                        tangentAddress += baseVertexStride
                    }
                }
            }

            // Count the non-zero deltas for each vertex/frame.  Each non-zero delta value will be stored in a
            // segment corresponding to the vertex to which it applies.
            var blendShapeVertexCount = 0
            for blendShape in blendShapes {
                for frame in blendShape.frames {
                    for i in 0..<vertexCount {
                        if !frame.indexIsZero(i) {
                            blendShapeVertexCount += 1
                        }
                    }
                }
            }

            // Create the blend shape buffer with space for indices and vertices.  The format is from Unity:
            // https://docs.unity3d.com/ScriptReference/Rendering.BlendShapeBufferLayout.PerVertex.html
            // It starts with a list of Int32 indices representing the start and/or end points within the buffer
            // of the data for each vertex (with the indices being offsets that treat the entire buffer as an
            // Int32 array).  For vertexCount vertices, there are (vertexCount + 1) offsets: the range for vertex
            // i starts at index[i] and ends at index[i + 1] (exclusive), so we need one additional value to contain
            // the end of the last range.  The indices are followed by the contents of the ranges: for each vertex,
            // each range contains the non-zero deltas along with the frames to which they apply.
            let blendShapeIndicesSize = (vertexCount + 1) * MemoryLayout<Int32>.size
            let blendShapeVertexStride = MemoryLayout<Int32>.size + MemoryLayout<simd_float3>.size * 3
            blendShapeVertices = mtlDevice.makeBuffer(
                length: blendShapeIndicesSize + blendShapeVertexCount * blendShapeVertexStride,
                options: [])
            var blendShapeIndexAddress = blendShapeVertices!.contents()
            var blendShapeVertexAddress = blendShapeIndexAddress + blendShapeIndicesSize
            let indicesPerVertex = Int32(blendShapeVertexStride / MemoryLayout<Int32>.size)

            // Populate the indices and vertices.
            var currentIndex = Int32(vertexCount) + 1
            for i in 0..<vertexCount {
                blendShapeIndexAddress.storeBytes(of: currentIndex, as: Int32.self)
                blendShapeIndexAddress += MemoryLayout<Int32>.size

                var frameIndex: Int32 = 0
                for blendShape in blendShapes {
                    for frame in blendShape.frames {
                        if !frame.indexIsZero(i) {
                            blendShapeVertexAddress.storeBytes(of: frameIndex, as: Int32.self)
                            blendShapeVertexAddress += MemoryLayout<Int32>.stride
                            blendShapeVertexAddress.storeBytes(of: frame.deltaVertices[i], as: simd_float3.self)
                            blendShapeVertexAddress += MemoryLayout<simd_float3>.stride
                            blendShapeVertexAddress.storeBytes(of: frame.deltaNormals[i], as: simd_float3.self)
                            blendShapeVertexAddress += MemoryLayout<simd_float3>.stride
                            blendShapeVertexAddress.storeBytes(of: frame.deltaTangents[i], as: simd_float3.self)
                            blendShapeVertexAddress += MemoryLayout<simd_float3>.stride
                            currentIndex += indicesPerVertex
                        }
                        frameIndex += 1
                    }
                }
            }
            blendShapeIndexAddress.storeBytes(of: currentIndex, as: Int32.self)

            // If there are no joint influences, we use an alternate path that avoids skinning.
            if jointInfluencesPerVertex == 0 {
                jointInfluences = nil
                jointCount = 0
                return
            }

            // Create the buffer for the joint influences.  Each joint influence contains the joint index and the
            // associated weight.
            let jointInfluenceStride = MemoryLayout<Int32>.size + MemoryLayout<Float>.size
            jointInfluences = mtlDevice.makeBuffer(
                length: jointInfluenceStride * vertexCount * jointInfluencesPerVertex, options: [])
            var jointInfluenceAddress = jointInfluences!.contents()

            jointCount = 0
            if let jointInfluences = part.jointInfluences {
                var it = jointInfluences.influences.makeIterator()
                for _ in 0..<part.positions.count {
                    for _ in 0..<jointInfluencesPerVertex {
                        let jointInfluence = it.next()!
                        jointCount = max(jointCount, jointInfluence.jointIndex + 1)

                        jointInfluenceAddress.storeBytes(of: Int32(jointInfluence.jointIndex), as: Int32.self)
                        jointInfluenceAddress += MemoryLayout<Int32>.stride
                        jointInfluenceAddress.storeBytes(of: jointInfluence.weight, as: Float.self)
                        jointInfluenceAddress += MemoryLayout<Float>.stride
                    }
                }
            }
        }

        // Creates a mesh instance (based on LowLevelMesh) hold the blended geometry and associated buffers.  This
        // will be used by updateBlendedMeshInstance to hold the results of blending and skinning.  We combine
        // blending with skinning because RealityKit's skinning support doesn't work with LowLevelMesh (there's no
        // way to supply the joint influences, for example).  Similarly, we perform the blending/skinning ourselves
        // despite the fact that RealityKit ostensibly supports blend shapes for models because there is no way at
        // present to supply blend shape data as part of a MeshResource.  If Apple adds that, we can remove our
        // blending implementation in favor of theirs.
        //
        // Note that the localBounds supplied here come from the SkinnedMeshRenderer, are relative to the root bone,
        // and include animated deformations.  This is important for correct frustum culling.
        func createBlendedMeshInstance(_ localBounds: BoundingBox) -> PolySpatialComponents.BlendedMeshInstance {
            // Start with the blended attributes interleaved in the first buffer.  These are the results of the
            // blending and skinning process, and comprise float3 position, normal, tangent, and bitangent
            // interleaved for each vertex.
            let float3Size = MemoryLayout<simd_float3>.size
            var vertexAttributes: [LowLevelMesh.Attribute] = [
                .init(semantic: .position, format: .float3, layoutIndex: 0, offset: 0),
                .init(semantic: .normal, format: .float3, layoutIndex: 0, offset: float3Size),
                .init(semantic: .tangent, format: .float3, layoutIndex: 0, offset: float3Size * 2),
                .init(semantic: .bitangent, format: .float3, layoutIndex: 0, offset: float3Size * 3),
            ]
            var vertexLayouts: [LowLevelMesh.Layout] = [.init(bufferIndex: 0, bufferStride: float3Size * 4)]

            // Gather the fixed attributes (UVs, color) for the second buffer.  These are ordered according to the
            // "standard" LowLevelMesh semantic ordering and their formats match those of the original buffers.
            var semanticBuffers: [LowLevelMesh.VertexSemantic: AnyMeshBuffer] = [:]
            for buffer in bufferPart!.buffers.values {
                if buffer.id == .textureCoordinates {
                    semanticBuffers[.uv0] = buffer
                } else if buffer.id.isCustom {
                    switch buffer.id.name {
                        case PolySpatialRealityKit.instance.describe(vertexUVIndex: 0):
                            semanticBuffers[.uv0] = buffer
                        case PolySpatialRealityKit.instance.describe(vertexUVIndex: 1):
                            semanticBuffers[.uv1] = buffer
                        case PolySpatialRealityKit.instance.describe(vertexUVIndex: 2):
                            semanticBuffers[.uv2] = buffer
                        case PolySpatialRealityKit.instance.describe(vertexUVIndex: 3):
                            semanticBuffers[.uv3] = buffer
                        case "vertexColor":
                            semanticBuffers[.color] = buffer
                        default:
                            break
                    }
                }
            }
            var fixedStride = 0
            var fixedBuffers: [AnyMeshBuffer] = []
            for semantic in orderedVertexSemantics {
                if let buffer = semanticBuffers[semantic] {
                    var format = MTLVertexFormat.invalid
                    var size = 0
                    switch buffer.elementType {
                        case .simd2Float:
                            format = .float2
                            size = MemoryLayout<simd_float2>.size
                        case .simd3Float:
                            format = .float3
                            size = MemoryLayout<simd_float3>.size
                        case .simd4Float:
                            format = .float4
                            size = MemoryLayout<simd_float4>.size
                        default:
                            LogError("Unsupported element type: \(buffer.elementType)")
                    }
                    vertexAttributes.append(.init(
                        semantic: semantic, format: format, layoutIndex: 1, offset: fixedStride))
                    fixedStride += size
                    fixedBuffers.append(buffer)
                }
            }
            if fixedStride > 0 {
                vertexLayouts.append(.init(bufferIndex: 1, bufferStride: fixedStride))
            }

            // Create the mesh and its buffers.
            let lowLevelMesh = try! LowLevelMesh(descriptor: .init(
                vertexCapacity: vertexCount,
                vertexAttributes: vertexAttributes,
                vertexLayouts: vertexLayouts,
                indexCapacity: indexCount,
                indexType: .uint32))

            // Copy the indices for all parts and the parts themselves.
            lowLevelMesh.replaceUnsafeMutableIndices {
                let indexBuffer = $0.bindMemory(to: UInt32.self)
                var indexOffset = 0
                for model in contents.models {
                    for part in model.parts {
                        let indexCount = part.triangleIndices!.count
                        lowLevelMesh.parts.append(.init(
                            indexOffset: indexOffset * MemoryLayout<UInt32>.stride,
                            indexCount: indexCount,
                            topology: .triangle,
                            materialIndex: part.materialIndex,
                            bounds: localBounds))

                        part.triangleIndices!.elements.withUnsafeBytes {
                            let bufferSlice = UnsafeMutableBufferPointer(
                                rebasing: indexBuffer[indexOffset..<indexOffset + indexCount])
                            UnsafeMutableRawBufferPointer(bufferSlice).copyMemory(from: $0)
                        }
                        indexOffset += indexCount
                    }
                }
            }

            // Copy the fixed attributes.
            lowLevelMesh.replaceUnsafeMutableBytes(bufferIndex: 1) {
                let bufferAddress = $0.baseAddress!
                var fixedOffset = 0
                for buffer in fixedBuffers {
                    var attributeAddress = bufferAddress + fixedOffset
                    switch buffer.elementType {
                        case .simd2Float:
                            for value in buffer.get(simd_float2.self)! {
                                attributeAddress.storeBytes(of: value, as: simd_float2.self)
                                attributeAddress += fixedStride
                            }
                            fixedOffset += MemoryLayout<simd_float2>.size
                        case .simd3Float:
                            for value in buffer.get(simd_float3.self)! {
                                attributeAddress.storeBytes(of: value, as: simd_float3.self)
                                attributeAddress += fixedStride
                            }
                            fixedOffset += MemoryLayout<simd_float3>.size
                        case .simd4Float:
                            for value in buffer.get(simd_float4.self)! {
                                attributeAddress.storeBytes(of: value, as: simd_float4.self)
                                attributeAddress += fixedStride
                            }
                            fixedOffset += MemoryLayout<simd_float4>.size
                        default:
                            LogError("Unsupported element type: \(buffer.elementType)")
                    }
                }
            }

            let mtlDevice = PolySpatialRealityKit.instance.mtlDevice!
            var jointMatrices: MTLBuffer?
            var jointNormalMatrices: MTLBuffer?
            if jointCount > 0 {
                jointMatrices = mtlDevice.makeBuffer(
                    length: MemoryLayout<simd_float4x4>.size * jointCount, options: [])
                jointNormalMatrices = mtlDevice.makeBuffer(
                    length: MemoryLayout<simd_float3x3>.size * jointCount, options: [])
            }
            return PolySpatialComponents.BlendedMeshInstance(
                self, version, try! .init(from: lowLevelMesh),
                mtlDevice.makeBuffer(length: MemoryLayout<Float>.size * blendShapeFrameCount, options: [])!,
                jointMatrices, jointNormalMatrices)
        }

        // Update the contents of a blended mesh instance with new blend shape coefficients and joint transforms.
        func updateBlendedMeshInstance(
            _ instance: PolySpatialComponents.BlendedMeshInstance,
            _ blendShapeWeights: [Float], _ jointTransforms: [Transform],
            _ onComplete: (() -> Void)? = nil) {

            // Update the per-frame blend shape weights.
            var currentFrameWeight = instance.blendFrameWeights.contents().bindMemory(
                to: Float.self, capacity: blendShapeFrameCount)
            for i in 0..<blendShapes.count {
                let blendShape = blendShapes[i]
                let blendShapeWeight = (i < blendShapeWeights.count) ? blendShapeWeights[i] : 0
                for j in 0..<blendShape.frames.count {
                    let blendShapeFrame = blendShape.frames[j]
                    var frameWeight: Float = 0
                    if blendShapeWeight <= blendShapeFrame.weight || j == blendShape.frames.count - 1 {
                        if j == 0 {
                            frameWeight = blendShapeWeight / blendShapeFrame.weight
                        } else {
                            let previousWeight = blendShape.frames[j - 1].weight
                            if blendShapeWeight >= previousWeight {
                                frameWeight = (blendShapeWeight - previousWeight) /
                                    (blendShapeFrame.weight - previousWeight)
                            }
                        }
                    } else {
                        let nextWeight = blendShape.frames[j + 1].weight
                        if blendShapeWeight <= nextWeight {
                            frameWeight = (nextWeight - blendShapeWeight) /
                                (nextWeight - blendShapeFrame.weight)
                        }
                    }
                    currentFrameWeight.pointee = frameWeight
                    currentFrameWeight += 1
                }
            }

            let lowLevelMesh = instance.mesh.lowLevelMesh!
            let commandBuffer = PolySpatialRealityKit.instance.mtlCommandQueue!.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!
            let computePipelineState: MTLComputePipelineState
            if jointCount > 0 {
                computePipelineState = PolySpatialRealityKit.instance.blendAndSkinCompute!

                // Update the joint transforms.
                let jointMatrices = instance.jointMatrices!.contents().bindMemory(
                    to: simd_float4x4.self, capacity: jointCount)
                let jointNormalMatrices = instance.jointNormalMatrices!.contents().bindMemory(
                    to: simd_float3x3.self, capacity: jointCount)
                if let skeletonJoints = contents.skeletons.first(where: { _ in true })?.joints {
                    // First pass: multiply matrices by parents to get model-relative transforms.
                    for i in 0..<jointCount {
                        var matrix = (i < jointTransforms.count) ? jointTransforms[i].matrix : .init(1)
                        if let parentIndex = skeletonJoints[i].parentIndex {
                            matrix = jointMatrices[parentIndex] * matrix
                        }
                        jointMatrices[i] = matrix
                    }

                    // Second pass: multiply by inverse bind pose matrices and get normal matrices.
                    for i in 0..<jointCount {
                        var matrix = jointMatrices[i]
                        matrix *= skeletonJoints[i].inverseBindPoseMatrix
                        jointMatrices[i] = matrix
                        jointNormalMatrices[i] = matrix.normalMatrix
                    }
                }
                commandEncoder.setBuffer(jointInfluences!, offset: 0, index: 5)
                commandEncoder.setBytes(&jointInfluencesPerVertex, length: MemoryLayout<Int>.size, index: 6)
                commandEncoder.setBuffer(instance.jointMatrices!, offset: 0, index: 7)
                commandEncoder.setBuffer(instance.jointNormalMatrices!, offset: 0, index: 8)

            } else {
                computePipelineState = PolySpatialRealityKit.instance.blendCompute!
            }
            commandEncoder.setComputePipelineState(computePipelineState)
            let results = lowLevelMesh.replace(bufferIndex: 0, using: commandBuffer)
            commandEncoder.setBuffer(results, offset: 0, index: 0)
            commandEncoder.setBytes(&vertexCount, length: MemoryLayout<Int>.size, index: 1)
            commandEncoder.setBuffer(baseVertices!, offset: 0, index: 2)
            commandEncoder.setBuffer(blendShapeVertices!, offset: 0, index: 3)
            commandEncoder.setBuffer(instance.blendFrameWeights, offset: 0, index: 4)
            commandEncoder.dispatchThreadgroups(
                .init(width: vertexCount, height: 1, depth: 1),
                threadsPerThreadgroup: .init(
                    width: computePipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1))
            commandEncoder.endEncoding()

            guard let completionHandler = onComplete else {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                return
            }
            commandBuffer.addCompletedHandler { _ in
                Task { @MainActor in completionHandler() }
            }
            commandBuffer.commit()
        }
    }

    func describe(modelId: PolySpatialAssetID) -> String {
        return "\(modelId):model"
    }

    func describe(modelInstanceId: PolySpatialAssetID) -> String {
        return "\(modelInstanceId):instance"
    }

    func describe(vertexUVIndex: Int) -> String {
        return "vertexUV\(vertexUVIndex)"
    }

    func CreateUninitializedMeshAsset(_ id: PolySpatialAssetID) -> MeshAsset {
        let parts: [MeshResource.Part] = []
        var contents = MeshResource.Contents.init()
        contents.models = .init([.init(id: describe(modelId: id), parts: parts)])
        contents.instances = .init([.init(id: describe(modelInstanceId: id), model: describe(modelId: id))])
        UpdateMeshDefinition(id, .init(contents))
        return meshAssets[id]!
    }

    func CreateOrUpdateMeshAsset(_ id: PolySpatialAssetID, _ mesh: UnsafePointer<PolySpatialMesh>?) {
        let unityMesh = mesh!.pointee
        let parts = GenerateParts(id, mesh, ModifyParts)
        let contents = GenerateContents(id, mesh, parts)
        let numUVSets = Int(unityMesh.texCoordsCount)

        // If there are no vertices, there are no buffers; let's also assume there are no blend shapes,
        // since we use the presence of blend shapes to determine whether we need to blend
        // (which is pointless without buffers).
        let vertexCount = parts.map { $0.positions.count }.reduce(0, +)
        let blendShapesCount = (vertexCount == 0) ? 0 : unityMesh.blendShapesCount
        let blendShapes: [BlendShape] = (0..<blendShapesCount).map { blendShapeIndex in
            let unityBlendShape = unityMesh.blendShapes(at: blendShapeIndex)!
            return .init(unityBlendShape.name!, (0..<unityBlendShape.framesCount).map { frameIndex in
                let unityFrame = unityBlendShape.frames(at: frameIndex)!
                return .init(
                    unityFrame.weight,
                    unityFrame.deltaVerticesAsBuffer!.map { $0.swapCoordinateSystem() },
                    unityFrame.deltaNormalsAsBuffer!.map { $0.swapCoordinateSystem() },
                    unityFrame.deltaTangentsAsBuffer!.map { $0.swapCoordinateSystem() })
            })
        }

        // TODO (LXR-2993): Figure out why replacing the MeshResource/ModelComponent is causing a performance
        // regression with (at least) bake to mesh particles, since that is the approach that Apple recommended.
        if let existingAsset = meshAssets[id] {
            existingAsset.replace(contents, numUVSets, blendShapes)
            ModifyMeshAsset(id, mesh, existingAsset)
            NotifyMeshOrMaterialObservers(id, true)
        } else {
            let newAsset = MeshAsset(contents, numUVSets, blendShapes)
            ModifyMeshAsset(id, mesh, newAsset)
            UpdateMeshDefinition(id, newAsset) { id in
                // Special mesh asset deleter to clean out the cachedSkinnedMesh dictionary.
                self.DeleteMeshAsset(id);
                self.skinnedMeshManager.cachedSkinnedMeshes.removeValue(forKey: id)
            }
        }
    }

    func createOrUpdateNativeMeshAsset(_ id: PolySpatialAssetID, _ mesh: UnsafePointer<PolySpatialNativeMesh>?) {
        let unityMesh = mesh!.pointee

        // LowLevelMeshes can't have zero vertices.
        if unityMesh.vertexCount == 0 {
            if let existingAsset = meshAssets[id] {
                existingAsset.replace(.init())
                NotifyMeshOrMaterialObservers(id, true)
            } else {
                UpdateMeshDefinition(id, .init(.init()))
            }
            return
        }

        // Matches the TransferExtents struct in ComputeShaders.metal.
        struct TransferExtents {
            let sourceOffset: Int32
            let destOffset: Int32
            let size: Int32
        }

        var numUVSets = 0
        var vertexLayouts: [LowLevelMesh.Layout] = []
        var sourceStrides: [Int] = []
        var vertexAttributes: [LowLevelMesh.Attribute] = []
        var attributeExtents: [TransferExtents] = []
        for vertexAttributeDescriptor in unityMesh.vertexAttributeDescriptorsAsBuffer! {
            if let uvIndex = vertexAttributeDescriptor.attribute.uvIndex() {
                numUVSets = max(numUVSets, uvIndex + 1)
            }
            let layoutIndex = Int(vertexAttributeDescriptor.stream)
            while vertexLayouts.count <= layoutIndex {
                vertexLayouts.append(LowLevelMesh.Layout(
                    bufferIndex: vertexLayouts.count, bufferOffset: 0, bufferStride: 0))
                sourceStrides.append(0)
            }
            let sourceAttributeSize =
                vertexAttributeDescriptor.format.bytesPerElement() * Int(vertexAttributeDescriptor.dimension)
            attributeExtents.append(.init(
                sourceOffset: Int32(sourceStrides[layoutIndex]),
                destOffset: Int32(vertexLayouts[layoutIndex].bufferStride),
                size: Int32(sourceAttributeSize)))
            if vertexAttributeDescriptor.attribute == .tangent {
                // Special handling for tangents, which become tangents + bitangents.
                vertexAttributes.append(LowLevelMesh.Attribute(
                    semantic: .tangent,
                    format: .float3,
                    layoutIndex: layoutIndex,
                    offset: vertexLayouts[layoutIndex].bufferStride))
                vertexLayouts[layoutIndex].bufferStride += MemoryLayout<Float>.size * 3

                vertexAttributes.append(LowLevelMesh.Attribute(
                    semantic: .bitangent,
                    format: .float3,
                    layoutIndex: layoutIndex,
                    offset: vertexLayouts[layoutIndex].bufferStride))
                vertexLayouts[layoutIndex].bufferStride += MemoryLayout<Float>.size * 3

            } else {
                vertexAttributes.append(LowLevelMesh.Attribute(
                    semantic: vertexAttributeDescriptor.attribute.rk(),
                    format: vertexAttributeDescriptor.format.rk(vertexAttributeDescriptor.dimension),
                    layoutIndex: layoutIndex,
                    offset: vertexLayouts[layoutIndex].bufferStride))
                vertexLayouts[layoutIndex].bufferStride += sourceAttributeSize
            }
            sourceStrides[layoutIndex] += sourceAttributeSize
        }

        // Matches the SubMesh struct in ComputeShaders.metal.
        struct ComputeShaderSubMesh {
            let indexStart: Int32
            let indexCount: Int32
            let baseVertexIndex: Int32
        }

        var indexCapacity = UInt32(0)
        var parts: [LowLevelMesh.Part] = []
        var computeShaderSubMeshes: [ComputeShaderSubMesh] = []
        var vertexRanges: [Range<Int>] = []
        for subMesh in unityMesh.subMeshesAsBuffer! {
            indexCapacity = max(indexCapacity, UInt32(subMesh.indexStart + subMesh.indexCount))
            parts.append(LowLevelMesh.Part(
                indexOffset: Int(subMesh.indexStart) * MemoryLayout<UInt32>.size,
                indexCount: Int(subMesh.indexCount),
                topology: subMesh.topology.rk(),
                materialIndex: parts.count,
                bounds: subMesh.bounds.rk()))
            computeShaderSubMeshes.append(ComputeShaderSubMesh(
                indexStart: subMesh.indexStart, indexCount: subMesh.indexCount,
                baseVertexIndex: subMesh.baseVertexIndex))
            vertexRanges.append(Int(subMesh.firstVertex)..<Int(subMesh.firstVertex + subMesh.vertexCount))
        }
        var vertexCapacity = UInt32(unityMesh.vertexCount)
        let lowLevelMeshDescriptor = LowLevelMesh.Descriptor(
            vertexCapacity: Int(vertexCapacity),
            vertexAttributes: vertexAttributes,
            vertexLayouts: vertexLayouts,
            indexCapacity: Int(indexCapacity),
            indexType: .uint32)

        // We can reuse the existing LowLevelMesh, if any, if its descriptor matches exactly.
        let lowLevelMesh: LowLevelMesh
        let reusedLowLevelMesh: Bool
        if let existingAsset = meshAssets[id], let existingLowLevelMesh = existingAsset.mesh.lowLevelMesh,
                existingLowLevelMesh.descriptor == lowLevelMeshDescriptor {
            lowLevelMesh = existingLowLevelMesh
            existingAsset.replace(vertexRanges)
            reusedLowLevelMesh = true
        } else {
            lowLevelMesh = try! .init(descriptor: lowLevelMeshDescriptor)
            reusedLowLevelMesh = false
        }
        lowLevelMesh.parts.replaceAll(parts)

        let commandBuffer = mtlCommandQueue!.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!
        var computePipelineState = (unityMesh.indexFormat == .uint16 ?
            transferTriangleIndices16Compute : transferTriangleIndices32Compute)!
        commandEncoder.setComputePipelineState(computePipelineState)

        let rawIndexBufferPointer = UnsafeRawPointer(bitPattern: UInt(unityMesh.nativeIndexBufferPtr))
        let nativeIndexBuffer = Unmanaged<MTLBuffer>.fromOpaque(rawIndexBufferPointer!).takeUnretainedValue()
        commandEncoder.setBuffer(nativeIndexBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(lowLevelMesh.replaceIndices(using: commandBuffer), offset: 0, index: 1)
        commandEncoder.setBytes(&indexCapacity, length: MemoryLayout<UInt32>.size, index: 2)
        // Setting the buffer to "zero" (empty array) causes a "missing buffer binding" exception,
        // so instead we use a single unused sub mesh struct as a placeholder.
        if computeShaderSubMeshes.isEmpty {
            var unusedSubMesh = ComputeShaderSubMesh(indexStart: 0, indexCount: 0, baseVertexIndex: 0)
            commandEncoder.setBytes(&unusedSubMesh, length: MemoryLayout<ComputeShaderSubMesh>.size, index: 3)
        } else {
            computeShaderSubMeshes.withUnsafeMutableBytes {
                commandEncoder.setBytes($0.baseAddress!, length: $0.count, index: 3)
            }
        }
        var subMeshCount = UInt32(computeShaderSubMeshes.count)
        commandEncoder.setBytes(&subMeshCount, length: MemoryLayout<UInt32>.size, index: 4)

        commandEncoder.dispatchThreadgroups(
            .init(width: Int(indexCapacity), height: 1, depth: 1),
            threadsPerThreadgroup: .init(
                width: computePipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1))

        computePipelineState = transferVertexAttributesCompute!
        commandEncoder.setComputePipelineState(computePipelineState)
        for i in 0..<vertexLayouts.count {
            let rawVertexBufferPointer = UnsafeRawPointer(bitPattern: UInt(unityMesh.nativeVertexBufferPtrs[i]))
            let nativeVertexBuffer = Unmanaged<MTLBuffer>.fromOpaque(rawVertexBufferPointer!).takeUnretainedValue()

            commandEncoder.setBuffer(nativeVertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(lowLevelMesh.replace(bufferIndex: i, using: commandBuffer), offset: 0, index: 1)
            commandEncoder.setBytes(&vertexCapacity, length: MemoryLayout<UInt32>.size, index: 2)
            var sourceStride = UInt32(sourceStrides[i])
            commandEncoder.setBytes(&sourceStride, length: MemoryLayout<UInt32>.size, index: 3)
            var destStride = UInt32(vertexLayouts[i].bufferStride)
            commandEncoder.setBytes(&destStride, length: MemoryLayout<UInt32>.size, index: 4)

            // Start off with position/normal/tangent/color set to "unused."
            var unusedExtents = TransferExtents(sourceOffset: -1, destOffset: -1, size: -1)
            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<TransferExtents>.size, index: 5)
            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<TransferExtents>.size, index: 6)
            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<TransferExtents>.size, index: 7)
            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<TransferExtents>.size, index: 8)

            // Find the attributes that we will use for this buffer.
            var texCoordExtents: [TransferExtents] = []
            for (j, vertexAttributeDescriptor) in unityMesh.vertexAttributeDescriptorsAsBuffer!.enumerated() {
                if vertexAttributeDescriptor.stream != i {
                    continue
                }
                var extents = attributeExtents[j]
                switch vertexAttributeDescriptor.attribute {
                    case .position:
                        commandEncoder.setBytes(&extents, length: MemoryLayout<TransferExtents>.size, index: 5)
                    case .normal:
                        commandEncoder.setBytes(&extents, length: MemoryLayout<TransferExtents>.size, index: 6)
                    case .tangent:
                        commandEncoder.setBytes(&extents, length: MemoryLayout<TransferExtents>.size, index: 7)
                    case .color:
                        commandEncoder.setBytes(&extents, length: MemoryLayout<TransferExtents>.size, index: 8)
                    case .texCoord0, .texCoord1, .texCoord2, .texCoord3, .texCoord4, .texCoord5, .texCoord6, .texCoord7:
                        texCoordExtents.append(extents)
                    default: break
                }
            }
            // Setting the buffer to "zero" (empty array) causes a "missing buffer binding" exception, so instead we
            // use a single unused extents struct as a placeholder.
            if texCoordExtents.isEmpty {
                commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<TransferExtents>.size, index: 9)
            } else {
                texCoordExtents.withUnsafeMutableBytes {
                    commandEncoder.setBytes($0.baseAddress!, length: $0.count, index: 9)
                }
            }
            var texCoordExtentsCount = UInt32(texCoordExtents.count)
            commandEncoder.setBytes(&texCoordExtentsCount, length: MemoryLayout<UInt32>.size, index: 10)

            commandEncoder.dispatchThreadgroups(
                .init(width: Int(vertexCapacity), height: 1, depth: 1),
                threadsPerThreadgroup: .init(
                    width: computePipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1))
        }
        commandEncoder.endEncoding()
        commandBuffer.commit()

        // If we reused the LowLevelMesh, the effect is immediate.  We can notify the observers directly.
        if reusedLowLevelMesh {
            NotifyMeshOrMaterialObservers(id, true)
            return
        }

        // Update the mesh synchronously iff the flag is set (used for testing).
        if runtimeFlags.contains(.updateMeshesSynchronously) {
            UpdateMeshDefinition(id, .init(lowLevelMesh, numUVSets, vertexRanges))
            return
        }

        // If not, then the update is asynchronous.  Replace when it's ready, as long as it wasn't replaced
        // in the meantime.
        let oldMeshAsset = getMeshAssetForId(id)
        let oldMeshVersion = oldMeshAsset.version
        Task { @MainActor in
            let newMeshAsset = await MeshAsset(lowLevelMesh, numUVSets, vertexRanges)
            if tryGetMeshAssetForId(id) === oldMeshAsset && oldMeshAsset.version == oldMeshVersion {
                UpdateMeshDefinition(id, newMeshAsset)
            }
        }
    }

    static func generateConvexShape(_ mesh: MeshResource) -> ShapeResource {
        if let lowLevelMesh = mesh.lowLevelMesh {
            return .generateConvex(from: getPoints(lowLevelMesh))
        } else {
            return .generateConvex(from: mesh)
        }
    }

    static func generateConvexShape(_ mesh: MeshResource) async throws -> ShapeResource {
        if let lowLevelMesh = mesh.lowLevelMesh {
            return try await .generateConvex(from: getPoints(lowLevelMesh))
        } else {
            return try await .generateConvex(from: mesh)
        }
    }

    static func getPoints(_ lowLevelMesh: LowLevelMesh) -> [simd_float3] {
        var points = Set<simd_float3>()
        for vertexAttribute in lowLevelMesh.descriptor.vertexAttributes {
            if vertexAttribute.semantic != .position {
                continue
            }
            lowLevelMesh.withUnsafeIndices { indexBuffer in
                let indices = indexBuffer.bindMemory(to: UInt32.self)

                // Because of the way we populate LowLevelMeshes, we always have one layout per buffer.
                lowLevelMesh.withUnsafeBytes(bufferIndex: vertexAttribute.layoutIndex) { vertexBuffer in
                    let stride = lowLevelMesh.descriptor.vertexLayouts[vertexAttribute.layoutIndex].bufferStride
                    for part in lowLevelMesh.parts {
                        let intOffset = part.indexOffset / MemoryLayout<UInt32>.stride
                        for index in indices[intOffset..<intOffset + part.indexCount] {
                            let packed = vertexBuffer.load(
                                fromByteOffset: vertexAttribute.offset + Int(index) * stride, as: MTLPackedFloat3.self)
                            points.insert(.init(packed.x, packed.y, packed.z))
                        }
                    }
                }
            }
            break
        }
        return .init(points)
    }

    static func generateStaticMeshShape(_ mesh: MeshResource) async throws -> ShapeResource {
        var positions: [simd_float3] = []
        var positionIndices: [simd_float3: UInt16] = [:]
        var faceIndices: [UInt16] = []
        if let lowLevelMesh = mesh.lowLevelMesh {
            for vertexAttribute in lowLevelMesh.descriptor.vertexAttributes {
                if vertexAttribute.semantic != .position {
                    continue
                }
                lowLevelMesh.withUnsafeIndices { indexBuffer in
                    let indices = indexBuffer.bindMemory(to: UInt32.self)

                    // Because of the way we populate LowLevelMeshes, we always have one layout per buffer.
                    lowLevelMesh.withUnsafeBytes(bufferIndex: vertexAttribute.layoutIndex) { vertexBuffer in
                        let stride = lowLevelMesh.descriptor.vertexLayouts[vertexAttribute.layoutIndex].bufferStride
                        for part in lowLevelMesh.parts {
                            let intOffset = part.indexOffset / MemoryLayout<UInt32>.stride
                            for originalIndex in indices[intOffset..<intOffset + part.indexCount] {
                                let packed = vertexBuffer.load(
                                    fromByteOffset: vertexAttribute.offset + Int(originalIndex) * stride,
                                    as: MTLPackedFloat3.self)
                                let position = simd_float3(packed.x, packed.y, packed.z)
                                let index: UInt16
                                if let existingIndex = positionIndices[position] {
                                    index = existingIndex
                                } else {
                                    if positions.count > UInt16.max {
                                        LogWarning(
                                            "Static mesh contains more than \(Int(UInt16.max) + 1) unique positions.")
                                        return
                                    }
                                    index = UInt16(positions.count)
                                    positionIndices[position] = index
                                    positions.append(position)
                                }
                                faceIndices.append(index)
                            }
                        }
                    }
                }
                break
            }
        } else {
            // We should be able to use .generateStaticMesh(from: mesh), but it throws
            // "Fatal error: Not enough bits to represent the passed value".
            for model in mesh.contents.models {
                for part in model.parts {
                    guard let triangleIndices = part.triangleIndices else {
                        continue
                    }
                    let originalPositions = part.positions.elements
                    for originalIndex in triangleIndices {
                        let position = originalPositions[Int(originalIndex)]
                        let index: UInt16
                        if let existingIndex = positionIndices[position] {
                            index = existingIndex
                        } else {
                            if positions.count > UInt16.max {
                                LogWarning(
                                    "Static mesh contains more than \(Int(UInt16.max) + 1) unique positions.")
                                return try await .generateStaticMesh(positions: positions, faceIndices: faceIndices)
                            }
                            index = UInt16(positions.count)
                            positionIndices[position] = index
                            positions.append(position)
                        }
                        faceIndices.append(index)
                    }
                }
            }
        }
        return try await .generateStaticMesh(positions: positions, faceIndices: faceIndices)
    }

    func UpdateMeshDefinition(
        _ id: PolySpatialAssetID, _ asset: MeshAsset, _ deleter: ((PolySpatialAssetID) -> Void)? = nil) {
        meshAssets[id] = asset

        NotifyMeshOrMaterialObservers(id)

        assetDeleters[id] = deleter ?? DeleteMeshAsset
    }

    internal func ModifyParts(_ id: PolySpatialAssetID,
                              _ mesh: UnsafePointer<PolySpatialMesh>?,
                              _ part: inout MeshResource.Part) {
        let unityMesh = mesh!.pointee
        let vertexCount: Int = Int(unityMesh.verticesCount)

        // Optionally set up the start of a skeleton and cache the info. The skinned mesh will be finished later when data pertaining to the transform hierarchy comes in.
        if unityMesh.boneWeightsCount > 0 {
            // Handle bone weights/joint influences per bone. A buffer is created to allow for a cast from UInt8 to Int32.
            let boneWeightsPerVertex = unityMesh.bonesPerVertexAsBuffer
            let boneWeights = unityMesh.boneWeightsAsBuffer

            // Unity supports a variable number of influences per vertex, and provides an array to specify the number of influences for each vertex. Since RK wants a fixed number of influences per vertex, we'll need to pad the bone weights array from Unity with additional 0's to indicate that those influences are unused.
            let maxInfluencesPerVertex = Int(boneWeightsPerVertex!.max() ?? 0)
            guard maxInfluencesPerVertex > 0 else {
                PolySpatialRealityKit.instance.LogException("Max number of bone weights per vertex in a skinned mesh was 0.")
                return
            }

            var jointBuffer = [MeshJointInfluence](repeating: MeshJointInfluence(jointIndex: 0, weight: 0), count: maxInfluencesPerVertex * vertexCount)
            var boneWeightsIndex = 0
            for (index, influencesPerVertex) in boneWeightsPerVertex!.enumerated() {
                // vertexIndex will give us the index associated with each vertex in the array.
                // For example, if maxInfluencesPerVertex is 4, this will give us 0...4...8, then influenceIndex will give us the index within each set of 4 influences per vertex. The bone weights index will keep track of the packed bone weights in the unity boneWeights array.
                let vertexIndex = maxInfluencesPerVertex * index

                for influenceIndex in 0...influencesPerVertex - 1 {
                    jointBuffer[vertexIndex + Int(influenceIndex)] = boneWeights![boneWeightsIndex].rk()
                    boneWeightsIndex += 1
                }
            }

            part.skeletonID = skinnedMeshManager.GenerateSkeletonName(id)
            part.jointInfluences = MeshResource.JointInfluences(influences: MeshBuffer.init(jointBuffer), influencesPerVertex: maxInfluencesPerVertex)
        }
    }

    internal func ModifyMeshAsset(
        _ id: PolySpatialAssetID, _ mesh: UnsafePointer<PolySpatialMesh>?, _ asset: MeshAsset) {
        let unityMesh = mesh!.pointee

        if unityMesh.bindPosesCount > 0 {
            let bindPoseCount = Int(unityMesh.bindPosesCount)
            let bindPoses = unityMesh.bindPosesAsBuffer
            var bindPoseBuffer = [simd_float4x4](repeating: matrix_identity_float4x4, count: bindPoseCount)

            for i in 0..<bindPoseCount {
                bindPoseBuffer[i] = bindPoses![i].swapCoordinateSystem()
            }

            skinnedMeshManager.CacheSkinnedMeshContents(id, asset, bindPoseBuffer)
        }
    }


    func GenerateParts(_ id: PolySpatialAssetID,
                                _ mesh: UnsafePointer<PolySpatialMesh>?,
                                _ ModifyPart: ModifyPartsFunctionHandler) -> [MeshResource.Part] {
        assert(id.isValid)
        let unityMesh = mesh!.pointee

        let vertexCount: Int = Int(unityMesh.verticesCount)
        let subMeshesCount: Int = Int(unityMesh.subMeshesCount)
        let vertices = unityMesh.verticesAsBuffer!
        let subMeshes = unityMesh.subMeshesAsBuffer ?? .init(start: nil, count: 0)
        let norms = unityMesh.normalsAsBuffer ?? .init(start: nil, count: 0)
        let tangents = unityMesh.tangentsAsBuffer ?? .init(start: nil, count: 0)
        let colors = unityMesh.colorsAsBuffer ?? .init(start: nil, count: 0)

        // PolySpatialVec3 is packed; simd_float3 is padded to 4-float size, so can't memcpy
        // We need to take into account coordinate space anyway
        let positionBuffer = MeshBuffer<SIMD3<Float>>.init(.init(unsafeUninitializedCapacity: vertexCount) {
            buffer, initializedCount in for i in 0..<vertexCount {
                buffer[i] = vertices[i].swapCoordinateSystem()
            }
            initializedCount = vertexCount
        })

        func createTexCoord2Buffer<T: SIMD2Convertible>(_ data: UnsafeBufferPointer<T>) -> MeshBuffer<SIMD2<Float>> {
            .init(.init(unsafeUninitializedCapacity: vertexCount) {
                buffer, initializedCount in for j in 0..<vertexCount {
                    // RK UVs have different Y origin
                    buffer[j] = data[j].rkInvertYTexCoordAsFloat2()
                }
                initializedCount = vertexCount
            })
        }

        func createTexCoord3Buffer<T: SIMD3Convertible>(_ data: UnsafeBufferPointer<T>) -> MeshBuffer<SIMD3<Float>> {
            .init(.init(unsafeUninitializedCapacity: vertexCount) {
                buffer, initializedCount in for j in 0..<vertexCount {
                    buffer[j] = data[j].rkAsFloat3()
                }
                initializedCount = vertexCount
            })
        }

        var tangentBuffer: MeshBuffer<SIMD3<Float>>?
        var bitangentBuffer: MeshBuffer<SIMD3<Float>>?
        var normalBuffer: MeshBuffer<SIMD3<Float>>?

        let supportedTexCoordCount = 2
        let texCoordCount = min(unityMesh.texCoordsCount, Int32(supportedTexCoordCount))

        var texCoord2Buffers: [MeshBuffer<SIMD2<Float>>?] = .init(repeating: nil, count: Int(texCoordCount))
        var texCoord3Buffers: [MeshBuffer<SIMD3<Float>>?] = .init(repeating: nil, count: Int(texCoordCount))
        var texCoord4Buffers: [MeshBuffer<SIMD4<Float>>?] = .init(repeating: nil, count: Int(texCoordCount))

        for i in 0..<texCoordCount {
            let texCoords = unityMesh.texCoords(at: i)

            if texCoords!.hasData2 {
                texCoord2Buffers[Int(i)] = createTexCoord2Buffer(texCoords!.data2AsBuffer!)
            } else if texCoords!.hasData3 {
                let data = texCoords!.data3AsBuffer!
                if i == 0 {
                    // UV0 must be float2
                    texCoord2Buffers[Int(i)] = createTexCoord2Buffer(data)
                } else {
                    texCoord3Buffers[Int(i)] = .init(.init(unsafeUninitializedCapacity: vertexCount) {
                        buffer, initializedCount in for j in 0..<vertexCount {
                            // RK UVs have different Y origin
                            buffer[j] = data[j].rkInvertYTexCoord()
                        }
                        initializedCount = vertexCount
                    })
                }
            } else if texCoords!.hasData4 {
                let data = texCoords!.data4AsBuffer!
                if i == 0 {
                    // UV0 must be float2
                    texCoord2Buffers[Int(i)] = createTexCoord2Buffer(data)
                } else {
                    texCoord4Buffers[Int(i)] = .init(.init(unsafeUninitializedCapacity: vertexCount) {
                        buffer, initializedCount in for j in 0..<vertexCount {
                            // RK UVs have different Y origin
                            buffer[j] = data[j].rkInvertYTexCoord()
                        }
                        initializedCount = vertexCount
                    })
                }
            }
        }

        if norms.count > 0 {
            // packed vs unpacked issue, so can't memcpy
            normalBuffer = MeshBuffer<SIMD3<Float>>.init(.init(unsafeUninitializedCapacity: vertexCount) {
                buffer, initializedCount in for i in 0..<vertexCount {
                    buffer[i] = norms[i].swapCoordinateSystem()
                }
                initializedCount = vertexCount
            })
        } else {
            // Populate normal buffer with texCoord3 buffer
            if unityMesh.texCoordsCount >= 4, let texCoords3 = unityMesh.texCoords(at: 3) {

                if texCoords3.hasData2, let targetBuffer = texCoords3.data2AsBuffer {
                    normalBuffer = createTexCoord3Buffer(targetBuffer)
                } else if texCoords3.hasData3, let targetBuffer = texCoords3.data3AsBuffer {
                    normalBuffer = createTexCoord3Buffer(targetBuffer)
                } else if texCoords3.hasData4, let targetBuffer = texCoords3.data4AsBuffer {
                    normalBuffer = createTexCoord3Buffer(targetBuffer)
                }
            }
        }

        if tangents.count > 0 {
            tangentBuffer = .init(.init(unsafeUninitializedCapacity: vertexCount) {
                buffer, initializedCount in for i in 0..<vertexCount {
                    buffer[i] = simd_make_float3(tangents[i].swapCoordinateSystem())
                }
                initializedCount = vertexCount
            })

            if let normals = normalBuffer?.elements {
                bitangentBuffer = .init(.init(unsafeUninitializedCapacity: vertexCount) {
                    buffer, initializedCount in for i in 0..<vertexCount {
                        let tangent = tangents[i].swapCoordinateSystem()
                        buffer[i] = simd_cross(simd_make_float3(tangent), normals[i]) * tangent.w
                    }
                    initializedCount = vertexCount
                })
            }
        }
        // Populate bitangent buffer with texCoord2 buffer
        else if unityMesh.texCoordsCount >= 3, let texCoords2 = unityMesh.texCoords(at: 2) {
            if texCoords2.hasData2, let targetBuffer = texCoords2.data2AsBuffer {
                bitangentBuffer = createTexCoord3Buffer(targetBuffer)
            } else if texCoords2.hasData3, let targetBuffer = texCoords2.data3AsBuffer {
                bitangentBuffer = createTexCoord3Buffer(targetBuffer)
            } else if texCoords2.hasData4, let targetBuffer = texCoords2.data4AsBuffer {
                bitangentBuffer = createTexCoord3Buffer(targetBuffer)
            }
        }

        // RK seems to require this to be a float array (rather than allowing us to use the 32-bit colors directly).
        // I tried byte arrays and int32 arrays, but always ended up with RK crashing.
        var colorBuffer: MeshBuffer<SIMD4<Float>>?
        if colors.count > 0 {
            colorBuffer = .init(.init(unsafeUninitializedCapacity: vertexCount) {
                buffer, initializedCount in for i in 0..<vertexCount {
                    buffer[i] = .init(colors[i])
                }
                initializedCount = vertexCount
            })
        }

        var parts: [MeshResource.Part] = []
        for subMeshIndex in 0..<subMeshesCount {
            let subMesh = subMeshes[subMeshIndex]
            let baseVertexIndex = UInt32(subMesh.baseVertexIndex)
            assert(subMesh.topology == .triangles, "Expected to find triangle topology, found \(subMesh.topology)")

            var part = MeshResource.Part.init(id: "\(id):\(subMeshIndex)", materialIndex: subMeshIndex)
            part.positions = positionBuffer
            part.normals = normalBuffer
            part.tangents = tangentBuffer
            part.bitangents = bitangentBuffer

            for i in 0..<texCoord2Buffers.count {
                let texCoord2Buffer = texCoord2Buffers[i]
                if texCoord2Buffer != nil {
                    if i == 0 {
                        part.textureCoordinates = texCoord2Buffer
                    } else {
                        part[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD2<Float>.self)] = texCoord2Buffer
                    }
                }

                let texCoord3Buffer = texCoord3Buffers[i]
                if texCoord3Buffer != nil {
                    if i == 0 {
                        part[MeshBuffers.custom("vertexUV", type: SIMD3<Float>.self)] = texCoord3Buffer
                    } else {
                        part[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD3<Float>.self)] = texCoord3Buffer
                    }
                }

                let texCoord4Buffer = texCoord4Buffers[i]
                if texCoord4Buffer != nil {
                    if i == 0 {
                        part[MeshBuffers.custom("vertexUV", type: SIMD4<Float>.self)] = texCoord4Buffer
                    } else {
                        part[MeshBuffers.custom("vertexUV\(i)", type: SIMD4<Float>.self)] = texCoord4Buffer
                    }
                }
            }

            // Currently, sampling the vertex colors of geometry that lacks explicit ones returns UV0.
            // We have reported this to Apple as FB13421556.  If they fix that issue, we should remove the
            // fallback white vertex colors so as to conserve memory.
            part[MeshBuffers.custom("vertexColor", type: SIMD4<Float>.self)] =
                colorBuffer ?? .init(repeatElement(.one, count: vertexCount))

            if !unityMesh.indices16.isEmpty {
                let slice = unityMesh.indices16AsBuffer![Int(subMesh.indexStart)..<(Int(subMesh.indexStart + subMesh.indexCount))]
                let subMeshIndices = UnsafeBufferPointer<ushort>(rebasing: slice)

                part.triangleIndices = MeshBuffer<UInt32>.init(.init(unsafeUninitializedCapacity: subMeshIndices.count) {
                    buffer, initializedCount in
                    var index = 0
                    for _ in 0..<subMeshIndices.count/3 {
                        // NOTE: swapping CW for CCW
                        buffer[index + 0] = baseVertexIndex + UInt32(subMeshIndices[index + 0])
                        buffer[index + 1] = baseVertexIndex + UInt32(subMeshIndices[index + 2])
                        buffer[index + 2] = baseVertexIndex + UInt32(subMeshIndices[index + 1])
                        index += 3
                    }
                    initializedCount = subMeshIndices.count
                })
            } else if !unityMesh.indices32.isEmpty {
                let slice = unityMesh.indices32AsBuffer![Int(subMesh.indexStart)..<(Int(subMesh.indexStart + subMesh.indexCount))]
                let subMeshIndices = UnsafeBufferPointer<uint>(rebasing: slice)

                part.triangleIndices = MeshBuffer<UInt32>.init(.init(unsafeUninitializedCapacity: subMeshIndices.count) {
                    buffer, initializedCount in
                    var index = 0
                    for _ in 0..<subMeshIndices.count/3 {
                        // NOTE: swapping CW for CCW
                        buffer[index + 0] = baseVertexIndex + UInt32(subMeshIndices[index + 0])
                        buffer[index + 1] = baseVertexIndex + UInt32(subMeshIndices[index + 2])
                        buffer[index + 2] = baseVertexIndex + UInt32(subMeshIndices[index + 1])
                        index += 3
                    }
                    initializedCount = subMeshIndices.count
                })
            }

            ModifyPart(id, mesh, &part)

            parts.append(part)
        }

        return parts
    }

    func GenerateContents(_ id: PolySpatialAssetID,
                                   _ mesh: UnsafePointer<PolySpatialMesh>?,
                                   _ parts: [MeshResource.Part]) -> MeshResource.Contents {
        var contents = MeshResource.Contents.init()
        contents.models = .init([.init(id: describe(modelId: id), parts: parts)])
        // this is odd, I guess we need a single instance of it, and we reference it by string id?
        contents.instances = .init([.init(id: describe(modelInstanceId: id), model: describe(modelId: id))])

        return contents
    }

    func DeleteMeshAsset(_ id: PolySpatialAssetID) {
        assert(id.isValid)

        // TODO -- same issue as with Materials.  We should go through
        // all the ModelComponents and remove the mesh, but in theory
        // if Unity is telling us that the Mesh is gone, nothing should be referencing
        // it any more.
        meshAssets.removeValue(forKey: id)

        // If we get here, this asset should no longer be referenced by anything,
        // because it's gone on the Unity side.
        if meshOrMaterialReferences[id] != nil && meshOrMaterialReferences[id]!.count != 0 {
            print("Mesh \(id) still in use, has \(meshOrMaterialReferences[id]!.count) references")
        }
    }
}

extension LowLevelMesh.Descriptor: @retroactive Equatable {
    public static func == (lhs: LowLevelMesh.Descriptor, rhs: LowLevelMesh.Descriptor) -> Bool {
        lhs.vertexCapacity == rhs.vertexCapacity &&
        lhs.vertexAttributes == rhs.vertexAttributes &&
        lhs.vertexLayouts == rhs.vertexLayouts &&
        lhs.indexCapacity == rhs.indexCapacity &&
        lhs.indexType == rhs.indexType
    }
}

extension LowLevelMesh.Attribute: @retroactive Equatable {
    public static func == (lhs: LowLevelMesh.Attribute, rhs: LowLevelMesh.Attribute) -> Bool {
        lhs.semantic == rhs.semantic &&
        lhs.format == rhs.format &&
        lhs.layoutIndex == rhs.layoutIndex &&
        lhs.offset == rhs.offset
    }
}

extension LowLevelMesh.Layout: @retroactive Equatable {
    public static func == (lhs: LowLevelMesh.Layout, rhs: LowLevelMesh.Layout) -> Bool {
        lhs.bufferIndex == rhs.bufferIndex &&
        lhs.bufferOffset == rhs.bufferOffset &&
        lhs.bufferStride == rhs.bufferStride
    }
}
