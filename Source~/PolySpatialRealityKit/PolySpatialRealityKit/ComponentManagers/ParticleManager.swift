import Foundation
import RealityKit

@MainActor
class ParticleManager {
    var particleRenderingMode: PolySpatialParticleReplicationMode?

    // We add all bakeToMesh particle systems and trails to the same model sort group so they can blend properly together
    var sortGroupComponent: ModelSortGroupComponent

    // Maps the IDs of main emitters to their sub-emitter data (including the sub-emitter ID).
    private var mainEmitterIdToSubEmitterData: [PolySpatialInstanceID: PolySpatialParticleSubEmitterData] = [:]

    // Maps the IDs of sub-emitters to their main emitters.
    private var subEmitterIdToMainEmitterId: [PolySpatialInstanceID: PolySpatialInstanceID] = [:]

    // The IDs of the main emitters that need their sub-emitters updated on the current frame.
    private var dirtyMainEmitterIds: Set<PolySpatialInstanceID> = []

    private var gravitationalForce = PolySpatialVec3(x: 0, y: -9.81, z: 0).swapCoordinateSystem()

    init(_ sortingGroups: [PolySpatialSortGroup: ModelSortGroup]) {
        let particleSystemSortingGroup = sortingGroups[.particleSystem]!
        sortGroupComponent = ModelSortGroupComponent(group: particleSystemSortingGroup, order: 0)
    }

    func createOrUpdateParticleSystem(
        _ id: PolySpatialInstanceID, _ data: UnsafeMutablePointer<PolySpatialParticleSystemData>?) {

        createOrUpdateParticleSystem(PolySpatialRealityKit.instance.GetEntity(id), data!.pointee)
    }

    // Creates/updates the particle system with the resolved entity and system data.  Can be overridden to perform
    // custom actions with the resolved arguments (visionOS, for example, sets the sort group on the entity).
    func createOrUpdateParticleSystem(_ entity: PolySpatialEntity, _ particleSystem: PolySpatialParticleSystemData) {
        particleRenderingMode = particleSystem.particleReplicationMode
        guard let particleRenderingMode = particleRenderingMode else { return }

        switch particleRenderingMode {
            case .replicateProperties:
                createOrUpdateReplicatePropertiesParticleSystem(entity, particleSystem)

            case .bakeToMesh:
                createOrUpdateBakeToMeshParticleSystem(entity, particleSystem)

            case .bakeToTexture:
                createOrUpdateBakeToTextureParticleSystem(entity, particleSystem)
        }

        // Set our base sort group component.
        entity.setModelSortGroupBase(sortGroupComponent)
    }

    func createOrUpdateBakeToMeshParticleSystem(
        _ entity: PolySpatialEntity, _ particleSystem: PolySpatialParticleSystemData) {

        // Instantiate a Vfx mesh backed by mesh & material(s)
        guard let renderData = particleSystem.renderData,
                let meshId = renderData.meshId,
                let materialIds = renderData.materialIdsAsBuffer else {
            PolySpatialRealityKit.instance.LogError("Set Particle Emitter Component without having renderData, meshId or materialIds.")
            return
        }

        if meshId != PolySpatialAssetID.invalidAssetId {
            let backingEntity = getOrCreateParticleBackingEntity(entity)
            backingEntity.setRenderMeshAndMaterials(meshId, Array(materialIds), renderData.shadowCastingMode != .off)
        }
        if let trailRenderer = particleSystem.trailRenderData {
            let backingEntity = getOrCreateTrailBackingEntity(entity)
            backingEntity.setRenderMeshAndMaterials(
                trailRenderer.meshId!, Array(trailRenderer.materialIdsAsBuffer!), renderData.shadowCastingMode != .off)
        } else {
            // Remove trail entity if no trail data as it was removed
            removeTrailBackingEntity(entity)
        }
    }

    func createOrUpdateBakeToTextureParticleSystem(
        _ entity: PolySpatialEntity, _ particleSystem: PolySpatialParticleSystemData) {

        if particleSystem.particleVertexCount == 0 {
            return
        }

        guard let renderData = particleSystem.renderData,
                let materialIds = renderData.materialIdsAsBuffer else {
            PolySpatialRealityKit.instance.LogError("Set Particle Emitter Component without having renderData, meshId or materialIds.")
            return
        }
        let boundsExtent = particleSystem.approximateUpperBoundExtent!.swapCoordinateSystem()

        if let particleMesh = MeshResource.getOrCreateMeshToSupportSize(vertexCount: particleSystem.particleVertexCount) {
            let renderInfo = PolySpatialComponents.RenderInfo()
            renderInfo.meshSource = .resource(particleMesh)
            renderInfo.materialIds = .init(materialIds)
            renderInfo.castShadows = renderData.shadowCastingMode != .off
            renderInfo.boundsMargin = max(max(boundsExtent.x, boundsExtent.y), boundsExtent.z)
            getOrCreateParticleBackingEntity(entity).setRenderInfo(renderInfo)
        }
    }

    func destroyParticleSystem(_ id: PolySpatialInstanceID) {
        let entity = PolySpatialRealityKit.instance.GetEntity(id)
        removeParticleBackingEntity(entity)
        removeTrailBackingEntity(entity)
        removeSubEmitterDatum(id)
    }

    func getOrCreateParticleBackingEntity(
        _ entity: PolySpatialEntity, _ parentToEntity: Bool = false) -> PolySpatialEntity {

        if let particleBackingEntity = entity.particleBackingEntity {
            return particleBackingEntity
        }
        let particleBackingEntity = PolySpatialEntity(entity.unityId)
        particleBackingEntity.setParent(
            parentToEntity ? entity : PolySpatialRealityKit.instance.GetRootEntity(entity.unityId))
        entity.particleBackingEntity = particleBackingEntity
        return particleBackingEntity
    }

    func removeParticleBackingEntity(_ entity: PolySpatialEntity) {
        guard let particleBackingEntity = entity.particleBackingEntity else {
            return
        }
        particleBackingEntity.dispose()
        entity.particleBackingEntity = nil
    }

    func getOrCreateTrailBackingEntity(_ entity: PolySpatialEntity) -> PolySpatialEntity {
        if let trailBackingEntity = entity.trailBackingEntity {
            return trailBackingEntity
        }
        let trailBackingEntity = PolySpatialEntity(entity.unityId)
        trailBackingEntity.setParent(PolySpatialRealityKit.instance.GetRootEntity(entity.unityId))
        entity.trailBackingEntity = trailBackingEntity
        return trailBackingEntity
    }

    func removeTrailBackingEntity(_ entity: PolySpatialEntity) {
        guard let trailBackingEntity = entity.trailBackingEntity else {
            return
        }
        trailBackingEntity.dispose()
        entity.trailBackingEntity = nil
    }

    // This checks the bit flag to see if a certain inherit property has been enabled.
    func hasSubemitterInheritProperty(_ source: Int32, _ property: PolySpatialParticleSubEmitterInherit) -> Bool {
        return (source & property.value) != 0
    }

    func removeSubEmitterDatum(_ id: PolySpatialInstanceID) {
        if let subEmitterDatum = mainEmitterIdToSubEmitterData.removeValue(forKey: id) {
            subEmitterIdToMainEmitterId[subEmitterDatum.id] = nil
            dirtyMainEmitterIds.remove(id)
        }
    }

    func createOrUpdateReplicatePropertiesParticleSystem(
        _ entity: PolySpatialEntity, _ particleSystem: PolySpatialParticleSystemData) {

        let particleEntity = getOrCreateParticleBackingEntity(entity, true)
        var component = ParticleEmitterComponent()
        var emitter = ParticleEmitterComponent.ParticleEmitter()

        switch particleSystem.playState {
            case .paused:
                component.simulationState = .pause
                break
            case .playing:
                component.simulationState = .play
                break
            case.stoppedAndClearedEmission:
                component.simulationState = .stop
                break
            case .stoppedEmitting:
                component.simulationState = .stop
                break
        }

        let curveKeyBuffer = particleSystem.curveKeyBufferAsBuffer
        let gradientAlphaKeyBuffer = particleSystem.gradientAlphaKeyBufferAsBuffer
        let gradientColorKeyBuffer = particleSystem.gradientColorKeyBufferAsBuffer

        let mainModule = particleSystem.main!
        let lifeSpan = mainModule.startLifetime.getValueAndVariation(curveKeyBuffer)
        emitter.lifeSpan = Double(lifeSpan.value)
        emitter.lifeSpanVariation = Double(lifeSpan.valueVariation)

        let duration = mainModule.duration
        let isRepeating = mainModule.looping
        let isWarmup = mainModule.prewarm
        if (isRepeating) {
            component.timing = .repeating(warmUp: isWarmup ? TimeInterval(duration) : 0, emit: .init(duration: Double(duration)), idle: .init(duration: 0))
        } else {
            component.timing = .once(warmUp: isWarmup ? TimeInterval(duration) : 0, emit: .init(duration: Double(duration)))
        }

        var sizeFirstVal: Float
        var sizeLastVal: Float
        var sizeVariation: Float

        (sizeFirstVal, sizeLastVal, sizeVariation) = mainModule.startSize.getCurveValues(curveKeyBuffer)

        emitter.sizeMultiplierAtEndOfLifespanPower = mainModule.startSize.toSizeForce(curveKeyBuffer)

        // RK doesn't support particle angle per axis, so the angle is set to 0 if this is ticked true. Otherwise, not sure which value to use.
        if !mainModule.isStartRotation3D {
            let emitterAngle = mainModule.startRotation.x!.getValueAndVariation(curveKeyBuffer)
            emitter.angle = emitterAngle.value
            emitter.angleVariation = emitterAngle.valueVariation
        } else {
            PolySpatialRealityKit.LogWarning(
                "Setting each axes seprately on Main::StartRotation for particle sys \(entity.id) is currently not supported.")
        }

        (emitter.color, emitter.colorEvolutionPower) = mainModule.startColor.rk(gradientAlphaKeyBuffer, gradientColorKeyBuffer, &emitter)

        // This property has changed, it now seems to control whether acceleration and force field properties are local or global.
        component.fieldSimulationSpace = .local

        // Should always inherit from entity transform, otherwise particles
        // won't scale with the volume.
        component.particlesInheritTransform = true

        if particleSystem.emission != nil {
            let emissionModule = particleSystem.emission
            (emitter.birthRate, emitter.birthRateVariation) = (emissionModule?.rateOverTime)!.getValueAndVariation(curveKeyBuffer)

            // TODO LXR-2800: add support for burst.
        }

        // Special function to handle emission direction and speed.
        handleEmissionDirectionAndSpeed(particleEntity, particleSystem, &component, &emitter, curveKeyBuffer)

        // Handle gravity if it is present. 9.81 is the typical gravitational force, and acceleration is expressed in local space.
        let gravityForce = mainModule.gravityModifier.getValueAndVariation(curveKeyBuffer).value

        if gravityForce != 0 {
            let worldRotation = particleEntity.convert(
                transform: Transform(), from: PolySpatialRealityKit.instance.GetRootEntity(entity.unityId)).rotation
            let correctedGravity = worldRotation.act(gravitationalForce)

            emitter.acceleration += correctedGravity * gravityForce
        }

        if let colorOverLifetime = particleSystem.colorOverLifetime {
            (emitter.color, emitter.colorEvolutionPower) = colorOverLifetime.color!.rk(gradientAlphaKeyBuffer, gradientColorKeyBuffer, &emitter)
        }

        if let sizeModule = particleSystem.sizeOverLifetime {
            if !sizeModule.separateAxes {
                // Size and size multiplier are multiplied by the original sizes.
                let sizeOverLife = sizeModule.size.x!.getCurveValues(curveKeyBuffer)
                sizeFirstVal *= sizeOverLife.firstVal
                sizeLastVal *= sizeOverLife.lastVal
                sizeVariation *= sizeOverLife.valueVariation

                emitter.sizeMultiplierAtEndOfLifespanPower = sizeModule.size.x!.toSizeForce(curveKeyBuffer)
            } else {
                PolySpatialRealityKit.instance.LogWarning(
                    "Setting each axes separately on SizeOverLifetime  for particle sys \(entity.unityId) is currently not supported.")
            }
        }

        if let rotationModule = particleSystem.rotationOverLifetime {
            // TODO SND-120: Have to enforce that in Unity, the angular velocity fields must all be set to same number, since in Unity, it's a vector and here it's a float. For now, get the average and use that number.
            if !rotationModule.separateAxes {
                (emitter.angularSpeed, _, emitter.angularSpeedVariation) = rotationModule.angularVelocity.z!.getCurveValues(curveKeyBuffer)
            } else {
                PolySpatialRealityKit.instance.LogWarning(
                    "Setting each axes separately on RotationOverLifetime for particle sys \(entity.unityId) is currently not supported.")
            }
        }

        if let noiseModule = particleSystem.noise {
            emitter.noiseStrength = noiseModule.strength!.getValueAndVariation(curveKeyBuffer).value
            emitter.noiseScale = noiseModule.positionAmount!.getValueAndVariation(curveKeyBuffer).value
            emitter.noiseAnimationSpeed = noiseModule.scrollSpeed!.getValueAndVariation(curveKeyBuffer).value
        }

        // Remove any old mappings.
        removeSubEmitterDatum(entity.unityId)

        component.spawnedEmitter = nil
        if particleSystem.subEmittersCount > 0 {
            if particleSystem.subEmittersCount > 1 {
                PolySpatialRealityKit.LogWarning(
                    "Only one subemitter for particle system \(entity.unityId) is supported in RK right now.")
            }
            var subEmitterDatum = particleSystem.subEmitters(at: 0)!
            if subEmitterDatum.id.isValid {
                // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
                subEmitterDatum = .init(
                    id: .init(id: subEmitterDatum.id.id, hostId: entity.unityId.hostId,
                        hostVolumeIndex: entity.unityId.hostVolumeIndex),
                    type: subEmitterDatum.type, inherit: subEmitterDatum.inherit)
                mainEmitterIdToSubEmitterData[entity.unityId] = subEmitterDatum
                subEmitterIdToMainEmitterId[subEmitterDatum.id] = entity.unityId
                dirtyMainEmitterIds.insert(entity.unityId)
            }
        }

        if let mainEmitterId = subEmitterIdToMainEmitterId[entity.unityId] {
            dirtyMainEmitterIds.insert(mainEmitterId)
        }

        if let imageSequenceModule = particleSystem.textureSheetAnimation {
            var imgSequence = ParticleEmitterComponent.ParticleEmitter.ImageSequence()
            imgSequence.rowCount = Int(imageSequenceModule.tilesX)
            imgSequence.columnCount = Int(imageSequenceModule.tilesY)
            imgSequence.frameRate = imageSequenceModule.fps
            let startFrame = imageSequenceModule.startFrame!.getValueAndVariation(curveKeyBuffer)
            imgSequence.initialFrame = Int(startFrame.value)
            imgSequence.initialFrameVariation = Int(startFrame.valueVariation)
            imgSequence.animationMode = .looping // Unity doesn't have explicit support for the others, so just set to looping
            emitter.imageSequence = imgSequence
        }

        emitter.isLightingEnabled = particleSystem.lightsIsEnabled

        // Handle initial size and size multiplier, after considering startSize and sizeOverLifetime.
        if (sizeFirstVal == 0) {
            // Make sure emitter.size is not 0, otherwise things might not even show up.
            sizeFirstVal = 0.01
        }

        emitter.size = sizeFirstVal
        emitter.sizeVariation = sizeVariation
        emitter.sizeMultiplierAtEndOfLifespan = sizeLastVal / sizeFirstVal

        // Handle particle rendering.
        emitter.image = PolySpatialRealityKit.instance.whiteTexture
        if let rendererModule = particleSystem.rendererProperties {
            emitter.billboardMode = rendererModule.renderMode.rk()
            emitter.sortOrder = rendererModule.sortMode.rk()
            emitter.stretchFactor = rendererModule.lengthScale

            if let renderData = particleSystem.renderData {
               if let material = PolySpatialRealityKit.instance.GetVfXMaterialForID(renderData.materialIds(at: 0)!) {
                    // The particle material list is needed to side-step the issue of figuring out how to extract textures from each of the different possible RK material types. For particles, all we really need is the texture and some other pertinent info like blend mode.

                   // TODO (LXR-3590): We should be updating the emitter image when the texture asset changes.
                   emitter.image = material.texture?.getFlipped() ?? PolySpatialRealityKit.instance.whiteTexture
                   emitter.isLightingEnabled = material.isLit

                   let isOpaque = !material.isTransparent

                   // This only affects how particles blend with each other therefore we have to make the color's opacity 1.0 if the material is opaque.
                   emitter.blendMode = material.blendMode.rk(isOpaque)

                   emitter.color = switch emitter.color {
                       case .constant(let value): .constant(tint(value, material.color))
                       case .evolving(let start, let end): .evolving(
                           start: tint(start, material.color), end: tint(end, material.color))
                       default: emitter.color
                   }

                   if isOpaque {
                       emitter.color = switch emitter.color {
                           case .constant(let value): .constant(value.opaque())
                           case .evolving(let start, let end): .evolving(
                                start: start.opaque(), end: end.opaque())
                           default: emitter.color
                       }
                   }

                } else {
                    PolySpatialRealityKit.instance.LogWarning(
                        "No material found for \(entity.unityId) and for material id \(renderData.materialIds(at: 0) ?? PolySpatialAssetID()).")
                }
                particleEntity.setCastShadows(renderData.shadowCastingMode != .off)
            }
        }

        component.mainEmitter = emitter
        particleEntity.components.set(component)
    }

    // Updates any sub-emitter relationships (that is, both main emitter and sub-emitter) that have changed
    // during the frame.
    func updateSubEmitters() {
        for mainEmitterId in dirtyMainEmitterIds {
            let subEmitterDatum = mainEmitterIdToSubEmitterData[mainEmitterId]!
            guard let spawnedParticleEntity =
                    PolySpatialRealityKit.instance.TryGetEntity(subEmitterDatum.id)?.particleBackingEntity else {
                // Try again next frame.
                continue
            }
            var spawnedEmitterComponent = spawnedParticleEntity.components[ParticleEmitterComponent.self]!

            // Turn the spawned emitter particle component off, the main emitter component will handle simulation.
            spawnedEmitterComponent.simulationState = .stop
            spawnedParticleEntity.components.set(spawnedEmitterComponent)

            let mainEntity = PolySpatialRealityKit.instance.GetEntity(mainEmitterId)
            let mainParticleEntity = mainEntity.particleBackingEntity!
            var mainEmitterComponent = mainParticleEntity.components[ParticleEmitterComponent.self]!

            mainEmitterComponent.spawnedEmitter = spawnedEmitterComponent.mainEmitter
            mainEmitterComponent.spawnOccasion = subEmitterDatum.type.rk()

            mainEmitterComponent.spawnSpreadFactor = spawnedEmitterComponent.speed
            mainEmitterComponent.spawnSpreadFactorVariation = spawnedEmitterComponent.speedVariation

            // The other property inherits are not currently implemented in RK.
            if hasSubemitterInheritProperty(subEmitterDatum.inherit, PolySpatialParticleSubEmitterInherit.color) {
                mainEmitterComponent.spawnInheritsParentColor = true
            }

            mainParticleEntity.components.set(mainEmitterComponent)
        }
        dirtyMainEmitterIds.removeAll()
    }

    func handleEmitterShape(
        _ data: PolySpatialParticleEmitterShape,
        _ component: inout ParticleEmitterComponent,
        _ emitter: inout ParticleEmitterComponent.ParticleEmitter) {
        let shape = data.shape
        switch shape {
            // Set some properties to make the shape emitters in RK match the shape emitters in Unity more.
        case .sphere:
            component.emitterShape = .sphere
            component.birthLocation = .volume
            component.birthDirection = .normal
            break

        case .hemisphere:
            component.emitterShape = .sphere
            component.birthLocation = .volume
            component.radialAmount = .pi / 2
            break

        case .cone:
            // Cone is unique, Unity cones emit out of the z-axis.
            component.emitterShape = .cone
            component.birthLocation = .surface
            component.emissionDirection = PolySpatialVec3(x: 0, y: 0, z: 1).swapCoordinateSystem()
            emitter.spreadingAngle = data.angle * .pi / 180
            component.radialAmount = data.arc * .pi / 180
            break

        case .coneVolume:
            // Cone is unique, Unity cones emit out of the z-axis.
            component.emitterShape = .cone
            component.birthLocation = .volume
            component.emissionDirection = PolySpatialVec3(x: 0, y: 0, z: 1).swapCoordinateSystem()
            emitter.spreadingAngle = data.angle * .pi / 180
            component.radialAmount = data.arc * .pi / 180
            break

        case .donut:
            component.emitterShape = .torus
            component.birthLocation = .volume
            component.birthDirection = .normal
            component.radialAmount = data.arc * .pi / 180
            component.torusInnerRadius = data.donutRadius * .pi / 180
            break

        case .box:
            component.emitterShape = .box
            component.birthLocation = .volume
            break

        case .boxShell:
            component.emitterShape = .box
            component.birthLocation = .surface
            break

        case .boxEdge:
            // No real equivalent, closest is box and surface.
            PolySpatialRealityKit.instance.LogWarning("Box edge emitter shape not supported!")
            component.emitterShape = .box
            component.birthLocation = .surface
            break

        case .circle:
            // Closest is a sphere that's been flattened into a disc.
            component.emitterShape = .sphere
            component.birthLocation = .volume
            component.birthDirection = .normal
            component.emitterShapeSize = .init(x: 1, y: 1, z: 0)
            break

        case .singleSidedEdge:
            component.emitterShape = .plane
            component.birthLocation = .surface
            component.emitterShapeSize = .init(x: 1, y: 0, z: 0)
            break

        case .rectangle:
            component.emitterShape = .plane
            component.birthLocation = .surface
            break

        default:
            PolySpatialRealityKit.instance.LogWarning("Emitter shape \(shape) not valid, defaulting to point emitter shape.")
            component.emitterShape = .point
        }
    }

    func handleEmissionDirectionAndSpeed(
        _ particleEntity: PolySpatialEntity,
        _ source: PolySpatialParticleSystemData,
        _ component: inout ParticleEmitterComponent,
        _ emitter: inout ParticleEmitterComponent.ParticleEmitter,
        _ curveKeyBuffer: UnsafeBufferPointer<Unity_PolySpatial_Internals_PolySpatialParticleCurveKey>?) {
        // !! Handle shape module first before handling speed and velocityOverLifetime if it is available - the initial emitter direction is closely linked with the emitter shape !!

        // Set a default shape if user never specifies emitter shape module.
        component.emitterShape = .point
        component.birthLocation = .volume
        component.birthDirection = .local
        component.emitterShapeSize = .one
        emitter.spreadingAngle = 0

        if let shapeModule = source.emitterShape {
            handleEmitterShape(shapeModule, &component, &emitter)

            particleEntity.setTransform(.init(
                scale: ConvertPolySpatialVec3VectorToFloat3(shapeModule.shapeScale!),
                rotation: ConvertPolySpatialQuaternionToRotation(shapeModule.shapeRotation!),
                translation: ConvertPolySpatialVec3PositionToFloat3(shapeModule.shapePosition!)))
        }

        if let main = source.main {
            (component.speed, component.speedVariation) = main.startSpeed.getValueAndVariation(curveKeyBuffer)
        }

        component.emissionDirection *= component.speed

        if let velocityModule = source.velocityOverLifetime {
            // The original emission direction vector, set when we set speed, needs to be added to the velocity vector we get from Unity, keeping in mind the transform space.

            if velocityModule.space.toBirthDirection() == .world {
                // The original component emission dir is local, whereas the vector we've received is world, so we have to change transform spaces.
                let worldRotation = particleEntity.convert(transform: Transform(), from: PolySpatialRealityKit.instance.GetRootEntity(particleEntity.unityId)).rotation
                let correctedVelocity = worldRotation.act(velocityModule.linearVelocity.rk(curveKeyBuffer).value)

                component.emissionDirection += correctedVelocity
            } else {
                component.emissionDirection += velocityModule.linearVelocity.rk(curveKeyBuffer).value
            }

            // If birth direction was set to .normal in HandleEmitterShape, this will overwrite it. Problem is while birthDirection is set to normal, velocity does not apply. Assumably, if the user set velocity over lifetime, they want the particles to be heading in a certain direction.
            component.birthDirection = .local
        }

        let normDirection = normalize(component.emissionDirection)
        let normMagSquared = simd_length_squared(normDirection)
        let originalMagSquared = simd_length_squared(component.emissionDirection)
        var magnitude: Float = 0
        if normMagSquared != 0 {
            magnitude = sqrt(originalMagSquared / normMagSquared)
        }

        // Apply limit velocity over lifetime.
        if let limitVelocityModule = source.limitVelocityOverLifetime {
            var maxSpeedLimit: Float = magnitude
            if !limitVelocityModule.separateAxes {
                maxSpeedLimit = (limitVelocityModule.speed?.x!.getValueAndVariation(curveKeyBuffer).value)!
            } else {
                PolySpatialRealityKit.instance.LogWarning("Setting each axes separately on LimitVelocityOverLifetime::Speed  for particle sys \(particleEntity.unityId) is currently not supported.")
            }

            if magnitude > maxSpeedLimit {
                let overLimit = magnitude - maxSpeedLimit
                magnitude = magnitude - (overLimit * limitVelocityModule.dampen)
            }

            emitter.dampingFactor = limitVelocityModule.drag!.getValueAndVariation(curveKeyBuffer).value
        }

        component.speed = magnitude
        if (magnitude.isNaN) {
            component.speed = 0
        }

        component.emissionDirection = normDirection
        if (normDirection.x.isNaN || normDirection.y.isNaN || normDirection.z.isNaN) {
            component.emissionDirection = .zero
        }
    }
}
