import Foundation

extension PolySpatialRealityKit {
    func sendPointerInputEvents(with events: [PolySpatialPointerEvent], to connectionId: PolySpatialConnectionID) {
        if events.isEmpty {
            return
        }
        events.withUnsafeBufferPointer { buf in
            var inputType = PolySpatialInputType.pointer.rawValue
            SendHostCommand(.inputEvent, to: connectionId, &inputType, buf)
        }
    }
}
