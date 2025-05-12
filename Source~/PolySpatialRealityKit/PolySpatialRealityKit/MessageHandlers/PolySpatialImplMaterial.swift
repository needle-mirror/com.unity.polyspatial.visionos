import RealityKit
import UIKit

@_implementationOnly import FlatBuffers

// MaterialParameters.Handle doesn't implement Hashable and doesn't provide any accessors
// for its internal state, so we hash and compare it as an opaque byte array.
extension MaterialParameters.Handle: @retroactive Hashable {
    public static func == (lhs: MaterialParameters.Handle, rhs: MaterialParameters.Handle) -> Bool {
        withUnsafeBytes(of: lhs) { leftBytes in
            withUnsafeBytes(of: rhs) { rightBytes in
                leftBytes.elementsEqual(rightBytes)
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes(of: self) {
            hasher.combine(bytes: $0)
        }
    }
}

extension PolySpatialRealityKit {
    class ShaderGraphData {
        var name: String
        var materialXEncoding: String
        var materialXPrimPath: String

        init(_ name: String, _ materialXEncoding: String, _ materialXPrimPath: String) {
            self.name = name
            self.materialXEncoding = materialXEncoding
            self.materialXPrimPath = materialXPrimPath
        }
    }

    class ShaderPropertyMapData {
        var name: String
        var floatProperties: [String]
        var intProperties: [String]
        var vector4Properties: [String]
        var colorProperties: [String]
        var matrix4x4Properties: [String]
        var textureProperties: [String]
        var texturePropertyTransformsEnabled: [Bool]
        var keywords: [String]
        var faceCulling: MaterialParameterTypes.FaceCulling
        var readsDepth: Bool
        var writesDepth: Bool
        var castShadows: Bool
        var allowMaterialOverride: Bool

        init(
            _ name: String,
            _ floatProperties: [String],
            _ intProperties: [String],
            _ vector4Properties: [String],
            _ colorProperties: [String],
            _ matrix4x4Properties: [String],
            _ textureProperties: [String],
            _ texturePropertyTransformsEnabled: [Bool],
            _ keywords: [String],
            _ faceCulling: MaterialParameterTypes.FaceCulling,
            _ readsDepth: Bool,
            _ writesDepth: Bool,
            _ castShadows: Bool,
            _ allowMaterialOverride: Bool) {

            self.name = name
            self.floatProperties = floatProperties
            self.intProperties = intProperties
            self.vector4Properties = vector4Properties
            self.colorProperties = colorProperties
            self.matrix4x4Properties = matrix4x4Properties
            self.textureProperties = textureProperties
            self.texturePropertyTransformsEnabled = texturePropertyTransformsEnabled
            self.keywords = keywords
            self.faceCulling = faceCulling
            self.readsDepth = readsDepth
            self.writesDepth = writesDepth
            self.castShadows = castShadows
            self.allowMaterialOverride = allowMaterialOverride
        }
    }

    class UnlitMaterialAsset: MaterialAsset {
        var material: UnlitMaterial
        var flipped: UnlitMaterial?
        let colorTextureID: PolySpatialAssetID

        var program: UnlitMaterial.Program {
            get { material.program }
            set {
                material.program = newValue
                flipped = nil
                PolySpatialRealityKit.instance.NotifyMeshOrMaterialObservers(id)
            }
        }

        override var textureIDs: any Collection<PolySpatialAssetID> {
            get {
                // We could just return the invalid colorTextureID, but then superclass constructor
                // would attempt to reference PolySpatialRealityKit.instance, which would be an
                // error when creating the invalid material in PolySpatialRealityKit.init.
                colorTextureID.isValid ? CollectionOfOne(colorTextureID) : EmptyCollection()
            }
        }

        init(_ id: PolySpatialAssetID, _ material: UnlitMaterial,
            colorTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId) {

            self.material = material
            self.colorTextureID = colorTextureID

            super.init(id)
        }

        override func getMaterial(_ flip: Bool = false) -> Material {
            if !flip {
                return material
            }
            if let existingFlipped = flipped {
                return existingFlipped
            }
            var newFlipped = material
            newFlipped.faceCulling = MaterialAsset.getFlippedCulling(material.faceCulling)
            flipped = newFlipped
            return newFlipped
        }

        override func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, TextureAsset>) {
            if let asset = assets[colorTextureID] {
                material.color.texture!.resource = asset.texture.resource
            }
            flipped = nil
            super.texturesUpdated(assets)
        }
    }

    class OcclusionMaterialAsset: MaterialAsset {
        let material: OcclusionMaterial

        init(_ id: PolySpatialAssetID, _ material: OcclusionMaterial) {
            self.material = material

            super.init(id)
        }

        override func getMaterial(_ flip: Bool = false) -> Material {
            material
        }
    }

    class PhysicallyBasedMaterialAsset: MaterialAsset {
        var material: PhysicallyBasedMaterial
        var flipped: PhysicallyBasedMaterial?
        let baseColorTextureID: PolySpatialAssetID
        let emissiveColorTextureID: PolySpatialAssetID
        let metallicTextureID: PolySpatialAssetID
        let specularTextureID: PolySpatialAssetID
        let roughnessTextureID: PolySpatialAssetID
        let normalTextureID: PolySpatialAssetID
        let ambientOcclusionTextureID: PolySpatialAssetID
        let clearcoatTextureID: PolySpatialAssetID
        let clearcoatRoughnessTextureID: PolySpatialAssetID

        var program: PhysicallyBasedMaterial.Program {
            get { material.program }
            set {
                // We should be able to just set the program on the existing material, since
                // it's a settable property.  However, doing so seems to clear (at least) the
                // base texture, so instead we create an entirely new material and copy the
                // properties.
                var newMaterial = PhysicallyBasedMaterial(program: newValue)
                newMaterial.faceCulling = material.faceCulling
                newMaterial.baseColor = material.baseColor
                newMaterial.emissiveIntensity = material.emissiveIntensity
                newMaterial.emissiveColor = material.emissiveColor
                newMaterial.metallic = material.metallic
                newMaterial.specular = material.specular
                newMaterial.roughness = material.roughness
                newMaterial.normal = material.normal
                newMaterial.ambientOcclusion = material.ambientOcclusion
                newMaterial.clearcoat = material.clearcoat
                newMaterial.clearcoatRoughness = material.clearcoatRoughness
                newMaterial.blending = material.blending
                newMaterial.opacityThreshold = material.opacityThreshold
                newMaterial.textureCoordinateTransform = material.textureCoordinateTransform
                material = newMaterial
                flipped = nil
                PolySpatialRealityKit.instance.NotifyMeshOrMaterialObservers(id)
            }
        }

        override var textureIDs: any Collection<PolySpatialAssetID> {
            get {
                [baseColorTextureID, emissiveColorTextureID, metallicTextureID, specularTextureID,
                    roughnessTextureID, normalTextureID, ambientOcclusionTextureID, clearcoatTextureID,
                    clearcoatRoughnessTextureID]
            }
        }

        init(_ id: PolySpatialAssetID, _ material: PhysicallyBasedMaterial,
            baseColorTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            emissiveColorTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            metallicTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            specularTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            roughnessTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            normalTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            ambientOcclusionTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            clearcoatTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId,
            clearcoatRoughnessTextureID: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId) {

            self.material = material
            self.baseColorTextureID = baseColorTextureID
            self.emissiveColorTextureID = emissiveColorTextureID
            self.metallicTextureID = metallicTextureID
            self.specularTextureID = specularTextureID
            self.roughnessTextureID = roughnessTextureID
            self.normalTextureID = normalTextureID
            self.ambientOcclusionTextureID = ambientOcclusionTextureID
            self.clearcoatTextureID = clearcoatTextureID
            self.clearcoatRoughnessTextureID = clearcoatRoughnessTextureID

            super.init(id)
        }

        override func getMaterial(_ flip: Bool = false) -> Material {
            if !flip {
                return material
            }
            if let existingFlipped = flipped {
                return existingFlipped
            }
            var newFlipped = material
            newFlipped.faceCulling = MaterialAsset.getFlippedCulling(material.faceCulling)
            flipped = newFlipped
            return newFlipped
        }

        override func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, TextureAsset>) {
            if let asset = assets[baseColorTextureID] {
                material.baseColor.texture!.resource = asset.texture.resource
            }
            if let asset = assets[emissiveColorTextureID] {
                material.emissiveColor.texture!.resource = asset.texture.resource
            }
            if let asset = assets[metallicTextureID] {
                material.metallic.texture!.resource = asset.texture.resource
            }
            if let asset = assets[specularTextureID] {
                material.specular.texture!.resource = asset.texture.resource
            }
            if let asset = assets[roughnessTextureID] {
                material.roughness.texture!.resource = asset.texture.resource
            }
            if let asset = assets[normalTextureID] {
                material.normal.texture!.resource = asset.texture.resource
            }
            if let asset = assets[ambientOcclusionTextureID] {
                material.ambientOcclusion.texture!.resource = asset.texture.resource
            }
            if let asset = assets[clearcoatTextureID] {
                material.clearcoat.texture!.resource = asset.texture.resource
            }
            if let asset = assets[clearcoatRoughnessTextureID] {
                material.clearcoatRoughness.texture!.resource = asset.texture.resource
            }
            flipped = nil
            super.texturesUpdated(assets)
        }
    }

    struct TextureParam: Equatable {
        let id: PolySpatialAssetID
        let sizeHandle: MaterialParameters.Handle?

        init(_ id: PolySpatialAssetID, _ sizeHandle: MaterialParameters.Handle?) {
            self.id = id
            self.sizeHandle = sizeHandle
        }
    }

    class ShaderGraphMaterialAsset: MaterialAsset {
        var material: ShaderGraphMaterial
        var flipped: ShaderGraphMaterial?
        let textureParams: Dictionary<MaterialParameters.Handle, TextureParam>

        override var textureIDs: any Collection<PolySpatialAssetID> {
            get {
                textureParams.values.map { $0.id }
            }
        }

        init(_ id: PolySpatialAssetID, _ material: ShaderGraphMaterial,
            _ textureParams: Dictionary<MaterialParameters.Handle, TextureParam>) {

            self.material = material
            self.textureParams = textureParams

            super.init(id)
        }

        override func getMaterial(_ flip: Bool = false) -> Material {
            if !flip {
                return material
            }
            if let existingFlipped = flipped {
                return existingFlipped
            }
            var newFlipped = material
            newFlipped.faceCulling = MaterialAsset.getFlippedCulling(material.faceCulling)
            flipped = newFlipped
            return newFlipped
        }

        override func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, TextureAsset>) {
            for (handle, param) in textureParams {
                if let asset = assets[param.id] {
                    try? material.setParameter(handle: handle, value: .textureResource(asset.texture.resource))
                    if let sizeHandle = param.sizeHandle {
                        try? material.setParameter(handle: sizeHandle, value: .simd3Float(asset.size))
                    }
                }
            }
            flipped = nil
            super.texturesUpdated(assets)
        }
    }

    // A material with AssetID `id` now has a new Material representation.  There is no
    // Material.replace, so we have to keep track ourselves of what model entities use what material
    // and go and update them ourselves.
    func UpdateMaterialDefinition(_ asset: MaterialAsset, _ deleter: ((PolySpatialAssetID) -> Void)? = nil) {
        materialAssets.updateValue(asset, forKey: asset.id)?.dispose()

        NotifyMeshOrMaterialObservers(asset.id)

        assetDeleters[asset.id] = deleter ?? DeleteMaterialAsset
    }

    // We don't really delete the asset, we just remove it from the
    // cache. Any entity still using the asset will keep it around
    // until that entity is either destroyed or someone changes the
    // assigned asset for it.
    //
    func DeleteMaterialAsset(_ id: PolySpatialAssetID) {
        materialAssets.removeValue(forKey: id)?.dispose()
        vfxMaterials.removeValue(forKey: id)

        // If we get here, this asset should no longer be referenced by anything,
        // because it's gone on the Unity side.
        //
        // TODO -- LXR-2551 this assert currently triggers very often! We don't use PolySpatialAssert
        // because that would log and all our tests fail. Instead, just print to Swift output
        // only so that we don't totally silence this.
        //PolySpatialAssert(materialReferences[id] == nil || materialReferences[id]!.count == 0,
        //                  "Material \(id) still in use, has \(materialReferences[id]!.count) references")
        if meshOrMaterialReferences[id] != nil && meshOrMaterialReferences[id]!.count != 0 {
            print("Material \(id) still in use, has \(meshOrMaterialReferences[id]!.count) references")
        }
    }

    func toTextureAsset(_ tex: PolySpatialAssetID) -> TextureAsset? {
        return tex.isValid ? GetTextureAssetForId(tex) : nil
    }

    func toTextureParameter(_ tex: PolySpatialTexture) -> MaterialParameters.Texture? {
        toTextureParameter(tex.textureId.id)
    }

    func toTextureParameter(_ tex: PolySpatialAssetID) -> MaterialParameters.Texture? {
        if !tex.isValid {
            return nil
        }
        return GetTextureAssetForId(tex).texture
    }

    func toRealityKitOpacityThreshold(_ opacityThreshold: PolySpatialOpacityThreshold) -> Float? {
        return opacityThreshold.isEnabled ? opacityThreshold.value : nil
    }

    func CreateUninitializedMaterialAsset(_ id: PolySpatialAssetID) -> MaterialAsset {
        var material = CreateUnlitMaterial()
        material.color = .init(tint: .magenta)
        materialAssets[id] = UnlitMaterialAsset(id, material)
        assetDeleters[id] = DeleteMaterialAsset
        return materialAssets[id]!
    }

    func getOrCreateUnlitMaterial(_ id: PolySpatialAssetID, _ blendingMode: PolySpatialBlendingMode) -> UnlitMaterial {
        let existingAsset = materialAssets[id] as? UnlitMaterialAsset

        if let existingMaterial = existingAsset?.material,
                existingMaterial.program.descriptor.blendMode == blendingMode.rk() {
            return existingMaterial
        } else if blendingMode != .additive {
            pendingUnlitAdditiveMaterialIds.remove(id)
            return CreateUnlitMaterial()
        } else if let unlitAdditiveProgram = self.unlitAdditiveProgram {
            return .init(program: unlitAdditiveProgram)
        } else {
            pendingUnlitAdditiveMaterialIds.insert(id)
            return CreateUnlitMaterial()
        }
    }

    func CreateUnlitMaterial() -> UnlitMaterial {
        if let unlitAlphaProgram {
            return .init(program: unlitAlphaProgram)
        } else {
            return .init(applyPostProcessToneMap: false)
        }
    }

    func getOrCreatePhysicallyBasedMaterial(
        _ id: PolySpatialAssetID, _ blendingMode: PolySpatialBlendingMode) -> PhysicallyBasedMaterial {

        let existingAsset = materialAssets[id] as? PhysicallyBasedMaterialAsset

        if let existingMaterial = existingAsset?.material,
                existingMaterial.program.descriptor.blendMode == blendingMode.rk() {
            return existingMaterial
        } else if blendingMode != .additive {
            pendingPhysicallyBasedAdditiveMaterialIds.remove(id)
            if let physicallyBasedAlphaProgram {
                return .init(program: physicallyBasedAlphaProgram)
            } else {
                return .init()
            }
        } else if let physicallyBasedAdditiveProgram = self.physicallyBasedAdditiveProgram {
            return .init(program: physicallyBasedAdditiveProgram)
        } else {
            pendingPhysicallyBasedAdditiveMaterialIds.insert(id)
            return .init()
        }
    }

    func CreateOrUpdateFontMaterialAsset(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialUnlitMaterial>?) {
        CreateOrUpdateUnlitMaterialAsset(id, materialPtr)
    }

    func CreateOrUpdateUnlitMaterialAsset(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialUnlitMaterial>?) {
        let material = materialPtr!.pointee
        var unlitMaterial = getOrCreateUnlitMaterial(id, material.blendingMode)

        unlitMaterial.color = .init(tint: material.baseColorMap.color.rk(), texture: toTextureParameter(material.baseColorMap.textureId.id))
        if material.isTransparent {
            unlitMaterial.blending = createUnlitTransparentBlending(material.opacity)
        } else {
            unlitMaterial.blending = .opaque
        }
        unlitMaterial.opacityThreshold = toRealityKitOpacityThreshold(material.opacityThreshold)

        unlitMaterial.faceCulling = material.cullMode.rk()

        let textureCoordinateTransform = UnlitMaterial.TextureCoordinateTransform.init(
            offset: material.offset.rk(), scale: material.scale.rk(), rotation: 0)
        if unlitMaterial.textureCoordinateTransform.offset != textureCoordinateTransform.offset ||
                unlitMaterial.textureCoordinateTransform.scale != textureCoordinateTransform.scale {
            unlitMaterial.textureCoordinateTransform = textureCoordinateTransform
        }

        if PolySpatialRealityKit.instance.particleRenderingMode == .replicateProperties {
            vfxMaterials[id] = .init(
                texture: toTextureAsset(material.baseColorMap.textureId.id),
                blendMode: material.blendingMode,
                color: material.baseColorMap.color.rk(),
                isLit: false,
                isTransparent: material.isTransparent,
                opacity: material.opacity)
        }

        UpdateMaterialDefinition(UnlitMaterialAsset(id, unlitMaterial, colorTextureID: material.baseColorMap.textureId.id))
    }

    func createUnlitTransparentBlending(_ opacity: Float) -> UnlitMaterial.Blending {
        // Currently, RealityKit ignores texture alpha on UnlitMaterials if opacity is set to 1.0.  We've notified
        // Apple about this as FB13525148, but until they fix the issue, we need to ensure opacity is less than one.
        // TODO (LXR-3060): Remove this workaround once Apple fixes the issue.
        .transparent(opacity: .init(floatLiteral: min(opacity, 0.999)))
    }

    internal func CreateOrUpdateUnlitMaterialAssetFromParticle(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialUnlitParticleMaterial>?) {
        let material = materialPtr!.pointee
        var unlitMaterial = getOrCreateUnlitMaterial(id, material.blendingMode)

        unlitMaterial.color = .init(tint: material.baseColorMap.color.rk(), texture: toTextureParameter(material.baseColorMap.textureId.id))
        if material.isTransparent {
            unlitMaterial.blending = createUnlitTransparentBlending(material.opacity)
        } else {
            unlitMaterial.blending = .opaque
        }

        UpdateMaterialDefinition(UnlitMaterialAsset(id, unlitMaterial, colorTextureID: material.baseColorMap.textureId.id))
    }

    func CreateOrUpdateOcclusionMaterialAsset(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialOcclusionMaterial>?) {
        UpdateMaterialDefinition(OcclusionMaterialAsset(id, .init()))
    }

    func CreateOrUpdatePBRMaterialAsset(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialPBRMaterial>?) {
        let materialDef = materialPtr!.pointee
        var pbrmaterial = getOrCreatePhysicallyBasedMaterial(id, materialDef.blendingMode)

        let cullMode = materialDef.cullMode.rk()
        if pbrmaterial.faceCulling != cullMode {
            pbrmaterial.faceCulling = cullMode
        }

        let baseColor = PhysicallyBasedMaterial.BaseColor.init(tint: materialDef.baseColorMap.color.rk(), texture: toTextureParameter(materialDef.baseColorMap.textureId.id))
        if pbrmaterial.baseColor.tint != baseColor.tint || pbrmaterial.baseColor.texture != baseColor.texture {
            pbrmaterial.baseColor = baseColor
        }

        var emissiveIntensity = materialDef.emissiveIntensity
        var emissiveColor: PhysicallyBasedMaterial.EmissiveColor
        // color and texture are added rather than multiplied in RealityKit; this is a hack to work around
        if materialDef.emissiveColorMap.textureId.id.isValid {
            emissiveIntensity *= Float(materialDef.emissiveColorMap.color.rkLinear().brightnessComponent)
            emissiveColor = .init(texture: toTextureParameter(materialDef.emissiveColorMap.textureId.id))
        } else {
            // raise to an exponent derived from experimentation in an effort to match Unity rendering
            let experimentalExponent = 1.0 / 2.2
            emissiveColor = .init(color: materialDef.emissiveColorMap.color.rkPow(experimentalExponent),
                texture: toTextureParameter(materialDef.emissiveColorMap.textureId.id))
        }

        if pbrmaterial.emissiveIntensity != emissiveIntensity {
            pbrmaterial.emissiveIntensity = emissiveIntensity
        }

        if pbrmaterial.emissiveColor.color != emissiveColor.color || pbrmaterial.emissiveColor.texture != emissiveColor.texture {
            pbrmaterial.emissiveColor = emissiveColor
        }

        var metallic: PhysicallyBasedMaterial.Metallic
        var specular: PhysicallyBasedMaterial.Specular
        switch materialDef.workflow {
            case .polySpatialMetallicWorkflow:
                metallic = .init(scale: materialDef.metallicMap.scalar, texture: toTextureParameter(materialDef.metallicMap.textureId.id))
                // the specular scalar value indicates whether we want highlights or not
                specular = .init(floatLiteral: materialDef.specularMap.scalar)
            case .polySpatialSpecularWorkflow:
                metallic = .init(floatLiteral: 0)
                specular = .init(scale: materialDef.specularMap.scalar, texture: toTextureParameter(materialDef.specularMap.textureId.id))
            @unknown default:
                LogError("Unsupported workflow type \(materialDef.workflow) passed into provider.")
        }

        if pbrmaterial.metallic.scale != metallic.scale || pbrmaterial.metallic.texture != metallic.texture {
            pbrmaterial.metallic = metallic
        }

        if pbrmaterial.specular.scale != specular.scale || pbrmaterial.specular.texture != specular.texture {
            pbrmaterial.specular = specular
        }

        let roughness = PhysicallyBasedMaterial.Roughness.init(scale: materialDef.roughnessMap.scalar, texture: toTextureParameter(materialDef.roughnessMap.textureId.id))
        if pbrmaterial.roughness.scale != roughness.scale || pbrmaterial.roughness.texture != roughness.texture {
            pbrmaterial.roughness = roughness
        }

        let normal = PhysicallyBasedMaterial.Normal.init(texture: toTextureParameter(materialDef.normalMap))
        if pbrmaterial.normal.texture != normal.texture {
            pbrmaterial.normal = normal
        }

        // Unity takes the ambient occlusion term from the green channel; RealityKit from the red.  See
        // https://github.cds.internal.unity3d.com/unity/unity/blob/0c94d673a03e1c6046c5e4b07c02253068393367/Shaders/Includes/UnityStandardInput.cginc#L117
        var ambientOcclusion = PhysicallyBasedMaterial.AmbientOcclusion(texture: toTextureParameter(materialDef.ambientOcclusionMap))
        ambientOcclusion.texture?.swizzle.red = .green
        if pbrmaterial.ambientOcclusion.texture != ambientOcclusion.texture {
            pbrmaterial.ambientOcclusion = ambientOcclusion
        }

        let clearcoat = PhysicallyBasedMaterial.Clearcoat.init(
            scale: materialDef.clearcoatMap.scalar,
            texture: toTextureParameter(materialDef.clearcoatMap.textureId.id))
        if pbrmaterial.clearcoat.scale != clearcoat.scale || pbrmaterial.clearcoat.texture != clearcoat.texture {
            pbrmaterial.clearcoat = clearcoat
        }

        let clearcoatRoughness = PhysicallyBasedMaterial.ClearcoatRoughness.init(
            scale: materialDef.clearcoatRoughnessMap.scalar,
            texture: toTextureParameter(materialDef.clearcoatRoughnessMap.textureId.id))
        if pbrmaterial.clearcoatRoughness.scale != clearcoatRoughness.scale || pbrmaterial.clearcoatRoughness.texture != clearcoatRoughness.texture {
            pbrmaterial.clearcoatRoughness = clearcoatRoughness
        }

        if materialDef.isTransparent {
            // Unity doesn't have a concept of a separate transparency map.  Given the code in ConvertCommonURPMaterialProperties,
            // we're always going to get materialDef.opacity == transparencyMap.scale.  We're going to assert that and compare.
            // TODO -- need to see what RealityKit does with base color maps with an alpha channel
            PolySpatialAssert(materialDef.opacity == materialDef.transparencyMap.scalar && !materialDef.transparencyMap.textureId.id.isValid)
            pbrmaterial.blending = .transparent(opacity: .init(floatLiteral: materialDef.opacity))
        } else {
            pbrmaterial.blending = PhysicallyBasedMaterial.Blending.opaque
        }
        setOpacityThreshold(&pbrmaterial, materialDef)

        let textureCoordinateTransform = PhysicallyBasedMaterial.TextureCoordinateTransform.init(
            offset: materialDef.offset.rk(), scale: materialDef.scale.rk(), rotation: 0)
        if pbrmaterial.textureCoordinateTransform.offset != textureCoordinateTransform.offset || pbrmaterial.textureCoordinateTransform.scale != textureCoordinateTransform.scale {
            pbrmaterial.textureCoordinateTransform = textureCoordinateTransform
        }

        if particleRenderingMode == .replicateProperties {
            vfxMaterials[id] = .init(
                texture: toTextureAsset(materialDef.baseColorMap.textureId.id),
                blendMode: materialDef.blendingMode,
                color: materialDef.baseColorMap.color.rk(),
                isLit: true,
                isTransparent: materialDef.isTransparent,
                opacity: materialDef.opacity)
        }

        UpdateMaterialDefinition(PhysicallyBasedMaterialAsset(
            id, pbrmaterial,
            baseColorTextureID: materialDef.baseColorMap.textureId.id,
            emissiveColorTextureID: materialDef.emissiveColorMap.textureId.id,
            metallicTextureID: materialDef.metallicMap.textureId.id,
            specularTextureID: materialDef.specularMap.textureId.id,
            roughnessTextureID: materialDef.roughnessMap.textureId.id,
            normalTextureID: materialDef.normalMap.textureId.id,
            ambientOcclusionTextureID: materialDef.ambientOcclusionMap.textureId.id,
            clearcoatTextureID: materialDef.clearcoatMap.textureId.id,
            clearcoatRoughnessTextureID: materialDef.clearcoatRoughnessMap.textureId.id))
    }

    func setOpacityThreshold(_ material: inout PhysicallyBasedMaterial, _ materialData: PolySpatialPBRMaterial) {
        let opacityThreshold = toRealityKitOpacityThreshold(materialData.opacityThreshold)
        if material.opacityThreshold != opacityThreshold {
            material.opacityThreshold = opacityThreshold
        }
    }

    internal func CreateOrUpdateUnlitParticleMaterialAsset(_ id: PolySpatialAssetID, _materialPtr: UnsafePointer<PolySpatialUnlitParticleMaterial>?) {
        if (PolySpatialRealityKit.instance.particleRenderingMode == .replicateProperties) {
            let material = _materialPtr!.pointee
            let vfxMaterial = VfXMaterial(
                texture: toTextureAsset(material.baseColorMap.textureId.id),
                blendMode: material.blendingMode,
                color: material.baseColorMap.color.rk(),
                isLit: false,
                isTransparent: material.isTransparent,
                opacity: material.opacity)

            vfxMaterials[id] = vfxMaterial
            assetDeleters[id] = { id in self.vfxMaterials.removeValue(forKey: id) }

        } else {
            assetDeleters[id] = { _ in }
        }
    }

    internal func CreateOrUpdateLitParticleMaterialAsset(_ id: PolySpatialAssetID, _materialPtr: UnsafePointer<PolySpatialLitParticleMaterial>?) {
        if (PolySpatialRealityKit.instance.particleRenderingMode == .replicateProperties) {
            let material = _materialPtr!.pointee
            let vfxMaterial = VfXMaterial(
                texture: toTextureAsset(material.baseColorMap.textureId.id),
                blendMode: material.blendingMode,
                color: material.baseColorMap.color.rk(),
                isLit: true,
                isTransparent: material.isTransparent,
                opacity: material.opacity)

            vfxMaterials[id] = vfxMaterial
            assetDeleters[id] = { id in self.vfxMaterials.removeValue(forKey: id) }

        } else {
            assetDeleters[id] = { _ in }
        }
    }

    internal func CreateOrUpdateShaderGraphMaterialAsset(_ id: PolySpatialAssetID, _ data: inout ByteBuffer) {
        let materialDef: PolySpatialShaderMaterial = getRoot(byteBuffer: &data)
        let shaderId = materialDef.shaderId!

        // Delegate to the CachedShaderGraph subclass.
        let shaderGraph = ShaderManager.instance.getCachedShaderGraph(shaderId)
        shaderGraph.updateMaterialDefinition(id, materialDef, data)
    }

    internal func CreateShaderGraphAsset(_ id: PolySpatialAssetID, _ data: UnsafePointer<PolySpatialShaderData>?, _ asyncId: PolySpatialAssetID?) {
        CreateShaderGraphAssetAndDeleter(id, data) { id in
            self.DeleteShaderGraphAsset(id)
            ShaderManager.instance.getCachedShaderGraph(id).removeSelf()
        }
        ShaderManager.instance.getCachedShaderGraph(id, asyncId).tryStartLoading()
    }

    func CreateShaderGraphAssetAndDeleter(
        _ id: PolySpatialAssetID, _ data: UnsafePointer<PolySpatialShaderData>?,
        _ deleter: ((PolySpatialAssetID) -> Void)? = nil) {

        let polyspatialShaderGraphData = data!.pointee
        let shaderData = ShaderGraphData(polyspatialShaderGraphData.name!, polyspatialShaderGraphData.materialXencoding!, polyspatialShaderGraphData.materialXprimPath!)
        shaderGraphAssets[id] = shaderData
        assetDeleters[id] = deleter ?? DeleteShaderGraphAsset
    }

    // We don't really delete the asset, we just remove it from the
    // cache. Any entity still using the asset will keep it around
    // until that entity is either destroyed or someone changes the
    // assigned asset for it.
    //
    func DeleteShaderGraphAsset(_ id: PolySpatialAssetID) {
        shaderGraphAssets.removeValue(forKey: id)
        // If we get here, this asset should no longer be referenced by anything,
        // because it's gone on the Unity side.
        PolySpatialAssert(shaderGraphAssets[id] == nil)
    }

    func CreateShaderPropertyMapAsset(_ id: PolySpatialAssetID, _ data: UnsafePointer<PolySpatialShaderPropertyMapData>?) {
        let polyspatialPropertyMap = data!.pointee

        var floatProperties = [String](repeating: "", count: Int(polyspatialPropertyMap.floatPropertiesCount))
        for i in 0..<polyspatialPropertyMap.floatPropertiesCount {
            floatProperties[Int(i)] = polyspatialPropertyMap.floatProperties(at: i)!
        }

        var intProperties = [String](repeating: "", count: Int(polyspatialPropertyMap.intPropertiesCount))
        for i in 0..<polyspatialPropertyMap.intPropertiesCount {
            intProperties[Int(i)] = polyspatialPropertyMap.intProperties(at: i)!
        }

        var vector4Properties = [String](repeating: "", count: Int(polyspatialPropertyMap.vector4PropertiesCount))
        for i in 0..<polyspatialPropertyMap.vector4PropertiesCount {
            vector4Properties[Int(i)] = polyspatialPropertyMap.vector4Properties(at: i)!
        }

        var colorProperties = [String](repeating: "", count: Int(polyspatialPropertyMap.colorPropertiesCount))
        for i in 0..<polyspatialPropertyMap.colorPropertiesCount {
            colorProperties[Int(i)] = polyspatialPropertyMap.colorProperties(at: i)!
        }

        var matrix4x4Properties = [String](repeating: "", count: Int(polyspatialPropertyMap.matrix4x4PropertiesCount))
        for i in 0..<polyspatialPropertyMap.matrix4x4PropertiesCount {
            matrix4x4Properties[Int(i)] = polyspatialPropertyMap.matrix4x4Properties(at: i)!
        }

        var textureProperties = [String](repeating: "", count: Int(polyspatialPropertyMap.texturePropertiesCount))
        for i in 0..<polyspatialPropertyMap.texturePropertiesCount {
            textureProperties[Int(i)] = polyspatialPropertyMap.textureProperties(at: i)!
        }

        var texturePropertyTransformsEnabled = [Bool](repeating: false, count: Int(polyspatialPropertyMap.texturePropertyTransformsEnabledCount))
        for i in 0..<polyspatialPropertyMap.texturePropertyTransformsEnabledCount {
            texturePropertyTransformsEnabled[Int(i)] = polyspatialPropertyMap.texturePropertyTransformsEnabled(at: i)
        }

        var keywords = [String](repeating: "", count: Int(polyspatialPropertyMap.keywordsCount))
        for i in 0..<polyspatialPropertyMap.keywordsCount {
            keywords[Int(i)] = polyspatialPropertyMap.keywords(at: i)!
        }

        var readsDepth = true
        if polyspatialPropertyMap.zTestMode == .always {
            readsDepth = false
        } else if polyspatialPropertyMap.zTestMode != .lessEqual {
            LogWarning("Unsupported depth test mode: \(polyspatialPropertyMap.zTestMode)")
        }

        let propertyMap = ShaderPropertyMapData(
            polyspatialPropertyMap.name!,
            floatProperties,
            intProperties,
            vector4Properties,
            colorProperties,
            matrix4x4Properties,
            textureProperties,
            texturePropertyTransformsEnabled,
            keywords,
            polyspatialPropertyMap.cullMode.rk(),
            readsDepth,
            polyspatialPropertyMap.zWriteControl != .forceDisabled,
            polyspatialPropertyMap.castShadows,
            polyspatialPropertyMap.allowMaterialOverride)
        shaderPropertyMaps[id] = propertyMap
        assetDeleters[id] = DeleteShaderPropertyMapAsset
    }

    // We don't really delete the asset, we just remove it from the
    // cache. Any entity still using the asset will keep it around
    // until that entity is either destroyed or someone changes the
    // assigned asset for it.
    //
    func DeleteShaderPropertyMapAsset(_ id: PolySpatialAssetID) {
        shaderPropertyMaps.removeValue(forKey: id)
        // If we get here, this asset should no longer be referenced by anything,
        // because it's gone on the Unity side.
        PolySpatialAssert(shaderPropertyMaps[id] == nil)
    }
}
