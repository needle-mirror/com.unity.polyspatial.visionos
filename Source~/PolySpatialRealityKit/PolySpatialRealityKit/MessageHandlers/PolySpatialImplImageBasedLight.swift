import CoreImage
import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateImageBasedLight(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ imageBasedLightInfo: UnsafeMutablePointer<PolySpatialImageBasedLightData>?) {
        let entity = GetEntity(id)
        let info = imageBasedLightInfo!.pointee
            
        entity.setImageBasedLightInfo(
            info.sourceAssetId0,
            info.sourceAssetId1,
            info.blend,
            info.inheritsRotation,
            info.intensityExponent)
    }
    
    func destroyImageBasedLight(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.clearImageBasedLightInfo()
    }

    func createOrUpdateImageBasedLightReceiver(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ imageBasedLightReceiverInfo: UnsafeMutablePointer<PolySpatialImageBasedLightReceiverData>?) {
        let entity = GetEntity(id)
        let info = imageBasedLightReceiverInfo!.pointee
            
        // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
        let remappedImageBasedLightId = PolySpatialInstanceID(id: info.imageBasedLightId.id, hostId: id.hostId, hostVolumeIndex: id.hostVolumeIndex)
        
        entity.components.set(ImageBasedLightReceiverComponent(
            imageBasedLight: GetEntity(remappedImageBasedLightId)))

        entity.updateBackingEntityComponents(ImageBasedLightReceiverComponent.self)
    }
    
    func destroyImageBasedLightReceiver(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
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
