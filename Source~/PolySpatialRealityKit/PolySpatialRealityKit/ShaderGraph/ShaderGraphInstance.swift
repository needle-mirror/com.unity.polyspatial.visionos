import Foundation

@MainActor
class ShaderGraphInstance: Hashable {
    nonisolated static func == (lhs: ShaderGraphInstance, rhs: ShaderGraphInstance) -> Bool {
        return lhs === rhs
    }

    let id: PolySpatialAssetID

    var castShadows = true

    var hasVolumeToWorldTextureProperty: Bool { false }
    var hasObjectBoundsProperties: Bool { false }
    var hasLightmapProperties: Bool { false }
    var hasLightProbeProperties: Bool { false }
    var hasReflectionProbeProperties: Bool { false }

    init(_ id: PolySpatialAssetID) {
        self.id = id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }

    func insertIntoGlobalProperties() {
        // Nothing by default.
    }

    // Removes this instance from the global instance map, the instance set associated with its shader graph,
    // and from any other places where it may be referenced (such as the global properties).
    func removeSelf() {
        ShaderManager.instance.shaderGraphInstances.removeValue(forKey: id)
    }
}
