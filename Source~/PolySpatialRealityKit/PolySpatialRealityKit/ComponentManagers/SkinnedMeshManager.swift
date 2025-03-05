import Foundation
import RealityKit

@MainActor
class SkinnedMeshManager {
    // Stores everything we need to generate the skinned mesh.
    struct SkinnedMeshContents {
        var asset: PolySpatialRealityKit.MeshAsset
        var skeletonName: String
        var bindPoses: [simd_float4x4]
    }

    // The backing entity acts as the root of the skeleton and caches data about bone ids and transforms.
    class UnitySkeletonData: Component {
        var cachedJointTransforms: [Transform]
        var bones: [PolySpatialInstanceID]
        init (_ bones: [PolySpatialInstanceID]) {
            self.bones = bones
            self.cachedJointTransforms = .init(repeating: Transform(), count: bones.count)
        }
    }

    // Each PolySpatialEntity that is part of a skeleton should have this component.
    class UnityBoneComponent: Component {
        var boneIndexMapping: [PolySpatialEntity: Int] = [:]

        init (_ smrInstanceId: PolySpatialInstanceID,
              _ backEntity: PolySpatialEntity,
              _ jointIndex: Int) {
            self.boneIndexMapping[backEntity] = jointIndex
        }

        // Adds all skeletons (backing entities) this bone is a part of to a list of all dirty skeletons, so they can be batch-processed.
        func MarkSkeletonDirty(_ dirtySkinnedMeshes: inout Set<PolySpatialEntity>) {
            for mapping in boneIndexMapping {
                dirtySkinnedMeshes.insert(mapping.key)
            }
        }
    }

    // Used to store the precursor materials to the skinned mesh.
    public var cachedSkinnedMeshes: [PolySpatialAssetID: SkinnedMeshContents] = [:]

    private var skinnedMeshAssetIdToBackingEntity: [PolySpatialAssetID: PolySpatialEntity] = [:]

    // A list of skinned meshes which have dirty transforms and need to be updated.
    private var dirtySkinnedMeshes: Set<(PolySpatialEntity)> = .init()

    // Entities which have had their joint transforms and/or blend shape weights updated on the current frame.
    public var dirtyBlendedMeshInstances: Set<PolySpatialEntity> = []

    // Convenience function for generating a skeleton name - the skeleton name in the mesh part and the skeleton name when calling MeshResource.Skeleton must match, otherwise it won't be recognized.
    public func GenerateSkeletonName(_ entityId: PolySpatialAssetID) -> String {
        return "Skeleton: \(entityId)"
    }

    public func CacheSkinnedMeshContents(_ skinnedMeshAssetId: PolySpatialAssetID,
                                         _ asset: PolySpatialRealityKit.MeshAsset,
                                         _ bindPoses: [simd_float4x4]) {
        cachedSkinnedMeshes[skinnedMeshAssetId] = SkinnedMeshContents(
            asset: asset,
            skeletonName: GenerateSkeletonName(skinnedMeshAssetId),
            bindPoses: bindPoses)
    }

    // Generates a skinned mesh from cached mesh contents with a skeleton that has a flattened bone hierarchy. These bones will be parented to whatever entity that receives this skinned mesh.
    public func GenerateSkinnedMesh(_ meshId: PolySpatialAssetID,
                                    _ boneCount: Int32) {
        if let cachedMesh = cachedSkinnedMeshes[meshId] {
            guard boneCount > 0 else {
                PolySpatialRealityKit.LogError("Bone count was 0 while generating skinned mesh: \(meshId).")
                return
            }

            let boneCountInt = Int(boneCount)

            var jointNamesBuffer = [String](repeating: "", count: boneCountInt)
            for index in 0..<jointNamesBuffer.count {
                jointNamesBuffer[index] = "Bone_\(index)"
            }

            let skeleton = MeshResource.Skeleton(id: cachedMesh.skeletonName,
                                                      jointNames: jointNamesBuffer,
                                                      inverseBindPoseMatrices: cachedMesh.bindPoses)

            var newContents = cachedMesh.asset.contents
            newContents.skeletons = [skeleton!]

            // Cache this newly generated mesh asset so we can use it (and delete it) like any other mesh asset.
            // Deleting the contents of skinnedMeshAssets means we'll have to regenerate the mesh each time there's a
            // change to the skinned mesh asset but that might okay given how infrequently it should change and how
            // precisely the skeleton/model needs to fit each other.
            PolySpatialRealityKit.instance.UpdateMeshDefinition(
                meshId, .init(newContents, cachedMesh.asset.numUVSets, cachedMesh.asset.blendShapes))
            cachedSkinnedMeshes.removeValue(forKey: meshId)
        }
    }

    public func InitializeBoneMapping(_ info: PolySpatialSkinnedRendererData,
                                      _ originalEntity: PolySpatialEntity,
                                      _ skinnedMeshInstanceId: PolySpatialInstanceID,
                                      _ boneCount: Int) -> PolySpatialEntity {
        // Create backing entity on RK side, and make it a child of the parent of the root bone (according to Unity). If parent doesn't exist, make it a child of the root entity.
        let backingEntity = PolySpatialEntity.init(skinnedMeshInstanceId)

        // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
        let rootBoneId = PolySpatialInstanceID(
            id: info.rootBoneId.id, hostId: skinnedMeshInstanceId.hostId,
            hostVolumeIndex: skinnedMeshInstanceId.hostVolumeIndex)

        // Parent to the root bone if we have blend shapes; otherwise, to the parent of the root bone.  We parent to
        // the root bone for blended meshes so that the local bounds supplied to the LowLevelMesh (parts) will be transformed
        // correctly into world space.
        let meshAsset = PolySpatialRealityKit.instance.getMeshAssetForId(info.renderData!.meshId!)
        let parentEntity: Entity
        if meshAsset.blendShapes.count > 0 {
            // If the root bone is not supplied, we parent to the original entity.
            parentEntity = rootBoneId.isValid ? PolySpatialRealityKit.instance.GetEntity(rootBoneId) : originalEntity
        } else {
            parentEntity = PolySpatialRealityKit.instance.TryGetEntity(rootBoneId)?.parent ??
                PolySpatialRealityKit.instance.GetRootEntity(skinnedMeshInstanceId)
        }

        backingEntity.setParent(parentEntity)
        let boneIds = info.skeletonBoneIdsAsBuffer!

        var skeletonBones = Array(repeating: PolySpatialInstanceID(), count: boneCount)
        var boneIndex = 0
        for originalBoneId in boneIds {
            // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
            let boneId = PolySpatialInstanceID.init(id: originalBoneId.id, hostId: skinnedMeshInstanceId.hostId, hostVolumeIndex: skinnedMeshInstanceId.hostVolumeIndex)

            guard let boneEntity = PolySpatialRealityKit.instance.TryGetEntity(boneId) else {
                PolySpatialRealityKit.LogWarning("Skinned mesh renderer \(originalEntity.name) was missing a bone during skeleton initialization. If a skinned mesh renderer is using a game object as a bone, do not delete that game object.")
                continue
            }

            skeletonBones[boneIndex] = boneId

            if boneEntity.components.has(UnityBoneComponent.self) {
                let existingComponent = boneEntity.components[UnityBoneComponent.self]! as UnityBoneComponent
                existingComponent.boneIndexMapping[backingEntity] = boneIndex
            } else {
                boneEntity.components[UnityBoneComponent.self] = .init(skinnedMeshInstanceId, backingEntity, boneIndex)
            }

            boneIndex += 1

            MarkSkeletonDirty(boneEntity)
        }

        backingEntity.name = originalEntity.name + " Backing Entity"
        backingEntity.isEnabled = originalEntity.isEnabled

        // Ensure the backing entity transform is always identity.
        backingEntity.transform = .identity
        backingEntity.components[UnitySkeletonData.self] = .init(skeletonBones)

        // Link the original entity to the backing entity, allowing it to synchronize state.
        originalEntity.skinnedBackingEntity = backingEntity

        return backingEntity
    }

    public func MarkSkeletonDirty(_ boneEntity: PolySpatialEntity) {
        if boneEntity.components.has(UnityBoneComponent.self) {
            let boneComponent = boneEntity.components[UnityBoneComponent.self]! as UnityBoneComponent
            boneComponent.MarkSkeletonDirty(&dirtySkinnedMeshes)
        }
    }

    public func UpdateDirtySkeletons() {
        for backingEntity in dirtySkinnedMeshes {
            let skeletonData = backingEntity.components[UnitySkeletonData.self]! as UnitySkeletonData

            // This caching is not used right now, but in future can be used to reduce the number of calculations we have to do.
            var cachedTransforms = skeletonData.cachedJointTransforms

            var boneIndex = 0
            for bone in skeletonData.bones {
                guard let boneEntity = PolySpatialRealityKit.instance.TryGetEntity(bone) else {
                    // Commented out this warning message - this is called too many times and will flood logs. Additionally, Unity allows for silent deletion of bones during runtime without issue.
                    continue
                }
                let modelSpaceTransform = boneEntity.convert(transform: Transform.identity, to: backingEntity)
                cachedTransforms[boneIndex] = modelSpaceTransform
                boneIndex += 1
            }

            backingEntity.blendJointTransforms = cachedTransforms
        }
        dirtySkinnedMeshes.removeAll(keepingCapacity: true)
    }

    public func updateBlendedMeshInstances() {
        for entity in dirtyBlendedMeshInstances {
            entity.updateBlendedMeshInstance()
        }
        dirtyBlendedMeshInstances.removeAll()
    }

    public func CleanUpSkinnedMeshCaches(_ id: PolySpatialInstanceID) {
        let entity = PolySpatialRealityKit.instance.GetEntity(id)
        guard let backingEntity = entity.skinnedBackingEntity else {
            return
        }

        backingEntity.isEnabled = false

        let skeleton = backingEntity.components[UnitySkeletonData.self]! as UnitySkeletonData
        // Find all the polyspatial entities and remove references to this skinned mesh within their bone components.
        for boneId in skeleton.bones {
            // Entity may have been deleted by the time we get to this cleanup.
            if let boneEntity = PolySpatialRealityKit.instance.TryGetEntity(boneId) {
                let boneComponent = boneEntity.components[SkinnedMeshManager.UnityBoneComponent.self]! as UnityBoneComponent
                boneComponent.boneIndexMapping.removeValue(forKey: backingEntity)

                if boneComponent.boneIndexMapping.isEmpty {
                    boneEntity.components.remove(UnityBoneComponent.self)
                }
            }
        }

        backingEntity.setRenderMeshAndMaterials(PolySpatialAssetID.invalidAssetId, [])
        backingEntity.components.remove(UnitySkeletonData.self)
        backingEntity.dispose()

        entity.setRenderMeshAndMaterials(PolySpatialAssetID.invalidAssetId, [])
        entity.skinnedBackingEntity = nil
    }
}
