import CoreGraphics
import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

// Singleton containing all variables to be tracked and additional functions used in PolySpatialRealityKit.
@MainActor
class PolySpatialRealityKitExtra: PolySpatialRealityKitDelegate {
    static var instance = PolySpatialRealityKitExtra()
    private init() {
        PolySpatialRealityKit.instance.delegates.append(self)
              
    }

    public static func reset() {
        PolySpatialRealityKitExtra.instance = .init()
    }

    public func on(volumeAdded: PolySpatialVolume) { }
    public func on(volumeRemoved: PolySpatialVolume) { }
}
