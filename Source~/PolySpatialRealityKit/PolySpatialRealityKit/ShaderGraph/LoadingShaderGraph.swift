import CoreGraphics
import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

@MainActor
class LoadingShaderGraph: CachedShaderGraph {
    var materialPropertyId: PolySpatialAssetID?
    var asyncCommandId: PolySpatialAssetID?
    var shaderGraphInstances: Set<LoadingShaderGraphInstance> = []
    var startedLoading = false
    
    override func updateMaterialDefinition(
        _ id: PolySpatialAssetID, _ materialDef: PolySpatialShaderMaterial, _ data: ByteBuffer) {

        materialPropertyId = materialDef.shaderPropertyMapId

        // ByteBuffer.init(contiguousBytes:,count:) creates an owned copy.
        let dataCount = Int(data.size)
        let dataCopy = ByteBuffer(
            contiguousBytes: UnsafeMutableRawBufferPointer(start: data.memory, count: dataCount), count: dataCount)
        let currentInstance = ShaderManager.instance.shaderGraphInstances[id]
        if let loadingInstance = currentInstance as? LoadingShaderGraphInstance,
                loadingInstance.shaderGraph === self {
            loadingInstance.data = dataCopy
        } else {
            ShaderManager.instance.shaderGraphInstances[id]?.removeSelf()
            ShaderManager.instance.shaderGraphInstances[id] =
                LoadingShaderGraphInstance(id, self, dataCopy)
        }
            
        tryStartLoading()
    }
    
    static let disableShaderGraphsWithTextures =
        ProcessInfo.processInfo.arguments.contains("-disableShaderGraphsWithTextures")

    override func tryStartLoading() {
        guard !startedLoading, let materialPropertyId = self.materialPropertyId,
            let shaderDef = PolySpatialRealityKit.instance.shaderGraphAssets[shaderId] else {
            return
        }
        startedLoading = true
        
        // The "Apple Paravirtual device" doesn't support argument buffers (or at least not at the level required),
        // and this causes crashes whenever we use shader graphs with texture parameters.  So, on CI, we replace all
        // shaders that use textures with unlit ones.
        // TODO (LXR-4139): Remove this workaround if/when we fix the issue with CI. 
        if LoadingShaderGraph.disableShaderGraphsWithTextures &&
                !PolySpatialRealityKit.instance.shaderPropertyMaps[materialPropertyId]!.textureProperties.isEmpty {
            reportLoadSuccessToHost()
            replaceSelf(InvalidShaderGraph(shaderId, UnlitMaterial()))
            return
        }

        Task {
            do {
                let material = try await ShaderGraphMaterial.init(
                    named: shaderDef.materialXPrimPath, from: shaderDef.materialXEncoding.data(using: .utf8)!)
                Task { @MainActor in handleLoadSuccess(material, materialPropertyId) }
            } catch {
                Task { @MainActor in handleLoadFailure(shaderDef.name, error) }
            }
        }
    }

    func handleLoadSuccess(_ material: ShaderGraphMaterial, _ materialPropertyId: PolySpatialAssetID) {
        guard ShaderManager.instance.cachedShaderGraphs[shaderId] === self else {
            return // Removed before loading finished.
        }
        reportLoadSuccessToHost()
        replaceSelf(ValidShaderGraph(
            shaderId, material, PolySpatialRealityKit.instance.shaderPropertyMaps[materialPropertyId]!))
    }

    func reportLoadSuccessToHost() {
        if var asyncCommandId = self.asyncCommandId {
            var command: PolySpatialCommand = .createOrUpdateShaderMaterialAsset
            var result = true
            PolySpatialRealityKit.instance.SendHostCommand(.asyncResponse, &asyncCommandId, &command, &result)
        }
    }

    func handleLoadFailure(_ shaderName: String, _ error: any Error) {
        guard ShaderManager.instance.cachedShaderGraphs[shaderId] === self else {
            return // Removed before loading finished.
        }
        if var asyncCommandId = self.asyncCommandId {
            var command: PolySpatialCommand = .createOrUpdateShaderMaterialAsset
            var result = false
            PolySpatialRealityKit.instance.SendHostCommand(.asyncResponse, &asyncCommandId, &command, &result)
        }

        let errorMaterial = PolySpatialRealityKit.instance.LogWarningAndGetMaterial(
            "Could not load ShaderGraph '\(shaderName)': \(error)")
        replaceSelf(InvalidShaderGraph(shaderId, errorMaterial))
    }

    func replaceSelf(_ cachedShaderGraph: CachedShaderGraph) {
        ShaderManager.instance.cachedShaderGraphs[shaderId] = cachedShaderGraph

        for shaderGraphInstance in shaderGraphInstances {
            let materialDef: PolySpatialShaderMaterial = getRoot(byteBuffer: &shaderGraphInstance.data)
            cachedShaderGraph.updateMaterialDefinition(
                shaderGraphInstance.id, materialDef, shaderGraphInstance.data)
        }
    }
    
    override func removeSelf() {
        for shaderGraphInstance in shaderGraphInstances {
            shaderGraphInstance.removeSelf()
        }
        super.removeSelf()
    }
}
