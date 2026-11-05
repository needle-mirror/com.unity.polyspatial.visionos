extension PolySpatialRealityKit {
    
    func createOrUpdateCanvasRenderer(
        _ entity: PolySpatialEntity,
        _ canvasRendererData: UnsafeMutablePointer<PolySpatialCanvasRendererData>?) {
        
        let info = canvasRendererData!.pointee

        guard var renderData = info.renderData else {
            LogException("No render info available for \(entity).")
            return
        }

        entity.setMaskedRendererInfo(
            info.color.cgColor(), info.mainTextureId, info.maskTextureId, info.maskUvtransform.toFloat4x4())
        createOrUpdateMeshRenderer(entity, &renderData)
    }
    
    func destroyCanvasRenderer(_ entity: PolySpatialEntity) {
        entity.clearMaskedRendererInfo()
        destroyMeshRenderer(entity)
    }
}
