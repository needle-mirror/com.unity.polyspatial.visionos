import Foundation
import RealityKit
import UIKit

// CurveKey Aliases
typealias PolySpatialParticleCurveMode = Unity_PolySpatial_Internals_PolySpatialParticleCurveMode
typealias PolySpatialParticleCurveKey = Unity_PolySpatial_Internals_PolySpatialParticleCurveKey
typealias PolySpatialParticleMinMaxCurve = Unity_PolySpatial_Internals_PolySpatialParticleMinMaxCurve
typealias PolySpatialParticleMinMaxCurveVector3 = Unity_PolySpatial_Internals_PolySpatialParticleMinMaxCurveVector3

// Gradient Aliases
typealias PolySpatialParticleGradientMode = Unity_PolySpatial_Internals_PolySpatialParticleGradientMode
typealias PolySpatialParticleGradientAlphaKey = Unity_PolySpatial_Internals_PolySpatialParticleGradientAlphaKey
typealias PolySpatialParticleGradientColorKey = Unity_PolySpatial_Internals_PolySpatialParticleGradientColorKey
typealias PolySpatialParticleGradient = Unity_PolySpatial_Internals_PolySpatialParticleGradient
typealias PolySpatialParticleMinMaxGradient = Unity_PolySpatial_Internals_PolySpatialParticleMinMaxGradient

// Particle Module Aliases
typealias PolySpatialRenderMode = Unity_PolySpatial_Internals_PolySpatialParticleRenderMode
typealias PolySpatialSortMode = Unity_PolySpatial_Internals_PolySpatialParticleSortMode
typealias PolySpatialParticleSimulationSpace = Unity_PolySpatial_Internals_PolySpatialParticleSimulationSpace
typealias PolySpatialParticleEmitterGeometry = Unity_PolySpatial_Internals_PolySpatialParticleEmitterGeometry
typealias PolySpatialParticleEmitterShape = Unity_PolySpatial_Internals_PolySpatialParticleEmitterShape
typealias PolySpatialParticleSpawnOccasion = Unity_PolySpatial_Internals_PolySpatialParticleSubEmitterType
typealias PolySpatialParticleSubEmitterInherit = Unity_PolySpatial_Internals_PolySpatialParticleSubEmitterInherit

extension PolySpatialParticleSimulationSpace {
    func toSimulationSpace() -> ParticleEmitterComponent.SimulationSpace {
        switch self {
            case .local: return .local
            case .world: return .global
            default: return .local
        }
    }

    func toBirthDirection() -> ParticleEmitterComponent.BirthDirection {
        switch self {
            case .local: return .local
            case .world: return .world
            default: return .local
        }
    }
}

extension PolySpatialRenderMode {
    func rk() -> ParticleEmitterComponent.ParticleEmitter.BillboardMode {
        switch self {
            // Stretch and mesh are not supported as of yet.
            case .billboard: return .billboard
            case .horizontalBillboard: return .billboardYAligned
            case .verticalBillboard: return .free(axis: SIMD3(1, 0, 0), variation: 0) // vertical billboard means no pitching along x axis.
            default: return .billboard
        }
    }
}

extension PolySpatialSortMode {
    func rk() -> ParticleEmitterComponent.ParticleEmitter.SortOrder {
        switch self {
            case .none_: return .unsorted
            case .oldestInFront: return .decreasingAge
            case .youngestInFront: return .increasingAge
            case .byDepth: return .increasingDepth
            case .byDistance: return .increasingDepth
        }
    }
}

extension PolySpatialBlendingMode {
    // If this particle is opaque, this function will just return that it should be opaque, otherwise, it will attempt to convert Unity's blend mode to the RK equivalent.
    func rk(_ isOpaque: Bool) -> ParticleEmitterComponent.ParticleEmitter.BlendMode {

        if isOpaque {
            return .opaque
        }

        switch self {
        case .alpha: return .alpha
        case .additive: return .additive
        default: return .alpha
        }
    }
}

extension PolySpatialParticleSpawnOccasion {
    func rk() -> ParticleEmitterComponent.SpawnOccasion {
        switch self {
            case .birth: return .onBirth
            case .death: return .onDeath
            default: return .onUpdate
        }
    }
}

extension PolySpatialParticleMinMaxCurve {
    func getValueAndVariation(_ keyBuffer: UnsafeBufferPointer<PolySpatialParticleCurveKey>?) -> (value: Float, valueVariation: Float) {
        switch self.mode {
            case .constant:
                return (self.minValue, 0)
            case .randomBetweenTwoConstants:
                // In RK, variation is applied as + - to the actual value.
                let midPoint = (self.maxValue + self.minValue) / 2
                let valVar = self.maxValue - midPoint
                return (midPoint, valVar)
            case .curve:
                // As of now, there is no support for curves in RK, so this is an attempt to at least capture some of the values.
                // Note that if a curve is a bell curve, this may very well return 0 for both.
                let firstKeyIndex = Int(self.minCurveStartIndex)
                let firstVal = keyBuffer![firstKeyIndex].value * self.curveMultiplier
                
                // The last value isn't used at present.
                // let lastKeyIndex = firstKeyIndex + Int(self.minCurveLength - 1)
                // let lastVal = keyBuffer![lastKeyIndex].value * self.curveMultiplier

                // Technically there's no value variation, just an initial value and an end value.
                return (value: firstVal, valueVariation: 0)
            case .randomBetweenTwoCurves:
                let firstKeyIndex = Int(self.minCurveStartIndex)
                let lastKeyIndex = Int(self.maxCurveStartIndex + self.maxCurveLength - 1)

                let firstVal = keyBuffer![firstKeyIndex].value * self.curveMultiplier
                let lastVal = keyBuffer![lastKeyIndex].value * self.curveMultiplier

                return (value: firstVal, valueVariation: lastVal - firstVal)
        }
    }

    func getCurveValues(_ keyBuffer: UnsafeBufferPointer<PolySpatialParticleCurveKey>?) -> (firstVal: Float, lastVal: Float, valueVariation: Float) {
        switch self.mode {
            case .constant:
                return (firstVal: self.minValue,
                        lastVal: self.minValue,
                        valueVariation: 0)
            case .randomBetweenTwoConstants:
                let midPoint = (self.maxValue + self.minValue) / 2
                let valVar = self.maxValue - midPoint
                return (firstVal: midPoint,
                        lastVal: midPoint,
                        valueVariation: valVar)
            case .curve:
                // As of now, there is no support for curves in RK, so this is an attempt to at least capture some of the values.
                // Note that if a curve is a bell curve, this may very well return 0 for both.
                let firstKeyIndex = Int(self.minCurveStartIndex)
                let lastKeyIndex = firstKeyIndex + Int(self.minCurveLength - 1)

                let firstVal = keyBuffer![firstKeyIndex].value * self.curveMultiplier
                let lastVal = keyBuffer![lastKeyIndex].value * self.curveMultiplier

                return (firstVal: firstVal,
                        lastVal: lastVal,
                        valueVariation: 0)
            case .randomBetweenTwoCurves:
                let firstKeyMinIndex = Int(self.minCurveStartIndex)
                let firstKeyMaxIndex = Int(self.minCurveStartIndex)
                let lastKeyIndex = Int(self.maxCurveStartIndex + self.maxCurveLength - 1)

                let firstMinVal = keyBuffer![firstKeyMinIndex].value * self.curveMultiplier
                let firstMaxVal = keyBuffer![firstKeyMaxIndex].value * self.curveMultiplier
                let lastVal = keyBuffer![lastKeyIndex].value * self.curveMultiplier

                let midPoint = (firstMinVal + firstMaxVal) / 2

                return (firstVal: midPoint,
                        lastVal: lastVal,
                        valueVariation: lastVal - midPoint)
        }
    }

    // Determines how quickly the size value changes from beginning to end.
    func toSizeForce(_ keyBuffer: UnsafeBufferPointer<PolySpatialParticleCurveKey>?) -> Float {
        switch self.mode {
            case .constant:
                // Default values for size mult and size force for a constant unchanging value.
                return 1.0
            case .randomBetweenTwoConstants:
                return 1.0
            case .curve:
                // As of now, there is no support for curves in RK, so this is an attempt to at least capture some of the values.
                // Note that if a curve is a bell curve, this may very well return 0 for both.
                let firstKeyIndex = Int(self.minCurveStartIndex)

                // This is inexact math, but essentially, force determines how quickly particles go from initial value to end value, the higher it is the faster it evolves. Max is roughly around 100, and min is as close to 0 as possible, but not negative. The curve key tangents can be somewhat mapped to that.
                var rate = keyBuffer![firstKeyIndex].outTangent
                rate = rate <= 0 ? 1 : (1 / rate)

                return rate
            case .randomBetweenTwoCurves:
                let minFirstKeyIndex = Int(self.minCurveStartIndex)

                var rate = keyBuffer![minFirstKeyIndex].outTangent
                rate = rate <= 0 ? 1 : (1 / rate)

                return rate
        }
    }
}

extension PolySpatialParticleMinMaxCurveVector3 {
    func rk(_ keyBuffer: UnsafeBufferPointer<PolySpatialParticleCurveKey>?) ->
    (value: SIMD3<Float>,
     valueVariation: SIMD3<Float>) {
        let x = self.x!.getValueAndVariation(keyBuffer)
        let y = self.y!.getValueAndVariation(keyBuffer)
        let z = self.z!.getValueAndVariation(keyBuffer)

        let vec3 = PolySpatialVec3(x: x.value, y: y.value, z: z.value)
        let varVec3 = PolySpatialVec3(x: x.valueVariation, y: y.valueVariation, z: z.valueVariation)

        return (value: vec3.swapCoordinateSystem(),
                valueVariation: varVec3.swapCoordinateSystem())
    }
}

extension PolySpatialParticleMinMaxGradient {
    // Grabs the first and last alpha and color keys from a gradient.
    func GetFirstAndLastValues(
        _ alphaKeyBuffer: UnsafeBufferPointer<PolySpatialParticleGradientAlphaKey>?,
        _ colorKeyBuffer: UnsafeBufferPointer<PolySpatialParticleGradientColorKey>?,
        _ gradientInfo: PolySpatialParticleGradient) -> (firstAlpha: PolySpatialParticleGradientAlphaKey,
                                                     lastAlpha: PolySpatialParticleGradientAlphaKey,
                                                     firstColor: PolySpatialParticleGradientColorKey,
                                                     lastColor: PolySpatialParticleGradientColorKey) {
        let firstAlphaIndex = Int(gradientInfo.alphaKeysStartIndex)
        let lastAlphaIndex = firstAlphaIndex + Int(gradientInfo.alphaKeysLength - 1)

        let firstColorIndex = Int(gradientInfo.colorKeysStartIndex)
        let lastColorIndex = firstColorIndex + Int(gradientInfo.colorKeysLength - 1)

        return (firstAlpha: alphaKeyBuffer![firstAlphaIndex],
                lastAlpha: alphaKeyBuffer![lastAlphaIndex],
                firstColor: colorKeyBuffer![firstColorIndex],
                lastColor: colorKeyBuffer![lastColorIndex])
    }

    // Applies the alpha key to the color key and returns that color. This may result in unintended visual effects, especially if there are fewer alpha keys than color keys or vice-versa, but this should hold until the new API comes in.
    func SyncAlphaAndColorValues(
        _ alpha: Float,
        _ color: UnityEngine_Color32) -> UIColor {
        return UnityEngine_Color32.init(
            r: color.r,
            g: color.g,
            b: color.b,
            a: UInt8(alpha * 255)).rk()
    }

    static public var colorGradientType: RealityFoundation.ParticleEmitterComponent.ParticleEmitter.OpacityCurve = .constant
    static public var colorGradientTypeFadeOut: RealityFoundation.ParticleEmitterComponent.ParticleEmitter.OpacityCurve = .easeFadeOut
    static public var colorGradientTypeFadeIn: RealityFoundation.ParticleEmitterComponent.ParticleEmitter.OpacityCurve = .easeFadeIn
    static public var colorGradientTypeBellCurve: RealityFoundation.ParticleEmitterComponent.ParticleEmitter.OpacityCurve = .gradualFadeInOut

    func rk(_ alphaKeyBuffer: UnsafeBufferPointer<PolySpatialParticleGradientAlphaKey>?,
            _ colorKeyBuffer: UnsafeBufferPointer<PolySpatialParticleGradientColorKey>?,
            _ emitter: inout ParticleEmitterComponent.ParticleEmitter) ->
                (color: ParticleEmitterComponent.ParticleEmitter.ParticleColor,
                 colorEvoPower: Float) {

        func setOpacityCurve(_ firstAlpha: Float, _ lastAlpha: Float) -> (firstVal: Float, lastVal: Float, opacityMode: RealityFoundation.ParticleEmitterComponent.ParticleEmitter.OpacityCurve) {
            if (firstAlpha > 0 && lastAlpha == 0) {
                return (firstAlpha, 1, PolySpatialParticleMinMaxGradient.colorGradientTypeFadeOut)
            } else if (firstAlpha == 0 && lastAlpha > 0) {
                return (1, lastAlpha, PolySpatialParticleMinMaxGradient.colorGradientTypeFadeIn)
            } else if (firstAlpha == 0 && lastAlpha == 0) {
                // This is a common situation that occurs with the limited approach currently - if first and last alpha is zero, the system is effectively invisible.
                return (1, 1, PolySpatialParticleMinMaxGradient.colorGradientTypeBellCurve)
            }

            return (firstAlpha, lastAlpha, PolySpatialParticleMinMaxGradient.colorGradientType)
        }

        // Need to by default set to .constant, otherwise, RK's default for this property is quickFadeInOut
        emitter.opacityCurve = PolySpatialParticleMinMaxGradient.colorGradientType
        switch self.mode {
            case .color:
                return (.constant(.single(self.minColor!.rk())), 0)
            case .randomBetweenTwoColors:
                return (.constant(.random(a: self.minColor!.rk(), b: self.maxColor!.rk())), 0)
            case .randomColor:
                // Random color mode means each color on the gradient is a possible (randomly chosen) color for the particle system. Here, we only have two possible colors to randomly choose between.
                var firstAlphaKey: PolySpatialParticleGradientAlphaKey
                var lastAlphaKey: PolySpatialParticleGradientAlphaKey
                var firstColorKey: PolySpatialParticleGradientColorKey
                var lastColorKey: PolySpatialParticleGradientColorKey

                (firstAlphaKey,
                 lastAlphaKey,
                 firstColorKey,
                 lastColorKey) = GetFirstAndLastValues(alphaKeyBuffer,
                                                       colorKeyBuffer,
                                                       self.minGradient!)

                let result = setOpacityCurve(firstAlphaKey.alpha, lastAlphaKey.alpha)
                let firstAlpha = result.firstVal
                let lastAlpha = result.lastVal
                emitter.opacityCurve = result.opacityMode

                let firstColor = SyncAlphaAndColorValues(firstAlpha, firstColorKey.color)
                let lastColor = SyncAlphaAndColorValues(lastAlpha, lastColorKey.color)

                return (.constant(.random(a: firstColor, b: lastColor)), 0)

            // Gets the first and last color value on the buffer and attempts to apply the first and last alpha value to those two colors. Again, this may cause unexpected visual results if the alpha and color keys are not aligned in Unity, but the RK API is supposed to change in the near-term, so this may end up being a temporary workaround.
            case .gradient:
                var firstAlphaKey: PolySpatialParticleGradientAlphaKey
                var lastAlphaKey: PolySpatialParticleGradientAlphaKey
                var firstColorKey: PolySpatialParticleGradientColorKey
                var lastColorKey: PolySpatialParticleGradientColorKey

                (firstAlphaKey,
                 lastAlphaKey,
                 firstColorKey,
                 lastColorKey) = GetFirstAndLastValues(alphaKeyBuffer,
                                                       colorKeyBuffer,
                                                       self.minGradient!)

                let result = setOpacityCurve(firstAlphaKey.alpha, lastAlphaKey.alpha)
                let firstAlpha = result.firstVal
                let lastAlpha = result.lastVal
                emitter.opacityCurve = result.opacityMode

                let firstColor = SyncAlphaAndColorValues(firstAlpha, firstColorKey.color)
                let lastColor = SyncAlphaAndColorValues(lastAlpha, lastColorKey.color)

                // Color evolution power is how fast a value turns to its end color.
                // Questions - does it result in a gradient in the backend? Or is it a discrete change? More testing is needed.
                return (color: .evolving(start: .single(firstColor), end: .single(lastColor)),
                        colorEvoPower: lastColorKey.time)

            case .randomBetweenTwoGradients:
                var minFirstAlphaKey: PolySpatialParticleGradientAlphaKey
                var minLastAlphaKey: PolySpatialParticleGradientAlphaKey
                var minFirstColorKey: PolySpatialParticleGradientColorKey
                var minLastColorKey: PolySpatialParticleGradientColorKey

                (minFirstAlphaKey,
                 minLastAlphaKey,
                 minFirstColorKey,
                 minLastColorKey) = GetFirstAndLastValues(alphaKeyBuffer,
                                                       colorKeyBuffer,
                                                       self.minGradient!)

                let result = setOpacityCurve(minFirstAlphaKey.alpha, minLastAlphaKey.alpha)
                let firstAlpha = result.firstVal
                let lastAlpha = result.lastVal
                emitter.opacityCurve = result.opacityMode

                let minFirstColor = SyncAlphaAndColorValues(firstAlpha, minFirstColorKey.color)
                let minLastColor = SyncAlphaAndColorValues(lastAlpha, minLastColorKey.color)

                var maxFirstAlphaKey: PolySpatialParticleGradientAlphaKey
                var maxLastAlphaKey: PolySpatialParticleGradientAlphaKey
                var maxFirstColorKey: PolySpatialParticleGradientColorKey
                var maxLastColorKey: PolySpatialParticleGradientColorKey

                (maxFirstAlphaKey,
                 maxLastAlphaKey,
                 maxFirstColorKey,
                 maxLastColorKey) = GetFirstAndLastValues(alphaKeyBuffer,
                                                       colorKeyBuffer,
                                                       self.maxGradient!)

                var firstMaxAlpha = maxFirstAlphaKey.alpha
                var lastMaxAlpha = maxLastAlphaKey.alpha
                if maxFirstAlphaKey.alpha == 0 && maxLastAlphaKey.alpha == 0 {
                    // This is a common situation that occurs with the limited approach currently - if first and last alpha is zero, the system is effectively invisible.
                    firstMaxAlpha = 0.01
                    lastMaxAlpha = 0.01
                    emitter.opacityCurve = PolySpatialParticleMinMaxGradient.colorGradientType
                }

                let maxFirstColor = SyncAlphaAndColorValues(firstMaxAlpha, maxFirstColorKey.color)
                let maxLastColor = SyncAlphaAndColorValues(lastMaxAlpha, maxLastColorKey.color)

                // The color evol power is again somewhat arbitrary as well, since the min and max curves could very well be changing at different rates.
                return (color: .evolving(start: .random(a: minFirstColor,
                                                        b: maxFirstColor),
                                         end: .random(a: minLastColor,
                                                      b: maxLastColor)),
                        colorEvoPower: minLastColorKey.time)
        }
    }
}
