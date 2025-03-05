import Foundation
import RealityKit
import SwiftUI
import Combine

// An descriptor for a PolySpatial "Window" that can contain a volume,
// either a bounded or unbounded one. (Windows have also been called
// "Volume Renderers" in the past.) Utlimately created by the toplevel
// Swift app's Scene's WindowGroup(s).
//
// Used by both the WindowManager as well as the (public to users)
// top level Swift app trampoline code.
//
// The outputDimensions are the requested dimensions based on the configuration.
// The actualDimensions are filled in when the window is opened.
public class PolySpatialWindow: Identifiable, Hashable, Equatable {
    public var uuid: UUID
    public var windowConfiguration: String
    public var outputDimensions: simd_float3
    public var actualDimensions: simd_float3
    public var rootEntity: Entity
    public var inputTransform = matrix_identity_float4x4
    public var shouldContentScaleWithWindow: Bool = true

    public var id: UUID { uuid }

    public init(_ uuid: UUID, _ windowConfiguration: String,  _ outputDimensions: simd_float3? = nil) {
        self.uuid = uuid
        self.windowConfiguration = windowConfiguration
        self.actualDimensions = .init()
        self.rootEntity = .init()

        // ImmersiveSpaces don't have output dimensions, so fall back to 1x1x1 as "identity" size.
        if outputDimensions != nil {
            self.outputDimensions = outputDimensions!
        } else {
            self.outputDimensions = .init(1, 1, 1)
        }
    }

    public static func windowConfigurationIsImmersive(_ configuration: String) -> Bool {
        return configuration == "Unbounded" || configuration == "CompositorSpace"
    }

    public static func == (lhs: PolySpatialWindow, rhs: PolySpatialWindow) -> Bool {
        lhs.uuid == rhs.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

extension UUID {
    public static let zero = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
}

// Swift Environment additions to allow for @Environment(\.pslWindow)
// so that Views can access the window they're contained in.
public struct PolySpatialWindowEnvironmentKey: EnvironmentKey {
    public static let defaultValue: PolySpatialWindow = .init(UUID.zero, "", simd_float3.zero)
}

extension EnvironmentValues {
    public var pslWindow: PolySpatialWindow {
        get { self[PolySpatialWindowEnvironmentKey.self] }
        set { self[PolySpatialWindowEnvironmentKey.self] = newValue }
    }
}
