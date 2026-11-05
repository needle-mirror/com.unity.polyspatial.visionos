extension PolySpatialRealityKit {

    func createOrUpdateSpriteRenderer(
        _ entity: PolySpatialEntity,
        _ spriteRenderData: UnsafeMutablePointer<PolySpatialSpriteRenderData>?) {

        let info = spriteRenderData!.pointee

        guard var renderData = info.renderData else {
            LogException("No render info available for \(entity).")
            return
        }

        entity.setMaskedRendererInfo(
            info.color.cgColor(), info.mainTextureId, info.maskTextureId, info.maskUvtransform.toFloat4x4(),
            info.maskingOperation, info.maskAlphaCutoff)
        createOrUpdateMeshRenderer(entity, &renderData)
    }
    
    func destroySpriteRenderer(_ entity: PolySpatialEntity) {
        entity.clearMaskedRendererInfo()
        destroyMeshRenderer(entity)
    }

    func createOrUpdateSpriteMask(_ entity: PolySpatialEntity, _ spriteMaskData: UnsafeMutablePointer<PolySpatialSpriteMaskData>?) {
        // Don't actually render anything here. This is setup material for masking out sprites
        // when called in createOrUpdateSpriteRenderer.
    }
    
    func destroySpriteMask(_ entity: PolySpatialEntity) {
    }
}
