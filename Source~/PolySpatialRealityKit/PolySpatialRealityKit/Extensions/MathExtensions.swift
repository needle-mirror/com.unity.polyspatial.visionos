import simd
import Foundation
import RealityKit
import SceneKit

typealias PolySpatialBounds = UnityEngine_Bounds
typealias PolySpatialVec2 = UnityEngine_Vector2
typealias PolySpatialVec3 = UnityEngine_Vector3
typealias PolySpatialVec4 = UnityEngine_Vector4
typealias PolySpatialMatrix4x4 = UnityEngine_Matrix4x4
typealias PolySpatialQuaternion = UnityEngine_Quaternion
typealias PolySpatialRGBA = UnityEngine_Color32

func ConvertPolySpatialVec2ToFloat2(_ v: PolySpatialVec2) -> simd_float2 {
    return simd_make_float2(v.x, v.y)
}

func ConvertPolySpatialVec2ToFloat3(_ v: PolySpatialVec2) -> simd_float3 {
    return simd_make_float3(v.x, v.y, 0.0)
}

func ConvertPolySpatialVec2ToInvertedYFloat2(_ v: PolySpatialVec2) -> simd_float2 {
    return simd_make_float2(v.x, 1.0 - v.y)
}

func ConvertPolySpatialVec3ToInvertedYFloat3(_ v: PolySpatialVec3) -> simd_float3 {
    return simd_make_float3(v.x, 1.0 - v.y, v.z)
}

func ConvertPolySpatialVec4ToTruncatedFloat3(_ v: PolySpatialVec4) -> simd_float3 {
    return simd_make_float3(v.x, v.y, v.z)
}

func ConvertPolySpatialVec4ToInvertedYFloat4(_ v: PolySpatialVec4) -> simd_float4 {
    return simd_make_float4(v.x, 1.0 - v.y, v.z, v.w)
}

func ConvertPolySpatialVec3PositionToFloat3(_ xrPosition: PolySpatialVec3) -> simd_float3 {
    // Flip the Z-coordinate to go between Unity and ARKit worldspaces.
    return simd_make_float3(xrPosition.x, xrPosition.y, -xrPosition.z)
}

func ConvertPolySpatialVec3VectorToFloat3(_ xrPosition: PolySpatialVec3) -> simd_float3 {
    return simd_make_float3(xrPosition.x, xrPosition.y, xrPosition.z)
}

func ConvertPolySpatialVec4VectorToFloat4(_ xrPosition: PolySpatialVec4) -> simd_float4 {
    return simd_make_float4(xrPosition.x, xrPosition.y, xrPosition.z, xrPosition.w)
}

func ConvertPolySpatialQuaternionToRotation(_ xrRotation: PolySpatialQuaternion) -> simd_quatf {
    // Flip the Z-coordinate to go between Unity and ARKit worldspaces.
    return simd_quaternion(xrRotation.x, xrRotation.y, -xrRotation.z, -xrRotation.w)
}

func ConvertPolySpatialQuaternionToTransform(_ xrQuaternion: PolySpatialQuaternion ) -> simd_float4x4 {
    // Flip the Z- and W-coordinates of the quaternion to go between Unity and ARKit worldspaces.
    return simd_matrix4x4(ConvertPolySpatialQuaternionToRotation(xrQuaternion))
}

func ConvertPolySpatialMatrix4x4ToFloat4x4(_ transform: PolySpatialMatrix4x4) -> simd_float4x4 {
    return simd_matrix(
        simd_make_float4(transform.m00, transform.m10, transform.m20, transform.m30),
        simd_make_float4(transform.m01, transform.m11, transform.m21, transform.m31),
        simd_make_float4(transform.m02, transform.m12, transform.m22, transform.m32),
        simd_make_float4(transform.m03, transform.m13, transform.m23, transform.m33)
    )
}

func ConvertFloat2ToPolySpatialVec2(_ v: simd_float2) -> PolySpatialVec2 {
    return PolySpatialVec2(x: v.x, y: v.y)
}

func ConvertFloat2ToInvertedYPolySpatialVec2(_ v: simd_float2) -> PolySpatialVec2 {
    return PolySpatialVec2(x: v.x, y: 1.0 - v.y)
}

func ConvertFloat3PositionToPolySpatialVec3(_ xrPosition: simd_float3) -> PolySpatialVec3 {
    // Flip the Z-coordinate to go between ARKit and Unity worldspaces.
    return PolySpatialVec3(x: xrPosition.x, y: xrPosition.y, z: -xrPosition.z)
}

func ConvertFloat3VectorToPolySpatialVec3(_ xrPosition: simd_float3) -> PolySpatialVec3 {
    return PolySpatialVec3(x: xrPosition.x, y: xrPosition.y, z: xrPosition.z)
}

func ConvertFloat4VectorToPolySpatialVec4(_ xrPosition: simd_float4) -> PolySpatialVec4 {
    return PolySpatialVec4(x: xrPosition.x, y: xrPosition.y, z: xrPosition.z, w: xrPosition.w)
}

func ConvertRotationToPolySpatialQuaternion(_ xrRotation: simd_quatf) -> PolySpatialQuaternion {
    // Flip the Z- and W-coordinates of the quaternion to go between ARKit and Unity worldspaces.
    return PolySpatialQuaternion(x: Float32(xrRotation.vector.x), y: Float32(xrRotation.vector.y), z: Float32(-xrRotation.vector.z), w: Float32(-xrRotation.vector.w))
}

// Converting the basis of the transform from left hand to right hand
// (or visa-versa) is done by flipping the sign of the 3rd column and
// row of the original transform.
//
// [m00 m01 m02 m03]       [ m00  m01 -m02  m03]
// [m10 m11 m12 m13]    -> [ m10  m11 -m12  m13]
// [m20 m21 m22 m23]       [-m20 -m21  m22 -m23]
// [m30 m31 m32 m33]       [ m30  m31 -m32  m33]
//
// Becuase we flip m22 twice it reverts to its original value.
func SwapCoordinateSystems(_ t: simd_float4x4) -> simd_float4x4 {
    var r = t
    r.columns.0.z *= -1.0
    r.columns.1.z *= -1.0
    r.columns.2.x *= -1.0
    r.columns.2.y *= -1.0
    r.columns.2.w *= -1.0
    r.columns.3.z *= -1.0
    return r
}

extension Float {
    public func approximatelyEqual(_ other: Float, _ epsilon: Float = 1e-6) -> Bool {
        return abs(self - other) <= epsilon
    }
}

extension CGFloat {
    public func approximatelyEqual(_ other: CGFloat, _ epsilon: CGFloat = 1e-6) -> Bool {
        return abs(self - other) <= epsilon
    }
}

extension PolySpatialBounds {
    func rk() -> BoundingBox {
        let rkCenter = center.rkPosition()
        let rkExtents = extents.rk()
        return .init(min: rkCenter - rkExtents, max: rkCenter + rkExtents)
    }
}

protocol SIMD2Convertible {
    func rkInvertYTexCoordAsFloat2() -> SIMD2<Float>
}

protocol SIMD3Convertible {
    func rkAsFloat3() -> SIMD3<Float>
}

extension PolySpatialVec2: SIMD2Convertible {
    func rk() -> SIMD2<Float> {
        ConvertPolySpatialVec2ToFloat2(self)
    }

    func rkInvertYTexCoordAsFloat2() -> SIMD2<Float> {
        rkInvertYTexCoord()
    }

    // When Vec2 is used as texcoords, RK Y starts in opposite corner
    func rkInvertYTexCoord() -> SIMD2<Float> {
        ConvertPolySpatialVec2ToInvertedYFloat2(self)
    }

    func swapCoordinateSystem() -> SIMD2<Float> {
        .init(x: self.x, y: -self.y)
    }

    func exactlyEqual(_ rhs: PolySpatialVec2) -> Bool {
        return (self.x == rhs.x && self.y == rhs.y)
    }
}

extension PolySpatialVec3: SIMD2Convertible {
    // Unity is left-handed, while RealityKit is right-handed. Positions and vectors are converted by negating the z-coordinate
    func swapCoordinateSystem() -> SIMD3<Float> {
        ConvertPolySpatialVec3PositionToFloat3(self)
    }

    func average() -> Float {
        return (self.x + self.y + self.z) / 3
    }

    func rk() -> SIMD3<Float> {
        ConvertPolySpatialVec3VectorToFloat3(self)
    }

    func rkPosition() -> SIMD3<Float> {
        ConvertPolySpatialVec3PositionToFloat3(self)
    }

    func rkInvertYTexCoordAsFloat2() -> SIMD2<Float> {
        rkInvertYTexCoord().xy
    }

    func rkInvertYTexCoord() -> SIMD3<Float> {
        ConvertPolySpatialVec3ToInvertedYFloat3(self)
    }

    func exactlyEqual(_ rhs: PolySpatialVec3) -> Bool {
        return (self.x == rhs.x && self.y == rhs.y && self.z == rhs.z)
    }
}

extension PolySpatialVec4: SIMD2Convertible {
    func toFloat3() -> SIMD3<Float> {
        ConvertPolySpatialVec4ToTruncatedFloat3(self)
    }

    // Unity is left-handed, while RealityKit is right-handed. Positions and vectors are converted by negating the z-coordinate
    func swapCoordinateSystem() -> SIMD4<Float> {
        .init(x: self.x, y: self.y, z: -self.z, w: self.w)
    }

    func exactlyEqual(_ rhs: PolySpatialVec4) -> Bool {
        return (self.x == rhs.x && self.y == rhs.y && self.z == rhs.z && self.w == rhs.w)
    }

    func rk() -> SIMD4<Float> {
        ConvertPolySpatialVec4VectorToFloat4(self)
    }

    func rkPosition() -> SIMD4<Float> {
        self.swapCoordinateSystem()
    }

    func rkInvertYTexCoordAsFloat2() -> SIMD2<Float> {
        rkInvertYTexCoord().xy
    }

    func rkInvertYTexCoord() -> SIMD4<Float> {
        ConvertPolySpatialVec4ToInvertedYFloat4(self)
    }
}

extension PolySpatialVec2: SIMD3Convertible {
    func rkAsFloat3() -> SIMD3<Float> {
        ConvertPolySpatialVec2ToFloat3(self)
    }
}

extension PolySpatialVec3: SIMD3Convertible {
    func rkAsFloat3() -> SIMD3<Float> {
        ConvertPolySpatialVec3VectorToFloat3(self)
    }

    func approximatelyEqual(_ other: PolySpatialVec3, _ epsilon: Float = 1e-6) -> Bool {
        return x.approximatelyEqual(other.x) &&
                y.approximatelyEqual(other.y) &&
                z.approximatelyEqual(other.z)
    }
}

extension PolySpatialVec4: SIMD3Convertible {
    func rkAsFloat3() -> SIMD3<Float> {
        ConvertPolySpatialVec4ToTruncatedFloat3(self)
    }
}

extension PolySpatialMatrix4x4 {
    func swapCoordinateSystem() -> simd_float4x4 {
        SwapCoordinateSystems(ConvertPolySpatialMatrix4x4ToFloat4x4(self))
    }

    func toFloat4x4() -> simd_float4x4 {
        ConvertPolySpatialMatrix4x4ToFloat4x4(self)
    }

    func exactlyEqual(_ rhs: PolySpatialMatrix4x4) -> Bool {
        return (self.m00 == rhs.m00 && self.m10 == rhs.m10 && self.m20 == rhs.m20 && self.m30 == rhs.m30
            && self.m01 == rhs.m01 && self.m11 == rhs.m11 && self.m21 == rhs.m21 && self.m31 == rhs.m31
            && self.m02 == rhs.m02 && self.m12 == rhs.m12 && self.m22 == rhs.m22 && self.m32 == rhs.m32
            && self.m03 == rhs.m03 && self.m13 == rhs.m13 && self.m23 == rhs.m23 && self.m33 == rhs.m33)
    }
}

extension PolySpatialQuaternion {
    func swapCoordinateSystem() -> simd_quatf {
        ConvertPolySpatialQuaternionToRotation(self)
    }

    func rk() -> simd_quatf {
        ConvertPolySpatialQuaternionToRotation(self)
    }
}

extension SIMD2 where Scalar: FloatingPoint {
    func invertYTexCoord() -> SIMD2<Scalar> {
        return .init(x: self.x, y: 1 - self.y)
    }
}

extension SIMD3 where Scalar: FloatingPoint {
    var magnitudeSquared: Scalar {
        return x*x+y*y+z*z
    }

    var length: Scalar {
        return sqrt(magnitudeSquared)
    }

    var xy: SIMD2<Scalar> {
        return SIMD2<Scalar>(x, y)
    }

    func invertYTexCoord() -> SIMD3<Scalar> {
        return .init(x: self.x, y: 1 - self.y, z: self.z)
    }
}

extension SIMD3<Float> {
    func approximatelyEqual(_ other: SIMD3<Float>, _ epsilon: Float = 1e-6) -> Bool {
        return x.approximatelyEqual(other.x) &&
                y.approximatelyEqual(other.y) &&
                z.approximatelyEqual(other.z)
    }
}

extension SIMD4 where Scalar: FloatingPoint {
    init (_ c: PolySpatialRGBA) {
        self.init(Scalar(c.r) / Scalar(255), Scalar(c.g) / Scalar(255),
            Scalar(c.b) / Scalar(255), Scalar(c.a) / Scalar(255))
    }

    var xy: SIMD2<Scalar> {
        return SIMD2<Scalar>(x, y)
    }

    var xyz: SIMD3<Scalar> {
        return SIMD3<Scalar>(x, y, z)
    }

    func invertYTexCoord() -> SIMD4<Scalar> {
        return .init(x: self.x, y: 1 - self.y, z: self.z, w: self.w)
    }
}

extension simd_quatf {
    public func approximatelyEqual(_ other: simd_quatf, _ epsilon: Float = 1e-6) -> Bool {
        let selfDotOther = simd_dot(simd_normalize(self), simd_normalize(other))
        return min(abs(selfDotOther), 1.0).approximatelyEqual(1.0, epsilon)
    }

    public func eulerAngles() -> SIMD3<Float> {
       let n = SCNNode()
        n.simdOrientation = self
        return n.simdEulerAngles
    }
}

// Returns the angle between the two provided quaternions in radians.
func simd_angle(_ a: simd_quatf, _ b: simd_quatf) -> Float {
    // See https://github.cds.internal.unity3d.com/unity/unity/blob/trunk/Runtime/Math/Quaternion.cpp#L44
    acos(min(abs(dot(a, b)), 1)) * 2
}

extension float4x4 {
    init(scale: Float) {
        self.init(SIMD4<Float>(scale, 0, 0, 0),
                  SIMD4<Float>(0, scale, 0, 0),
                  SIMD4<Float>(0, 0, scale, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }

    init(nonuniformScale: SIMD3<Float>) {
        self.init(SIMD4<Float>(nonuniformScale.x, 0, 0, 0),
                  SIMD4<Float>(0, nonuniformScale.y, 0, 0),
                  SIMD4<Float>(0, 0, nonuniformScale.z, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }

    init(rotationAxis: SIMD3<Float>, angleRadians: Float) {
        let x = rotationAxis.x, y = rotationAxis.y, z = rotationAxis.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(SIMD4<Float>( t * x * x + c, t * x * y + z * s, t * x * z - y * s, 0),
                  SIMD4<Float>( t * x * y - z * s, t * y * y + c, t * y * z + x * s, 0),
                  SIMD4<Float>( t * x * z + y * s, t * y * z - x * s, t * z * z + c, 0),
                  SIMD4<Float>(                 0, 0, 0, 1))
    }

    init(translate: SIMD3<Float>) {
        self.init(SIMD4<Float>(   1, 0, 0, 0),
                  SIMD4<Float>(   0, 1, 0, 0),
                  SIMD4<Float>(   0, 0, 1, 0),
                  SIMD4<Float>(translate[0], translate[1], translate[2], 1))
    }

    init(fovRadians: Float, aspectRatio: Float, zNear: Float, zFar: Float) {
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = zFar - zNear
        let zScale = -(zFar + zNear) / zRange
        let wzScale = -2 * zFar * zNear / zRange

        let xx = xScale
        let yy = yScale
        let zz = zScale
        let zw = Float(-1)
        let wz = wzScale

        self.init(SIMD4<Float>(xx, 0, 0, 0),
                  SIMD4<Float>( 0, yy, 0, 0),
                  SIMD4<Float>( 0, 0, zz, zw),
                  SIMD4<Float>( 0, 0, wz, 0))
    }

    var normalMatrix: float3x3 {
        let upperLeft = float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
        return upperLeft.transpose.inverse
    }

    var translation: SIMD3<Float> {
        return self[3].xyz
    }

    var rotation: simd_quatf {
        return simd_quatf(self)
    }

    var scale: SIMD3<Float> {
        // This is the equivalent of transforming the basis vectors by the matrix and taking the resulting lengths.
        return .init(length(self[0].xyz), length(self[1].xyz), length(self[2].xyz))
    }

    func approximatelyEqual(_ rhs: float4x4, epsilon: Float = 1e-6) -> Bool {
        // compare position, rotation, and scale against an epsilon
        return (simd_distance(self.translation, rhs.translation).approximatelyEqual(0.0, epsilon)
            && self.rotation.approximatelyEqual(rhs.rotation, epsilon)
            && simd_distance(self.scale, rhs.scale).approximatelyEqual(0.0, epsilon))
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}

extension PolySpatialBoneWeight {
    func rk() -> MeshJointInfluence {
        .init(jointIndex: Int(self.boneIndex), weight: self.weight)
    }
}
