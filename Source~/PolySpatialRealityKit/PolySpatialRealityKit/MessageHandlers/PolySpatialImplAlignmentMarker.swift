import CoreImage
import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateAlignmentMarker(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ alignmentMarkerInfo: UnsafeMutablePointer<PolySpatialAlignmentMarkerData>?) {
        let entity = GetEntity(id)
        let info = alignmentMarkerInfo!.pointee
        entity.setAlignmentMarkerInfo(info)
    }

    func destroyAlignmentMarker(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.clearAlignmentMarkerInfo()
    }
}
