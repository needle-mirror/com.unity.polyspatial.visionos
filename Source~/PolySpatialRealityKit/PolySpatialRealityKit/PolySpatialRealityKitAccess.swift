import Foundation
import RealityKit
import SwiftUI
@_implementationOnly
import PolySpatialRealityKitC

// This file serves as a trampoline between UnityFramework (where iOSPlatformAPI.mm is linked), and the Unity-iPhone Swift app,
// where this is linked.  We can't put libpolyspatial into UnityFramework, because for whatever reason UnityFramework
// doesn't link with swift symbols, and Unity-iPhone is already a Swift app.  But our polyspatial code lives inside
// UnityFramework, which wants to call GetPolySpatialNativeAPI with __Internal DllImport linkage.  So the Swift app
// early on hands the API data to iOSPlatformAPI.mm via these methods, so that we can return it later.

@MainActor
@objc public class PolySpatialRealityKitAccess: NSObject {
    private override init() { }

    public static func register() {
        PolySpatialRealityKit.registerAllSystems()
    }

    public static func getApiData() -> UnsafeRawPointer {
        .init(PolySpatialRealityKit.GetPolySpatialAPIStruct())
    }

    public static func getApiSize() -> Int32 {
        Int32(MemoryLayout<PolySpatialNativeAPI>.size)
    }

    public static func addDelegate(_ delegate: PolySpatialRealityKitDelegate) {
        PolySpatialRealityKit.instance.delegates.append(delegate)
    }
}
