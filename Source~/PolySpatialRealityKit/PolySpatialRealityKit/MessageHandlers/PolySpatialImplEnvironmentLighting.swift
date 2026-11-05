import RealityKit

extension PolySpatialRealityKit {

    func createOrUpdateEnvironmentLightingConfiguration(
        _ entity: PolySpatialEntity,
        _ environmentLightingConfigurationInfo: UnsafeMutablePointer<PolySpatialEnvironmentLightingConfigurationData>?) {
        let info = environmentLightingConfigurationInfo!.pointee
        entity.components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: info.environmentLightingWeight))
        entity.updateBackingEntityComponents(EnvironmentLightingConfigurationComponent.self)
    }
    
    func destroyEnvironmentLightingConfiguration(_ entity: PolySpatialEntity) {
        entity.components.remove(EnvironmentLightingConfigurationComponent.self)
        entity.updateBackingEntityComponents(EnvironmentLightingConfigurationComponent.self)
    }
}
