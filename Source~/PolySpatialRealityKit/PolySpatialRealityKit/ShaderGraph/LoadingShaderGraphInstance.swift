import Foundation

@_implementationOnly import FlatBuffers

class LoadingShaderGraphInstance: ShaderGraphInstance {
    unowned let shaderGraph: LoadingShaderGraph
    var data: ByteBuffer

    init(_ id: PolySpatialAssetID, _ shaderGraph: LoadingShaderGraph, _ data: ByteBuffer) {
        self.shaderGraph = shaderGraph
        self.data = data
        super.init(id)
        shaderGraph.shaderGraphInstances.insert(self)

        PolySpatialRealityKit.instance.UpdateMaterialDefinition(
            PolySpatialRealityKit.UnlitMaterialAsset(id, PolySpatialRealityKit.invisibleMaterial),
            ShaderManager.instance.DeleteShaderGraphMaterialAsset)
    }

    override func removeSelf() {
        super.removeSelf()
        shaderGraph.shaderGraphInstances.remove(self)
    }
}
