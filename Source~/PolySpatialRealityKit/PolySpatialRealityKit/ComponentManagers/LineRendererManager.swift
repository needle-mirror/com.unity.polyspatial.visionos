import Foundation
import RealityKit

/// Class to handle Line Renderer create/destroy commands.
@MainActor
class LineRendererManager {

    func createOrUpdateLineRenderer(_ entity: PolySpatialEntity, _ data: UnsafeMutablePointer<PolySpatialLineRendererData>?) {
        createOrUpdateLineRenderer(entity, data!.pointee)
    }
    
    func createOrUpdateLineRenderer(_ entity: PolySpatialEntity, _ lineRenderer: PolySpatialLineRendererData) {

        PolySpatialAssert(lineRenderer.isBakeToMeshDataAvailable, "Line Renderer updated without BakeToMesh data being available.")

        // Instantiate a Vfx mesh backed by mesh & material(s)
        guard let renderData = lineRenderer.renderData,
                let meshId = renderData.meshId,
                !renderData.materialIds.isEmpty,
                meshId != PolySpatialAssetID.invalidAssetId else {
            PolySpatialRealityKit.instance.LogError("Set Line Renderer Component without having renderData, valid meshId or materialIds.")
            return
        }

        let backingEntity = getOrCreateLineRendererBackingEntity(entity)
        backingEntity.setRenderMeshAndMaterials(meshId, Array(renderData.materialIds))

        if !lineRenderer.isWorldSpace {
            let rootEntity = entity.viewSubgraph.root
            // Convert the entity position from the entity parent's local space to root's local space
            let posRootSpace = entity.parent!.convert(position: entity.position, to: rootEntity)
            backingEntity.position = posRootSpace
        } else {
            backingEntity.position = .zero
        }
    }

    func destroyLineRenderer(_ entity: PolySpatialEntity) {
        removeLineRendererBackingEntity(entity)
    }
    
    func getOrCreateLineRendererBackingEntity(
        _ entity: PolySpatialEntity, _ parentToEntity: Bool = false) -> PolySpatialEntity {
            
        if let lineRendererEntity = entity.lineRendererBackingEntity {
            return lineRendererEntity
        }
        let lineRendererBackingEntity = PolySpatialEntity(entity.unityId, entity.viewSubgraph)
        lineRendererBackingEntity.setParent(
            parentToEntity ? entity : entity.viewSubgraph.root)
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
