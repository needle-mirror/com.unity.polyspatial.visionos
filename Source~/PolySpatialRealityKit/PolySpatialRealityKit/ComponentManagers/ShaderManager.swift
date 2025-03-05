import CoreGraphics
import UIKit
import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

// Singleton containing all variables to be tracked and additional functions used in PolySpatialRealityKit.
@MainActor
class ShaderManager {
    static var instance = ShaderManager()

    var cachedShaderGraphs: [PolySpatialAssetID: CachedShaderGraph] = [:]
    var shaderGraphInstances: [PolySpatialAssetID: ShaderGraphInstance] = [:]

    var shaderGlobalProperties: [ShaderGlobalProperty] = []
    var shaderGlobalFloatProperties: [ShaderGlobalProperty] = []
    var shaderGlobalIntegerProperties: [ShaderGlobalProperty] = []
    var shaderGlobalVectorProperties: [ShaderGlobalProperty] = []
    var shaderGlobalColorProperties: [ShaderGlobalProperty] = []
    var shaderGlobalMatrixProperties: [ShaderGlobalProperty] = []
    var shaderGlobalTextureProperties: [ShaderGlobalProperty] = []
    var shaderGlobalTextureSizeProperties: [ShaderGlobalProperty] = []
    var shaderGlobalKeywordProperties: [ShaderGlobalProperty] = []

    // The current value of the update counter, which is used to detect changes in global properties in order to
    // determine when to apply them to materials.  The counter is incremented twice per frame: once immediately after
    // setting the global property values received from the simulation (in order to distinguish between those values
    // and out-of-band values set afterwards by trackers) and once after applying all property values that have not
    // been applied via material updates (in order to prepare for the next frame).
    var shaderGlobalCurrentUpdate = 1

    static let kVolumeToWorldTextureParam = "polySpatial_VolumeToWorldTexture"
    static let kVolumeToWorldTextureHandle = ShaderGraphMaterial.parameterHandle(name: kVolumeToWorldTextureParam)

    static let kObjectBoundsCenterParam = "polySpatial_ObjectBoundsCenter"
    static let kObjectBoundsCenterHandle = ShaderGraphMaterial.parameterHandle(name: kObjectBoundsCenterParam)
    static let kObjectBoundsExtentsParam = "polySpatial_ObjectBoundsExtents"
    static let kObjectBoundsExtentsHandle = ShaderGraphMaterial.parameterHandle(name: kObjectBoundsExtentsParam)
    static let kObjectBoundsParams = [kObjectBoundsCenterParam, kObjectBoundsExtentsParam]

    static let kLightmapParam = "polySpatial_Lightmap"
    static let kLightmapHandle = ShaderGraphMaterial.parameterHandle(name: kLightmapParam)
    static let kLightmapIndParam = "polySpatial_LightmapInd"
    static let kLightmapIndHandle = ShaderGraphMaterial.parameterHandle(name: kLightmapIndParam)
    static let kLightmapSTParam = "polySpatial_LightmapST"
    static let kLightmapSTHandle = ShaderGraphMaterial.parameterHandle(name: kLightmapSTParam)
    static let kLightmapOnParam = "LIGHTMAP_ON"
    static let kLightmapOnHandle = ShaderGraphMaterial.parameterHandle(name: kLightmapOnParam)
    static let kLightmapParams = [kLightmapParam, kLightmapIndParam, kLightmapSTParam, kLightmapOnParam]

    static let kSHArParam = "polySpatial_SHAr"
    static let kSHAgParam = "polySpatial_SHAg"
    static let kSHAbParam = "polySpatial_SHAb"
    static let kSHBrParam = "polySpatial_SHBr"
    static let kSHBgParam = "polySpatial_SHBg"
    static let kSHBbParam = "polySpatial_SHBb"
    static let kSHCParam = "polySpatial_SHC"
    static let kLightProbeParams = [kSHArParam, kSHAgParam, kSHAbParam, kSHBrParam, kSHBgParam, kSHBbParam, kSHCParam]
    static let kLightProbeHandles = kLightProbeParams.map(ShaderGraphMaterial.parameterHandle)

    static let kReflectionProbeCount = 2
    static let kReflectionProbeTexturePrefix = "polySpatial_SpecCube"
    static let kReflectionProbeWeightPrefix = "polySpatial_SpecCubeWeight"
    static let kReflectionProbeTextureParams = getReflectionProbeParams(kReflectionProbeTexturePrefix)
    static let kReflectionProbeTextureHandles = kReflectionProbeTextureParams.map(ShaderGraphMaterial.parameterHandle)
    static let kReflectionProbeWeightParams = getReflectionProbeParams(kReflectionProbeWeightPrefix)
    static let kReflectionProbeWeightHandles = kReflectionProbeWeightParams.map(ShaderGraphMaterial.parameterHandle)
    static let kReflectionProbeParams = kReflectionProbeTextureParams + kReflectionProbeWeightParams

    static let kColorParam = "_Color"
    static let kColorHandle = ShaderGraphMaterial.parameterHandle(name: kColorParam)
    static let kHoverColorParam = "_HoverColor"
    static let kHoverColorHandle = ShaderGraphMaterial.parameterHandle(name: kHoverColorParam)
    static let kMainTexParam = "_MainTex"
    static let kMainTexHandle = ShaderGraphMaterial.parameterHandle(name: kMainTexParam)
    static let kMaskOperationParam = "_MaskOperation"
    static let kMaskOperationHandle = ShaderGraphMaterial.parameterHandle(name: kMaskOperationParam)
    static let kAlphaCutoffParam = "_AlphaCutoff"
    static let kAlphaCutoffHandle = ShaderGraphMaterial.parameterHandle(name: kAlphaCutoffParam)
    static let kMaskTextureParam = "_MaskTexture"
    static let kMaskTextureHandle = ShaderGraphMaterial.parameterHandle(name: kMaskTextureParam)
    static let kUVTransformParam = "_UVTransform"
    static let kUVTransformHandle = ShaderGraphMaterial.parameterHandle(name: kUVTransformParam)

    static let kCullParam = "_Cull"
    static let kZWriteControlParam = "_ZWriteControl"
    static let kZTestParam = "_ZTest"
    static let kCastShadows = "_CastShadows"

    static let kBuiltInCullModeParam = "_BUILTIN_CullMode"
    static let kBuiltInZWriteControlParam = "_BUILTIN_ZWriteControl"
    static let kBuiltInZTestParam = "_BUILTIN_ZTest"

    static func getReflectionProbeParams(_ prefix: String) -> [String] {
        (0..<kReflectionProbeCount).map { "\(prefix)\($0)" }
    }

    static func getTextureSizePropertyName(_ texturePropertyName: String) -> String {
        "TextureSize\(texturePropertyName)"
    }

    static func getTextureTransformPropertyName(_ texturePropertyName: String) -> String {
        "TextureTransform\(texturePropertyName)"
    }

    internal func getCachedShaderGraph(_ id: PolySpatialAssetID, _ asyncId: PolySpatialAssetID? = .invalidAssetId) -> CachedShaderGraph {
        if let cachedShaderGraph = cachedShaderGraphs[id] {
            return cachedShaderGraph
        }
        let loadingLoadingGraph = LoadingShaderGraph(id)

        if asyncId != .invalidAssetId {
            loadingLoadingGraph.asyncCommandId = asyncId
        }

        cachedShaderGraphs[id] = loadingLoadingGraph
        return loadingLoadingGraph
    }

    internal func SetShaderGlobalPropertyMap(_ shaderGlobalPropertyMap: PolySpatialShaderGlobalPropertyMap) {
        shaderGlobalFloatProperties = (0..<shaderGlobalPropertyMap.floatPropertiesCount).map {
            .init(shaderGlobalPropertyMap.floatProperties(at: $0)!, .float(0.0))
        }
        shaderGlobalIntegerProperties = (0..<shaderGlobalPropertyMap.integerPropertiesCount).map {
            .init(shaderGlobalPropertyMap.integerProperties(at: $0)!, .int(0))
        }
        shaderGlobalVectorProperties = (0..<shaderGlobalPropertyMap.vectorPropertiesCount).map {
            .init(shaderGlobalPropertyMap.vectorProperties(at: $0)!, .simd4Float(.zero))
        }
        shaderGlobalColorProperties = (0..<shaderGlobalPropertyMap.colorPropertiesCount).map {
            .init(shaderGlobalPropertyMap.colorProperties(at: $0)!, .color(UIColor.black))
        }
        shaderGlobalMatrixProperties = (0..<shaderGlobalPropertyMap.matrixPropertiesCount).map {
            .init(shaderGlobalPropertyMap.matrixProperties(at: $0)!, .float4x4(.init()))
        }
        shaderGlobalTextureProperties = (0..<shaderGlobalPropertyMap.texturePropertiesCount).map {
            .init(shaderGlobalPropertyMap.textureProperties(at: $0)!, .textureResource(
                PolySpatialRealityKit.instance.GetTextureAssetForId(
                    PolySpatialAssetID.invalidAssetId).texture.resource))
        }
        shaderGlobalTextureSizeProperties = (0..<shaderGlobalPropertyMap.texturePropertiesCount).map {
            .init(ShaderManager.getTextureSizePropertyName(
                shaderGlobalPropertyMap.textureProperties(at: $0)!), .simd3Float(.zero))
        }
        shaderGlobalKeywordProperties = (0..<shaderGlobalPropertyMap.keywordsCount).map {
            .init(shaderGlobalPropertyMap.keywords(at: $0)!, .bool(false))
        }
        shaderGlobalProperties = shaderGlobalFloatProperties + shaderGlobalIntegerProperties +
            shaderGlobalVectorProperties + shaderGlobalColorProperties + shaderGlobalMatrixProperties +
            shaderGlobalTextureProperties + shaderGlobalTextureSizeProperties + shaderGlobalKeywordProperties

        for (_, cachedShaderGraph) in cachedShaderGraphs {
            cachedShaderGraph.updateShaderGlobalProperties()
        }

        for shaderGraphInstance in shaderGraphInstances.values {
            shaderGraphInstance.insertIntoGlobalProperties()
        }
    }

    internal func SetShaderGlobalPropertyValues(_ shaderGlobalPropertyValues: PolySpatialShaderGlobalPropertyValues) {
        for (index, property) in shaderGlobalFloatProperties.enumerated() {
            property.setFloat(shaderGlobalPropertyValues.floatProperties(at: Int32(index)))
        }
        for (index, property) in shaderGlobalIntegerProperties.enumerated() {
            property.setInteger(shaderGlobalPropertyValues.integerProperties(at: Int32(index)))
        }
        for (index, property) in shaderGlobalVectorProperties.enumerated() {
            property.setVector4(ConvertPolySpatialVec4VectorToFloat4(
                shaderGlobalPropertyValues.vectorProperties(at: Int32(index))!))
        }
        for (index, property) in shaderGlobalColorProperties.enumerated() {
            property.setColor(shaderGlobalPropertyValues.colorProperties(at: Int32(index))!.cgColor())
        }
        for (index, property) in shaderGlobalMatrixProperties.enumerated() {
            property.setMatrix(ConvertPolySpatialMatrix4x4ToFloat4x4(
                shaderGlobalPropertyValues.matrixProperties(at: Int32(index))!))
        }
        for (index, property) in shaderGlobalTextureProperties.enumerated() {
            property.setTexture(shaderGlobalPropertyValues.textureProperties(at: Int32(index))!,
                shaderGlobalTextureSizeProperties[index])
        }
        for (index, property) in shaderGlobalKeywordProperties.enumerated() {
            property.setBool(shaderGlobalPropertyValues.keywordValues(at: Int32(index)))
        }

        // Increment the update counter so that global updates performed by trackers (e.g., the volume camera tracker,
        // which sets volumeToWorldProperty) can be distinguished from global updates received from the simulation.
        // Global updates received from the simulation can be applied to materials when they are updated, whereas
        // updates received from trackers can only be applied in ApplyRemainingShaderGlobalPropertyValues (because they
        // happen after all material updates are completed).
        shaderGlobalCurrentUpdate += 1
    }

    internal func ApplyRemainingShaderGlobalPropertyValues() {
        for shaderGlobalProperty in shaderGlobalProperties {
            // We update any properties whose last update was on this frame: either from the simulation global update
            // (shaderGlobalCurrentUpdate - 1) or from a global update performed by a tracker
            // (shaderGlobalCurrentUpdate).
            if shaderGlobalCurrentUpdate - shaderGlobalProperty.lastUpdate < 2 {
                for shaderGraphInstance in shaderGlobalProperty.shaderGraphInstances {
                    shaderGraphInstance.updateGlobalsAndMaterialDefinition()
                }
            }
        }

        // Advance the update immediately in case we have global updates outside of the frame cycle.
        shaderGlobalCurrentUpdate += 1
    }

    internal func DeleteShaderGraphMaterialAsset(_ id: PolySpatialAssetID) {
        PolySpatialRealityKit.instance.DeleteMaterialAsset(id)
        shaderGraphInstances[id]?.removeSelf()
    }
}
