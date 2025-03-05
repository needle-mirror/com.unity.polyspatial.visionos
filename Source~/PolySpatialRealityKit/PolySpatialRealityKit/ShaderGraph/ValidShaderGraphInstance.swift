import CoreGraphics
import Foundation
import RealityKit

class ValidShaderGraphInstance: ShaderGraphInstance {
    unowned let shaderGraph: ValidShaderGraph
    var material: ShaderGraphMaterial
    var setParams: Set<MaterialParameters.Handle> = []
    var textureParams: Dictionary<MaterialParameters.Handle, PolySpatialRealityKit.TextureParam> = [:]

    // The value of shaderGlobalCurrentUpdate when global properties were last applied to this instance.
    // This is used to determine when instances must be updated (if this value is not equal to the current
    // shaderGlobalCurrentUpdate), and which properties to apply when doing so (all properties whose last updates
    // are greater than this value).
    var lastGlobalUpdate = 0

    override var hasVolumeToWorldTextureProperty: Bool { shaderGraph.hasVolumeToWorldTextureProperty }
    override var hasObjectBoundsProperties: Bool { shaderGraph.hasObjectBoundsProperties }
    override var hasLightmapProperties: Bool { shaderGraph.hasLightmapProperties }
    override var hasLightProbeProperties: Bool { shaderGraph.hasLightProbeProperties }
    override var hasReflectionProbeProperties: Bool { shaderGraph.hasReflectionProbeProperties }

    init(_ id: PolySpatialAssetID, _ shaderGraph: ValidShaderGraph) {
        self.shaderGraph = shaderGraph
        self.material = shaderGraph.material
        super.init(id)
        castShadows = shaderGraph.castShadows
        shaderGraph.shaderGraphInstances.insert(self)
        insertIntoGlobalProperties()
    }

    override func removeSelf() {
        super.removeSelf()
        shaderGraph.shaderGraphInstances.remove(self)
        removeFromGlobalProperties()
    }

    override func insertIntoGlobalProperties() {
        for shaderGlobalProperty in shaderGraph.shaderGlobalProperties {
            shaderGlobalProperty.shaderGraphInstances.insert(self)
        }
    }

    func removeFromGlobalProperties() {
        for shaderGlobalProperty in shaderGraph.shaderGlobalProperties {
            shaderGlobalProperty.shaderGraphInstances.remove(self)
        }
    }

    func updateMaterialDefinition(_ materialDef: PolySpatialShaderMaterial) {
        var hasPropertiesIndex = 0
        for (index, handle) in shaderGraph.floatHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                let propertyValue = materialDef.floatProperties[index]
                if let propertyApplier = shaderGraph.floatPropertyAppliers[index] {
                    propertyApplier(self, propertyValue)
                } else {
                    try? material.setParameter(handle: handle, value: .float(propertyValue))
                    setParams.insert(handle)
                }
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.intHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                let propertyValue = materialDef.intProperties[index]
                try? material.setParameter(handle: handle, value: .int(propertyValue))
                setParams.insert(handle)
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.vectorHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                let propertyValue = ConvertPolySpatialVec4VectorToFloat4(
                    materialDef.vector4Properties(at: Int32(index))!)
                try? material.setParameter(
                    handle: handle,
                    value: shaderGraph.vectorIsVector2[index] ?
                        .simd2Float(propertyValue.xy) : .simd4Float(propertyValue))
                setParams.insert(handle)
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.colorHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                let propertyValue = materialDef.colorProperties(at: Int32(index))!.cgColor()
                try? material.setParameter(handle: handle, value: .color(propertyValue))
                setParams.insert(handle)
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.matrixHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                let propertyValue = ConvertPolySpatialMatrix4x4ToFloat4x4(
                    materialDef.matrix4x4Properties(at: Int32(index))!)
                try? material.setParameter(
                    handle: handle, value: shaderGraph.matrixValueCreators[index](propertyValue))
                setParams.insert(handle)
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.textureHandles.enumerated() {
            if materialDef.hasProperties[hasPropertiesIndex] {
                setTextureParam(
                    handle,
                    PolySpatialRealityKit.TextureParam(
                        materialDef.textureProperties(at: Int32(index))!, shaderGraph.textureSizeHandles[index]))

                if let transformHandle = shaderGraph.textureTransformHandles[index] {
                    let propertyValue = ConvertPolySpatialVec4VectorToFloat4(
                        materialDef.textureTransformProperties(at: Int32(index))!)
                    try? material.setParameter(handle: transformHandle, value: .simd4Float(propertyValue))
                }
                setParams.insert(handle)
            }
            hasPropertiesIndex += 1
        }
        for (index, handle) in shaderGraph.keywordHandles.enumerated() {
            let keywordValue = materialDef.keywordValues[index]
            try? material.setParameter(handle: handle, value: .bool(keywordValue))
        }

        // Set globals, register the updated material. and push the update to all entities that reference it.
        updateGlobalsAndMaterialDefinition(true)
    }

    func updateGlobalsAndMaterialDefinition(_ fromCreateOrUpdateMaterial: Bool = false) {
        var currentUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
        var shouldUpdateMaterial = false

        // If we are invoked from CreateOrUpdateShaderGraphMaterialAsset2, we must use the previous value of
        // shaderGlobalCurrentUpdate (that is, the value associated with global updates received from the
        // simulation, rather than from trackers).  This is because the current value will have already been
        // incremented in preparation for global updates supplied by trackers, but those updates will not yet
        // have taken place (because tracker updates happen after material updates).  We also force a material
        // definition update.
        if fromCreateOrUpdateMaterial {
            currentUpdate -= 1
            shouldUpdateMaterial = true

        // When called from ApplyRemainingShaderGlobalPropertyValues, we can exit early if already up-to-date.
        } else if lastGlobalUpdate == currentUpdate {
            return
        }
        for shaderGlobalProperty in shaderGraph.shaderGlobalProperties {
            // Note that we don't set params that have already been set from the material definition; those
            // override global properties.
            if shaderGlobalProperty.lastUpdate > lastGlobalUpdate && !setParams.contains(shaderGlobalProperty.handle) {
                if let textureParam = shaderGlobalProperty.textureParam {
                    setTextureParam(shaderGlobalProperty.handle, textureParam)
                } else {
                    try? material.setParameter(
                        handle: shaderGlobalProperty.handle, value: shaderGlobalProperty.value)
                }
                shouldUpdateMaterial = true
            }
        }
        lastGlobalUpdate = currentUpdate

        if shouldUpdateMaterial {
            PolySpatialRealityKit.instance.UpdateMaterialDefinition(
                PolySpatialRealityKit.ShaderGraphMaterialAsset(id, material, textureParams),
                ShaderManager.instance.DeleteShaderGraphMaterialAsset)
        }
    }

    func setTextureParam(_ handle: MaterialParameters.Handle, _ param: PolySpatialRealityKit.TextureParam) {
        textureParams[handle] = param

        // If the id is invalid (i.e., the texture property is null), the asset will be the magenta error texture.
        // We shouldn't see this, since we transfer default textures (Texture2D.white, Texture2D.black, etc.)
        let asset = PolySpatialRealityKit.instance.GetTextureAssetForId(param.id)
        try? material.setParameter(handle: handle, value: .textureResource(asset.texture.resource))
        if let sizeHandle = param.sizeHandle {
            try? material.setParameter(handle: sizeHandle, value: .simd3Float(asset.size))
        }
    }
}
