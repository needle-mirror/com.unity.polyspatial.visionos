import ARKit
import CoreGraphics
import Foundation
import RealityKit

//
// A helper Entity subclass for things that PolySpatial needs.
//
// Provides quick access to components that we may use (RenderInfo, ModelComponent, etc.),
// as well as helper methods for updating things like RenderInfo+ModelComponent
//
class PolySpatialEntity: Entity, HasModel, TextureObserver {

    // The single collision component shared by all raycast targets.
    static let raycastTargetCollisionComponent = CollisionComponent(
        shapes: [.generateBox(size: .one)], mode: .trigger, collisionOptions: .static)

    public var unityId: PolySpatialInstanceID { self.instanceRef.unityId }

    // this is required to be present, otherwise something went very wrong
    var instanceRef: PolySpatialComponents.InstanceRef {
        self.components[PolySpatialComponents.InstanceRef.self]!
    }

    struct CollisionShape {
        let info: PolySpatialColliderData
        let resource: ShapeResource?
        let worldScale: SIMD3<Float>

        init(_ info: PolySpatialColliderData, _ resource: ShapeResource?, _ worldScale: simd_float3) {
            self.info = info
            self.resource = resource
            self.worldScale = worldScale
        }
    }
    var collisionShapes: [PolySpatialComponentID: CollisionShape] = [:]

    // if accessed, these are added
    var renderInfo: PolySpatialComponents.RenderInfo {
        if !self.components.has(PolySpatialComponents.RenderInfo.self) {
            self.components.set(PolySpatialComponents.RenderInfo())
        }
        return self.components[PolySpatialComponents.RenderInfo.self]!
    }

    // Returns the ModelComponent associated with the entity, which could be on the child of the
    // raycastTargetBackingEntity.
    var model: ModelComponent? {
        if let raycastTargetBackingEntity {
            return raycastTargetBackingEntity.model
        } else {
            return self.components[ModelComponent.self]
        }
    }

    // The array of transforms for each of the model's joints.
    var blendJointTransforms: [Transform] = [] {
        didSet {
            jointTransforms = blendJointTransforms

            if components[PolySpatialComponents.BlendedMeshInstance.self] != nil {
                PolySpatialRealityKit.instance.skinnedMeshManager.dirtyBlendedMeshInstances.insert(self)
            }
        }
    }

    // The array of weights for each of the model's blend shapes.
    var blendShapeWeights: [Float] = [] {
        didSet {
            if components[PolySpatialComponents.BlendedMeshInstance.self] != nil {
                PolySpatialRealityKit.instance.skinnedMeshManager.dirtyBlendedMeshInstances.insert(self)
            }
        }
    }

    // The local bounds of the model, accounting for animated deformations.  These are relative to the root bone,
    // and thus we expect blended meshes to be parented to the root bone.
    var blendLocalBounds: BoundingBox?

    // The entity is mirrored if an odd number of its scale components are negative.
    var isMirrored: Bool {
        ((scale.x < 0.0) != (scale.y < 0.0)) != (scale.z < 0.0)
    }

    // Sets whether this entity is a UIGraphic (Image/RawImage) acting as a raycast target.
    var raycastTarget = false {
        didSet {
            // If we actually have a mesh to render, then we need to update the model component here, because
            // raycast targets' model components are transferred to a backing grandchild (so that we can put
            // the collision component on the raycastTargetBackingEntity and have its child be affected by the
            // accompanying hover component).
            if components.has(PolySpatialComponents.RenderInfo.self) {
                updateModelComponent()
            }
        }
    }

    // A reference to the raycast target backing entity.  This is created as a child of any entity with raycastTarget
    // enabled in order to transform a unit cube ShapeResource into the bounds of the raycast mesh (in order to avoid
    // creating a new ShapeResource, which is inexplicably expensive, whenever the mesh changes).  The ModelComponent
    // representing the visible mesh is then created as a child of the raycast target backing entity, with the child
    // having the inverse of the backing entity transform.
    var raycastTargetBackingEntity: PolySpatialEntity? {
        get {
            components[PolySpatialComponents.RaycastTargetBackingEntity.self]?.entity
        }
        set {
            if let entity = newValue {
                components.set(PolySpatialComponents.RaycastTargetBackingEntity(entity))
                updateBackingEntityComponents(entity)
            } else {
                // We don't bother removing the components from the backing entity,
                // because we assume that it's being deleted.
                components.remove(PolySpatialComponents.RaycastTargetBackingEntity.self)
            }
        }
    }

    // A reference to the skinned backing entity: a separate entity created by SkinnedMeshManager, parented to the
    // parent of the root bone, that contains the actual skinned ModelComponent.  We copy various RealityKit components
    // to this backing entity so that their behavior affects that ModelComponent.
    var skinnedBackingEntity: PolySpatialEntity? {
        get {
            components[PolySpatialComponents.SkinnedBackingEntity.self]?.entity
        }
        set {
            if let entity = newValue {
                components.set(PolySpatialComponents.SkinnedBackingEntity(entity))
                updateBackingEntityComponents(entity)
            } else {
                // We don't bother removing the components from the backing entity,
                // because we assume that it's being deleted.
                components.remove(PolySpatialComponents.SkinnedBackingEntity.self)
            }
        }
    }

    // A reference to the particle backing entity: a separate entity created by ParticleManager, parented to the
    // volume root (for bake-to-mesh/bake-to-texture particles) or the original entity (for replicate-properties
    // particles), that contains the actual particle ModelComponent.  We copy various RealityKit components to this
    // backing entity so that their behavior affects that ModelComponent.
    var particleBackingEntity: PolySpatialEntity? {
        get {
            components[PolySpatialComponents.ParticleBackingEntity.self]?.entity
        }
        set {
            if let entity = newValue {
                components.set(PolySpatialComponents.ParticleBackingEntity(entity))
                updateBackingEntityComponents(entity)
            } else {
                // We don't bother removing the components from the backing entity,
                // because we assume that it's being deleted.
                components.remove(PolySpatialComponents.ParticleBackingEntity.self)
            }
        }
    }

    var lineRendererBackingEntity: PolySpatialEntity? {
        get {
            components[PolySpatialComponents.LineRendererBackingEntity.self]?.entity
        }
        set {
            if let entity = newValue {
                components.set(PolySpatialComponents.LineRendererBackingEntity(entity))
                updateBackingEntityComponents(entity)
            } else {
                // We don't bother removing the components from the backing entity,
                // because we assume that it's being deleted.
                components.remove(PolySpatialComponents.LineRendererBackingEntity.self)
            }
        }
    }

    // A reference to the trail backing entity: a separate entity created by ParticleManager, parented to the
    // volume root, that contains the actual trail ModelComponent.  We copy various RealityKit components
    // to this backing entity so that their behavior affects that ModelComponent.
    var trailBackingEntity: PolySpatialEntity? {
        get {
            components[PolySpatialComponents.TrailBackingEntity.self]?.entity
        }
        set {
            if let entity = newValue {
                components.set(PolySpatialComponents.TrailBackingEntity(entity))
                updateBackingEntityComponents(entity)
            } else {
                // We don't bother removing the components from the backing entity,
                // because we assume that it's being deleted.
                components.remove(PolySpatialComponents.TrailBackingEntity.self)
            }
        }
    }

    var lastSentInteractionPhase: PolySpatialPointerPhase = .none_ {
        didSet {
            // If you dispose and remove an entity from world mid interacton then it stops registering input and can never send its .ended event on release.
            // So if we are mid interaction we disable the entity until phase gets updated to ended or cancelled here. Then we remove entity from world
            if disposed &&
                (lastSentInteractionPhase == .ended ||
                 lastSentInteractionPhase == .cancelled ||
                 lastSentInteractionPhase == .none_) {
                removeFromParent(preservingWorldTransform: false)
            }
        }
    }

    private var disposed: Bool = false

    required init() {
        assertionFailure("Should never use this init on PolySpatialEntity")
    }

    init(_ unityId: PolySpatialInstanceID) {
        super.init()

        self.name = "\(unityId.id):\(unityId.hostId):\(unityId.hostVolumeIndex)"
        self.components.set(PolySpatialComponents.InstanceRef(unityId))
    }

    // Unsubscribes the entity from the resources that it was listening to.  We can't use deinit, because
    // we need to retain a strong reference in the observer set (for comparison purposes), which prevents
    // the entity from being reclaimed.  So, be sure to call this when destroying the entity.
    func dispose() {
        disposed = true

        // If you remove an entity from world mid interacton then it stops registering input and can never send its .ended event on release.
        // Check here if phase is mid interaction. If so disable entity for now, then remove it from world in lastSentInteractionPhase.didSet when interaction finishes.
        switch lastSentInteractionPhase {
        case .began, .moved:
            self.isEnabled = false
            break
        default:
            // By definition, if we're being disposed, we shouldn't have a parent.
            removeFromParent(preservingWorldTransform: false)
            break
        }

        disposeBackingEntities()

        unregisterMeshesAndMaterials()
        removeSelfAsRenderInfoTextureObserver()
        removeSelfAsMaskedRendererTextureObserver()
        removeSelfAsImageBasedLightTextureObserver()
        removeSelfAsAlignmentMarkerTextureObserver()
        clearAlignmentMarkerTracker()

        PolySpatialRealityKit.instance.skinnedMeshManager.dirtyBlendedMeshInstances.remove(self)

        // If we were host to a static batch, make sure we dispose of its elements as well.
        if let staticBatchRootInfo = components[PolySpatialComponents.StaticBatchRootInfo.self] {
            staticBatchRootInfo.clearContents()
            StaticBatchManager.instance.dirtyStaticBatchRootIds.remove(unityId)
        }

        // Likewise, make sure that we are removed from any existing static batch
        // (in case our render info wasn't cleared).
        clearStaticBatchElementInfo()
    }

    // Called when one or more of our entity-specific textures (lightmap, reflection probe) was updated.
    func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, PolySpatialRealityKit.TextureAsset>) {
        let isInAssets = { assets[$0] != nil }
        if let imageBasedLightInfo = components[PolySpatialComponents.ImageBasedLightInfo.self],
            imageBasedLightInfo.texturesContain(isInAssets) {

            updateImageBasedLightComponent()
        }
        let maskedRendererInfo = components[PolySpatialComponents.MaskedRendererInfo.self]
        if let renderInfo = components[PolySpatialComponents.RenderInfo.self],
            renderInfo.texturesContain(isInAssets) || maskedRendererInfo != nil &&
                maskedRendererInfo!.texturesContain(isInAssets) {

            updateModelComponent()
        }
    }

    // A mesh or material with the given id was updated.  If referencePreserved is true,
    // the mesh was updated in-place (meaning that the ModelComponent, which stores the mesh by
    // reference, doesn't necessarily need to be updated).
    func meshOrMaterialUpdated(_ id: PolySpatialAssetID, _ referencePreserved: Bool) {
        if let renderInfo = components[PolySpatialComponents.RenderInfo.self],
                renderInfo.meshId == id || renderInfo.materialIds.contains(id) {
            // If the reference is preserved and we have the same number of materials, then we only
            // need to update the raycast target transforms (which are based on the mesh contents).
            if referencePreserved,
                let mesh = PolySpatialRealityKit.instance.TryGetMeshForId(id),
                let model = self.model,
                mesh.expectedMaterialCount == model.materials.count {

                updateRaycastTargetTransforms()
            } else {
                updateModelComponent()
            }
        }
        for (componentId, collisionShape) in collisionShapes {
            if collisionShape.info.meshId == id {
                updateMeshCollisionShape(componentId, collisionShape.info)
            }
        }
    }

    func setParent(_ parent: Entity?, preservingWorldTransform: Bool = false) {
        super.setParent(parent, preservingWorldTransform: preservingWorldTransform)

        // If we had previously inherited a sorting group, we need to clear it out.
        PolySpatialRealityKit.instance.clearInheritedSortingGroupRecursively(self)

        // Add ourselves and our descendants to the parent's sorting group, if it includes descendants.
        if let sortGroupInfo = parent?.components[PolySpatialComponents.ModelSortGroupInfo.self],
            let component = sortGroupInfo.sortGroupComponentOverride,
            sortGroupInfo.overrideAppliesToDescendants {

            PolySpatialRealityKit.instance.setSortingGroupRecursively(
                sortGroupInfo.overrideSortGroupEntityId,
                self,
                component.group,
                component.order,
                true,
                false)
        }
    }

    func setTransform(_ transform: Transform) {
        let wasMirrored = isMirrored

        components.set(transform)
        if wasMirrored != isMirrored && components.has(PolySpatialComponents.RenderInfo.self) {
            updateModelComponent()
        }
    }

    func updateModelComponent() {
        let ric = self.components[PolySpatialComponents.RenderInfo.self]! as PolySpatialComponents.RenderInfo
        let meshAsset = PolySpatialRealityKit.instance.tryGetMeshAssetForId(ric.meshId)
        let newMesh: MeshResource

        // I initially tried to use the original (shared, unblended) mesh for the case where we have blend shapes but
        // all the weights are zero (which seems like it would be common).  However, this causes the visionOS simulator
        // to crash.  Basically, it seems we can't switch to a different mesh once we've set a ModelComponent with
        // a skinned mesh.
        // TODO (LXR-3550): File a repro case with Apple.
        if let blendedMeshInstance = components[PolySpatialComponents.BlendedMeshInstance.self],
                blendedMeshInstance.asset === meshAsset, blendedMeshInstance.version == meshAsset?.version {
            newMesh = blendedMeshInstance.mesh
        } else if let currentMeshAsset = meshAsset, currentMeshAsset.blendShapes.count > 0 {
            let blendedMeshInstance = currentMeshAsset.createBlendedMeshInstance(blendLocalBounds!)
            components.set(blendedMeshInstance)
            newMesh = blendedMeshInstance.mesh
        } else {
            components.remove(PolySpatialComponents.BlendedMeshInstance.self)
            newMesh = ric.mesh
        }

        var castShadows = ric.castShadows

        // create or update components, carve out a special exception for entities affected by video so we don't overwrite the video material.
        if self.components.has(PolySpatialComponents.UnityVideoPlayer.self) {
            self.updateVideoPlayerMesh(newMesh)
        } else if components.has(PolySpatialComponents.StaticBatchElementInfo.self) {
            // If we're part of a static batch, the batch will handle our rendering; we don't want a ModelComponent.
            components.remove(ModelComponent.self)
        } else {
            // Even if the mesh expects fewer materials than we have available, we still want to supply all of them in
            // case the mesh is replaced on the render thread before the ModelComponent is updated.  This prevents the
            // pink striped error material showing up for bake-to-mesh particles.
            let materials = (0..<max(ric.materialIds.count, newMesh.expectedMaterialCount)).map { index in
                index >= ric.materialIds.count ?
                    PolySpatialRealityKit.invisibleMaterial :
                    getMaterialForID(ric.materialIds[index], ric, &castShadows)
            }
            var modelComponent = ModelComponent(mesh: newMesh, materials: materials)
            modelComponent.boundsMargin = ric.boundsMargin
            self.components.set(modelComponent)
        }

        setCastShadows(castShadows)

        // Special handling for raycast targets, which require double backing components: a child to hold the
        // shared raycastTargetCollisionComponent (with a transform to move the unit cube to the mesh bounds) and a
        // grandchild to hold the actual ModelComponent (with a transform that reverses the unit cube transform).
        if raycastTarget {
            let raycastTargetBackingEntity: PolySpatialEntity
            let grandchildEntity: PolySpatialEntity
            if let existingRaycastTargetBackingEntity = self.raycastTargetBackingEntity {
                raycastTargetBackingEntity = existingRaycastTargetBackingEntity
                grandchildEntity = raycastTargetBackingEntity.raycastTargetBackingEntity!
            } else {
                raycastTargetBackingEntity = .init(unityId)
                raycastTargetBackingEntity.setParent(self)
                raycastTargetBackingEntity.components.set(PolySpatialEntity.raycastTargetCollisionComponent)

                grandchildEntity = .init(unityId)
                grandchildEntity.setParent(raycastTargetBackingEntity)
                raycastTargetBackingEntity.raycastTargetBackingEntity = grandchildEntity

                self.raycastTargetBackingEntity = raycastTargetBackingEntity
            }
            // Move the model, etc. from this entity to the grandchild.
            moveComponentToEntity(ModelComponent.self, grandchildEntity)
            moveComponentToEntity(DynamicLightShadowComponent.self, grandchildEntity)
            updateRaycastTargetTransforms()

        } else {
            disposeRaycastTargetBackingEntity()
        }
    }

    func setCastShadows(_ castShadows: Bool) {
        if castShadows {
            components.remove(DynamicLightShadowComponent.self)
        } else {
            components.set(DynamicLightShadowComponent(castsShadow: false))
        }
    }

    func moveComponentToEntity<T>(_ type: T.Type, _ entity: Entity) where T: Component {
        if let component = self.components[type] {
            self.components.remove(type)
            entity.components.set(component)
        } else {
            entity.components.remove(type)
        }
    }

    func registerMeshes() {
        if let renderInfo = components[PolySpatialComponents.RenderInfo.self] {
            PolySpatialRealityKit.instance.RegisterEntityWithMeshOrMaterial(renderInfo.meshId, self)
        }
        for collisionShape in collisionShapes.values {
            PolySpatialRealityKit.instance.RegisterEntityWithMeshOrMaterial(collisionShape.info.meshId, self)
        }
    }

    func unregisterMeshesAndMaterials() {
        unregisterMeshes()

        if let renderInfo = components[PolySpatialComponents.RenderInfo.self] {
            for materialId in renderInfo.materialIds {
                PolySpatialRealityKit.instance.UnregisterEntityWithMeshOrMaterial(materialId, self)
            }
        }
    }

    func unregisterMeshes() {
        if let renderInfo = components[PolySpatialComponents.RenderInfo.self] {
            PolySpatialRealityKit.instance.UnregisterEntityWithMeshOrMaterial(renderInfo.meshId, self)
        }
        for collisionShape in collisionShapes.values {
            PolySpatialRealityKit.instance.UnregisterEntityWithMeshOrMaterial(collisionShape.info.meshId, self)
        }
    }

    func removeSelfAsRenderInfoTextureObserver() {
        if let renderInfo = components[PolySpatialComponents.RenderInfo.self] {
            PolySpatialRealityKit.instance.RemoveTextureObserver(renderInfo.lightmapColorId, self)
            PolySpatialRealityKit.instance.RemoveTextureObserver(renderInfo.lightmapDirId, self)
            for reflectionProbe in renderInfo.reflectionProbes {
                PolySpatialRealityKit.instance.RemoveTextureObserver(reflectionProbe.textureAssetId, self)
            }
        }
    }

    // If this Entity doesn't already have RenderInfo/ModelComponent, add them.  Then
    // update the mesh and materials.
    func setRenderMeshAndMaterials(
        _ meshId: PolySpatialAssetID,
        _ materialIds: [PolySpatialAssetID],
        _ castShadows: Bool = true,
        _ boundsMargin: Float = 0,
        _ lightmap: PolySpatialLightmapRenderData? = nil,
        _ lightProbe: PolySpatialLightProbeData? = nil,
        _ reflectionProbes: [PolySpatialReflectionProbeData]? = nil) {

        if !meshId.isValid && materialIds.isEmpty {
            // this Entity had a MeshRenderer removed.  Clean ourselves up.
            setRenderInfo(nil)
            return
        }

        // create or update components
        let renderInfo = PolySpatialComponents.RenderInfo(meshId, materialIds, castShadows, boundsMargin)
        if let lightmap {
            let lightmapData = PolySpatialRealityKit.instance.lightmapData[Int(lightmap.index)]
            renderInfo.lightmapColorId = lightmapData.lightmapColor
            renderInfo.lightmapDirId = lightmapData.lightmapDir
            renderInfo.lightmapScaleOffset = ConvertPolySpatialVec4VectorToFloat4(lightmap.scaleOffset)
        }
        if let lightProbeData = lightProbe {
            renderInfo.lightProbeCoefficients[0] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shAr)
            renderInfo.lightProbeCoefficients[1] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shAg)
            renderInfo.lightProbeCoefficients[2] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shAb)
            renderInfo.lightProbeCoefficients[3] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shBr)
            renderInfo.lightProbeCoefficients[4] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shBg)
            renderInfo.lightProbeCoefficients[5] = ConvertPolySpatialVec4VectorToFloat4(lightProbeData.shBb)
            renderInfo.lightProbeCoefficients[6] = simd_float4(
                ConvertPolySpatialVec3VectorToFloat3(lightProbeData.shC), 0.0)
        }
        if let reflectionProbeData = reflectionProbes {
            renderInfo.reflectionProbes = reflectionProbeData
        }

        setRenderInfo(renderInfo)
    }

    // Sets or clears the render info component, updating the model if appropriate and registering as a listener
    // for changes to meshes/materials/textures.
    func setRenderInfo(_ renderInfo: PolySpatialComponents.RenderInfo?) {
        unregisterMeshesAndMaterials()
        removeSelfAsRenderInfoTextureObserver()

        guard let renderInfo = renderInfo else {
            // this Entity had a MeshRenderer removed.  Clean ourselves up.
            self.components.remove(ModelComponent.self)
            self.components.remove(PolySpatialComponents.RenderInfo.self)

            // Make sure we also dispose of the raycast backing entity to which may have moved the ModelComponent.
            disposeRaycastTargetBackingEntity()

            // Re-register meshes in case we have collision meshes.
            registerMeshes()
            return
        }
        self.components.set(renderInfo)

        // Register that we are using our mesh (obtained from the RenderInfo component) and each of our materials.
        registerMeshes()
        for materialId in renderInfo.materialIds {
            PolySpatialRealityKit.instance.RegisterEntityWithMeshOrMaterial(materialId, self)
        }

        // Register for lighting texture changes.
        PolySpatialRealityKit.instance.AddTextureObserver(renderInfo.lightmapColorId, self)
        PolySpatialRealityKit.instance.AddTextureObserver(renderInfo.lightmapDirId, self)
        for reflectionProbe in renderInfo.reflectionProbes {
            PolySpatialRealityKit.instance.AddTextureObserver(reflectionProbe.textureAssetId, self)
        }

        updateModelComponent()
    }

    // Updates the entity's blended mesh instace with its current shape weights and joint transforms.
    func updateBlendedMeshInstance() {
        if let blendedMeshInstance = components[PolySpatialComponents.BlendedMeshInstance.self] {
            blendedMeshInstance.update(self)
        }
    }

    // Sets the masked hover colors.  When using the masked shader and the HoverEffectComponent, the "normal"
    // color property provided here will be replaced by the hover color when the object is hovered.  This allows us
    // to replicate Unity's behavior for Selectables: they only transition to Highlighted from Normal (not from
    // Pressed or Selected).
    func setMaskedHoverColors(_ normalColor: CGColor, _ hoverColor: CGColor) {
        components.set(PolySpatialComponents.MaskedHoverColors(normalColor, hoverColor))

        // Update the model component (if any) since our shader parameters will have changed.
        if components.has(PolySpatialComponents.RenderInfo.self) {
            updateModelComponent()
        }
    }

    // Clears any previously set masked hover colors.
    func clearMaskedHoverColors() {
        components.remove(PolySpatialComponents.MaskedHoverColors.self)

        // Update the model component (if any) since our shader parameters will have changed.
        if components.has(PolySpatialComponents.RenderInfo.self) {
            updateModelComponent()
        }
    }

    // Sets the masked renderer state to apply to materials for this entity.  Note that this does not call
    // updateModelComponent, which is normally necessary to update the materials.  That's because we expect to
    // call setRenderMeshAndMaterials immediately after this, and that function will call updateModelComponent.
    func setMaskedRendererInfo(
        _ color: CGColor, _ mainTextureId: PolySpatialAssetID, _ maskTextureId: PolySpatialAssetID,
        _ maskUVTransform: float4x4, _ maskingOperation: PolySpatialMaskingOperation = .visibleInsideMask,
        _ maskAlphaCutoff: Float = 0.2) {

        removeSelfAsMaskedRendererTextureObserver()

        PolySpatialRealityKit.instance.AddTextureObserver(mainTextureId, self)
        PolySpatialRealityKit.instance.AddTextureObserver(maskTextureId, self)
        components.set(PolySpatialComponents.MaskedRendererInfo(
            color, mainTextureId, maskTextureId, maskUVTransform, maskingOperation, maskAlphaCutoff))
    }

    // Clears the masked renderer state.  Again, note that this does not actually update the ModelComponent.
    // We expect this call to be followed by a call to setRenderMeshAndMaterials with an invalid meshId.
    func clearMaskedRendererInfo() {
        removeSelfAsMaskedRendererTextureObserver()

        components.remove(PolySpatialComponents.MaskedRendererInfo.self)
    }

    func removeSelfAsMaskedRendererTextureObserver() {
        if let maskedRendererInfo = components[PolySpatialComponents.MaskedRendererInfo.self] {
            PolySpatialRealityKit.instance.RemoveTextureObserver(maskedRendererInfo.mainTextureId, self)
            PolySpatialRealityKit.instance.RemoveTextureObserver(maskedRendererInfo.maskTextureId, self)
        }
    }

    func removeSelfAsImageBasedLightTextureObserver() {
        if let imageBasedLightInfo = components[PolySpatialComponents.ImageBasedLightInfo.self] {
            PolySpatialRealityKit.instance.RemoveTextureObserver(imageBasedLightInfo.sourceAssetId0, self)
            PolySpatialRealityKit.instance.RemoveTextureObserver(imageBasedLightInfo.sourceAssetId1, self)
        }
    }

    func setImageBasedLightInfo(
        _ sourceAssetId0: PolySpatialAssetID,
        _ sourceAssetId1: PolySpatialAssetID,
        _ blend: Float,
        _ inheritsRotation: Bool,
        _ intensityExponent: Float) {

        removeSelfAsImageBasedLightTextureObserver()

        PolySpatialRealityKit.instance.AddTextureObserver(sourceAssetId0, self)
        PolySpatialRealityKit.instance.AddTextureObserver(sourceAssetId1, self)

        components.set(PolySpatialComponents.ImageBasedLightInfo(
            sourceAssetId0,
            sourceAssetId1,
            blend,
            inheritsRotation,
            intensityExponent))
        updateImageBasedLightComponent()
    }

    func clearImageBasedLightInfo() {
        removeSelfAsImageBasedLightTextureObserver()

        components.remove(PolySpatialComponents.ImageBasedLightInfo.self)
        updateImageBasedLightComponent()
    }

    func updateImageBasedLightComponent() {
        guard let info = components[PolySpatialComponents.ImageBasedLightInfo.self] else {
            components.remove(ImageBasedLightComponent.self)
            return
        }
        let source: ImageBasedLightComponent.Source
        if info.sourceAssetId0.isValid {
            if info.sourceAssetId1.isValid {
                let environmentResource0 =
                    PolySpatialRealityKit.instance.GetTextureAssetForId(info.sourceAssetId0).getEnvironmentResource()
                let environmentResource1 =
                    PolySpatialRealityKit.instance.GetTextureAssetForId(info.sourceAssetId1).getEnvironmentResource()
                source = switch info.blend {
                    case 0.0: .single(environmentResource0)
                    case 1.0: .single(environmentResource1)
                    default: .blend(environmentResource0, environmentResource1, info.blend)
                }
            } else {
                source = .single(
                    PolySpatialRealityKit.instance.GetTextureAssetForId(info.sourceAssetId0).getEnvironmentResource())
            }
        } else if info.sourceAssetId1.isValid {
            source = .single(
                PolySpatialRealityKit.instance.GetTextureAssetForId(info.sourceAssetId1).getEnvironmentResource())
        } else {
            source = .none
        }
        var imageBasedLight = ImageBasedLightComponent(source: source, intensityExponent: info.intensityExponent)
        imageBasedLight.inheritsRotation = info.inheritsRotation
        components.set(imageBasedLight)
    }

    func setAlignmentMarkerInfo(_ data: PolySpatialAlignmentMarkerData) {
        removeSelfAsAlignmentMarkerTextureObserver()

        PolySpatialRealityKit.instance.AddTextureObserver(data.textureAssetId, self)

        components.set(PolySpatialComponents.AlignmentMarkerInfo(data))
        updateAlignmentMarkerTracker()
    }

    func clearAlignmentMarkerInfo() {
        removeSelfAsAlignmentMarkerTextureObserver()

        components.remove(PolySpatialComponents.AlignmentMarkerInfo.self)
        updateAlignmentMarkerTracker()
    }

    func updateAlignmentMarkerTracker() {
        clearAlignmentMarkerTracker()
        guard let info = components[PolySpatialComponents.AlignmentMarkerInfo.self],
              info.data.textureAssetId.isValid, ImageTrackingProvider.isSupported else {
            return
        }
        let imageTrackingProvider = ImageTrackingProvider(referenceImages: [.init(
            cgimage: PolySpatialRealityKit.instance.GetTextureAssetForId(info.data.textureAssetId).getCGImage(),
            physicalSize: .init(width: Double(info.data.size.x), height: Double(info.data.size.y)))])
        components.set(PolySpatialComponents.AlignmentMarkerTracker(Task {
            let session = ARKitSession()
            do {
                try await session.run([imageTrackingProvider])
            } catch {
                return
            }
            for await update in imageTrackingProvider.anchorUpdates {
                if update.event != .removed {
                    let localToWorldTransform = update.anchor.originFromAnchorTransform *
                        simd_float4x4(scale: update.anchor.estimatedScaleFactor)
                    Task { @MainActor in
                        guard let volume = PolySpatialRealityKit.instance.tryGetVolume(unityId) else {
                            return
                        }
                        volume.alignmentMarkerStates[unityId] = .init(
                            info.data,
                            localToWorldTransform * simd_inverse(self.transformMatrix(relativeTo: volume.root)))
                    }
                }
            }
        }))
    }

    func clearAlignmentMarkerTracker() {
        if let tracker = components[PolySpatialComponents.AlignmentMarkerTracker.self] {
            tracker.task.cancel()
            components.remove(PolySpatialComponents.AlignmentMarkerTracker.self)

            if let volume = PolySpatialRealityKit.instance.tryGetVolume(unityId) {
                volume.alignmentMarkerStates.removeValue(forKey: unityId)
            }
        }
    }

    func removeSelfAsAlignmentMarkerTextureObserver() {
        if let alignmentMarkerInfo = components[PolySpatialComponents.AlignmentMarkerInfo.self] {
            PolySpatialRealityKit.instance.RemoveTextureObserver(alignmentMarkerInfo.data.textureAssetId, self)
        }
    }

    func setStaticBatchElementInfo(_ rootId: PolySpatialInstanceID) {
        components.set(PolySpatialComponents.StaticBatchElementInfo(rootId))

        let rootEntity = StaticBatchManager.instance.getStaticBatchRootEntity(rootId)!
        var staticBatchRootInfo = rootEntity.components[PolySpatialComponents.StaticBatchRootInfo.self] as
            PolySpatialComponents.StaticBatchRootInfo?
        if staticBatchRootInfo == nil {
            staticBatchRootInfo = .init()
            staticBatchRootInfo!.entity.setParent(rootEntity)
            rootEntity.components.set(staticBatchRootInfo!)
        }
        staticBatchRootInfo!.elements.insert(self)

        StaticBatchManager.instance.dirtyStaticBatchRootIds.insert(rootId)
    }

    func clearStaticBatchElementInfo() {
        guard let staticBatchElementInfo = components[PolySpatialComponents.StaticBatchElementInfo.self] as
            PolySpatialComponents.StaticBatchElementInfo? else {
            return
        }
        components.remove(PolySpatialComponents.StaticBatchElementInfo.self)

        guard let rootEntity = StaticBatchManager.instance.getStaticBatchRootEntity(staticBatchElementInfo.rootId),
            let staticBatchRootInfo = rootEntity.components[PolySpatialComponents.StaticBatchRootInfo.self] as
                PolySpatialComponents.StaticBatchRootInfo? else {
            return
        }

        staticBatchRootInfo.elements.remove(self)
        if staticBatchRootInfo.elements.isEmpty {
            staticBatchRootInfo.clearContents()
            staticBatchRootInfo.entity.removeFromParent()
            rootEntity.components.remove(PolySpatialComponents.StaticBatchRootInfo.self)
            StaticBatchManager.instance.dirtyStaticBatchRootIds.remove(staticBatchElementInfo.rootId)

        } else {
            StaticBatchManager.instance.dirtyStaticBatchRootIds.insert(staticBatchElementInfo.rootId)
        }
    }

    func setRendererSortingGroup(
        _ sortGroupEntityId: PolySpatialInstanceID,
        _ sortGroup: ModelSortGroup,
        _ sortOrder: Int32,
        _ appliesToDescendants: Bool,
        _ isAncestor: Bool) {

        if let info = components[PolySpatialComponents.ModelSortGroupInfo.self], info.sortGroupComponentOverride != nil {
            let sortGroupEntity = PolySpatialRealityKit.instance.GetEntity(sortGroupEntityId)
            PolySpatialRealityKit.instance.LogWarning(
                "\(self.name) is either already a member of a different sort group or has been referenced " +
                "twice in the same sorting group - membership to the custom sort group defined on " +
                "\(sortGroupEntity.name) will not be applied.")
            return
        }

        setModelSortGroupOverride(
            .init(group: sortGroup, order: sortOrder), sortGroupEntityId, appliesToDescendants, isAncestor)
    }

    func clearRendererSortingGroup() {
        setModelSortGroupOverride(nil)
    }

    func setModelSortGroupBase(_ component: ModelSortGroupComponent?) {
        var info = components[PolySpatialComponents.ModelSortGroupInfo.self] ?? .init()
        info.sortGroupComponentBase = component
        setModelSortGroupInfo(info)
    }

    func setModelSortGroupOverride(
        _ component: ModelSortGroupComponent?,
        _ sortGroupEntityId: PolySpatialInstanceID = PolySpatialInstanceID.none,
        _ appliesToDescendants: Bool = false,
        _ isAncestor: Bool = false) {

        var info = components[PolySpatialComponents.ModelSortGroupInfo.self] ?? .init()

        // Remove from the old sort group set, if any.
        if info.overrideSortGroupEntityId.isValid {
            PolySpatialRealityKit.instance.customSortGroup[info.overrideSortGroupEntityId, default: []].remove(unityId)
            if PolySpatialRealityKit.instance.customSortGroup[info.overrideSortGroupEntityId]!.isEmpty {
                PolySpatialRealityKit.instance.customSortGroup.removeValue(forKey: info.overrideSortGroupEntityId)
            }
        }

        // And add to the new, if any.
        if sortGroupEntityId.isValid {
            PolySpatialRealityKit.instance.customSortGroup[sortGroupEntityId, default: []].insert(unityId)
        }

        info.sortGroupComponentOverride = component
        info.overrideSortGroupEntityId = sortGroupEntityId
        info.overrideAppliesToDescendants = appliesToDescendants
        info.overrideIsAncestor = isAncestor
        setModelSortGroupInfo(info)
    }

    func setModelSortGroupInfo(_ info: PolySpatialComponents.ModelSortGroupInfo?) {
        if let infoComponent = info, let sortGroupComponent = infoComponent.sortGroupComponent {
            components.set(infoComponent)
            components.set(sortGroupComponent)
        } else {
            components.remove(PolySpatialComponents.ModelSortGroupInfo.self)
            components.remove(ModelSortGroupComponent.self)
        }
        updateBackingEntityComponents(ModelSortGroupComponent.self)
    }

    func disposeBackingEntities() {
        if let raycastTargetBackingEntity = self.raycastTargetBackingEntity {
            raycastTargetBackingEntity.dispose()
            self.raycastTargetBackingEntity = nil
        }
        if let skinnedBackingEntity = self.skinnedBackingEntity {
            skinnedBackingEntity.dispose()
            self.skinnedBackingEntity = nil
        }
        if let particleBackingEntity = self.particleBackingEntity {
            particleBackingEntity.dispose()
            self.particleBackingEntity = nil
        }
        if let trailBackingEntity = self.trailBackingEntity {
            trailBackingEntity.dispose()
            self.trailBackingEntity = nil
        }
    }

    // Synchronizes all synchronized component types to a single backing entity.
    func updateBackingEntityComponents(_ backingEntity: PolySpatialEntity, _ removeExisting: Bool = true) {
        updateBackingEntityComponent(backingEntity, ModelSortGroupComponent.self, removeExisting)
        updateBackingEntityComponent(backingEntity, ImageBasedLightReceiverComponent.self, removeExisting)
        updateBackingEntityComponent(backingEntity, EnvironmentLightingConfigurationComponent.self, removeExisting)
        updateBackingEntityComponent(backingEntity, GroundingShadowComponent.self, removeExisting)
        updateBackingEntityComponent(backingEntity, HoverEffectComponent.self, removeExisting)
    }

    // Synchronizes a single component type to all backing entities.
    func updateBackingEntityComponents<T>(_ type: T.Type, _ removeExisting: Bool = true) where T: Component {
        if let raycastTargetBackingEntity = self.raycastTargetBackingEntity {
            updateBackingEntityComponent(raycastTargetBackingEntity, type, removeExisting)
        }
        if let skinnedBackingEntity = self.skinnedBackingEntity {
            updateBackingEntityComponent(skinnedBackingEntity, type, removeExisting)
        }
        if let particleBackingEntity = self.particleBackingEntity {
            updateBackingEntityComponent(particleBackingEntity, type, removeExisting)
        }
        if let trailBackingEntity = self.trailBackingEntity {
            updateBackingEntityComponent(trailBackingEntity, type, removeExisting)
        }
        if let staticBatchElementInfo = components[PolySpatialComponents.StaticBatchElementInfo.self] as
                PolySpatialComponents.StaticBatchElementInfo? {
            // Request a static batch root update.  The update will merge the elements' synchronized components.
            StaticBatchManager.instance.dirtyStaticBatchRootIds.insert(staticBatchElementInfo.rootId)
        }
    }

    // Synchronizes a single component type to a single backing entity.
    func updateBackingEntityComponent<T>(
        _ backingEntity: PolySpatialEntity, _ type: T.Type, _ removeExisting: Bool = true) where T: Component {

        if let component = components[type] {
            backingEntity.components.set(component)
        } else if removeExisting {
            backingEntity.components.remove(type)
        }
        backingEntity.updateBackingEntityComponents(type, removeExisting)
    }

    func getMaterialForID(
        _ id: PolySpatialAssetID, _ renderInfo: PolySpatialComponents.RenderInfo,
        _ castShadows: inout Bool) -> Material {

        let material = PolySpatialRealityKit.instance.GetMaterialForID(id, isMirrored)

            if let instance = ShaderManager.instance.shaderGraphInstances[id],
                var shaderGraphMaterial = material as? ShaderGraphMaterial {

                castShadows = castShadows && instance.castShadows

                if instance.hasVolumeToWorldTextureProperty,
                        let volume = PolySpatialRealityKit.instance.tryGetVolume(unityId) {
                    try! shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kVolumeToWorldTextureHandle,
                        value: .textureResource(volume.volumeToWorldTextureResource))
                }

                if instance.hasObjectBoundsProperties {
                    let bounds = PolySpatialRealityKit.instance.GetMeshForId(renderInfo.meshId).bounds
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kObjectBoundsCenterHandle,
                        value: .simd3Float(bounds.center))

                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kObjectBoundsExtentsHandle,
                        value: .simd3Float(bounds.extents))
                }

                if instance.hasLightmapProperties {
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kLightmapHandle,
                        value: .textureResource(PolySpatialRealityKit.instance.GetTextureAssetForId(
                            renderInfo.lightmapColorId).texture.resource))

                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kLightmapIndHandle,
                        value: .textureResource(PolySpatialRealityKit.instance.GetTextureAssetForId(
                            renderInfo.lightmapDirId).texture.resource))

                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kLightmapSTHandle,
                        value: .simd4Float(renderInfo.lightmapScaleOffset))

                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kLightmapOnHandle,
                        value: .bool(renderInfo.lightmapColorId.isValid))
                }

                if instance.hasLightProbeProperties {
                    for (index, handle) in ShaderManager.kLightProbeHandles.enumerated() {
                        try? shaderGraphMaterial.setParameter(
                            handle: handle, value: .simd4Float(renderInfo.lightProbeCoefficients[index]))
                    }
                }

                if instance.hasReflectionProbeProperties {
                    for i in 0..<ShaderManager.kReflectionProbeCount {
                        let reflectionProbe = (i < renderInfo.reflectionProbes.count) ?
                            renderInfo.reflectionProbes[i] : .init()
                        try? shaderGraphMaterial.setParameter(
                            handle: ShaderManager.kReflectionProbeTextureHandles[i],
                            value: .textureResource(
                                PolySpatialRealityKit.instance.GetTextureAssetForId(
                                    reflectionProbe.textureAssetId).texture.resource))
                        try? shaderGraphMaterial.setParameter(
                            handle: ShaderManager.kReflectionProbeWeightHandles[i],
                            value: .float(reflectionProbe.weight))
                    }
                }

                if let maskedRendererInfo = components[PolySpatialComponents.MaskedRendererInfo.self] {
                    let colorValue = MaterialParameters.Value.color(maskedRendererInfo.color)
                    try? shaderGraphMaterial.setParameter(handle: ShaderManager.kColorHandle, value: colorValue)
                    if let maskedHoverColors = components[PolySpatialComponents.MaskedHoverColors.self],
                            maskedRendererInfo.color.approximatelyEqual(maskedHoverColors.normalColor) {
                        // Set the hover color to the one configured only if the base color is equal to the
                        // Selectable's "normal" color: this ensures that the hover transition doesn't happen if
                        // the Selectable is in the Pressed or Selected states.
                        try? shaderGraphMaterial.setParameter(
                            handle: ShaderManager.kHoverColorHandle, value: .color(maskedHoverColors.hoverColor))
                    } else {
                        // Default to hover color same as base color.
                        try? shaderGraphMaterial.setParameter(
                            handle: ShaderManager.kHoverColorHandle, value: colorValue)
                    }
                    if maskedRendererInfo.mainTextureId.isValid {
                        try? shaderGraphMaterial.setParameter(
                            handle: ShaderManager.kMainTexHandle,
                            value: .textureResource(
                                PolySpatialRealityKit.instance.GetTextureAssetForId(
                                    maskedRendererInfo.mainTextureId).texture.resource))
                    }
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kMaskTextureHandle,
                        value: .textureResource(
                            PolySpatialRealityKit.instance.GetTextureAssetForId(
                                maskedRendererInfo.maskTextureId).texture.resource))
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kUVTransformHandle,
                        value: .float4x4(maskedRendererInfo.maskUVTransform))
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kMaskOperationHandle,
                        value: .float(Float(maskedRendererInfo.maskingOperation.rawValue)))
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kAlphaCutoffHandle,
                        value: .float(maskedRendererInfo.maskAlphaCutoff))
                    try? shaderGraphMaterial.setParameter(
                        handle: ShaderManager.kHasGammaSpaceVertexColorsHandle, value: .float(1))
                }

                return shaderGraphMaterial
            }

        return material
    }

    // Updates the transforms of the backing entities used for raycast targets: the child, which transforms the unit
    // cube into the mesh bounds, and the grandchild, which reverses that transform (so that it doesn't affect the
    // ModelComponent).  We perform this workaround in order to avoid creating a new ShapeResource every frame when the
    // mesh changes, which drastically affects the update rate (reported to Apple as FB13566439).  If and when they fix
    // that issue, we can return to simply creating a new ShapeResource in a CollisionComponent on the owning entity
    // rather than the backing child/grandchild.
    func updateRaycastTargetTransforms() {
        guard let raycastTargetBackingEntity, let model else {
            return
        }
        let grandchildEntity = raycastTargetBackingEntity.raycastTargetBackingEntity!

        // The forward transform transforms the unit cube to the mesh bounds.
        let bounds = model.mesh.bounds
        let epsilon = 0.00001 // Avoid division by zero.
        let scale = max(bounds.max - bounds.min, .init(epsilon))
        raycastTargetBackingEntity.transform.scale = scale
        raycastTargetBackingEntity.transform.translation = bounds.center

        // The reverse transform cancels out the scale/translation.
        grandchildEntity.transform.scale = 1 / scale
        grandchildEntity.transform.translation = -bounds.center / scale
    }

    // Removes and disposes of the raycast target backing entity (and its backing entities) if present.
    func disposeRaycastTargetBackingEntity() {
        if let raycastTargetBackingEntity = self.raycastTargetBackingEntity {
            raycastTargetBackingEntity.dispose()
            self.raycastTargetBackingEntity = nil
        }
    }

    func createOrUpdateCollisionShape(_ info: PolySpatialColliderData) {
        // From RealityFoundation Swift Header
        /// Note the following when considering applying a non-uniform scale to an entity:
        /// - Non-uniform scaling is applicable only to box, convex mesh and triangle mesh collision shapes.
        /// - Non-uniform scaling is not supported for all other types of collision shapes. In this case the scale.x
        /// value is duplicated to the scale's y and z components as well to force scale uniformity based on the x component.
        /// - If the entity has a non-uniform scale assigned to its transform then that entity should not
        /// have any descendants assigned that contain rotations in their transforms. A good rule of thumb is to
        /// assign the non-uniform scale to the entity that has the collision shape, and avoid adding children below
        /// that entity.

        let id = info.colliderId

        let worldScale = self.scale(relativeTo: nil)

        switch info.shape {
        case .box:
            // box supports non-uniform scaling so you don't have to do the juggle with scale.max and ratios
            let offset = ConvertPolySpatialVec3PositionToFloat3(info.center)
            let size = ConvertPolySpatialVec3VectorToFloat3(info.size)

            if let shape = collisionShapes[id] {
                let previousInfo = shape.info
                if previousInfo.size.approximatelyEqual(info.size) {
                    if !previousInfo.center.approximatelyEqual(info.center) {
                        // if only offset changed, save time by only updating offset
                        let previousOffset = ConvertPolySpatialVec3PositionToFloat3(previousInfo.center)
                        setCollisionShape(
                            id, info, shape.resource!.offsetBy(translation: offset - previousOffset), worldScale)
                    }
                    break
                }
            }

            setCollisionShape(
                id, info, ShapeResource.generateBox(size: size).offsetBy(translation: offset), worldScale)

        case .sphere:
            let placement = calcCollisionPlacement(info, worldScale)

            if let shape = collisionShapes[id] {
                let previousInfo = shape.info
                if shape.worldScale.approximatelyEqual(worldScale) && previousInfo.size.approximatelyEqual(info.size) {
                    if !previousInfo.center.approximatelyEqual(info.center) {
                        // if only offset changed, save time by only updating offset
                        let previousPlacement = calcCollisionPlacement(previousInfo, worldScale)
                        let offset = placement.offset - previousPlacement.offset
                        setCollisionShape(id, info, shape.resource!.offsetBy(translation: offset), worldScale)
                    }
                    break
                }
            }

            setCollisionShape(
                id, info,
                ShapeResource.generateSphere(radius: placement.radius).offsetBy(translation: placement.offset),
                worldScale)

        case .capsule:
            let placement = calcCollisionPlacement(info, worldScale)

            if let shape = collisionShapes[id] {
                let previousInfo = shape.info
                if shape.worldScale.approximatelyEqual(worldScale) && previousInfo.size.approximatelyEqual(info.size) {
                    if !previousInfo.center.approximatelyEqual(info.center) {
                        // if only offset changed, save time by only updating offset
                        let previousPlacement = calcCollisionPlacement(previousInfo, shape.worldScale)
                        let offset = placement.offset - previousPlacement.offset
                        setCollisionShape(id, info, shape.resource!.offsetBy(translation: offset), worldScale)
                    }
                    break
                }
            }

            // For whatever reason height just doesn't need any scaling... Don't look at me, I didn't make realitykit.
            let height = info.size.y

            setCollisionShape(
                id, info,
                ShapeResource.generateCapsule(
                    height: height, radius: placement.radius).offsetBy(translation: placement.offset),
                worldScale)

        case .mesh:
            // Unity mesh collider does not support offset. Orientation and scale change are always okay.

            if let shape = collisionShapes[id], shape.info.meshId == info.meshId, shape.info.options == info.options {
                return
            }
            // Unregister meshes before (potentially) changing the mesh assignment.
            unregisterMeshes()

            setCollisionShape(id, info)
            if info.meshId.isValid {
                updateMeshCollisionShape(id, info)
            }

            // Re-register meshes now that we've updated the shape.
            registerMeshes()

        @unknown default:
            PolySpatialRealityKit.instance.LogError("Unsupported collider shape passed into provider.")
            return
        }
    }

    func destroyCollisionShape(_ id: PolySpatialComponentID) {
        guard let oldShape = collisionShapes[id] else {
            return
        }
        // If it's a mesh shape, we need to unregister the meshes before clearing.
        if oldShape.info.meshId.isValid {
            unregisterMeshes()
        }

        collisionShapes.removeValue(forKey: id)
        PolySpatialRealityKit.instance.dirtyCollisionObservers.insert(self)

        // Now re-register the remaining meshes.
        if oldShape.info.meshId.isValid {
            registerMeshes()
        }
    }

    func updateMeshCollisionShape(_ id: PolySpatialComponentID, _ info: PolySpatialColliderData) {
        let meshAsset = PolySpatialRealityKit.instance.getMeshAssetForId(info.meshId)
        let mesh = meshAsset.mesh

        // If mesh is uninitalized it will have 0 boundingRadius. Is there a better way to check this?
        let isMeshInitialized = mesh.bounds.boundingRadius > 0
        if !isMeshInitialized {
            return
        }
        let isConvex = 0 != (info.options & PolySpatialColliderOptions.convex.rawValue)

        // For testing, we need to generate the convex shapes synchronously so that they'll be available on the very
        // next frame.  Static meshes can only be created asynchronously.
        if isConvex && PolySpatialRealityKit.instance.runtimeFlags.contains(.updateMeshesSynchronously) {
            setCollisionShape(id, info, meshAsset.convexShape)
            return
        }

        // When we obtain the result after asynchronous processing, we need to verify that the source data hasn't
        // been removed or changed in the meantime.  To do this, we ensure that the collision shape still exists
        // and refers to the same mesh ID and options, that the MeshAsset hasn't been replaced with something else
        // (such as a LowLevelMesh), and that the current version matches the one we started with.  If any of
        // these things change, a new asynchronous request will be kicked off, and we want to be sure that this
        // won't overwrite its results in the unlikely scenario that it returns afterwards.
        let oldMeshAsset = meshAsset
        let oldMeshVersion = oldMeshAsset.version
        Task { @MainActor in
            do {
                let resource = try await (isConvex ?
                    meshAsset.convexShapeFuture : meshAsset.staticMeshShapeFuture).value
                if let currentShape = collisionShapes[id], currentShape.info.meshId == info.meshId,
                        currentShape.info.options == info.options,
                        PolySpatialRealityKit.instance.tryGetMeshAssetForId(info.meshId) === oldMeshAsset,
                        oldMeshAsset.version == oldMeshVersion {
                    setCollisionShape(id, info, resource)
                }
            } catch {
                PolySpatialRealityKit.instance.Log("Failed to generate shape resource: \(error)")
            }
        }
    }

    func calcCollisionPlacement(_ info: PolySpatialColliderData, _ worldScale: SIMD3<Float>) -> (offset: simd_float3, radius: Float32) {
        // RealityKit uses the X scale to scale the sphere/capsle collider while unity uses the max scale component.
        // Can reliably replicate unity sphere/capsule collider radius by applying xToMaxRatio to sphere size
        let xToMaxRatio = worldScale.max() / worldScale.x
        let radius = info.size.x * xToMaxRatio

        // Offsets also must be scaled by the ratio of each scale component to the max scale component.
        let maxToComponentRatio = worldScale / worldScale.max()
        let offset = ConvertPolySpatialVec3PositionToFloat3(info.center) * xToMaxRatio * maxToComponentRatio

        return (offset, radius)
    }

    func updateCollisionComponent() {
        if collisionShapes.isEmpty {
            components.remove(CollisionComponent.self)
        } else {
            let shapes = collisionShapes.values.compactMap { $0.resource }
            components.set(CollisionComponent(
                shapes: shapes,
                mode: .trigger,
                collisionOptions: .static))
        }
    }

    private func setCollisionShape(
        _ id: PolySpatialComponentID, _ info: PolySpatialColliderData,
        _ resource: ShapeResource? = nil, _ worldScale: simd_float3 = .zero) {

        collisionShapes[id] = .init(info, resource, worldScale)
        PolySpatialRealityKit.instance.dirtyCollisionObservers.insert(self)
    }

    // Special handling for meshes with video materials - they need their uvs inverted to work with RK video materials.
    func updateVideoPlayerMesh(_ newMesh: MeshResource) {
        guard let videoComp = self.components[PolySpatialComponents.UnityVideoPlayer.self] as PolySpatialComponents.UnityVideoPlayer? else {
            return
        }

        let renderComp = self.components[PolySpatialComponents.RenderInfo.self]! as PolySpatialComponents.RenderInfo

        if videoComp.invertAndCacheMesh(newMesh, renderComp.meshId) {
            let modelComp = self.components[ModelComponent.self]! as ModelComponent
            components.set(ModelComponent(mesh: videoComp.meshAsset!, materials: modelComp.materials))
        }
    }
}
