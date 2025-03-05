@_implementationOnly import FlatBuffers

@MainActor
class CachedShaderGraph {
    let shaderId: PolySpatialAssetID

    init(_ shaderId: PolySpatialAssetID) {
        self.shaderId = shaderId
    }

    func updateMaterialDefinition(
        _ id: PolySpatialAssetID, _ materialDef: PolySpatialShaderMaterial, _ data: ByteBuffer) {

        // Nothing by default.
    }

    func tryStartLoading() {
        // Replacing a loaded/invalid shader graph restarts the loading process, but does not (itself)
        // replace instances.  This is because materials that use the new shader graph must be resent
        // with data corresponding to the new property map.
        let loadingShaderGraph = LoadingShaderGraph(shaderId)
        ShaderManager.instance.cachedShaderGraphs[shaderId] = loadingShaderGraph

        loadingShaderGraph.tryStartLoading()
    }
    
    func updateShaderGlobalProperties() {
        // Nothing by default.
    }

    // Removes the shader graph from the cache and, if necessary, calls removeSelf on all of its instances
    // so that they can deregister themselves from any objects that may be retaining references to them.
    func removeSelf() {
        ShaderManager.instance.cachedShaderGraphs.removeValue(forKey: shaderId)
    }
}
