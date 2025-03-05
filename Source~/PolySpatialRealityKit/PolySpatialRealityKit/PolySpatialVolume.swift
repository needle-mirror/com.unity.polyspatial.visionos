//
// A PolySpatialVolume connects a SwiftUI view with a specific PolySpatialVolumeCamera from
// the simulation side
//

import Foundation
import RealityKit
import SwiftUI
import Combine

@MainActor
public class PolySpatialViewSubGraph {
    let volumeIndex: UInt8
    let root: Entity
    var entities: [PolySpatialInstanceID: PolySpatialEntity] = [:]
    var volume: PolySpatialVolume? = nil

    init(_ vidx: UInt8) {
        volumeIndex = vidx
        root = Entity()
    }
}

struct PolySpatialAlignmentMarkerState {
    let data: PolySpatialAlignmentMarkerData
    let rootTransform: simd_float4x4

    init(_ data: PolySpatialAlignmentMarkerData, _ rootTransform: simd_float4x4) {
        self.data = data
        self.rootTransform = rootTransform
    }
}

// Updates volumes' alignment transforms over time.
class PolySpatialVolumeAlignmentSystem: System {
    required init(scene: RealityFoundation.Scene) {
    }

    func update(context: SceneUpdateContext) {
        for viewSubGraph in PolySpatialRealityKit.instance.viewSubGraphs {
            viewSubGraph?.volume?.updateAlignmentMarkerTransform(.init(context.deltaTime))
        }
    }
}

@MainActor
public class PolySpatialVolume: ObservableObject, Equatable, Hashable {
    static let unboundedConfigString = "Unbounded"
    static let compositorConfigString = "CompositorSpace"
    static let boundedConfigString = "Bounded-"

    let id: PolySpatialInstanceID
    let root: Entity

    var rootEntity: Entity { get { root }}

    // Volume Camera properties
    @Published var isUnbounded = false
    var mode: PolySpatialVolumeCameraMode = .bounded
    var outputDimensions: simd_float3 = .init()

    var dimensions: simd_float3 = .init()
    var scale: simd_float3 = .init()
    var position: simd_float3 = .init()
    var rotation: simd_quatf = .init()

    var inputTransform = matrix_identity_float4x4 {
        didSet {
            if let windowUUID = assignedWindowUUID {
                PolySpatialWindowManager.shared.allWindows[windowUUID]!.inputTransform = inputTransform
            }
        }
    }

    private(set) var shouldScaleWithWindow: Bool = true {
        didSet {
            if let windowUUID = assignedWindowUUID {
                PolySpatialWindowManager.shared.allWindows[windowUUID]!.shouldContentScaleWithWindow = shouldScaleWithWindow
            }
        }
    }

    // The combined alignment marker transform, if any alignment markers are active.
    var alignmentMarkerTransform: Transform?

    class AlignmentMarkerPath {
        let source: Transform
        let dest: Transform
        let duration: Float
        var elapsed = Float(0)

        init(_ source: Transform, _ dest: Transform, _ duration: Float) {
            self.source = source
            self.dest = dest
            self.duration = duration
        }
    }

    // The path being followed by the alignment marker transform, if any.
    var alignmentMarkerPath: AlignmentMarkerPath?

    // Maps alignment marker IDs to their states.
    var alignmentMarkerStates: [PolySpatialInstanceID: PolySpatialAlignmentMarkerState] = [:] {
        didSet {
            // If there are no markers, return to the default behavior.
            if alignmentMarkerStates.isEmpty {
                alignmentMarkerTransform = nil
                alignmentMarkerPath = nil
                updateTransform()
                return
            }
            // Average the contributions of all alignment markers to find the target state.  To compute the average
            // using standard interpolation functions (such as simd_slerp), we decompose it into successive
            // interpolations (i.e., weighted averages between two values, with the weight of the current total being
            // proportional to the number of values in the total).
            // (A + B + C + D + ...) / N = lerp(lerp(lerp(lerp(0, A, 1), B, 1/2), C, 1/3), D, 1/4)...
            var combinedTranslation = simd_float3(0, 0, 0)
            var combinedRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            var combinedScale = simd_float3(1, 1, 1)
            var combinedLinearCorrectionThreshold = Float(0)
            var combinedAngularCorrectionThreshold = Float(0)
            var combinedLinearCorrectionSpeed = Float(0)
            var combinedAngularCorrectionSpeed = Float(0)
            var combinedWeight = Float(0)
            for state in alignmentMarkerStates.values {
                let t = 1 / (combinedWeight + 1)
                combinedTranslation = mix(combinedTranslation, state.rootTransform.translation, t: t)
                combinedRotation = simd_slerp(combinedRotation, state.rootTransform.rotation, t)
                combinedScale = mix(combinedScale, state.rootTransform.scale, t: t)
                combinedLinearCorrectionThreshold = simd_mix(
                    combinedLinearCorrectionThreshold, state.data.linearCorrectionThreshold, t)
                combinedAngularCorrectionThreshold = simd_mix(
                    combinedAngularCorrectionThreshold, state.data.angularCorrectionThreshold, t)
                combinedLinearCorrectionSpeed = simd_mix(
                    combinedLinearCorrectionSpeed, state.data.linearCorrectionSpeed, t)
                combinedAngularCorrectionSpeed = simd_mix(
                    combinedAngularCorrectionSpeed, state.data.angularCorrectionSpeed, t)
                combinedWeight += 1
            }
            let targetAlignmentMarkerTransform = Transform(
                scale: combinedScale, rotation: combinedRotation, translation: combinedTranslation)
            // On the first update, we simply jump directly to the target transform.
            guard let currentAlignmentMarkerTransform = self.alignmentMarkerTransform else {
                self.alignmentMarkerTransform = targetAlignmentMarkerTransform
                updateTransform()
                return
            }
            // Otherwise, we wait until the difference passes a threshold before correcting (unless already moving).
            let linearDifference = distance(currentAlignmentMarkerTransform.translation, combinedTranslation)
            let angularDifference = simd_angle(currentAlignmentMarkerTransform.rotation, combinedRotation) * 180 / .pi
            if alignmentMarkerPath != nil || linearDifference > combinedLinearCorrectionThreshold ||
                    angularDifference > combinedAngularCorrectionThreshold {

                // Avoid divide-by-zero: treat a zero speed as "instantaneous."
                let linearDuration = combinedLinearCorrectionSpeed == 0 ?
                    0 : linearDifference / combinedLinearCorrectionSpeed
                let angularDuration = combinedAngularCorrectionSpeed == 0 ?
                    0 : angularDifference / combinedAngularCorrectionSpeed

                alignmentMarkerPath = .init(
                    currentAlignmentMarkerTransform, targetAlignmentMarkerTransform,
                    max(linearDuration, angularDuration))
            }
        }
    }

    // if this is fully configured; i.e. if update() was called once
    var configured: Bool = false

    // if this volume camera had a new window configuration assigned to it during an update(). Used for notification purposes like invoking WindowStateChanged.
    var assignedNewWindowConfiguration: Bool = false

    public var assignedWindowUUID: UUID? = nil

    // host window properties
    var hostDimensions: simd_float3 = .init(1.0, 1.0, 1.0)

    let volumeToWorldLowLevelTexture: LowLevelTexture
    let volumeToWorldTextureResource: TextureResource

    init(_ cameraId: PolySpatialInstanceID, _ rootEntity: Entity) {
        id = cameraId
        root = rootEntity
        root.components.set(InputTargetComponent())

        // The volume-to-world texture contains three pixels: one for each row of an affine matrix.
        volumeToWorldLowLevelTexture = try! .init(descriptor: .init(
            pixelFormat: .rgba32Float, width: 3, height: 1, textureUsage: [.shaderRead, .shaderWrite]))
        volumeToWorldTextureResource = try! .init(from: volumeToWorldLowLevelTexture)
    }

    public var description: String {
        "volume(\(id))"
    }

    public func getOutputDimension() -> simd_float3 {
        return outputDimensions
    }

    // Overrides this volumes' outputDimensions, allowing
    public func overrideOutputDimension(_ outputDimensions: simd_float3) {
        self.outputDimensions = outputDimensions
    }

    static func windowConfigurationStringFor(outputDimensions: simd_float3, outputMode: PolySpatialVolumeCameraMode)
        -> String
    {
        if outputMode == .unbounded {
            return unboundedConfigString
        }

        if outputMode == .metal {
            return compositorConfigString
        }

        // Format dimensions.x with 3 decimal points. Must match VisionOSBuildProcessor
        // formatting (and even float to string conversion).
        // TODO -- replace with a UUID.
        let x: String = String(format: "%.3f", outputDimensions.x)
        let y: String = String(format: "%.3f", outputDimensions.y)
        let z: String = String(format: "%.3f", outputDimensions.z)
        return "\(boundedConfigString)\(x)x\(y)x\(z)"
    }

    static func windowConfigurationFromString(outputDimString: String) -> (mode: PolySpatialVolumeCameraMode, dimension: simd_float3) {
        if (outputDimString == unboundedConfigString || !outputDimString.hasPrefix(boundedConfigString)) {
            return (.unbounded, .one)
        }

        let SIndex = outputDimString.index(outputDimString.startIndex, offsetBy: boundedConfigString.count)

        let dimensionString = String(outputDimString[SIndex...])
        let dimensions = dimensionString.split(separator: "x")

        let x: Float = Float(dimensions[0]) ?? 1
        let y: Float = Float(dimensions[1]) ?? 1
        let z: Float = Float(dimensions[2]) ?? 1

        return (.bounded, .init(x: x, y: y, z: z))
    }

    public var desiredWindowConfiguration: String {
        return Self.windowConfigurationStringFor(outputDimensions: outputDimensions, outputMode: mode)
    }

    // returns false if the update succeeded
    // In certain cases, like over P2D, we may not have the right window for the requested output dimension.
    // In those cases, we have to find the best fit for a requested dimension.
    func update(cameraData data: PolySpatialVolumeCameraData, _ requestedWindowDim: simd_float3) -> Bool {
        assert(id.isValid)
        if configured {
            // if the window configuration changes, then this can't be updated in place
            let newWindowConfiguration = Self.windowConfigurationStringFor(outputDimensions: requestedWindowDim, outputMode: data.outputMode)
            if desiredWindowConfiguration != newWindowConfiguration {
                return false
            }
        }

        shouldScaleWithWindow = data.scaleWithWindow

        dimensions = data.dimensions.rk()
        position = data.position.rkPosition()
        rotation = data.rotation.rk()
        scale = data.scale.rk()

        outputDimensions = requestedWindowDim
        mode = data.outputMode
        isUnbounded = mode == .unbounded || mode == .metal

        updateTransform()

        // do we need to open or close the window for this volume?
        let windowCurrentlyOpen = assignedWindowUUID != nil
        if data.windowOpen != windowCurrentlyOpen {
            if data.windowOpen {
                PolySpatialWindowManager.shared.openWindowFor(volume: self)
            } else {
                PolySpatialWindowManager.shared.closeWindowFor(volume: self)
            }
        }

        configured = true

        return true
    }

    func update(window: PolySpatialWindow?,
                event: WindowEvent,
                isFocused: Bool? = nil) {

        var focused: Bool = false
        if let window {
            assert(self.assignedWindowUUID == nil)
            self.assignedWindowUUID = window.uuid
            self.update(hostDimensionsFromWindow: window)

            window.rootEntity.addChild(rootEntity)
            window.inputTransform = inputTransform
            window.shouldContentScaleWithWindow = shouldScaleWithWindow

            pslVolumeLog.trace("Volume \(self.id, privacy: .public): window assigned, uuid: \(self.assignedWindowUUID ?? .init(), privacy: .public) outputDimensions: \(window.outputDimensions, privacy: .public) actualDimensions: \(window.actualDimensions, privacy: .public)")

            focused = isFocused ?? true
        } else {
            assert(self.assignedWindowUUID != nil)
            pslVolumeLog.trace("Volume \(self.id, privacy: .public): window closed, uuid: \(self.assignedWindowUUID ?? .init(), privacy: .public)")
            self.rootEntity.removeFromParent()
            self.assignedWindowUUID = nil

            focused = isFocused ?? false
        }

        PolySpatialRealityKit.instance.notifyHostWindowState(self, windowEvent: event, focused: focused)
    }

    func update(hostDimensionsFromWindow: PolySpatialWindow) {
        if (mode == .bounded) {
            self.update(hostDimensions: hostDimensionsFromWindow.actualDimensions)
        } else {
            self.update(hostDimensions: SIMD3<Float>(1, 1, 1))
        }
    }

    func update(hostDimensions: simd_float3) {
        self.hostDimensions = hostDimensions
        updateTransform()
    }

    public func windowDismissed() {
        update(window: nil, event: .closed)
    }

    func updateAlignmentMarkerTransform(_ deltaTime: Float) {
        guard let alignmentMarkerPath = self.alignmentMarkerPath else {
            return
        }
        alignmentMarkerPath.elapsed += deltaTime
        if alignmentMarkerPath.elapsed >= alignmentMarkerPath.duration {
            self.alignmentMarkerTransform = alignmentMarkerPath.dest
            self.alignmentMarkerPath = nil
        } else {
            var t = alignmentMarkerPath.elapsed / alignmentMarkerPath.duration

            // In/out easing; cf. SmoothStep:
            // https://github.cds.internal.unity3d.com/unity/unity/blob/trunk/Runtime/Export/Math/Mathf.cs#L384
            t = -2 * t * t * t + 3 * t * t
            self.alignmentMarkerTransform = .init(
                scale: mix(alignmentMarkerPath.source.scale, alignmentMarkerPath.dest.scale, t: t),
                rotation: simd_slerp(alignmentMarkerPath.source.rotation, alignmentMarkerPath.dest.rotation, t),
                translation: mix(alignmentMarkerPath.source.translation, alignmentMarkerPath.dest.translation, t: t))
        }
        updateTransform()
    }

    private func updateTransform() {
        // this is the scale factor we need to scale the coordinate space coming from Unity into the
        // 1x1x1 canonical space
        let clientScalingFactor = scale * dimensions

        let invRotation = rotation.inverse
        let invClientScalingFactor = recip(clientScalingFactor)

        // then this is the final scale to get us to the destination realitykit space
        var invTotalScale = invClientScalingFactor
        if (shouldScaleWithWindow) {
            invTotalScale *= hostDimensions
        }

        // then compute the position offset we need to get to the realitykit origin
        let invTotalScaledPosition = invTotalScale * -position
        let invTotalRotatedAndScaledPosition = invRotation.act(invTotalScaledPosition)

        let invVolumeCameraTransform = Transform(
            scale: invTotalScale, rotation: invRotation, translation: invTotalRotatedAndScaledPosition)

        if let alignmentMarkerTransform {
            root.components.set(alignmentMarkerTransform)

            // The input transform first applies the inverse of the alignment marker transform (to bring us back
            // to Unity space) and then the inverse of the volume camera transform (because the simulation will
            // apply the forward volume camera transform).
            inputTransform = invVolumeCameraTransform.matrix * alignmentMarkerTransform.matrix.inverse

            setVolumeToWorldMatrix(SwapCoordinateSystems(root.transform.matrix.inverse))
            return
        }

        root.components.set(invVolumeCameraTransform)

        // The input transform is identity: the simulation will apply the forward volume camera transform,
        // cancelling out the inverse and bringing us back into Unity space.
        inputTransform = matrix_identity_float4x4

        // The volume-to-world transform is performed in Unity space, and so needs the original, unflipped coordinates.
        var volumeToWorld = Transform(
            scale: clientScalingFactor / hostDimensions,
            rotation: .init(ix: rotation.imag.x, iy: rotation.imag.y, iz: -rotation.imag.z, r: -rotation.real),
            translation: .init(position.x, position.y, -position.z)).matrix
        if mode == .bounded {
            // visionOS translates the volume back by half of its depth or one meter, whichever is less;
            // we must compensate by adding this offset.
            volumeToWorld *= float4x4.init(translate: .init(0, 0, min(hostDimensions.z * 0.5, 1.0)))
        }
        setVolumeToWorldMatrix(volumeToWorld)
    }

    private func setVolumeToWorldMatrix(_ matrix: simd_float4x4) {
        let commandBuffer = PolySpatialRealityKit.instance.mtlCommandQueue!.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!

        commandEncoder.setComputePipelineState(PolySpatialRealityKit.instance.copyMatrixToTextureCompute!)
        var transposedMatrix = matrix.transpose
        commandEncoder.setBytes(&transposedMatrix, length: MemoryLayout<simd_float4x4>.size, index: 0)
        commandEncoder.setTexture(volumeToWorldLowLevelTexture.replace(using: commandBuffer), index: 1)
        commandEncoder.dispatchThreadgroups(
            .init(width: 1, height: 1, depth: 1), threadsPerThreadgroup: .init(width: 1, height: 1, depth: 1))

        commandEncoder.endEncoding()
        commandBuffer.commit()
    }

    nonisolated public static func == (lhs: PolySpatialVolume, rhs: PolySpatialVolume) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
