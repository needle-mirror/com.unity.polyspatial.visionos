import RealityKit
import SwiftUI

typealias PolySpatialContentView = XROSPolySpatialContentView

struct XROSPolySpatialContentView: View {

    static let maxPointers = 2
    static var polyspatialPointerEvents: [PolySpatialPointerEvent] = .init(repeating: .init(), count: maxPointers)

    @EnvironmentObject var stats: PolySpatialStatistics
    @EnvironmentObject var sceneDelegate: PolySpatialSceneDelegate

    @Environment(\.physicalMetrics) var physicalMetrics
    @Environment(\.pslWindow) var pslWindow

    @State var converter: RealityViewContent?

    // This value changes with the Display -> Appearance -> Window Zoom level.
    @PhysicalMetric(from: .meters) var pointsPerMeter = 1

    init() {
    }

    @ViewBuilder
    var body: some View {
        ZStack {
            GeometryReader3D { proxy in
                RealityView { content in
                    converter = content
                    content.add(pslWindow.rootEntity)
                    PolySpatialWindowManager.shared.on(windowAdded: pslWindow, sceneDelegate, .init(physicalMetrics.convert(proxy.size, to: .meters).vector))
                }
                .onChange(of: proxy.size) {
                    PolySpatialWindowManager.shared.on(windowResized: pslWindow, .init(physicalMetrics.convert(proxy.size, to: .meters).vector))
                }
                .onChange(of: pointsPerMeter) {
                    PolySpatialWindowManager.shared.on(windowResized: pslWindow, .init(physicalMetrics.convert(proxy.size, to: .meters).vector))
                }
                // OnVolumeViewpointChange provides both the previous viewpoint and the current viewpoint but we really only care about the currentViewpoint.
                .onVolumeViewpointChange (updateStrategy: .all, {_, currentView in
                    PolySpatialWindowManager.shared.on(volumeViewpointChanged: pslWindow, currentView)
                })
                .gesture(SpatialEventGesture(coordinateSpace: .local)
                    .onChanged { pointerEvents in
                        let viewSize = proxy.frame(in: .local).size
                        handleGesture(events: pointerEvents, viewSize: viewSize)
                    }.onEnded { pointerEvents in
                        let viewSize = proxy.frame(in: .local).size
                        handleGesture(events: pointerEvents, viewSize: viewSize)
                    })

                if stats.displayOverlay {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            PolySpatialStatisticsView()
                            PolySpatialDebugHierarchyView()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    func handleGesture(events: SpatialEventCollection, viewSize: Size3D) {
        var i = 0
        var hostId = PolySpatialHostID.localDefault
        for pointerEvent in events {
            if i >= Self.maxPointers {
                PolySpatialRealityKit.instance.LogError("Max number of touches processed at a single time is \(Self.maxPointers).")
                break
            }

            var phase: PolySpatialPointerPhase = .began
            var kind: PolySpatialPointerKind = .touch
            var keys: PolySpatialPointerModifierKeys = .none
            var inputDevicePosition = SIMD3<Float>()
            var inputDeviceRotation = SIMD4<Float>(0, 0, 0, 1)
            var selectionRayOrigin = SIMD3<Float>()
            var selectionRayDirection = SIMD3<Float>()
            switch pointerEvent.phase {
            case .active:
                // began phase is inferred and added in SpatialPointerEventListener.cs
                phase = .moved
                break

            case .cancelled:
                // A touch can transition to a pinch mid input and sometimes it sends cancelled, sometimes not.
                phase = .cancelled
                break

            case .ended:
                phase = .ended
                break

            @unknown default:
                PolySpatialRealityKit.instance.LogError("Unknown touch phase \(pointerEvent.phase) received, no handler for it! ")
            }

            switch pointerEvent.kind {
            case .touch:
                kind = .touch
                break

            case .directPinch:
                kind = .directPinch
                break

            case .indirectPinch:
                kind = .indirectPinch
                break

            case .pointer:
                kind = .pointer
                break

            @unknown default:
                PolySpatialRealityKit.instance.LogError("Unknown touch kind \(pointerEvent.kind) received, no handler for it! ")
            }

            if pointerEvent.modifierKeys.contains(.capsLock) {
                keys.update(with: .capsLock)
            }
            if pointerEvent.modifierKeys.contains(.shift) {
                keys.update(with: .shift)
            }
            if pointerEvent.modifierKeys.contains(.control) {
                keys.update(with: .control)
            }
            if pointerEvent.modifierKeys.contains(.command) {
                keys.update(with: .command)
            }
            if pointerEvent.modifierKeys.contains(.option) {
                keys.update(with: .option)
            }
            if pointerEvent.modifierKeys.contains(.numericPad) {
                keys.update(with: .numericPad)
            }
            if pointerEvent.modifierKeys.contains(.all) {
                keys = [.capsLock, .shift, .control, .command, .option, .numericPad]
            }

            if let devicePose = pointerEvent.inputDevicePose {
                inputDevicePosition = ConvertPosition(devicePose.pose3D.position, viewSize)
                inputDeviceRotation = ConvertRotation(devicePose.pose3D.rotation)
            }

            if let selectionRay = pointerEvent.selectionRay {
                selectionRayOrigin = ConvertPosition(selectionRay.origin, viewSize)
                selectionRayDirection = ConvertDirection(selectionRay.direction)
            }

            var colliderId = PolySpatialInstanceID.none
            var volumeId = PolySpatialInstanceID.none
            if let polyspatialEntity = pointerEvent.targetedEntity as? PolySpatialEntity {
                colliderId = polyspatialEntity.unityId
                polyspatialEntity.lastSentInteractionPhase = phase
                if let volume = PolySpatialRealityKit.instance.tryGetVolume(colliderId) {
                    volumeId = volume.id
                } else {
                    PolySpatialRealityKit.instance.LogError("Could not find a volume for PolySpatialEntity \(colliderId)")
                }
            }

            if i == 0 {
                hostId = colliderId.hostId
            } else if colliderId.hostId != hostId {
                PolySpatialRealityKit.instance.LogError("Cannot process touches for objects belonging to different simulations at the same time")
                break
            }

            let position = ConvertPosition(pointerEvent.location3D, viewSize)
            let interactionId = Int32(truncatingIfNeeded:pointerEvent.id.hashValue)

            let sendPointerEvent: PolySpatialPointerEvent = .init(
                interactionId: interactionId,
                interactionPosition: ConvertFloat3PositionToPolySpatialVec3(position),
                interactionRayOrigin: ConvertFloat3PositionToPolySpatialVec3(selectionRayOrigin),
                // Interaction ray is in SwiftUI coordinate space, so Y and Z are inverted
                interactionRayDirection: PolySpatialVec3(x: selectionRayDirection.x, y: -selectionRayDirection.y, z: -selectionRayDirection.z),
                inputDevicePosition: ConvertFloat3PositionToPolySpatialVec3(inputDevicePosition),
                // Because device rotation is in SwiftUI coordinate space, quaternion conversion is x, -y, -z, w
                inputDeviceRotation: PolySpatialQuaternion(x: inputDeviceRotation.x, y: -inputDeviceRotation.y, z: -inputDeviceRotation.z, w: inputDeviceRotation.w),
                modifierKeys: keys,
                kind: kind,
                phase: phase,
                targetId: colliderId,
                volumeId: volumeId
            )

            Self.polyspatialPointerEvents[i] = sendPointerEvent
            i += 1
        }

        PolySpatialRealityKit.instance.sendPointerInputEvents(with: .init(Self.polyspatialPointerEvents[0..<i]), hostId: hostId)
    }

    func ConvertPosition(_ point: Point3D, _ viewSize: Size3D) -> SIMD3<Float> {
        var basePosition: simd_float3
        if PolySpatialWindow.windowConfigurationIsImmersive(pslWindow.windowConfiguration) {
            basePosition = converter!.convert(point, from: .local, to: pslWindow.rootEntity)
        } else {
            var mutablePoint = point;
            mutablePoint.y = viewSize.height - mutablePoint.y
            mutablePoint -= viewSize * 0.5

            // Convert to SIMD and compensate for volume dimensions -
            // unless the content isn't meant to scale with the window, in which case ignore the window's actual dimensions for the purpose of input.
            basePosition = simd_float3(physicalMetrics.convert(mutablePoint, to: .meters))
            if (pslWindow.shouldContentScaleWithWindow) {
                basePosition /= pslWindow.actualDimensions
            }
        }
        return (pslWindow.inputTransform * simd_float4(basePosition, 1)).xyz
    }

    func ConvertDirection(_ direction: Vector3D) -> SIMD3<Float> {
        return (pslWindow.inputTransform * simd_float4(simd_float3(direction), 0)).xyz
    }

    func ConvertRotation(_ rotation: Rotation3D) -> SIMD4<Float> {
        return (simd_quatf(pslWindow.inputTransform) * simd_quatf(vector: simd_float4(rotation.vector))).vector
    }
}
