extension PolySpatialRealityKit {

    func createOrUpdateSpriteRenderer(
        _ id: PolySpatialInstanceID,
        _ spriteRenderData: UnsafeMutablePointer<PolySpatialSpriteRenderData>?) {

        let info = spriteRenderData!.pointee

        guard var renderData = info.renderData else {
            LogException("No render info available for \(id).")
            return
        }

        GetEntity(id).setMaskedRendererInfo(
            info.color.cgColor(), info.mainTextureId, info.maskTextureId, info.maskUvtransform.toFloat4x4(),
            info.maskingOperation, info.maskAlphaCutoff)
        createOrUpdateMeshRenderer(id, &renderData)
    }
    
    func destroySpriteRenderer(_ id: PolySpatialInstanceID) {
        GetEntity(id).clearMaskedRendererInfo()
        destroyMeshRenderer(id)
    }

    func createOrUpdateSpriteMask(_ id: PolySpatialInstanceID, _ spriteMaskData: UnsafeMutablePointer<PolySpatialSpriteMaskData>?) {
        // Don't actually render anything here. This is setup material for masking out sprites
        // when called in createOrUpdateSpriteRenderer.
    }
    
    func destroySpriteMask(_ id: PolySpatialInstanceID) {
    }
}
