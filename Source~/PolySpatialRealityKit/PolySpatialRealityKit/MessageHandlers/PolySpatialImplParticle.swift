import Foundation
import RealityKit
import UIKit

extension PolySpatialRealityKit {
    struct VfXMaterial {
        var texture: TextureAsset?
        var blendMode: PolySpatialBlendingMode
        var color: UIColor
        var isLit: Bool
        var isTransparent: Bool
        var opacity: Float
    }
}
