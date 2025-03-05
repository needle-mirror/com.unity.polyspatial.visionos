import CoreGraphics
import Foundation
import RealityKit

@_implementationOnly import FlatBuffers

@MainActor
class ShaderGlobalProperty {
    let name: String
    let handle: MaterialParameters.Handle
    var value: MaterialParameters.Value
    var textureParam: PolySpatialRealityKit.TextureParam?
    var shaderGraphInstances: Set<ValidShaderGraphInstance> = []

    // The value of shaderGlobalCurrentUpdate (the global update counter) stored when the property last changed.
    // This is used to determine whether the property needs to be applied to a given material instance (that is,
    // whether the instance's lastGlobalUpdate is less than this value).
    var lastUpdate: Int

    init(_ name: String, _ value: MaterialParameters.Value, _ lastUpdate: Int? = nil) {
        self.name = name
        self.handle = ShaderGraphMaterial.parameterHandle(name: name)
        self.value = value
        self.lastUpdate = lastUpdate ?? ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setFloat(_ newValue: Float) {
        if case let .float(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .float(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setInteger(_ newValue: Int32) {
        if case let .int(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .int(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setVector2(_ newValue: SIMD2<Float>) {
        if case let .simd2Float(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .simd2Float(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setVector3(_ newValue: SIMD3<Float>) {
        if case let .simd3Float(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .simd3Float(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setVector4(_ newValue: SIMD4<Float>) {
        if case let .simd4Float(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .simd4Float(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setColor(_ newValue: CGColor) {
        if case let .color(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .color(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setMatrix(_ newValue: float4x4) {
        if case let .float4x4(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .float4x4(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setTexture(_ newTextureID: PolySpatialAssetID, _ sizeProperty: ShaderGlobalProperty) {
        let newParam = PolySpatialRealityKit.TextureParam(newTextureID, sizeProperty.handle)
        if textureParam == newParam {
            return
        }
        let newAsset = PolySpatialRealityKit.instance.GetTextureAssetForId(newTextureID)
        sizeProperty.setVector3(newAsset.size)
        
        self.value = .textureResource(newAsset.texture.resource)
        self.textureParam = newParam
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }

    func setBool(_ newValue: Bool) {
        if case let .bool(currentValue) = self.value, currentValue == newValue {
            return
        }
        self.value = .bool(newValue)
        self.textureParam = nil
        self.lastUpdate = ShaderManager.instance.shaderGlobalCurrentUpdate
    }
}
