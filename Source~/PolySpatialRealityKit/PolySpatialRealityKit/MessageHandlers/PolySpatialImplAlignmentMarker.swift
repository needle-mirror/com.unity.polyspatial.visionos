import CoreImage
import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateAlignmentMarker(
        _ entity: PolySpatialEntity,
        _ alignmentMarkerInfo: UnsafeMutablePointer<PolySpatialAlignmentMarkerData>?) {
        let info = alignmentMarkerInfo!.pointee
        entity.setAlignmentMarkerInfo(info)
    }

    func destroyAlignmentMarker(_ entity: PolySpatialEntity) {
        entity.clearAlignmentMarkerInfo()
    }
}
