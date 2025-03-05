import Foundation
import RealityKit
import UIKit


// Wraps an Any.Type value so that it can be used as a Dictionary key.  Any.Type is not itself
// Hashable and can't be extended to be so.
struct TypeKey : Hashable, Equatable {
    let type: Any.Type

    init(_ type: Any.Type) {
        self.type = type
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }
}

// Contains the static state verification functions.  State verification checks arbitrary values (type "Any") against
// a parsed JSON representation of the scene graph state, returning results that identify differences by their
// actual values and JSON paths.
@MainActor
class RealityKitStateVerifier {

    static let typeVerifiers: [TypeKey: (Any, Any, String) -> String] = [
        .init(Bool.self): verifyBoolState,
        .init(Int.self): createIntegerStateVerifier({ $0.intValue }),
        .init(UInt.self): createIntegerStateVerifier({ $0.uintValue }),
        .init(Int32.self): createIntegerStateVerifier({ $0.int32Value }),
        .init(UInt32.self): createIntegerStateVerifier({ $0.uint32Value }),
        .init(Int64.self): createIntegerStateVerifier({ $0.int64Value }),
        .init(UInt64.self): createIntegerStateVerifier({ $0.uint64Value }),
        .init(MTLVertexFormat.self): createIntegerStateVerifier({ MTLVertexFormat(rawValue: $0.uintValue) }),
        .init(MTLIndexType.self): createIntegerStateVerifier({ MTLIndexType(rawValue: $0.uintValue) }),
        .init(MTLPrimitiveType.self): createIntegerStateVerifier({ MTLPrimitiveType(rawValue: $0.uintValue) }),
        .init(Double.self): createFloatStateVerifier(Double.self),
        .init(Float.self): createFloatStateVerifier(Float.self),
        .init(CGFloat.self): createFloatStateVerifier(CGFloat.self),
        .init(simd_float2.self): verifySimdFloat2State,
        .init(simd_float3.self): verifySimdFloat3State,
        .init(simd_float4.self): verifySimdFloat4State,
        .init(Data.self): verifyDataState,
        .init(String.self): verifyStateAsString,
        .init(URL.self): verifyStateAsString,
        .init(EnvironmentResource.self): verifyEnvironmentResourceState,
        .init(TextureResource.self): verifyTextureResourceState,
        .init(MeshResource.self): verifyMeshResourceState,
        .init(MeshResource.Part.self): verifyMeshResourcePartState,
        .init(LowLevelMesh.self): verifyLowLevelMeshState,
        .init(VideoMaterial.self): verifyVideoMaterialState,
        .init(AttributedString.self): verifyAttributedStringState,
        .init(MeshJointInfluence.self): verifyMeshJointInfluenceState,
        .init(ShaderGraphMaterial.self): verifyShaderGraphMaterialState,
        .init(ShapeResource.self): verifyShapeResourceState,
        .init(ParticleEmitterComponent.self): verifyParticleEmitterComponentState,
        .init(ParticleEmitterComponent.ParticleEmitter.self): verifyParticleEmitterState,
    ]

    // Verifies the state of an arbitrary value (obj).  The expectedState is the parsed JSON result (e.g., an
    // NSDictionary for a JSON object).  The path is the constructed path to the JSON value (e.g., "foo.bar[0].baz").
    static func verifyState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let mirror = Mirror(reflecting: obj)

        // First check for null values, in case the value is an Optional.
        if mirror.displayStyle == .optional {
            if mirror.children.isEmpty {
                return expectedState is NSNull ? "" : "\(path) is null"
            }
            return verifyState(mirror.children.first!.value, expectedState, path)
        }

        // Then look for an exact type mapping.
        if let verifier = typeVerifiers[TypeKey(type(of: obj))] {
            return verifier(obj, expectedState, path)
        }

        // Some specific superclasses.
        if let paragraphStyle = obj as? NSParagraphStyle {
            return verifyNSParagraphStyleState(paragraphStyle, expectedState, path)
        } else if let font = obj as? UIFont {
            return verifyPlatformFontState(font, expectedState, path)
        } else if let color = obj as? UIColor {
            return verifyPlatformColorState(color, expectedState, path)
        } else if let entity = obj as? Entity {
            return verifyEntityState(entity, expectedState, path)
        }

        // CGColor's type needs to be checked via the CoreFoundation system.
        if CFGetTypeID(obj as AnyObject) == CGColor.typeID {
            return verifyCGColorState(obj as! CGColor, expectedState, path)
        }

        // Special handling for collections, tuples, and enum types.
        if mirror.displayStyle == .collection || mirror.displayStyle == .set {
            return verifyCollectionState(mirror, expectedState, path)
        } else if mirror.displayStyle == .tuple {
            return verifyTupleState(mirror, expectedState, path)
        } else if mirror.displayStyle == .enum {
            return verifyEnumState(obj, mirror, expectedState, path)
        }

        // Everything else is verified as a simple object according to its mirrored properties.
        return verifyObjectState(mirror, expectedState, path)
    }

    static func verifyBoolState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let actualValue = obj as! Bool
        if let expectedValue = expectedState as? NSNumber {
            return actualValue == expectedValue.boolValue ? "" : "\(path) is \(actualValue)"
        } else {
            return "\(path) is Bool"
        }
    }

    static func createIntegerStateVerifier<T: Equatable>(
        _ numberToValue: @escaping (NSNumber) -> T) -> (Any, Any, String) -> String {

        return { obj, expectedState, path in
            let actualValue = obj as! T
            if let expectedNumber = expectedState as? NSNumber {
                return actualValue == numberToValue(expectedNumber) ? "" : "\(path) is \(actualValue)"
            } else {
                return "\(path) is Integer"
            }
        }
    }

    static func createFloatStateVerifier<T: BinaryFloatingPoint>(_ type: T.Type) -> (Any, Any, String) -> String {
        return { obj, expectedState, path in
            let actualValue = Float(obj as! T)
            if let expectedNumber = expectedState as? NSNumber {
                let epsilon: Float = 0.000001
                return (abs(actualValue - expectedNumber.floatValue) < epsilon) ? "" : "\(path) is \(actualValue)"
            } else {
                return "\(path) is Float"
            }
        }
    }

    static func verifySimdFloat2State(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let value = obj as! simd_float2
        return verifyDictionaryState(["x": value.x, "y": value.y], expectedState, path)
    }

    static func verifySimdFloat3State(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let value = obj as! simd_float3
        return verifyDictionaryState(["x": value.x, "y": value.y, "z": value.z], expectedState, path)
    }

    static func verifySimdFloat4State(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let value = obj as! simd_float4
        return verifyDictionaryState(["x": value.x, "y": value.y, "z": value.z, "w": value.w], expectedState, path)
    }

    static func verifyMeshJointInfluenceState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let value = obj as! MeshJointInfluence
        return verifyDictionaryState(["jointIndex": value.jointIndex, "weight": value.weight], expectedState, path)
    }

    static func verifyDataState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        // Compare as hex string.
        // https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
        let string = (obj as! Data).map { String(format: "%02hhX", $0) }.joined()
        return verifyStateAsString(string, expectedState, path)
    }

    static func verifyStateAsString(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let actualValue = String(describing: obj)
        if let expectedValue = expectedState as? NSString {
            return actualValue == String(expectedValue) ? "" : "\(path) is '\(actualValue)'"
        } else {
            return "\(path) is String"
        }
    }

    static func verifyNSParagraphStyleState(
            _ paragraphStyle: NSParagraphStyle, _ expectedState: Any, _ path: String) -> String {
        let dictionary: [String: Any] = ["alignment": paragraphStyle.alignment.rawValue]
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyPlatformFontState(_ font: UIFont, _ expectedState: Any, _ path: String) -> String {
        let dictionary: [String: Any] = ["fontName": font.fontName, "pointSize": font.pointSize]
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyPlatformColorState(_ color: UIColor, _ expectedState: Any, _ path: String) -> String {
        // We verify UIColor/NSColor as objects (rather than, say, arrays) just to match Unity, where we
        // can match Colors as objects without a special case.
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let dictionary: [String: Any] = ["r": r, "g": g, "b": b, "a": a]
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyCGColorState(_ color: CGColor, _ expectedState: Any, _ path: String) -> String {
        let color = color.converted(to: .init(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let components = color.components!
        let dictionary: [String: Any] = ["r": components[0], "g": components[1], "b": components[2], "a": color.alpha]
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyEntityState(_ entity: Entity, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is Entity"
        }
        let mirror = Mirror(reflecting: entity)
        var results = ""
        for (key, expectedValue) in expectedObject {
            // Entities need special handling for their components (which we verify as an object with keys matching the
            // component type names) and children (which we verify as an object with name prefix keys).
            if let name = key as? String {
                if name == "components" {
                    appendResult(verifyComponentsState(entity, expectedValue, "\(path).components"), &results)
                } else if name == "children" {
                    appendResult(verifyChildrenState(entity, expectedValue, "\(path).children"), &results)
                }
            } else {
                appendResult(verifyProperty(mirror, path, key, expectedValue), &results)
            }
        }
        return results
    }

    static func verifyComponentsState(_ entity: Entity, _ expectedValue: Any, _ path: String) -> String {
        var dictionary: [String: Any] = [:]
        for component in entity.components {
            dictionary[.init(describing: type(of: component))] = component
        }
        return verifyDictionaryState(dictionary, expectedValue, path)
    }

    static func verifyChildrenState(_ entity: Entity, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is Object"
        }
        var results = ""
        for (key, expectedValue) in expectedObject {
            // If there's no child by that name, we expect to match "null".
            appendResult(
                verifyState(getChildByNamePrefix(entity, key as! String) as Any, expectedValue, "\(path)['\(key)']"),
                &results)
        }
        return results
    }

    static func getChildByNamePrefix(_ entity: Entity, _ namePrefix: String) -> Entity? {
        for child in entity.children {
            if child.name.hasPrefix(namePrefix) {
                return child
            }
        }
        return nil
    }

    static func verifyEnvironmentResourceState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let environment = obj as! EnvironmentResource
        var extraChildren: [String: Any] = [:]
        extraChildren["skybox"] = environment.skybox
        return verifyObjectState(.init(reflecting: obj), expectedState, path, extraChildren)
    }

    static func verifyTextureResourceState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is TextureResource"
        }
        let texture = obj as! TextureResource
        let mirror = Mirror(reflecting: obj)
        var extraChildren: [String: Any] = [:]
        extraChildren["textureType"] = texture.textureType.rawValue
        extraChildren["pixelFormat"] = texture.pixelFormat.rawValue
        var results = ""
        for (key, expectedValue) in expectedObject {
            // Special handling for texture contents.
            if let name = key as? String, name == "mipmapLevels" {
                appendResult(verifyMipmapLevelsState(texture, expectedValue, "\(path).mipmapLevels"), &results)
            } else {
                appendResult(verifyProperty(mirror, path, key, expectedValue, extraChildren), &results)
            }
        }
        return results
    }

    static func verifyMeshResourceState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let mesh = obj as! MeshResource
        return verifyObjectState(.init(reflecting: obj), expectedState, path, ["lowLevelMesh": mesh.lowLevelMesh as Any])
    }

    static func verifyMeshResourcePartState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let part = obj as! MeshResource.Part
        var extraChildren: [String: Any] = [:]
        for (identifier, buffer) in part.buffers {
            if buffer.elementType == .jointInfluence {
                extraChildren[identifier.name] = buffer.get(MeshJointInfluence.self)!.elements
                continue
            }
            extraChildren[identifier.name] = switch buffer.elementType {
                case .double: buffer.get(Double.self)!.elements
                case .float: buffer.get(Float.self)!.elements
                case .int8: buffer.get(Int8.self)!.elements
                case .int16: buffer.get(Int16.self)!.elements
                case .int32: buffer.get(Int32.self)!.elements
                case .simd2Float: buffer.get(simd_float2.self)!.elements
                case .simd3Float: buffer.get(simd_float3.self)!.elements
                case .simd4Float: buffer.get(simd_float4.self)!.elements
                case .uInt8: buffer.get(UInt8.self)!.elements
                case .uInt16: buffer.get(UInt16.self)!.elements
                case .uInt32: buffer.get(UInt32.self)!.elements
                default: fatalError("Unknown buffer type: \(buffer.elementType)")
            }
        }
        return verifyObjectState(.init(reflecting: obj), expectedState, path, extraChildren)
    }

    static func verifyLowLevelMeshState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let lowLevelMesh = obj as! LowLevelMesh
        var indices: [UInt32] = []
        lowLevelMesh.withUnsafeIndices {
            // For simplicity, we only support UInt32 indices.
            indices += $0.bindMemory(to: UInt32.self)[0..<lowLevelMesh.indexCapacity]
        }
        var buffers: [[Float]] = []
        for i in 0..<lowLevelMesh.descriptor.vertexBufferCount {
            // We always have one layout per buffer, and (for tests) we only support floats.
            let floatCapacity = lowLevelMesh.vertexCapacity *
                lowLevelMesh.descriptor.vertexLayouts[i].bufferStride / MemoryLayout<Float>.size
            lowLevelMesh.withUnsafeBytes(bufferIndex: i) {
                buffers.append(.init($0.bindMemory(to: Float.self)[0..<floatCapacity]))
            }
        }
        return verifyObjectState(
            .init(reflecting: obj), expectedState, path,
            ["parts": Array(lowLevelMesh.parts), "indices": indices, "buffers": buffers])
    }

    static func verifyShapeResourceState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is ShapeResource"
        }
        // We expect one key: the shape type.
        guard let shapeType = expectedObject.allKeys.first as? String else {
            return "\(path) requires type key"
        }
        let shapePath = "\(path).\(shapeType)"
        guard let shapeObject = expectedObject[shapeType] as? NSDictionary else {
            return "\(shapePath) is Object"
        }
        func toFloat(_ value: Any?, _ path: String) throws -> Float {
            guard let number = value as? NSNumber else {
                throw "\(path) is Number"
            }
            return number.floatValue
        }
        func toSimdFloat3(_ value: Any?, _ path: String) throws -> simd_float3 {
            guard let dictionary = value as? NSDictionary else {
                throw "\(path) is Object"
            }
            return try .init(
                toFloat(dictionary["x"], "\(path).x"),
                toFloat(dictionary["y"], "\(path).y"),
                toFloat(dictionary["z"], "\(path).z"))
        }
        do {
            var expectedShape: ShapeResource
            switch shapeType {
                case "box":
                    try expectedShape = .generateBox(size: toSimdFloat3(shapeObject["size"], "\(shapePath).size"))
                case "sphere":
                    try expectedShape = .generateSphere(radius: toFloat(shapeObject["radius"], "\(shapePath).radius"))
                case "capsule":
                    try expectedShape = .generateCapsule(
                        height: toFloat(shapeObject["height"], "\(shapePath).height"),
                        radius: toFloat(shapeObject["radius"], "\(shapePath).radius"))
                case "convex":
                    guard let points = shapeObject["points"] as? NSArray else {
                        return "\(shapePath).points is Array"
                    }
                    expectedShape = try .generateConvex(from: points.enumerated().map { (index, value) in
                        try toSimdFloat3(value, "\(shapePath).points[\(index)]")
                    })
                default:
                    return "\(shapePath) is invalid ShapeResource type"
            }
            if let translation = shapeObject["translation"] as? NSDictionary {
                try expectedShape = expectedShape.offsetBy(
                    translation: toSimdFloat3(translation, "\(shapePath).translation"))
            }
            return compareMeshResourceShapes(
                MeshResource(shape: obj as! ShapeResource), MeshResource(shape: expectedShape), path)
        } catch {
            return "\(error)"
        }
    }

    static func compareMeshResourceShapes(
        _ mesh: MeshResource, _ expectedMesh: MeshResource, _ path: String) -> String {

        // All we care about for ShapeResource purposes are the vertices and triangles.
        if mesh.contents.models.count != expectedMesh.contents.models.count {
            return "\(path) has \(mesh.contents.models.count) models"
        }
        for (i, (model, expectedModel)) in zip(mesh.contents.models, expectedMesh.contents.models).enumerated()  {
            if model.parts.count != expectedModel.parts.count {
                return "\(path).models[\(i)] has \(model.parts.count) parts"
            }
            for (j, (part, expectedPart)) in zip(model.parts, expectedModel.parts).enumerated() {
                if part.positions.count != expectedPart.positions.count {
                    return "\(path).models[\(i)].parts[\(j)] has \(part.positions.count) positions"
                }
                for (k, (position, expectedPosition)) in zip(part.positions, expectedPart.positions).enumerated() {
                    if position != expectedPosition {
                        return "\(path).models[\(i)].parts[\(j)].positions[\(k)] is \(position)"
                    }
                }
                let triangleIndices = part.triangleIndices!
                let expectedIndices = expectedPart.triangleIndices!
                if triangleIndices.count != expectedIndices.count {
                    return "\(path).models[\(i)].parts[\(j)] has \(part.triangleIndices!.count) indices"
                }
                for (k, (index, expectedIndex)) in zip(triangleIndices, expectedIndices).enumerated() {
                    if index != expectedIndex {
                        return "\(path).models[\(i)].parts[\(j)].triangleIndices[\(k)] is \(index)"
                    }
                }
            }
        }
        return ""
    }

    static func verifyParticleEmitterComponentState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let component = obj as! ParticleEmitterComponent
        return verifyObjectState(.init(reflecting: obj), expectedState, path, ["timing": component.timing])
    }

    static func verifyParticleEmitterState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let emitter = obj as! ParticleEmitterComponent.ParticleEmitter
        return verifyObjectState(.init(reflecting: obj), expectedState, path, ["color": emitter.color])
    }

    static func verifyVideoMaterialState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let material = obj as! VideoMaterial
        return verifyObjectState(.init(reflecting: obj), expectedState, path, ["avPlayer": material.avPlayer as Any])
    }

    static func verifyShaderGraphMaterialState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is ShaderGraphMaterial"
        }
        let material = obj as! ShaderGraphMaterial
        let mirror = Mirror(reflecting: material)
        let extraChildren: [String: Any] = [
            "faceCulling": material.faceCulling,
            "readsDepth": material.readsDepth,
            "writesDepth": material.writesDepth]
        var results = ""
        for (key, expectedValue) in expectedObject {
            // Special handling for shader graph parameters.
            if let name = key as? String, name == "parameters" {
                appendResult(verifyParametersState(material, expectedValue, "\(path).parameters"), &results)
            } else {
                appendResult(verifyProperty(mirror, path, key, expectedValue, extraChildren), &results)
            }
        }
        return results
    }

    static func verifyParametersState(_ material: ShaderGraphMaterial, _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is Object"
        }
        var results = ""
        for (key, expectedValue) in expectedObject {
            appendResult(
                verifyState(material.getParameter(name: key as! String) as Any, expectedValue, "\(path).\(key)"),
                &results)
        }
        return results
    }

    static func verifyMipmapLevelsState(_ texture: TextureResource, _ expectedState: Any, _ path: String) -> String {
        // For simplicity's sake, we only support RGBA32 for now.
        let bytesPerPixel: Int
        switch texture.pixelFormat {
            case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb:
                bytesPerPixel = 4
            default:
                return "\(path) has unsupported pixel format \(texture.pixelFormat)"
        }

        // Copy to an MTLTexture with the same type/format/dimensions/etc.
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = texture.textureType
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.depth = texture.depth
        descriptor.arrayLength = texture.arrayLength
        descriptor.mipmapLevelCount = texture.mipmapLevelCount
        descriptor.usage = .unknown
        let copy = PolySpatialRealityKit.instance.mtlDevice!.makeTexture(descriptor: descriptor)!
        try! texture.copy(to: copy)

        // Get that texture's contents as Data.
        switch texture.textureType {
            case .type2D:
                let mipmapLevels = (0..<texture.mipmapLevelCount).map { mipmapLevel in
                    let width = max(texture.width >> mipmapLevel, 1)
                    let height = max(texture.height >> mipmapLevel, 1)
                    let bytesPerRow = width * bytesPerPixel
                    var data = Data(count: height * bytesPerRow)
                    data.withUnsafeMutableBytes {
                        copy.getBytes(
                            $0.baseAddress!, bytesPerRow: bytesPerRow,
                            from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: mipmapLevel)
                    }
                    return data
                }
                return verifyCollectionState(.init(reflecting: mipmapLevels), expectedState, path)

            case .typeCube:
                let mipmapLevels = (0..<texture.mipmapLevelCount).map { mipmapLevel in
                    let width = max(texture.width >> mipmapLevel, 1)
                    let height = max(texture.height >> mipmapLevel, 1)
                    let bytesPerRow = width * bytesPerPixel
                    let bytesPerImage = height * bytesPerRow
                    return (0..<6).map { slice in
                        var data = Data(count: bytesPerImage)
                        data.withUnsafeMutableBytes {
                            copy.getBytes(
                                $0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage,
                                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: mipmapLevel, slice: slice)
                        }
                        return data
                    }
                }
                return verifyCollectionState(.init(reflecting: mipmapLevels), expectedState, path)

            default:
                return "\(path) has unsupported texture type \(texture.textureType)"
        }
    }

    static func verifyAttributedStringState(_ obj: Any, _ expectedState: Any, _ path: String) -> String {
        let attributedString = obj as! AttributedString
        let dictionary: [String: Any] = [
            "text": String(attributedString.characters),
            "foregroundColor": attributedString[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] as Any,
            "font": attributedString[AttributeScopes.UIKitAttributes.FontAttribute.self] as Any,
            "paragraphStyle": attributedString[AttributeScopes.UIKitAttributes.ParagraphStyleAttribute.self] as Any]
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyCollectionState(_ mirror: Mirror, _ expectedState: Any, _ path: String) -> String {
        guard let expectedArray = expectedState as? NSArray else {
            return "\(path) is Collection"
        }
        if mirror.children.count != expectedArray.count {
            return "\(path) has count \(mirror.children.count)"
        }
        var results = ""
        var index = 0
        for child in mirror.children {
            appendResult(verifyState(child.value, expectedArray[index], "\(path)[\(index)]"), &results)
            index += 1
        }
        return results
    }

    static func verifyTupleState(_ mirror: Mirror, _ expectedState: Any, _ path: String) -> String {
        // Tuples may be labeled (in which case we match them like objects--e.g., { maximumDistance: 0.5 }), or
        // unlabeled, in which case we match them as simple values if the length is one or as arrays otherwise.
        // The children of unlabeled tuples have the labels ".0", ".1", etc.  If any of the children have that
        // format, we assume the tuple is unlabeled.
        func isAnonymousTupleChild(_ child: Mirror.Child) -> Bool {
            try! child.label == nil || /\.\d+/.wholeMatch(in: child.label!) != nil
        }
        if !mirror.children.contains(where: isAnonymousTupleChild) {
            return verifyLabeledChildrenState(mirror, expectedState, path)
        } else if mirror.children.count == 1 {
            return verifyState(mirror.children.first!, expectedState, path)
        } else {
            return verifyCollectionState(mirror, expectedState, path)
        }
    }

    static func verifyEnumState(_ obj: Any, _ mirror: Mirror, _ expectedState: Any, _ path: String) -> String {
        // Enums can be either stateless, in which case we match their string representations (as in C#), or
        // stateful, in which case we match an object mapping the case to the state tuple
        // (e.g., { automatic: { maximumDistance: 0.5 } }).
        if let expectedValue = expectedState as? NSString {
            let actualValue = String(describing: obj)
            return actualValue == String(expectedValue) ? "" : "\(path) is '\(actualValue)'"
        } else {
            return verifyLabeledChildrenState(mirror, expectedState, path)
        }
    }

    static func verifyLabeledChildrenState(_ mirror: Mirror, _ expectedState: Any, _ path: String) -> String {
        var dictionary: [String: Any] = [:]
        for child in mirror.children {
            if let label = child.label {
                dictionary[label] = child.value
            }
        }
        return verifyDictionaryState(dictionary, expectedState, path)
    }

    static func verifyDictionaryState(_ dictionary: [String: Any], _ expectedState: Any, _ path: String) -> String {
        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is Object"
        }
        var results = ""
        for (key, expectedValue) in expectedObject {
            appendResult(verifyState(dictionary[key as! String] as Any, expectedValue, "\(path).\(key)"), &results)
        }
        return results
    }

    static func verifyObjectState(
        _ mirror: Mirror, _ expectedState: Any, _ path: String, _ extraChildren: [String: Any] = [:]) -> String {

        guard let expectedObject = expectedState as? NSDictionary else {
            return "\(path) is Object"
        }
        var results = ""
        for (key, expectedValue) in expectedObject {
            appendResult(verifyProperty(mirror, path, key, expectedValue, extraChildren), &results)
        }
        return results
    }

    static func verifyProperty(
        _ mirror: Mirror, _ path: String, _ key: Any, _ expectedValue: Any,
        _ extraChildren: [String: Any] = [:]) -> String {

        let valuePath = "\(path).\(key)"
        if let name = key as? String {
            if name == "typeName" {
                // Special handling for the object type name (match as unqualified string).
                return verifyState(String(describing: mirror.subjectType), expectedValue, valuePath)
            } else if let extraChildIndex = extraChildren.index(forKey: name) {
                return verifyState(extraChildren[extraChildIndex].value, expectedValue, valuePath)
            } else if let actualValue = mirror.descendant(name) {
                return verifyState(actualValue, expectedValue, valuePath)
            }
        }
        if let superclassMirror = mirror.superclassMirror {
            return verifyProperty(superclassMirror, path, key, expectedValue)
        } else {
            return "\(valuePath) not found"
        }
    }

    static func appendResult(_ line: String, _ results: inout String) {
        if !line.isEmpty {
            if !results.isEmpty {
                results += "\n"
            }
            results += line
        }
    }
}

extension PolySpatialRealityKit {

    func verifyState(_ expectedStates: String) -> String {
        do {
            // We use JSON5 in order to allow unquoted identifier keys, single quoted strings, and trailing commas,
            // all of which make for cleaner inline JSON representations in the C# test code.
            let root = try JSONSerialization.jsonObject(
                with: expectedStates.data(using: .utf8)!, options: [.json5Allowed])
            // The top-level RealityKit mapping contains the state for this platform.
            guard let realityKitState = (root as? NSDictionary)?["RealityKit"] else {
                return ""
            }
            // The top-level object to verify is the PolySpatialRealityKit.instance, which contains a reference to the
            // volume array; each volume contains a reference to the root entity for that volume, etc.
            return RealityKitStateVerifier.verifyState(PolySpatialRealityKit.instance, realityKitState, "RealityKit")
        } catch {
            return "Invalid JSON."
        }
    }
}
