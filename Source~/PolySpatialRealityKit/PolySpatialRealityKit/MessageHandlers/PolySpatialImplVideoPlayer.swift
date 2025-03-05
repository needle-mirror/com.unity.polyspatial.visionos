import Foundation
import RealityKit
import AVFoundation
@_implementationOnly
import FlatBuffers
import UIKit

typealias PolySpatialVideoPlayerData = Unity_PolySpatial_Internals_PolySpatialVideoPlayerData
typealias PolySpatialVideoPlayerState = Unity_PolySpatial_Internals_PolySpatialVideoPlayerState

extension PolySpatialRealityKit {
    // A helper function to take in a mesh and attempt to invert its UV y-origin, returns a copy of the mesh with uv inverted. Useful for native RK materials that expect a certain y-origin.
    func invertMeshUV(_ oldMesh: MeshResource, _ meshId: PolySpatialAssetID) -> MeshResource {
        // For LowLevelMeshes, we flip the UVs with a compute shader.
        if let lowLevelMesh = oldMesh.lowLevelMesh {
            return try! .init(from: invertMeshUV(lowLevelMesh))
        }

        var uvInvertedContents = oldMesh.contents
        var uvInvertedModels: [MeshResource.Model] = []

        for oldModel in oldMesh.contents.models {
            var uvInvertedParts: [MeshResource.Part] = []
            for oldPart in oldModel.parts {
                var part = oldPart

                // There can be more than one UV set.
                for i in 0..<meshAssets[meshId]!.numUVSets {
                    if i == 0 {
                        let oldTextureCoords = oldPart.textureCoordinates!
                        let uvInvertedCoords: [SIMD2<Float>] = .init(
                            unsafeUninitializedCapacity: oldTextureCoords.count,
                            initializingWith: {buffer, initializedCount in
                                for (index, textureCoords) in oldTextureCoords.enumerated() {
                                    buffer[index] = .init(x: textureCoords.x, y: 1 - textureCoords.y)
                                }
                                initializedCount = oldTextureCoords.count
                            })
                        part.textureCoordinates = .init(uvInvertedCoords)
                    }

                    if let oldTextureCoords2 = oldPart[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD2<Float>.self)] {
                        let uvInvertedCoords2: [SIMD2<Float>] = .init(
                            unsafeUninitializedCapacity: oldTextureCoords2.count,
                            initializingWith: {buffer, initializedCount in
                                for (index, textureCoords) in oldTextureCoords2.enumerated() {
                                    buffer[index] = textureCoords.invertYTexCoord()
                                }
                                initializedCount = oldTextureCoords2.count
                            })
                        part[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD2<Float>.self)] = .init(uvInvertedCoords2)
                    }

                    if let oldTextureCoords3 = oldPart[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD3<Float>.self)] {
                        let uvInvertedCoords3: [SIMD3<Float>] = .init(
                            unsafeUninitializedCapacity: oldTextureCoords3.count,
                            initializingWith: {buffer, initializedCount in
                                for (index, textureCoords) in oldTextureCoords3.enumerated() {
                                    buffer[index] = textureCoords.invertYTexCoord()
                                }
                                initializedCount = oldTextureCoords3.count
                            })
                        part[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD3<Float>.self)] = .init(uvInvertedCoords3)
                    }

                    if let oldTextureCoords4 = oldPart[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD4<Float>.self)] {
                        let uvInvertedCoords4: [SIMD4<Float>] = .init(
                            unsafeUninitializedCapacity: oldTextureCoords4.count,
                            initializingWith: {buffer, initializedCount in
                                for (index, textureCoords) in oldTextureCoords4.enumerated() {
                                    buffer[index] = textureCoords.invertYTexCoord()
                                }
                                initializedCount = oldTextureCoords4.count
                            })
                        part[MeshBuffers.custom(describe(vertexUVIndex: i), type: SIMD4<Float>.self)] = .init(uvInvertedCoords4)
                    }
                }
                uvInvertedParts.append(part)
            }
            uvInvertedModels.append(MeshResource.Model.init(id: oldModel.id, parts: uvInvertedParts))
        }

        uvInvertedContents.models = .init(uvInvertedModels)
        return try! MeshResource.generate(from: uvInvertedContents)
    }

    func invertMeshUV(_ oldMesh: LowLevelMesh) -> LowLevelMesh {
        let newMesh = try! LowLevelMesh(descriptor: oldMesh.descriptor)
        newMesh.parts.replaceAll(oldMesh.parts)

        let commandBuffer = mtlCommandQueue!.makeCommandBuffer()!
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!

        // Copy the indices directly.
        let sourceIndexBuffer = oldMesh.readIndices(using: commandBuffer)
        blitCommandEncoder.copy(
            from: sourceIndexBuffer,
            sourceOffset: 0,
            to: newMesh.replaceIndices(using: commandBuffer),
            destinationOffset: 0,
            size: sourceIndexBuffer.length)
        blitCommandEncoder.endEncoding()

        let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!
        let computePipelineState = flipTexCoordsCompute!
        commandEncoder.setComputePipelineState(computePipelineState)
        var vertexCapacity = UInt32(oldMesh.descriptor.vertexCapacity)
        commandEncoder.setBytes(&vertexCapacity, length: MemoryLayout<UInt32>.size, index: 2)

        // Copy/flip each buffer.
        for i in 0..<oldMesh.descriptor.vertexBufferCount {
            commandEncoder.setBuffer(oldMesh.read(bufferIndex: i, using: commandBuffer), offset: 0, index: 0)
            commandEncoder.setBuffer(newMesh.replace(bufferIndex: i, using: commandBuffer), offset: 0, index: 1)

            // When we build the LowLevelMesh, we ensure that we have one and only one layout per vertex buffer.
            var stride = UInt32(oldMesh.descriptor.vertexLayouts[i].bufferStride)
            commandEncoder.setBytes(&stride, length: MemoryLayout<UInt32>.size, index: 3)

            var texCoordOffsets: [UInt32] = []
            for vertexAttribute in oldMesh.descriptor.vertexAttributes {
                if vertexAttribute.layoutIndex != i {
                    continue
                }
                switch vertexAttribute.semantic {
                    case .uv0, .uv1, .uv2, .uv3, .uv4, .uv5, .uv6, .uv7:
                        // We flip the second float (the V coordinate).
                        texCoordOffsets.append(UInt32(vertexAttribute.offset + MemoryLayout<Float>.size))
                    default: break
                }
            }
            // Setting the buffer to "zero" (empty array) causes a "missing buffer binding" exception,
            // so instead we use a single zero value as a placeholder.
            if texCoordOffsets.isEmpty {
                var unusedOffset = UInt32(0)
                commandEncoder.setBytes(&unusedOffset, length: MemoryLayout<UInt32>.size, index: 4)
            } else {
                texCoordOffsets.withUnsafeMutableBytes {
                    commandEncoder.setBytes($0.baseAddress!, length: $0.count, index: 4)
                }
            }
            var texCoordOffsetCount = UInt32(texCoordOffsets.count)
            commandEncoder.setBytes(&texCoordOffsetCount, length: MemoryLayout<UInt32>.size, index: 5)

            commandEncoder.dispatchThreadgroups(
                .init(width: Int(vertexCapacity), height: 1, depth: 1),
                threadsPerThreadgroup: .init(
                    width: computePipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1))
        }

        commandEncoder.endEncoding()
        commandBuffer.commit()

        return newMesh
    }

    // Sets video component first time, optionally inverts mesh uvs.
    func setVideoComponent(_ info: PolySpatialVideoPlayerData, _ rendererEntity: PolySpatialEntity) {
        if !rendererEntity.components.has(ModelComponent.self) || !rendererEntity.components.has(PolySpatialComponents.RenderInfo.self) {
            PolySpatialRealityKit.instance.LogWarning("No model or render component found for mesh entity \(info.meshRendererEntityId!) when setting the video player on it, video player component will not be initialized.")
            return
        }

        let videoUrl = NSURL.fileURL(withPath: info.pathToVideo!)

        let videoComp = PolySpatialComponents.UnityVideoPlayer(videoUrl)
        let modelComp = rendererEntity.components[ModelComponent.self]! as ModelComponent
        let renderComp = rendererEntity.components[PolySpatialComponents.RenderInfo.self]! as PolySpatialComponents.RenderInfo

        rendererEntity.components.set(videoComp)
        if videoComp.invertAndCacheMesh(modelComp.mesh, renderComp.meshId) {
            rendererEntity.components.set(ModelComponent.init(mesh: videoComp.meshAsset!, materials: [videoComp.videoMaterial]))
        }

        videoComp.state = info.playState
        return
    }

    func updateVideoComponent(_ info: PolySpatialVideoPlayerData, _ rendererEntity: PolySpatialEntity, _ firstTimeSetup: Bool) {
        guard let videoComp = rendererEntity.components[PolySpatialComponents.UnityVideoPlayer.self] as PolySpatialComponents.UnityVideoPlayer? else {
            PolySpatialRealityKit.instance.LogWarning("Renderer entity \(rendererEntity) does not have a video component.")
            return
        }

        let newUrl = NSURL.fileURL(withPath: info.pathToVideo!)

        // Url was changed.
        if videoComp.videoUrl != newUrl {
            videoComp.changeUrl(newUrl)

            rendererEntity.components.set(ModelComponent.init(mesh: videoComp.meshAsset!, materials: [videoComp.videoMaterial]))
        }

        // Set up play on awake.
        if firstTimeSetup {
            // Handle first time loop setup.
            videoComp.setLooping(info.isLooping)
            if info.playOnAwake {
                videoComp.player.play()
            } else {
                videoComp.player.pause()
            }
            return
        }

        // Set direct volume and mute.
        videoComp.player.isMuted = info.isMuted
        videoComp.player.volume = info.volume

        // Set up play state if just updating.
        videoComp.setState(info.playState, info.isLooping)
    }

    // Removes video component, optionally restores previous mesh and materials.
    func cleanUpVideoPlayer(_ id: PolySpatialInstanceID) {
        // Video player was deleted or disabled, do some cleanup here.
        guard let oldRenderId = videoPlayerEntityMap[id] else {
            return
        }

        guard let oldRenderEntity = TryGetEntity(oldRenderId) else {
            return
        }

        oldRenderEntity.components.remove(PolySpatialComponents.UnityVideoPlayer.self)
        if oldRenderEntity.components.has(ModelComponent.self) {
            oldRenderEntity.updateModelComponent()
        }

        videoPlayerEntityMap[id] = nil
    }

    // Resets all video players in the identified volume, recreating their assets and video materials/model components.
    func resetVideoPlayers(_ volumeId: PolySpatialInstanceID) {
        for entityId in videoPlayerEntityMap.values {
            guard entityId.hostId == volumeId.hostId, entityId.hostVolumeIndex == volumeId.hostVolumeIndex else {
                continue
            }
            let entity = GetEntity(entityId)
            let videoComp = entity.components[PolySpatialComponents.UnityVideoPlayer.self]!
            let previousState = videoComp.state
            let wasLooping = (videoComp.avPlayerLooper != nil)

            videoComp.changeUrl(videoComp.videoUrl)
            entity.components.set(ModelComponent(mesh: videoComp.meshAsset!, materials: [videoComp.videoMaterial]))
            videoComp.setState(previousState, wasLooping)
        }
    }
}
