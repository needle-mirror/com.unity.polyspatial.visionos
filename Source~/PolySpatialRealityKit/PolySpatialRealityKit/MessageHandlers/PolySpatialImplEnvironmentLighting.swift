import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateEnvironmentLightingConfiguration(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ environmentLightingConfigurationInfo: UnsafeMutablePointer<PolySpatialEnvironmentLightingConfigurationData>?) {
        let entity = GetEntity(id)
        let info = environmentLightingConfigurationInfo!.pointee
        entity.components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: info.environmentLightingWeight))
        entity.updateBackingEntityComponents(EnvironmentLightingConfigurationComponent.self)
    }
    
    func destroyEnvironmentLightingConfiguration(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.components.remove(EnvironmentLightingConfigurationComponent.self)
        entity.updateBackingEntityComponents(EnvironmentLightingConfigurationComponent.self)
    }
}
