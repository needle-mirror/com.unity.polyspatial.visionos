import Foundation
import RealityKit

extension MeshResource {
    
    private static var degenerateMeshes: [Int32: MeshResource] = [:]

    static func getOrCreateMeshToSupportSize(vertexCount: Int32) -> MeshResource? {
        var ithMeshSize = Int32(15);
        while (ithMeshSize < vertexCount)
        {
            ithMeshSize *= 3
        }
        
        if degenerateMeshes[ithMeshSize] == nil {
            degenerateMeshes[ithMeshSize] = MeshResource.generateDegenerateMesh(vertexCount: Int(ithMeshSize))
        }

        return degenerateMeshes[ithMeshSize]
    }
    
    static func generateDegenerateMesh(vertexCount: Int) -> MeshResource? {
        let triangleIndices: [UInt32] = .init(unsafeUninitializedCapacity: vertexCount) { buffer, initializedCount in
            // Winding order needs to be reversed because RK's z direction is opposite to Unity's.
            for i in stride(from: 0, to: vertexCount, by: 3) {
                buffer[i] = UInt32(i)
                buffer[i + 1] = UInt32(i + 2)
                buffer[i + 2] = UInt32(i + 1)
            }
            initializedCount = vertexCount
        }

        var descriptor = MeshDescriptor(name: "DegenerateMesh")
        descriptor.positions = MeshBuffer<SIMD3<Float>>.init(.init(unsafeUninitializedCapacity: vertexCount) {
            buffer, initializedCount in
            for i in 0..<vertexCount {
                buffer[i] = SIMD3(Float.random(in: -1...1),
                                  Float.random(in: -1...1),
                                  Float.random(in: -1...1))
            }
            initializedCount = vertexCount
        })
        descriptor.primitives = .triangles(triangleIndices)
        
        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            PolySpatialRealityKit.LogError("Error creating particle mesh: \(error)")
        }
                
        return nil
    }
}
