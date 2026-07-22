import CoreImage
import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateAlignmentMarker(
        _ id: PolySpatialInstanceID,
        _ alignmentMarkerInfo: UnsafeMutablePointer<PolySpatialAlignmentMarkerData>?) {
        let entity = GetEntity(id)
        let info = alignmentMarkerInfo!.pointee
        entity.setAlignmentMarkerInfo(info)
    }

    func destroyAlignmentMarker(_ entity: PolySpatialEntity) {
        entity.clearAlignmentMarkerInfo()
    }
}
