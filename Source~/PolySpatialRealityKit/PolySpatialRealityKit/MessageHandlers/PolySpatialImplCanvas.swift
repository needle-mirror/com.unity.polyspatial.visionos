extension PolySpatialRealityKit {
    
    func createOrUpdateCanvasRenderer(
        _ id: PolySpatialInstanceID,
        _ canvasRendererData: UnsafeMutablePointer<PolySpatialCanvasRendererData>?) {
        
        let info = canvasRendererData!.pointee

        guard var renderData = info.renderData else {
            LogException("No render info available for \(id).")
            return
        }

        GetEntity(id).setMaskedRendererInfo(
            info.color.cgColor(), info.mainTextureId, info.maskTextureId, info.maskUvtransform.toFloat4x4())
        createOrUpdateMeshRenderer(id, &renderData)
    }
    
    func destroyCanvasRenderer(_ id: PolySpatialInstanceID) {
        GetEntity(id).clearMaskedRendererInfo()
        destroyMeshRenderer(id)
    }
}
