import Foundation
import RealityKit
import UIKit

@_implementationOnly
import FlatBuffers
@_implementationOnly
import PolySpatialRealityKitC

@MainActor
extension PolySpatialRealityKit {
    public static func overrideApi(_: Int, _ api: inout PolySpatialNativeAPI) {
        // convenient place to init
        api.SendClientCommand = {(a, b, c, d) in PolySpatialRealityKit.instance.OnSendClientCommandOverrides(PolySpatialCommand.init(rawValue: a)!, b, c, d) }
    }

    internal func OnSendClientCommandOverrides(
        _ cmd: PolySpatialCommand,
        _ argCount: Int32,
        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
        _ argSizes: UnsafeMutablePointer<UInt32>?) {

        switch cmd {
            
            case .createOrUpdatePbrmaterialAsset:
                var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
                var materialPtr: UnsafeMutablePointer<PolySpatialPBRMaterial>?
                ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
                CreateOrUpdatePBRMaterialAsset2(assetIdPtr!.pointee, materialPtr)
                break

            // entity APIs


            case .endAppFrame:
                var instanceIdPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
                var frameDataPtr: UnsafeMutablePointer<PolySpatialFrameData>?
                ExtractArgs(argCount, args, argSizes, &instanceIdPtr, &frameDataPtr)

                PolySpatialWindowManager.shared.matchVolumesAndWindows()
                StaticBatchManager.instance.updateStaticBatches()
                particleManager.updateSubEmitters()
                NotifyTextureObservers()
                NotifyCollisionObservers()
                ShaderManager.instance.ApplyRemainingShaderGlobalPropertyValues()

                // Delay expensive mesh blending until all batched frames have been received.
                if !frameDataPtr!.pointee.morePendingFramesBatched {
                    skinnedMeshManager.updateBlendedMeshInstances()
                }
                break

            case .setShaderGlobalPropertyMap:
                var data: ByteBuffer?
                ExtractArgs(argCount, args, argSizes, &data)
                let shaderGlobalPropertyMap: PolySpatialShaderGlobalPropertyMap = getRoot(byteBuffer: &data!)
                ShaderManager.instance.SetShaderGlobalPropertyMap(shaderGlobalPropertyMap)
                break
            case .setShaderGlobalPropertyValues:
                var data: ByteBuffer?
                ExtractArgs(argCount, args, argSizes, &data)
                let shaderGlobalPropertyValues: PolySpatialShaderGlobalPropertyValues = getRoot(byteBuffer: &data!)
                ShaderManager.instance.SetShaderGlobalPropertyValues(shaderGlobalPropertyValues)
                break
            default:
                PolySpatialRealityKit.instance.OnSendClientCommand(cmd, argCount, args, argSizes)
                break
        }
    }

    // This is identical to the non-NDA version with the sole exception of comparing all properties before assigning them.
    // RealityKit is rather slow in assigning properties - even if the values are the same. By checking all the properties before
    // assigning, we can double the performance of this function. But unfortunately, textures are not equatable in the non-NDA RK SDK
    internal func CreateOrUpdatePBRMaterialAsset2(_ id: PolySpatialAssetID, _ materialPtr: UnsafePointer<PolySpatialPBRMaterial>?) {
        let materialDef = materialPtr!.pointee
        var pbrmaterial = getOrCreatePhysicallyBasedMaterial(id, materialDef.blendingMode)
        
        let cullMode = materialDef.cullMode.rk()
        if pbrmaterial.faceCulling != cullMode {
            pbrmaterial.faceCulling = cullMode
        }

        let baseColor = PhysicallyBasedMaterial.BaseColor.init(tint: materialDef.baseColorMap.color.rk(), texture: toTextureParameter(materialDef.baseColorMap.texture))
        if pbrmaterial.baseColor.tint != baseColor.tint || pbrmaterial.baseColor.texture != baseColor.texture {
            pbrmaterial.baseColor = baseColor
        }

        var emissiveIntensity = materialDef.emissiveIntensity
        var emissiveColor: PhysicallyBasedMaterial.EmissiveColor
        // color and texture are added rather than multiplied in RealityKit; this is a hack to work around
        if materialDef.emissiveColorMap.texture.isValid {
            emissiveIntensity *= Float(materialDef.emissiveColorMap.color.rkLinear().brightnessComponent)
            emissiveColor = .init(texture: toTextureParameter(materialDef.emissiveColorMap.texture))
        } else {
            // raise to an exponent derived from experimentation in an effort to match Unity rendering
            let experimentalExponent = 1.0 / 2.2
            emissiveColor = .init(color: materialDef.emissiveColorMap.color.rkPow(experimentalExponent),
                texture: toTextureParameter(materialDef.emissiveColorMap.texture))
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
                metallic = .init(scale: materialDef.metallicMap.scalar, texture: toTextureParameter(materialDef.metallicMap.texture))
                // the specular scalar value indicates whether we want highlights or not
                specular = .init(floatLiteral: materialDef.specularMap.scalar)
            case .polySpatialSpecularWorkflow:
                metallic = .init(floatLiteral: 0)
                specular = .init(scale: materialDef.specularMap.scalar, texture: toTextureParameter(materialDef.specularMap.texture))
            @unknown default:
                LogError("Unsupported workflow type \(materialDef.workflow) passed into provider.")
        }

        if pbrmaterial.metallic.scale != metallic.scale || pbrmaterial.metallic.texture != metallic.texture {
            pbrmaterial.metallic = metallic
        }

        if pbrmaterial.specular.scale != specular.scale || pbrmaterial.specular.texture != specular.texture {
            pbrmaterial.specular = specular
        }

        let roughness = PhysicallyBasedMaterial.Roughness.init(scale: materialDef.roughnessMap.scalar, texture: toTextureParameter(materialDef.roughnessMap.texture))
        if pbrmaterial.roughness.scale != roughness.scale || pbrmaterial.roughness.texture != roughness.texture {
            pbrmaterial.roughness = roughness
        }

        let normal = PhysicallyBasedMaterial.Normal.init(texture: toTextureParameter(materialDef.normalMap))
        if pbrmaterial.normal.texture != normal.texture {
            pbrmaterial.normal = normal
        }

        let ambientOcclusion = PhysicallyBasedMaterial.AmbientOcclusion.init(texture: toTextureParameter(materialDef.ambientOcclusionMap))
        if pbrmaterial.ambientOcclusion.texture != ambientOcclusion.texture {
            pbrmaterial.ambientOcclusion = ambientOcclusion
        }

        let clearcoat = PhysicallyBasedMaterial.Clearcoat.init(
            scale: materialDef.clearcoatMap.scalar,
            texture: toTextureParameter(materialDef.clearcoatMap.texture))
        if pbrmaterial.clearcoat.scale != clearcoat.scale || pbrmaterial.clearcoat.texture != clearcoat.texture {
            pbrmaterial.clearcoat = clearcoat
        }

        let clearcoatRoughness = PhysicallyBasedMaterial.ClearcoatRoughness.init(
            scale: materialDef.clearcoatRoughnessMap.scalar,
            texture: toTextureParameter(materialDef.clearcoatRoughnessMap.texture))
        if pbrmaterial.clearcoatRoughness.scale != clearcoatRoughness.scale || pbrmaterial.clearcoatRoughness.texture != clearcoatRoughness.texture {
            pbrmaterial.clearcoatRoughness = clearcoatRoughness
        }

        if materialDef.isTransparent {
            // Unity doesn't have a concept of a separate transparency map.  Given the code in ConvertCommonURPMaterialProperties,
            // we're always going to get materialDef.opacity == transparencyMap.scale.  We're going to assert that and compare.
            // TODO -- need to see what RealityKit does with base color maps with an alpha channel
            PolySpatialAssert(materialDef.opacity == materialDef.transparencyMap.scalar && !materialDef.transparencyMap.texture.isValid)
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

        UpdateMaterialDefinition(PhysicallyBasedMaterialAsset(
            id, pbrmaterial,
            baseColorTextureID: materialDef.baseColorMap.texture,
            emissiveColorTextureID: materialDef.emissiveColorMap.texture,
            metallicTextureID: materialDef.metallicMap.texture,
            specularTextureID: materialDef.specularMap.texture,
            roughnessTextureID: materialDef.roughnessMap.texture,
            normalTextureID: materialDef.normalMap.texture,
            ambientOcclusionTextureID: materialDef.ambientOcclusionMap.texture,
            clearcoatTextureID: materialDef.clearcoatMap.texture,
            clearcoatRoughnessTextureID: materialDef.clearcoatRoughnessMap.texture))
    }
}
