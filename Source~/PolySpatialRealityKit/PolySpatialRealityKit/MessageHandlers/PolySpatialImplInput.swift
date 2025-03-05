import Foundation

extension PolySpatialRealityKit {
    func sendPointerInputEvents(with events: [PolySpatialPointerEvent], hostId: PolySpatialHostID) {
        if events.isEmpty {
            return
        }
        events.withUnsafeBufferPointer { buf in
            var inputType = PolySpatialInputType.pointer.rawValue
            withUnsafePointer(to: hostId) {
                SendHostCommand(.inputEvent, &inputType, $0, buf)
            }
        }
    }
}
