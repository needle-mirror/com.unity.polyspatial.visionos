import Metal
import RealityKit

// A singleton that contains the state and functions required to build and manage static batches
// associated with common root objects (or the scene root).
@MainActor
class StaticBatchManager {
    static var instance = StaticBatchManager()

    // The set of static batch roots that need to be updated on the current frame.
    var dirtyStaticBatchRootIds: Set<PolySpatialInstanceID> = []

    // A key used to group static batch elements to PolySpatialEntity instances.  Each PolySpatialEntity
    // can only have one set of lighting parameters (lightmap, light probes, etc.)
    struct StaticBatchKey: Equatable, Hashable {
        let lightmapColorId: PolySpatialAssetID
        let lightmapDirId: PolySpatialAssetID
        let lightmapScaleOffset: simd_float4
        let lightProbeCoefficients: [simd_float4]
        let reflectionProbes: [PolySpatialReflectionProbeData]

        init(_ lightmapColorId: PolySpatialAssetID,
            _ lightmapDirId: PolySpatialAssetID,
            _ lightmapScaleOffset: simd_float4,
            _ lightProbeCoefficients: [simd_float4],
            _ reflectionProbes: [PolySpatialReflectionProbeData]) {

            self.lightmapColorId = lightmapColorId
            self.lightmapDirId = lightmapDirId
            self.lightmapScaleOffset = lightmapScaleOffset
            self.lightProbeCoefficients = lightProbeCoefficients
            self.reflectionProbes = reflectionProbes
        }
    }

    // Updates all static batches associated with the set of dirty static batch root IDs and clears the dirty set.
    func updateStaticBatches()
    {
        if dirtyStaticBatchRootIds.isEmpty {
            return
        }
        for staticBatchRootId in dirtyStaticBatchRootIds {
            updateStaticBatch(staticBatchRootId, getStaticBatchRootEntity(staticBatchRootId)!)
        }
        dirtyStaticBatchRootIds.removeAll()
    }

    // Return the entity associated with the provided static batch root, if any.  Invalid instance IDs resolve to
    // the scene root entity.
    func getStaticBatchRootEntity(_ id: PolySpatialInstanceID) -> Entity? {
        id.isValid ? PolySpatialRealityKit.instance.TryGetEntity(id) :
            PolySpatialRealityKit.instance.viewSubGraphs[Int(id.hostVolumeIndex)]?.root
    }

    // Updates the static batch with the given root id and associated entity, creating one or more children for each
    // batch key (set of lighting parameters) with per-material submeshes.
    func updateStaticBatch(_ id: PolySpatialInstanceID, _ entity: Entity) {
        // Require the presence of a StaticBatchRootInfo with our entity/elements.
        let staticBatchRootInfo = entity.components[PolySpatialComponents.StaticBatchRootInfo.self]!

        // Remove all existing children of the entity.
        staticBatchRootInfo.clearContents()

        // Create the mapping from static batch keys to elements.
        var staticBatchKeysToElements: Dictionary<StaticBatchKey, [PolySpatialEntity]> = [:]
        for element in staticBatchRootInfo.elements {
            staticBatchKeysToElements[element.renderInfo.staticBatchKey, default: []].append(element)
        }

        // Create one or more merged entities for each batch key.
        for (staticBatchKey, elements) in staticBatchKeysToElements {
            // Stores all buffers used for a material and their types so that we can compute size requirements.
            struct BufferSummary {
                var elementTypes: Dictionary<MeshBuffers.Identifier, MeshBuffers.ElementType> = [:]
                var bytesPerVertex = 0

                mutating func add(_ part: MeshResource.Part) {
                    for (identifier, buffer) in part.buffers {
                        if elementTypes.updateValue(buffer.elementType, forKey: identifier) == nil {
                            switch buffer.elementType {
                                case .simd2Float: bytesPerVertex += MemoryLayout<simd_float2>.size
                                case .simd3Float: bytesPerVertex += MemoryLayout<simd_float3>.size
                                case .simd4Float: bytesPerVertex += MemoryLayout<simd_float4>.size
                                default: break // UInt32 for indices; added separately.
                            }
                        }
                    }
                }
            }
            var materialBufferSummaries: Dictionary<PolySpatialAssetID, BufferSummary> = [:]

            // Stores a part to merge along with its material id and transform/normal matrices.
            struct MergePart {
                let element: PolySpatialEntity
                let materialId: PolySpatialAssetID
                let part: MeshResource.Part
                let transformMatrix: simd_float4x4
                let normalMatrix: simd_float3x3

                init(
                    _ element: PolySpatialEntity, _ materialId: PolySpatialAssetID,
                    _ part: MeshResource.Part, _ transformMatrix: simd_float4x4) {

                    self.element = element
                    self.materialId = materialId
                    self.part = part
                    self.transformMatrix = transformMatrix
                    self.normalMatrix = simd_inverse(simd_transpose(simd_float3x3(
                        transformMatrix.columns.0.xyz, transformMatrix.columns.1.xyz, transformMatrix.columns.2.xyz)))
                }
            }
            var mergeParts: [MergePart] = []

            // Like BufferSummary, but for LowLevelMeshes.
            @MainActor
            struct LowLevelBufferSummary {
                var semanticFormats: Dictionary<LowLevelMesh.VertexSemantic, MTLVertexFormat> = [:]

                var bytesPerVertex: Int {
                    semanticFormats.values.map({ $0.size() }).reduce(0, +)
                }

                mutating func add(_ lowLevelMesh: LowLevelMesh) {
                    for vertexAttribute in lowLevelMesh.descriptor.vertexAttributes {
                        guard let existingFormat = semanticFormats[vertexAttribute.semantic] else {
                            semanticFormats[vertexAttribute.semantic] = vertexAttribute.format
                            continue
                        }
                        // Promote UVs to higher vector types, colors to floats.
                        switch (existingFormat, vertexAttribute.format) {
                            case (.float2, .float3):
                                semanticFormats[vertexAttribute.semantic] = .float3
                            case (.float2, .float4), (.float3, .float4), (.uchar4Normalized, .float4):
                                semanticFormats[vertexAttribute.semantic] = .float4
                            default: break
                        }
                    }
                }
            }
            var lowLevelMaterialBufferSummaries: Dictionary<PolySpatialAssetID, LowLevelBufferSummary> = [:]

            // Like MergePart, but for LowLevelMeshes.
            struct LowLevelMergePart {
                let element: PolySpatialEntity
                let materialId: PolySpatialAssetID
                let lowLevelMesh: LowLevelMesh
                let part: LowLevelMesh.Part
                let vertexRange: Range<Int>
                let transformMatrix: simd_float4x4
                let normalMatrix: simd_float3x3

                var vertexCount: Int { vertexRange.upperBound - vertexRange.lowerBound }

                init(
                    _ element: PolySpatialEntity, _ materialId: PolySpatialAssetID, _ lowLevelMesh: LowLevelMesh,
                    _ part: LowLevelMesh.Part, _ vertexRange: Range<Int>, _ transformMatrix: simd_float4x4) {

                    self.element = element
                    self.materialId = materialId
                    self.lowLevelMesh = lowLevelMesh
                    self.part = part
                    self.vertexRange = vertexRange
                    self.transformMatrix = transformMatrix
                    self.normalMatrix = simd_inverse(simd_transpose(simd_float3x3(
                        transformMatrix.columns.0.xyz, transformMatrix.columns.1.xyz, transformMatrix.columns.2.xyz)))
                }
            }
            var lowLevelMergeParts: [LowLevelMergePart] = []
            var lowLevelMergedBounds = BoundingBox.empty

            // Collect the per-material buffer summaries and all the parts we need to merge for the key.
            for element in elements {
                let renderInfo = element.renderInfo
                let mesh = renderInfo.mesh

                // Populate the materialBufferSummaries/mergeParts for either low-level or CPU meshes.
                if let lowLevelMesh = mesh.lowLevelMesh {
                    let vertexRanges =
                        PolySpatialRealityKit.instance.getMeshAssetForId(renderInfo.meshId).lowLevelMeshVertexRanges
                    for (part, vertexRange) in zip(lowLevelMesh.parts, vertexRanges) {
                        if part.materialIndex < renderInfo.materialIds.count {
                            let materialId = renderInfo.materialIds[part.materialIndex]
                            lowLevelMaterialBufferSummaries[materialId, default: .init()].add(lowLevelMesh)
                            let transformMatrix = element.transformMatrix(relativeTo: entity)
                            lowLevelMergeParts.append(.init(
                                element, materialId, lowLevelMesh, part, vertexRange, transformMatrix))
                            lowLevelMergedBounds.formUnion(part.bounds.transformed(by: transformMatrix))
                        }
                    }
                } else {
                    for model in mesh.contents.models {
                        for part in model.parts {
                            if part.materialIndex < renderInfo.materialIds.count {
                                let materialId = renderInfo.materialIds[part.materialIndex]
                                materialBufferSummaries[materialId, default: .init()].add(part)
                                mergeParts.append(.init(
                                    element, materialId, part, element.transformMatrix(relativeTo: entity)))
                            }
                        }
                    }
                }
            }

            // Sort the parts by material so that parts of the same material will be grouped together.
            mergeParts.sort { $0.materialId < $1.materialId }

            // Adds a new entity containing the merge parts within the supplied range.
            func addMergedEntity(_ range: Range<Int>) {
                // Count the vertices and indices for each material in the range.
                struct BufferTotals {
                    var vertices = 0
                    var indices = 0

                    mutating func add(_ part: MeshResource.Part) {
                        vertices += part.positions.count
                        indices += part.triangleIndices!.count
                    }
                }
                var materialIdToBufferTotals: Dictionary<PolySpatialAssetID, BufferTotals> = [:]

                for mergePart in mergeParts[range] {
                    materialIdToBufferTotals[mergePart.materialId, default: .init()].add(mergePart.part)
                }

                // Merges the indices for the parts with the specified material, creating a new buffer.
                func mergeIndices(_ materialId: PolySpatialAssetID, _ size: Int) -> MeshBuffer<UInt32> {
                    .init(.init(unsafeUninitializedCapacity: size) { buffer, initializedCount in
                        var bufferIndex = 0
                        var indexOffset: UInt32 = 0
                        for mergePart in mergeParts[range].filter({ $0.materialId == materialId }) {
                            // Each index is offset by the number of vertices in preceding parts.
                            for index in mergePart.part.triangleIndices! {
                                buffer[bufferIndex] = index + indexOffset
                                bufferIndex += 1
                            }
                            indexOffset += UInt32(mergePart.part.positions.count)
                        }
                        initializedCount = size
                    })
                }

                // Merges the positions, normals, tangents, or bitangents for the parts with the specified material.
                func mergeVectors(
                    _ materialId: PolySpatialAssetID,
                    _ size: Int,
                    _ identifier: MeshBuffers.Identifier,
                    _ isPosition: Bool) -> MeshBuffer<simd_float3> {

                    .init(.init(unsafeUninitializedCapacity: size) { buffer, initializedCount in
                        var bufferIndex = 0
                        for mergePart in mergeParts[range].filter({ $0.materialId == materialId }) {
                            if let source = mergePart.part.buffers[identifier]?.get(simd_float3.self) {
                                if isPosition {
                                    for value in source {
                                        buffer[bufferIndex] = (mergePart.transformMatrix * simd_float4(value, 1)).xyz
                                        bufferIndex += 1
                                    }
                                } else {
                                    for value in source {
                                        buffer[bufferIndex] = mergePart.normalMatrix * value
                                        bufferIndex += 1
                                    }
                                }
                            } else {
                                // If the buffer isn't present, just initialize to zero.
                                for _ in 0..<mergePart.part.positions.count {
                                    buffer[bufferIndex] = .init()
                                    bufferIndex += 1
                                }
                            }
                        }
                        initializedCount = size
                    })
                }

                // Used in mergeFloat[2, 3, 4], this creates an array initializer for a merged buffer.
                func createMergeInitializer<T>(
                    _ materialId: PolySpatialAssetID, _ size: Int, _ identifier: MeshBuffers.Identifier) ->
                        (inout UnsafeMutableBufferPointer<T>, inout Int) -> Void where T: SIMD<Float> {
                    { buffer, initializedCount in
                        var bufferIndex = 0
                        for mergePart in mergeParts[range].filter({ $0.materialId == materialId }) {
                            if let source = mergePart.part.buffers[identifier]?.get(T.self) {
                                for value in source {
                                    buffer[bufferIndex] = value
                                    bufferIndex += 1
                                }
                            } else {
                                // If the buffer isn't present, just initialize to zero.
                                for _ in 0..<mergePart.part.positions.count {
                                    buffer[bufferIndex] = .zero
                                    bufferIndex += 1
                                }
                            }
                        }
                        initializedCount = size
                    }
                }

                // There's no generic version of MeshBuffer.init, so the best we can do is have a generic
                // array initializer creator and a set of type-specific functions that call it.
                func mergeFloat2(
                    _ materialId: PolySpatialAssetID,
                    _ size: Int,
                    _ identifier: MeshBuffers.Identifier) -> MeshBuffer<simd_float2> {

                    .init(.init(
                        unsafeUninitializedCapacity: size,
                        initializingWith: createMergeInitializer(materialId, size, identifier)))
                }
                func mergeFloat3(
                    _ materialId: PolySpatialAssetID,
                    _ size: Int,
                    _ identifier: MeshBuffers.Identifier) -> MeshBuffer<simd_float3> {

                    .init(.init(
                        unsafeUninitializedCapacity: size,
                        initializingWith: createMergeInitializer(materialId, size, identifier)))
                }
                func mergeFloat4(
                    _ materialId: PolySpatialAssetID,
                    _ size: Int,
                    _ identifier: MeshBuffers.Identifier) -> MeshBuffer<simd_float4> {

                    .init(.init(
                        unsafeUninitializedCapacity: size,
                        initializingWith: createMergeInitializer(materialId, size, identifier)))
                }

                // Create the mesh contents by merging all merge parts with the same material.
                let parts = materialIdToBufferTotals.enumerated().map() {
                    let (index, (materialId, totals)) = $0
                    var part = MeshResource.Part(id: "\(id):\(index)", materialIndex: index)
                    for (identifier, elementType) in materialBufferSummaries[materialId]!.elementTypes {
                        switch identifier.name {
                            case MeshBuffers.Identifier.triangleIndices.name:
                                part.triangleIndices = mergeIndices(materialId, totals.indices)
                            case MeshBuffers.Identifier.positions.name:
                                part.positions = mergeVectors(materialId, totals.vertices, identifier, true)
                            case MeshBuffers.Identifier.normals.name:
                                part.normals = mergeVectors(materialId, totals.vertices, identifier, false)
                            case MeshBuffers.Identifier.tangents.name:
                                part.tangents = mergeVectors(materialId, totals.vertices, identifier, false)
                            case MeshBuffers.Identifier.bitangents.name:
                                part.bitangents = mergeVectors(materialId, totals.vertices, identifier, false)
                            case MeshBuffers.Identifier.textureCoordinates.name:
                                part.textureCoordinates = mergeFloat2(materialId, totals.vertices, identifier)
                            default:
                                switch elementType {
                                    case .simd2Float:
                                        part[MeshBuffers.custom(identifier.name, type: simd_float2.self)] =
                                            mergeFloat2(materialId, totals.vertices, identifier)
                                    case .simd3Float:
                                        part[MeshBuffers.custom(identifier.name, type: simd_float3.self)] =
                                            mergeFloat3(materialId, totals.vertices, identifier)
                                    case .simd4Float:
                                        part[MeshBuffers.custom(identifier.name, type: simd_float4.self)] =
                                            mergeFloat4(materialId, totals.vertices, identifier)
                                    default:
                                        PolySpatialRealityKit.LogError(
                                            "Unsupported vertex buffer type: \(elementType)")
                                }
                        }
                    }
                    return part
                }

                var contents = MeshResource.Contents()
                let modelId = "\(id):model"
                contents.models = .init([.init(id: modelId, parts: parts)])
                contents.instances = .init([.init(id: "\(id):instance", model: modelId)])

                let child = PolySpatialEntity(id)
                child.setParent(staticBatchRootInfo.entity)
                child.setRenderInfo(.init(
                    try! MeshResource.generate(from: contents),
                    .init(materialIdToBufferTotals.keys),
                    staticBatchKey))

                // Merge any synchronized components from any of the elements.
                for mergePart in mergeParts[range] {
                    mergePart.element.updateBackingEntityComponents(child, false)
                }
            }

            // Add the parts by range, splitting into separate entities to keep buffer sizes below the limit.
            func addRange(_ range: Range<Int>) {
                // Find the total bytes that would be used to store all the parts in the range.
                let totalBytes = mergeParts[range].map { mergePart in
                    mergePart.part.triangleIndices!.count * MemoryLayout<UInt32>.size +
                        mergePart.part.positions.count * materialBufferSummaries[mergePart.materialId]!.bytesPerVertex
                }.reduce(0, +)

                // Metal buffers must be under 256MB, or else an assertion is raised in debug builds.
                let kMaxBytesPerBuffer = 256 * 1024 * 1024
                if totalBytes <= kMaxBytesPerBuffer {
                    addMergedEntity(range)
                } else if range.upperBound - range.lowerBound >= 2 {
                    let midpoint = (range.lowerBound + range.upperBound) / 2
                    addRange(range.lowerBound..<midpoint)
                    addRange(midpoint..<range.upperBound)
                } else {
                    PolySpatialRealityKit.LogError("Merge part exceeds Metal buffer limit: \(totalBytes)")
                }
            }
            if !mergeParts.isEmpty {
                addRange(0..<mergeParts.count)
            }

            // Sort the parts by material so that parts of the same material will be grouped together.
            lowLevelMergeParts.sort { $0.materialId < $1.materialId }

            // We delay creating the command buffer/encoder until we actually need them.
            var existingCommandBuffer: MTLCommandBuffer?
            var existingCommandEncoder: MTLComputeCommandEncoder?

            // Adds a new entity containing the merge parts within the supplied range.
            func addLowLevelMergedEntity(_ range: Range<Int>) {
                // Count the vertices and indices for each material in the range.
                @MainActor
                struct BufferTotals {
                    var vertices = 0
                    var indices = 0

                    mutating func add(_ mergePart: LowLevelMergePart) {
                        vertices += mergePart.vertexCount
                        indices += mergePart.part.indexCount
                    }
                }
                var materialIdToBufferTotals: Dictionary<PolySpatialAssetID, BufferTotals> = [:]

                for mergePart in lowLevelMergeParts[range] {
                    materialIdToBufferTotals[mergePart.materialId, default: .init()].add(mergePart)
                }

                // Each material in the range gets its own LowLevelMesh, since they may have different attributes.
                for (materialId, bufferTotals) in materialIdToBufferTotals {
                    let bufferSummary = lowLevelMaterialBufferSummaries[materialId]!

                    var semanticAttributes: [LowLevelMesh.VertexSemantic: LowLevelMesh.Attribute] = [:]
                    var attributeOffset = 0
                    for semantic in PolySpatialRealityKit.orderedVertexSemantics {
                        if let format = bufferSummary.semanticFormats[semantic] {
                            semanticAttributes[semantic] = .init(
                                semantic: semantic, format: format, layoutIndex: 0, offset: attributeOffset)
                            attributeOffset += format.size()
                        }
                    }

                    let lowLevelMesh = try! LowLevelMesh(descriptor: .init(
                        vertexCapacity: bufferTotals.vertices,
                        vertexAttributes: .init(semanticAttributes.values),
                        vertexLayouts: [.init(bufferIndex: 0, bufferOffset: 0, bufferStride: attributeOffset)],
                        indexCapacity: bufferTotals.indices,
                        indexType: .uint32))

                    // Create the command buffer/encoder if we haven't done so already.
                    let commandBuffer: MTLCommandBuffer
                    let commandEncoder: MTLComputeCommandEncoder
                    if let existingCommandBuffer, let existingCommandEncoder {
                        commandBuffer = existingCommandBuffer
                        commandEncoder = existingCommandEncoder
                    } else {
                        commandBuffer = PolySpatialRealityKit.instance.mtlCommandQueue!.makeCommandBuffer()!
                        existingCommandBuffer = commandBuffer
                        commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!
                        existingCommandEncoder = commandEncoder
                    }

                    let child = PolySpatialEntity(id)
                    child.setParent(staticBatchRootInfo.entity)

                    var destOffset = UInt32(0)
                    var baseVertex = UInt32(0)
                    for mergePart in lowLevelMergeParts[range] {
                        if mergePart.materialId != materialId {
                            continue
                        }
                        // Merge any synchronized components from any of the elements.
                        mergePart.element.updateBackingEntityComponents(child, false)

                        // Transfer the vertices with their transforms.
                        var computePipelineState = PolySpatialRealityKit.instance.batchVerticesCompute!
                        commandEncoder.setComputePipelineState(computePipelineState)

                        commandEncoder.setBuffer(
                            lowLevelMesh.replace(bufferIndex: 0, using: commandBuffer), offset: 0, index: 1)
                        var vertexCount = UInt32(mergePart.vertexCount)
                        commandEncoder.setBytes(&vertexCount, length: MemoryLayout<UInt32>.size, index: 2)
                        var destStride = UInt32(attributeOffset)
                        commandEncoder.setBytes(&destStride, length: MemoryLayout<UInt32>.size, index: 4)
                        var destStart = baseVertex * destStride
                        commandEncoder.setBytes(&destStart, length: MemoryLayout<UInt32>.size, index: 6)
                        var transformMatrix = mergePart.transformMatrix
                        commandEncoder.setBytes(&transformMatrix, length: MemoryLayout<simd_float4x4>.size, index: 7)
                        var normalMatrix = mergePart.normalMatrix
                        commandEncoder.setBytes(&normalMatrix, length: MemoryLayout<simd_float3x3>.size, index: 8)

                        // We assign one buffer per layout when we create the LowLevelMesh.
                        for layout in mergePart.lowLevelMesh.descriptor.vertexLayouts {
                            commandEncoder.setBuffer(
                                mergePart.lowLevelMesh.read(bufferIndex: layout.bufferIndex, using: commandBuffer),
                                offset: 0, index: 0)
                            var sourceStride = UInt32(layout.bufferStride)
                            commandEncoder.setBytes(&sourceStride, length: MemoryLayout<UInt32>.size, index: 3)
                            var sourceStart = UInt32(mergePart.vertexRange.lowerBound * layout.bufferStride)
                            commandEncoder.setBytes(&sourceStart, length: MemoryLayout<UInt32>.size, index: 5)

                            // Matches the BatchExtents struct in ComputeShaders.metal.
                            struct BatchExtents {
                                let sourceOffset: Int32
                                let destOffset: Int32
                                let sourceSize: Int32
                                let destSize: Int32
                            }

                            // Start off with position/normal/tangent/bitangent/color set to "unused."
                            var unusedExtents = BatchExtents(
                                sourceOffset: -1, destOffset: -1, sourceSize: -1, destSize: -1)
                            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 9)
                            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 10)
                            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 11)
                            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 12)
                            commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 13)

                            var texCoordExtents: [BatchExtents] = []
                            for sourceAttribute in mergePart.lowLevelMesh.descriptor.vertexAttributes {
                                if sourceAttribute.layoutIndex != layout.bufferIndex {
                                    continue
                                }
                                let destAttribute = semanticAttributes[sourceAttribute.semantic]!
                                var extents = BatchExtents(
                                    sourceOffset: Int32(sourceAttribute.offset),
                                    destOffset: Int32(destAttribute.offset),
                                    sourceSize: Int32(sourceAttribute.format.size()),
                                    destSize: Int32(destAttribute.format.size()))
                                switch sourceAttribute.semantic {
                                    case .position:
                                        commandEncoder.setBytes(&extents, length: MemoryLayout<BatchExtents>.size, index: 9)
                                    case .normal:
                                        commandEncoder.setBytes(&extents, length: MemoryLayout<BatchExtents>.size, index: 10)
                                    case .tangent:
                                        commandEncoder.setBytes(&extents, length: MemoryLayout<BatchExtents>.size, index: 11)
                                    case .bitangent:
                                        commandEncoder.setBytes(&extents, length: MemoryLayout<BatchExtents>.size, index: 12)
                                    case .color:
                                        commandEncoder.setBytes(&extents, length: MemoryLayout<BatchExtents>.size, index: 13)
                                    case .uv0, .uv1, .uv2, .uv3, .uv4, .uv5, .uv6, .uv7:
                                        texCoordExtents.append(extents)
                                    default:
                                        fatalError("Unsupported semantic: \(sourceAttribute.semantic)")
                                }
                            }
                            // Setting the buffer to "zero" (empty array) causes a "missing buffer binding" exception,
                            // so instead we use a single unused extents struct as a placeholder.
                            if texCoordExtents.isEmpty {
                                commandEncoder.setBytes(&unusedExtents, length: MemoryLayout<BatchExtents>.size, index: 14)
                            } else {
                                texCoordExtents.withUnsafeMutableBytes {
                                    commandEncoder.setBytes($0.baseAddress!, length: $0.count, index: 14)
                                }
                            }
                            var texCoordExtentsCount = UInt32(texCoordExtents.count)
                            commandEncoder.setBytes(&texCoordExtentsCount, length: MemoryLayout<UInt32>.size, index: 15)

                            commandEncoder.dispatchThreadgroups(
                                .init(width: mergePart.vertexCount, height: 1, depth: 1),
                                threadsPerThreadgroup: .init(
                                    width: computePipelineState.maxTotalThreadsPerThreadgroup,
                                    height: 1, depth: 1))
                        }

                        // Transfer the indices with an offset.
                        computePipelineState = PolySpatialRealityKit.instance.batchIndicesCompute!
                        commandEncoder.setComputePipelineState(computePipelineState)

                        commandEncoder.setBuffer(
                            mergePart.lowLevelMesh.readIndices(using: commandBuffer), offset: 0, index: 0)
                        commandEncoder.setBuffer(lowLevelMesh.replaceIndices(using: commandBuffer), offset: 0, index: 1)
                        var indexCount = UInt32(mergePart.part.indexCount)
                        commandEncoder.setBytes(&indexCount, length: MemoryLayout<UInt32>.size, index: 2)
                        var sourceOffset = UInt32(mergePart.part.indexOffset / MemoryLayout<UInt32>.size)
                        commandEncoder.setBytes(&sourceOffset, length: MemoryLayout<UInt32>.size, index: 3)
                        commandEncoder.setBytes(&destOffset, length: MemoryLayout<UInt32>.size, index: 4)
                        var indexDelta = Int32(Int(baseVertex) - mergePart.vertexRange.lowerBound)
                        commandEncoder.setBytes(&indexDelta, length: MemoryLayout<Int32>.size, index: 5)

                        commandEncoder.dispatchThreadgroups(
                            .init(width: mergePart.part.indexCount, height: 1, depth: 1),
                            threadsPerThreadgroup: .init(
                                width: computePipelineState.maxTotalThreadsPerThreadgroup,
                                height: 1, depth: 1))

                        destOffset += indexCount
                        baseVertex += vertexCount
                    }
                    lowLevelMesh.parts.append(.init(
                        indexOffset: 0, indexCount: bufferTotals.indices,
                        topology: .triangle, materialIndex: 0, bounds: lowLevelMergedBounds))

                    child.setRenderInfo(.init(try! .init(from: lowLevelMesh), [materialId], staticBatchKey))
                }
            }

            // Add the parts by range, splitting into separate entities to keep buffer sizes below the limit.
            func addLowLevelRange(_ range: Range<Int>) {
                // Find the total bytes that would be used to store all the parts in the range.
                var totalIndexBytes = 0
                var totalVertexBytes = 0
                for mergePart in lowLevelMergeParts[range] {
                    totalIndexBytes += mergePart.part.indexCount * MemoryLayout<UInt32>.size
                    totalVertexBytes += mergePart.vertexCount *
                        lowLevelMaterialBufferSummaries[mergePart.materialId]!.bytesPerVertex
                }

                // Metal buffers must be under 256MB, or else an assertion is raised in debug builds.
                let kMaxBytesPerBuffer = 256 * 1024 * 1024
                if totalIndexBytes <= kMaxBytesPerBuffer && totalVertexBytes <= kMaxBytesPerBuffer {
                    addLowLevelMergedEntity(range)
                } else if range.upperBound - range.lowerBound >= 2 {
                    let midpoint = (range.lowerBound + range.upperBound) / 2
                    addLowLevelRange(range.lowerBound..<midpoint)
                    addLowLevelRange(midpoint..<range.upperBound)
                } else {
                    PolySpatialRealityKit.LogError(
                        "Merge part exceeds Metal buffer limit: \(totalIndexBytes) index, \(totalVertexBytes) vertex")
                }
            }
            if !lowLevelMergeParts.isEmpty {
                addLowLevelRange(0..<lowLevelMergeParts.count)
            }

            if let commandEncoder = existingCommandEncoder, let commandBuffer = existingCommandBuffer {
                commandEncoder.endEncoding()
                commandBuffer.commit()
            }
        }
    }
}

extension MTLVertexFormat {
    func size() -> Int {
        switch self {
            case .float, .uchar4Normalized: 4
            case .float2: 8
            case .float3: 12
            case .float4: 16
            default: fatalError("Unsupported vertex format: \(self)")
        }
    }
}
