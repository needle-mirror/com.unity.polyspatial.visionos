import Foundation
import SwiftUI
import RealityKit
import Combine

public struct PolySpatialContentViewWrapper: View {
    @Environment(\.physicalMetrics) var physicalMetrics
    @Environment(\.pslWindow) var pslWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow

    var minVolumeSize: simd_float3
    var maxVolumeSize: simd_float3

    public var body: some View {
        Group {
            if (pslWindow.windowConfiguration != PolySpatialVolume.unboundedConfigString) {
                PolySpatialContentView()
                    .environmentObject(PolySpatialStatistics.shared)
                    .frame(minWidth: physicalMetrics.convert(CGFloat(minVolumeSize.x), from: .meters),
                           maxWidth: physicalMetrics.convert(CGFloat(maxVolumeSize.x), from: .meters),
                           minHeight: physicalMetrics.convert(CGFloat(minVolumeSize.y), from: .meters),
                           maxHeight: physicalMetrics.convert(CGFloat(maxVolumeSize.y), from: .meters))
                    .frame(minDepth: physicalMetrics.convert(CGFloat(minVolumeSize.z), from: .meters),
                           maxDepth: physicalMetrics.convert(CGFloat(maxVolumeSize.z), from: .meters))
            } else {
                PolySpatialContentView()
                    .environmentObject(PolySpatialStatistics.shared)
            }
        }
        .onAppear {
            PolySpatialWindowManagerAccess.openImmersiveSpace = openImmersiveSpace
            PolySpatialWindowManagerAccess.dismissImmersiveSpace = dismissImmersiveSpace
            PolySpatialWindowManagerAccess.openWindow = openWindow
            PolySpatialWindowManagerAccess.dismissWindow = dismissWindow
        }
    }

    public init(minSize: simd_float3, maxSize: simd_float3) {
        self.minVolumeSize = minSize
        self.maxVolumeSize = maxSize
    }
}
