import CoreImage
import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateImageBasedLight(
        _ entity: PolySpatialEntity,
        _ imageBasedLightInfo: UnsafeMutablePointer<PolySpatialImageBasedLightData>?) {
        let info = imageBasedLightInfo!.pointee

        entity.setImageBasedLightInfo(
            info.sourceAssetId0,
            info.sourceAssetId1,
            info.blend,
            info.inheritsRotation,
            info.intensityExponent)
    }

    func destroyImageBasedLight(_ entity: PolySpatialEntity) {
        entity.clearImageBasedLightInfo()
    }

    func createOrUpdateImageBasedLightReceiver(
        _ entity: PolySpatialEntity,
        _ imageBasedLightReceiverInfo: UnsafeMutablePointer<PolySpatialImageBasedLightReceiverData>?) {
        let info = imageBasedLightReceiverInfo!.pointee

        guard let imageBasedLight = entity.viewSubgraph.entities[info.imageBasedLightId] else {
            LogError("Image based light \(info.imageBasedLightId) for \(entity) not found")
            destroyImageBasedLightReceiver(entity)
            return
        }

        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: imageBasedLight))

        entity.updateBackingEntityComponents(ImageBasedLightReceiverComponent.self)
    }

    func destroyImageBasedLightReceiver(_ entity: PolySpatialEntity) {
        entity.components.remove(ImageBasedLightReceiverComponent.self)
        entity.updateBackingEntityComponents(ImageBasedLightReceiverComponent.self)
    }

    func createEnvironmentResource(_ asset: TextureAsset) -> EnvironmentResource {
        let cgImage: CGImage
        switch asset.size.z {
            case 1:
                // Depth of one: this is an equirectangular image.
                cgImage = asset.getCGImage()
            case 6:
                // Depth of six: this is a cube map.  Map the face size (texture width) to 180 degrees.
                cgImage = createCGImage(asset, textureCubeToEquirectangularCompute!, asset.texture.resource.width * 2)
            default:
                LogError("Invalid environment texture depth: \(asset.size.z)")
                cgImage = magentaImage
        }
        return try! EnvironmentResource(equirectangular: cgImage)
    }
}
