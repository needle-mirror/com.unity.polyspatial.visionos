import Foundation
import RealityKit

/// Class to handle Line Renderer create/destroy commands.
@MainActor
class LineRendererManager {

    func createOrUpdateLineRenderer(_ id: PolySpatialInstanceID, _ data: UnsafeMutablePointer<PolySpatialLineRendererData>?) {
        createOrUpdateLineRenderer(PolySpatialRealityKit.instance.GetEntity(id), data!.pointee)
    }
    
    func createOrUpdateLineRenderer(_ entity: PolySpatialEntity, _ lineRenderer: PolySpatialLineRendererData) {

        PolySpatialAssert(lineRenderer.isBakeToMeshDataAvailable, "Line Renderer updated without BakeToMesh data being available.")

        // Instantiate a Vfx mesh backed by mesh & material(s)
        guard let renderData = lineRenderer.renderData,
                let meshId = renderData.meshId,
                let materialIds = renderData.materialIdsAsBuffer,
                meshId != PolySpatialAssetID.invalidAssetId else {
            PolySpatialRealityKit.instance.LogError("Set Line Renderer Component without having renderData, valid meshId or materialIds.")
            return
        }

        let backingEntity = getOrCreateLineRendererBackingEntity(entity)
        backingEntity.setRenderMeshAndMaterials(meshId, Array(materialIds))

        if !lineRenderer.isWorldSpace {
            let rootEntity = PolySpatialRealityKit.instance.GetRootEntity(entity.unityId)
            // Convert the entity position from the entity parent's local space to root's local space
            let posRootSpace = entity.parent!.convert(position: entity.position, to: rootEntity)
            backingEntity.position = posRootSpace
        } else {
            backingEntity.position = .zero
        }
    }

    func destroyLineRenderer(_ id: PolySpatialInstanceID) {
        let entity = PolySpatialRealityKit.instance.GetEntity(id)
        removeLineRendererBackingEntity(entity)
    }
    
    func getOrCreateLineRendererBackingEntity(
        _ entity: PolySpatialEntity, _ parentToEntity: Bool = false) -> PolySpatialEntity {
            
        if let lineRendererEntity = entity.lineRendererBackingEntity {
            return lineRendererEntity
        }
        let lineRendererBackingEntity = PolySpatialEntity(entity.unityId)
        lineRendererBackingEntity.setParent(
            parentToEntity ? entity : PolySpatialRealityKit.instance.GetRootEntity(entity.unityId))
        entity.lineRendererBackingEntity = lineRendererBackingEntity
        return lineRendererBackingEntity
    }

    func removeLineRendererBackingEntity(_ entity: PolySpatialEntity) {
        guard let lineRendererBackingEntity = entity.lineRendererBackingEntity else {
            return
        }
        lineRendererBackingEntity.dispose()
        entity.lineRendererBackingEntity = nil
    }
}
