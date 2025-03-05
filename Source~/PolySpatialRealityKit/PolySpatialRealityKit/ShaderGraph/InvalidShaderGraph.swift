import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

@MainActor
class InvalidShaderGraph: CachedShaderGraph {
    let material: UnlitMaterial

    init(_ shaderId: PolySpatialAssetID, _ material: UnlitMaterial) {
        self.material = material
        super.init(shaderId)
    }

    override func updateMaterialDefinition(
        _ id: PolySpatialAssetID, _ materialDef: PolySpatialShaderMaterial, _ data: ByteBuffer) {

        ShaderManager.instance.shaderGraphInstances[id]?.removeSelf()
        PolySpatialRealityKit.instance.UpdateMaterialDefinition(
            PolySpatialRealityKit.UnlitMaterialAsset(id, material))
    }
}
