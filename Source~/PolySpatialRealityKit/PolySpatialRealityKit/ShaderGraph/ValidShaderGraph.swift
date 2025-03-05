import CoreGraphics
import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

class ValidShaderGraph: CachedShaderGraph {
    let material: ShaderGraphMaterial
    let castShadows: Bool
    let floatHandles: [MaterialParameters.Handle]
    let floatPropertyAppliers: [((ValidShaderGraphInstance, Float) -> Void)?]
    let intHandles: [MaterialParameters.Handle]
    let vectorHandles: [MaterialParameters.Handle]
    let vectorIsVector2: [Bool]
    let colorHandles: [MaterialParameters.Handle]
    let matrixHandles: [MaterialParameters.Handle]
    let matrixValueCreators: [(simd_float4x4) -> MaterialParameters.Value]
    let textureHandles: [MaterialParameters.Handle]
    let keywordHandles: [MaterialParameters.Handle]
    let parameterNames: Set<String>
    let textureSizeHandles: [MaterialParameters.Handle?]
    let textureTransformHandles: [MaterialParameters.Handle?]
    let hasVolumeToWorldTextureProperty: Bool
    let hasObjectBoundsProperties: Bool
    let hasLightmapProperties: Bool
    let hasLightProbeProperties: Bool
    let hasReflectionProbeProperties: Bool
    var shaderGlobalProperties: [ShaderGlobalProperty] = []
    var shaderGraphInstances: Set<ValidShaderGraphInstance> = []

    init(_ shaderId: PolySpatialAssetID, _ material: ShaderGraphMaterial,
        _ materialProperties: PolySpatialRealityKit.ShaderPropertyMapData) {

        var customizedMaterial = material
        customizedMaterial.faceCulling = materialProperties.faceCulling
        customizedMaterial.readsDepth = materialProperties.readsDepth
        customizedMaterial.writesDepth = materialProperties.writesDepth
        self.material = customizedMaterial

        castShadows = materialProperties.castShadows

        self.floatHandles = materialProperties.floatProperties.map(ShaderGraphMaterial.parameterHandle)

        if materialProperties.allowMaterialOverride {
            floatPropertyAppliers = materialProperties.floatProperties.map { propertyName in
                switch propertyName {
                    case ShaderManager.kCullParam, ShaderManager.kBuiltInCullModeParam: { instance, value in
                        switch value {
                            case 0: instance.material.faceCulling = .none
                            case 1: instance.material.faceCulling = .front
                            case 2: instance.material.faceCulling = .back
                            default: PolySpatialRealityKit.LogWarning("Unknown face culling value: \(value)")
                        }
                    }
                    case ShaderManager.kZWriteControlParam, ShaderManager.kBuiltInZWriteControlParam: { instance, value in
                        switch value {
                            case 0, 1: instance.material.writesDepth = true // Auto, ForceEnabled
                            case 2: instance.material.writesDepth = false // ForceDisabled
                            default: PolySpatialRealityKit.LogWarning("Unknown z write control value: \(value)")
                        }
                    }
                    case ShaderManager.kZTestParam, ShaderManager.kBuiltInZTestParam: { instance, value in
                        switch value {
                            case 4: instance.material.readsDepth = true // LEqual
                            case 8: instance.material.readsDepth = false // Always
                            default: PolySpatialRealityKit.LogWarning("Unsupported z test value: \(value)")
                        }
                    }
                    case ShaderManager.kCastShadows: { instance, value in
                        switch value {
                            case 0: instance.castShadows = false
                            case 1: instance.castShadows = true
                            default: PolySpatialRealityKit.LogWarning("Unsupported cast shadows value: \(value)")
                        }
                    }
                    default: nil
                }
            }
        } else {
            floatPropertyAppliers = .init(repeating: nil, count: materialProperties.floatProperties.count)
        }

        self.intHandles = materialProperties.intProperties.map(ShaderGraphMaterial.parameterHandle)
        self.vectorHandles = materialProperties.vector4Properties.map(ShaderGraphMaterial.parameterHandle)
        self.vectorIsVector2 = materialProperties.vector4Properties.map {
            if case .simd2Float(_) = material.getParameter(name: $0) {
                return true
            } else {
                return false
            }
        }
        self.colorHandles = materialProperties.colorProperties.map(ShaderGraphMaterial.parameterHandle)
        self.matrixHandles = materialProperties.matrix4x4Properties.map(ShaderGraphMaterial.parameterHandle)
        self.matrixValueCreators = materialProperties.matrix4x4Properties.map { property in
            switch material.getParameter(name: property) {
                case .float2x2(_): { matrix in .float2x2(.init(matrix[0].xy, matrix[1].xy)) }
                case .float3x3(_): { matrix in .float3x3(.init(matrix[0].xyz, matrix[1].xyz, matrix[2].xyz)) }
                default: { matrix in .float4x4(matrix) }
            }
        }
        self.textureHandles = materialProperties.textureProperties.map(ShaderGraphMaterial.parameterHandle)
        self.keywordHandles = materialProperties.keywords.map(ShaderGraphMaterial.parameterHandle)
        let parameterNames = Set(material.parameterNames) // Store as local to allow use in closure.
        self.parameterNames = parameterNames

        // Note: we need to use string names rather than parameter handles when we determine whether the
        // shader graph references a parameter.  Using handles always returns nil before the parameter is set.
        self.textureSizeHandles = materialProperties.textureProperties.map { textureProperty in
            let property = ShaderManager.getTextureSizePropertyName(textureProperty)
            return parameterNames.contains(property) ? ShaderGraphMaterial.parameterHandle(name: property) : nil
        }
        self.textureTransformHandles = materialProperties.textureProperties.enumerated().map { (i, textureProperty) in
            let property = ShaderManager.getTextureTransformPropertyName(textureProperty)
            return materialProperties.texturePropertyTransformsEnabled[i] && parameterNames.contains(property) ?
                ShaderGraphMaterial.parameterHandle(name: property) : nil
        }
        self.hasVolumeToWorldTextureProperty = parameterNames.contains(ShaderManager.kVolumeToWorldTextureParam)
        self.hasObjectBoundsProperties = ShaderManager.kObjectBoundsParams.contains(where: parameterNames.contains)
        self.hasLightmapProperties = ShaderManager.kLightmapParams.contains(where: parameterNames.contains)
        self.hasLightProbeProperties = ShaderManager.kLightProbeParams.contains(where: parameterNames.contains)
        self.hasReflectionProbeProperties = ShaderManager.kReflectionProbeParams.contains(where: parameterNames.contains)
        super.init(shaderId)
        updateShaderGlobalProperties()
    }

    override func updateMaterialDefinition(
        _ id: PolySpatialAssetID, _ materialDef: PolySpatialShaderMaterial, _ data: ByteBuffer) {

        var shaderGraphInstance: ValidShaderGraphInstance
        let currentInstance = ShaderManager.instance.shaderGraphInstances[id]
        if let validInstance = currentInstance as? ValidShaderGraphInstance, validInstance.shaderGraph === self {
            shaderGraphInstance = validInstance
        } else {
            ShaderManager.instance.shaderGraphInstances[id]?.removeSelf()
            shaderGraphInstance = .init(id, self)
            ShaderManager.instance.shaderGraphInstances[id] = shaderGraphInstance
        }

        shaderGraphInstance.updateMaterialDefinition(materialDef)
    }

    override func tryStartLoading() {
        // Remove our instances so that they aren't in the global property list and don't try to reference
        // this object after it has been destroyed.
        for shaderGraphInstance in shaderGraphInstances {
            shaderGraphInstance.removeSelf()
        }

        super.tryStartLoading()
    }

    override func updateShaderGlobalProperties() {
        shaderGlobalProperties = ShaderManager.instance.shaderGlobalProperties.filter {
            // Note: we need to use string names rather than parameter handles when we determine whether the
            // shader graph references a parameter.  Using handles always returns nil before the parameter is set.
            parameterNames.contains($0.name)
        }
    }

    override func removeSelf() {
        for shaderGraphInstance in shaderGraphInstances {
            shaderGraphInstance.removeSelf()
        }
        super.removeSelf()
    }
}
