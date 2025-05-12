import Foundation
import RealityKit
import UIKit

@MainActor
func PolySpatialAssert(_ condition: @autoclosure () -> Bool,
                       _ message: @autoclosure () -> String,
                       file: StaticString = #file,
                       line: UInt = #line,
                       caller: StaticString = #function) {
    if !condition() {
        // trim file to just the last component
        let file = file.description.split(separator: "/").last!
        let msg = "Assertion failed in \(caller) at \(file):\(line): \(message())"
        if PolySpatialRealityKit.instance.simHostAPI.SendHostCommand != nil {
            print(msg) // make sure it gets printed in wherever Swift logging is going
            PolySpatialRealityKit.instance.LogError(msg) // this will handle aborting if necessary
        } else {
            if PolySpatialRealityKit.abortOnError {
                assertionFailure(msg)
            } else {
                print(msg)
            }
        }
    }
}

@MainActor
func PolySpatialAssert(_ condition: @autoclosure () -> Bool,
                       file: StaticString = #file,
                       line: UInt = #line,
                       caller: StaticString = #function) {
    PolySpatialAssert(condition(), "Assertion failure", file: file, line: line, caller: caller)
}

@MainActor
func withAbortOnError(_ value: Bool, _ closure: () -> Void) {
    let saved = PolySpatialRealityKit.abortOnError
    PolySpatialRealityKit.abortOnError = value
    closure()
    PolySpatialRealityKit.abortOnError = saved
}

// Allow throwing strings as exceptions
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}

// 128-bit struct that allows for a packed representation of PolySpatialInstanceID
public struct PackedIdentifier: CustomStringConvertible {
    public init(id0: UInt64, id1: UInt64) {
        _id0 = id0;
        _id1 = id1;
    }

    public var description: String {
        "\(_id0):\(_id1)"
    }

    public var unityInstanceId: Int32 {
        .init(truncatingIfNeeded: _id0)
    }

    private var _id0 : UInt64;
    private var _id1 : UInt64;

    public var id0: UInt64 { _id0; }
    public var id1: UInt64 { _id1; }
}

// Extensions required so that HostID can be used in PolySpatialInstanceID extensions
extension PolySpatialHostID : Equatable, Hashable, CustomStringConvertible {
    public init(connectionId: UInt16) {
        self.init(connectionId: connectionId, reserved: 0)
    }

    public var description: String {
        "\(connectionId)"
    }

    public static func == (lhs: PolySpatialHostID, rhs: PolySpatialHostID) -> Bool {
        return lhs.connectionId == rhs.connectionId;
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(connectionId)
    }

    public var IsLocal: Bool { return connectionId == 0 }

    public static let localDefault = PolySpatialHostID(connectionId: 0)
}

// Extension to add Hashable support to the PolySpatialInstanceID type. This allows it
// to act as a key
extension PolySpatialInstanceID: Equatable, Hashable, CustomStringConvertible {
    public init(id: Int64, hostId: PolySpatialHostID, hostVolumeIndex: UInt8) {
        self.init(id: id, hostId: hostId, hostVolumeIndex: hostVolumeIndex, _Padding0: 0, _Padding1: 0)
    }

    public var description: String {
        hostVolumeIndex == 0 ? (hostId.IsLocal ? "\(id)" : "\(id):\(hostId)") : "\(id):\(hostId):\(hostVolumeIndex)";
    }

    public static func == (lhs: PolySpatialInstanceID, rhs: PolySpatialInstanceID) -> Bool {
        return lhs.id == rhs.id && lhs.hostId == rhs.hostId && lhs.hostVolumeIndex == rhs.hostVolumeIndex
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(hostId)
        hasher.combine(hostVolumeIndex)
    }

    public var isValid: Bool { return id != 0 }

    public static let none = PolySpatialInstanceID.init(id: 0, hostId: PolySpatialHostID.init(connectionId: 0), hostVolumeIndex: 0)

    public init(packed: PackedIdentifier) {
        self.init(
            id: .init(bitPattern: packed.id0),
            hostId: .init(connectionId: .init(truncatingIfNeeded: packed.id1)),
            hostVolumeIndex: .init(truncatingIfNeeded: (packed.id1 >> 32)))
    }

    public var packed: PackedIdentifier {
        .init(
            id0: .init(bitPattern: id),
            id1: .init(hostVolumeIndex) << 32 | .init(hostId.connectionId))
    }
}

// Read-Only access into a PolySpatialInstanceIdList data buffer.
struct UnsafePolySpatialInstanceIDBufferPointer {
    private let data: UnsafeRawBufferPointer

    public init(_ data: UnsafeRawBufferPointer) {
        self.data = data
    }

    public var count: Int { (data.count - MemoryLayout<PolySpatialInstanceIDListHeader>.size) / MemoryLayout<Int64>.size }

    public var instanceIds: UnsafeBufferPointer<Int64> {
        data[MemoryLayout<PolySpatialInstanceIDListHeader>.size...].bindMemory(to: Int64.self)
    }

    public var hostId: PolySpatialHostID {
        data.load(as: PolySpatialInstanceIDListHeader.self).hostId
    }

    public var hostVolumeIndex: UInt8 {
        data.load(as: PolySpatialInstanceIDListHeader.self).hostVolumeIndex
    }
}

// Extension to add Hashable support to the PolySpatialComponentID type.
extension PolySpatialComponentID: Equatable, Hashable, CustomStringConvertible {
    public var description: String {
        .init(describing: id)
    }

    public static func == (lhs: PolySpatialComponentID, rhs: PolySpatialComponentID) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var isValid: Bool { return id != 0 }

    public static let none = PolySpatialComponentID.init(id: 0)
}

extension PolySpatialAssetID: Equatable, Comparable, Hashable, CustomStringConvertible {
    struct ActualGuid {
        var a: UInt32
        var b: UInt16
        var c: UInt16
        var d0: UInt8
        var d1: UInt8
        var e: UInt8
        var f: UInt8
        var g: UInt8
        var h: UInt8
        var i: UInt8
        var j: UInt8
    }

    public var description: String {
        // this gets printed on the C# side as a GUID, and a GUID is actually
        // a struct of int sizes like this: 32-16-16-16-8-8-8-8-8-8.  So we can't
        // just print ints, because due to endianness, they would print in the
        // wrong order. So swizzle things around. d0 and d1 are sneaky because
        // they seem to be stored as uint8s on the C# side but are printed as a
        // short
        withUnsafePointer(to: self) {
            let guid = UnsafeRawPointer($0).assumingMemoryBound(to: ActualGuid.self).pointee
            return String(format: "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x:%ld",
                          guid.a, guid.b, guid.c, guid.d0, guid.d1,
                          guid.e, guid.f, guid.g, guid.h,
                          guid.i, guid.j, localFileId)
        }
    }

    public static func == (lhs: PolySpatialAssetID, rhs: PolySpatialAssetID) -> Bool {
        return lhs.id0 == rhs.id0
        && lhs.id1 == rhs.id1
        && lhs.id2 == rhs.id2
        && lhs.id3 == rhs.id3
        && lhs.localFileId == rhs.localFileId

        // return lhs.id == rhs.id
    }

    public static func < (lhs: PolySpatialAssetID, rhs: PolySpatialAssetID) -> Bool {
        if lhs.id0 != rhs.id0 {
            return lhs.id0 < rhs.id0
        } else if lhs.id1 != rhs.id1 {
            return lhs.id1 < rhs.id1
        } else if lhs.id2 != rhs.id2 {
            return lhs.id2 < rhs.id2
        } else if lhs.id3 != rhs.id3 {
            return lhs.id3 < rhs.id3
        } else {
            return lhs.localFileId < rhs.localFileId
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id0)
        hasher.combine(id1)
        hasher.combine(id2)
        hasher.combine(id3)
        hasher.combine(localFileId)
    }

    public static let invalidAssetId = PolySpatialAssetID.init(id0: 0, id1: 0, id2: 0, id3: 0, localFileId: 0)

    public var isValid: Bool { self != PolySpatialAssetID.invalidAssetId }
}

extension PolySpatialCullMode {
    func rk() -> PhysicallyBasedMaterial.FaceCulling {
        switch self {
            case .none_: return .none
            case .back: return .back
            case .front: return .front
            @unknown default: assertionFailure()
        }
    }
}

@MainActor
extension PolySpatialBlendingMode {
    func rk() -> MaterialParameterTypes.BlendMode {
        switch self {
            case .alpha: return .alpha
            case .additive: return .add
            default:
                PolySpatialRealityKit.LogWarning("Unsupported blending mode: \(self)")
                return .alpha
        }
    }
}

extension PolySpatialMeshTopology {
    func rk() -> MTLPrimitiveType {
        switch self {
            case .triangles: .triangle
            case .quads: .triangle
            case .lines: .line
            case .lineStrip: .lineStrip
            case .points: .point
        }
    }
}

extension PolySpatialVertexAttribute {
    func rk() -> LowLevelMesh.VertexSemantic {
        switch self {
            case .position: .position
            case .normal: .normal
            case .tangent: .tangent
            case .color: .color
            case .texCoord0: .uv0
            case .texCoord1: .uv1
            case .texCoord2: .uv2
            case .texCoord3: .uv3
            case .texCoord4: .uv4
            case .texCoord5: .uv5
            case .texCoord6: .uv6
            case .texCoord7: .uv7
            default: .unspecified
        }
    }

    func uvIndex() -> Int? {
        switch self {
            case .texCoord0: 0
            case .texCoord1: 1
            case .texCoord2: 2
            case .texCoord3: 3
            case .texCoord4: 4
            case .texCoord5: 5
            case .texCoord6: 6
            case .texCoord7: 7
            default: nil
        }
    }
}

extension PolySpatialVertexAttributeFormat {
    func rk(_ dimension: Int32) -> MTLVertexFormat {
        switch self {
            case .float32 where dimension == 1: .float
            case .float32 where dimension == 2: .float2
            case .float32 where dimension == 3: .float3
            case .float32 where dimension == 4: .float4
            case .float16 where dimension == 1: .half
            case .float16 where dimension == 2: .half2
            case .float16 where dimension == 3: .half3
            case .float16 where dimension == 4: .half4
            case .unorm8 where dimension == 1: .ucharNormalized
            case .unorm8 where dimension == 2: .uchar2Normalized
            case .unorm8 where dimension == 3: .uchar3Normalized
            case .unorm8 where dimension == 4: .uchar4Normalized
            case .snorm8 where dimension == 1: .charNormalized
            case .snorm8 where dimension == 2: .char2Normalized
            case .snorm8 where dimension == 3: .char3Normalized
            case .snorm8 where dimension == 4: .char4Normalized
            case .unorm16 where dimension == 1: .ushortNormalized
            case .unorm16 where dimension == 2: .ushort2Normalized
            case .unorm16 where dimension == 3: .ushort3Normalized
            case .unorm16 where dimension == 4: .ushort4Normalized
            case .snorm16 where dimension == 1: .shortNormalized
            case .snorm16 where dimension == 2: .short2Normalized
            case .snorm16 where dimension == 3: .short3Normalized
            case .snorm16 where dimension == 4: .short4Normalized
            case .uint8 where dimension == 1: .uchar
            case .uint8 where dimension == 2: .uchar2
            case .uint8 where dimension == 3: .uchar3
            case .uint8 where dimension == 4: .uchar4
            case .sint8 where dimension == 1: .char
            case .sint8 where dimension == 2: .char2
            case .sint8 where dimension == 3: .char3
            case .sint8 where dimension == 4: .char4
            case .uint16 where dimension == 1: .ushort
            case .uint16 where dimension == 2: .ushort2
            case .uint16 where dimension == 3: .ushort3
            case .uint16 where dimension == 4: .ushort4
            case .sint16 where dimension == 1: .short
            case .sint16 where dimension == 2: .short2
            case .sint16 where dimension == 3: .short3
            case .sint16 where dimension == 4: .short4
            case .uint32 where dimension == 1: .uint
            case .uint32 where dimension == 2: .uint2
            case .uint32 where dimension == 3: .uint3
            case .uint32 where dimension == 4: .uint4
            case .sint32 where dimension == 1: .int
            case .sint32 where dimension == 2: .int2
            case .sint32 where dimension == 3: .int3
            case .sint32 where dimension == 4: .int4
            default: fatalError("Unsupported format \(self) with dimension \(dimension)")
        }
    }

    func bytesPerElement() -> Int {
        switch self {
            case .float32, .uint32, .sint32: 4
            case .float16, .unorm16, .snorm16, .uint16, .sint16: 2
            case .unorm8, .snorm8, .uint8, .sint8: 1
        }
    }
}

extension PolySpatialReflectionProbeData: Equatable, Hashable {
    static func == (lhs: PolySpatialReflectionProbeData, rhs: PolySpatialReflectionProbeData) -> Bool {
        lhs.textureAssetId == rhs.textureAssetId && lhs.weight == rhs.weight
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(textureAssetId)
        hasher.combine(weight)
    }
}

extension UnityEngine_Color {
    func cgColor() -> CGColor {
        CGColor(srgbRed: CGFloat(self.r), green: CGFloat(self.g), blue: CGFloat(self.b), alpha: CGFloat(self.a))
    }
}

// AKA PolySpatialRGBA
extension UnityEngine_Color32 {
    func rk() -> UIColor {
        .init(self)
    }

    func rkLinear() -> UIColor {
        // TODO: what is the best way to specify a linear color space on visionOS?
        .init(self)
    }

    func rkPow(_ exponent: Double) -> UIColor {
        return .init(red: CGFloat(pow(Double(r)/255.0, exponent)),
              green: CGFloat(pow(Double(g)/255.0, exponent)),
              blue: CGFloat(pow(Double(b)/255.0, exponent)),
              alpha: CGFloat(Double(a)/255.0))
    }

    func cgColor() -> CGColor {
        CGColor(srgbRed: CGFloat(Double(self.r)/255.0), green: CGFloat(Double(self.g)/255.0), blue: CGFloat(Double(self.b)/255.0), alpha: CGFloat(Double(self.a)/255.0))
    }
}

extension UIColor {
    convenience init(_ v: PolySpatialVec4) {
        self.init(red: CGFloat(v.x), green: CGFloat(v.y), blue: CGFloat(v.z), alpha: CGFloat(v.w))
    }

    convenience init(_ v: PolySpatialRGBA) {
        self.init(red: CGFloat(Double(v.r)/255.0), green: CGFloat(Double(v.g)/255.0), blue: CGFloat(Double(v.b)/255.0), alpha: CGFloat(Double(v.a)/255.0))
    }

    convenience init(_ c: UnityEngine_Color) {
        self.init(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    var brightnessComponent: CGFloat {
        var brightness: CGFloat = 0.0
        getWhite(&brightness, alpha: nil)
        return brightness
    }
}
