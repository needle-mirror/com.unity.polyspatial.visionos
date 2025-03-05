import CoreGraphics
import Foundation
import RealityKit

typealias ColorValue = ParticleEmitterComponent.ParticleEmitter.ParticleColor.ColorValue
typealias Color = ParticleEmitterComponent.ParticleEmitter.Color

func tint(_ value: ColorValue, _ color: Color) -> ColorValue {
    switch value {
        case .single(let value): .single(multiply(value, color))
        case .random(let a, let b): .random(a: multiply(a, color), b: multiply(b, color))
        default: value
    }
}

func multiply(_ a: Color, _ b: Color) -> Color {
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return .init(red: ar * br, green: ag * bg, blue: ab * bb, alpha: aa * ba)
}


extension ColorValue {
    func opaque() -> ColorValue {
        switch self {
            case .single(let value): .single(value.opaque())
            case .random(let a, let b): .random(a: a.opaque(), b: b.opaque())
            default: self
        }
    }
}

extension Color {
    func opaque() -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return .init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension CGColor {
    func approximatelyEqual(_ rhs: CGColor, _ epsilon: CGFloat = 1e-6) -> Bool {
        if self.colorSpace != rhs.colorSpace || self.pattern != rhs.pattern ||
                self.numberOfComponents != rhs.numberOfComponents {
            return false
        }
        // Components include alpha.
        if let lhsComponents = self.components, let rhsComponents = rhs.components {
            for (lhsComponent, rhsComponent) in zip(lhsComponents, rhsComponents) {
                if !lhsComponent.approximatelyEqual(rhsComponent, epsilon) {
                    return false
                }
            }
        }
        return true
    }
}
