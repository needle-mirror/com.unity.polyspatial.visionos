import RealityKit
import AVFoundation

class PolySpatialComponents {
    static func registerComponents() {
        InstanceRef.registerComponent()
        RenderInfo.registerComponent()
        MaskedRendererInfo.registerComponent()
        MaskedHoverColors.registerComponent()
        ImageBasedLightInfo.registerComponent()
        AlignmentMarkerInfo.registerComponent()
        AlignmentMarkerTracker.registerComponent()
        ModelSortGroupInfo.registerComponent()
        BlendedMeshInstance.registerComponent()
        UnityVideoPlayer.registerComponent()
        ParticleBackingEntity.registerComponent()
        TrailBackingEntity.registerComponent()
        SkinnedBackingEntity.registerComponent()
        RaycastTargetBackingEntity.registerComponent()
        StaticBatchElementInfo.registerComponent()
        StaticBatchRootInfo.registerComponent()
    }

    class InstanceRef: Component {
        public var unityId: PolySpatialInstanceID

        public init() {
            self.unityId = PolySpatialInstanceID.none
        }

        public init(_ unityId: PolySpatialInstanceID) {
            self.unityId = unityId
        }
    }

    @MainActor
    class RenderInfo: Component {
        enum MeshSource {
            case asset(PolySpatialAssetID)
            case resource(MeshResource)
        }
        public var meshSource: MeshSource = .asset(PolySpatialAssetID.invalidAssetId)
        public var materialIds: [PolySpatialAssetID] = []
        public var lightmapColorId: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId
        public var lightmapDirId: PolySpatialAssetID = PolySpatialAssetID.invalidAssetId
        public var lightmapScaleOffset: simd_float4 = .zero
        public var lightProbeCoefficients: [simd_float4] = [.zero, .zero, .zero, .zero, .zero, .zero, .zero]
        public var reflectionProbes: [PolySpatialReflectionProbeData] = []
        public var castShadows = true
        public var boundsMargin: Float = 0

        public var meshId: PolySpatialAssetID {
            switch meshSource {
                case let .asset(assetId): assetId
                case .resource: PolySpatialAssetID.invalidAssetId
            }
        }

        public var mesh: MeshResource {
            switch meshSource {
                case let .asset(assetId): PolySpatialRealityKit.instance.GetMeshForId(assetId)
                case let .resource(resource): resource
            }
        }

        public var staticBatchKey: StaticBatchManager.StaticBatchKey {
            .init(lightmapColorId, lightmapDirId, lightmapScaleOffset, lightProbeCoefficients, reflectionProbes)
        }

        public init() { }

        public init(
            _ meshId: PolySpatialAssetID, _ materialIds: [PolySpatialAssetID],
            _ castShadows: Bool, _ boundsMargin: Float) {

            self.meshSource = .asset(meshId)
            self.materialIds = materialIds
            self.castShadows = castShadows
            self.boundsMargin = boundsMargin
        }

        public init(
            _ mesh: MeshResource,
            _ materialIds: [PolySpatialAssetID],
            _ staticBatchKey: StaticBatchManager.StaticBatchKey) {

            self.meshSource = .resource(mesh)
            self.materialIds = materialIds
            self.lightmapColorId = staticBatchKey.lightmapColorId
            self.lightmapDirId = staticBatchKey.lightmapDirId
            self.lightmapScaleOffset = staticBatchKey.lightmapScaleOffset
            self.lightProbeCoefficients = staticBatchKey.lightProbeCoefficients
            self.reflectionProbes = staticBatchKey.reflectionProbes
        }

        func texturesContain(_ predicate: (PolySpatialAssetID) -> Bool) -> Bool {
            predicate(lightmapColorId) || predicate(lightmapDirId) ||
                reflectionProbes.contains { predicate($0.textureAssetId) }
        }
    }

    struct MaskedRendererInfo: Component {
        public let color: CGColor
        public let mainTextureId: PolySpatialAssetID
        public let maskTextureId: PolySpatialAssetID
        public let maskUVTransform: float4x4
        public let maskingOperation: PolySpatialMaskingOperation
        public let maskAlphaCutoff: Float

        public init(
            _ color: CGColor, _ mainTextureId: PolySpatialAssetID, _ maskTextureId: PolySpatialAssetID,
            _ maskUVTransform: float4x4, _ maskingOperation: PolySpatialMaskingOperation, _ maskAlphaCutoff: Float) {

            self.color = color
            self.mainTextureId = mainTextureId
            self.maskTextureId = maskTextureId
            self.maskUVTransform = maskUVTransform
            self.maskingOperation = maskingOperation
            self.maskAlphaCutoff = maskAlphaCutoff
        }

        func texturesContain(_ predicate: (PolySpatialAssetID) -> Bool) -> Bool {
            predicate(mainTextureId) || predicate(maskTextureId)
        }
    }

    struct MaskedHoverColors: Component {
        public let normalColor: CGColor
        public let hoverColor: CGColor

        public init(_ normalColor: CGColor, _ hoverColor: CGColor) {
            self.normalColor = normalColor
            self.hoverColor = hoverColor
        }
    }

    struct ImageBasedLightInfo: Component {
        public let sourceAssetId0: PolySpatialAssetID
        public let sourceAssetId1: PolySpatialAssetID
        public let blend: Float
        public let inheritsRotation: Bool
        public let intensityExponent: Float

        public init(
            _ sourceAssetId0: PolySpatialAssetID,
            _ sourceAssetId1: PolySpatialAssetID,
            _ blend: Float,
            _ inheritsRotation: Bool,
            _ intensityExponent: Float) {

            self.sourceAssetId0 = sourceAssetId0
            self.sourceAssetId1 = sourceAssetId1
            self.blend = blend
            self.inheritsRotation = inheritsRotation
            self.intensityExponent = intensityExponent
        }

        func texturesContain(_ predicate: (PolySpatialAssetID) -> Bool) -> Bool {
            predicate(sourceAssetId0) || predicate(sourceAssetId1)
        }
    }

    struct AlignmentMarkerInfo: Component {
        public let data: PolySpatialAlignmentMarkerData

        public init(_ data: PolySpatialAlignmentMarkerData) {
            self.data = data
        }
    }

    struct AlignmentMarkerTracker: Component {
        public let task: Task<Void, Never>

        public init(_ task: Task<Void, Never>) {
            self.task = task
        }
    }

    struct ModelSortGroupInfo: Component {
        public var sortGroupComponentBase: ModelSortGroupComponent?
        public var sortGroupComponentOverride: ModelSortGroupComponent?
        public var overrideSortGroupEntityId = PolySpatialInstanceID.none
        public var overrideAppliesToDescendants = false
        public var overrideIsAncestor = false

        public var sortGroupComponent: ModelSortGroupComponent? {
            sortGroupComponentOverride ?? sortGroupComponentBase
        }
    }

    class BlendedMeshInstance: Component {
        public let asset: PolySpatialRealityKit.MeshAsset
        public let version: Int
        public let mesh: MeshResource
        public let blendFrameWeights: MTLBuffer
        public let jointMatrices: MTLBuffer?
        public let jointNormalMatrices: MTLBuffer?

        enum State {
            case uninitialized
            case readyToProcess
            case processing
            case updatePending
        }
        var state = State.uninitialized

        public init(
            _ asset: PolySpatialRealityKit.MeshAsset, _ version: Int, _ mesh: MeshResource,
            _ blendFrameWeights: MTLBuffer, _ jointMatrices: MTLBuffer?, _ jointNormalMatrices: MTLBuffer?) {

            self.asset = asset
            self.version = version
            self.mesh = mesh
            self.blendFrameWeights = blendFrameWeights
            self.jointMatrices = jointMatrices
            self.jointNormalMatrices = jointNormalMatrices
        }

        @MainActor public func update(_ entity: PolySpatialEntity) {
            switch state {
                case .uninitialized:
                    // If not yet initialized, we update synchronously and transition to ready state.
                    asset.updateBlendedMeshInstance(self, entity.blendShapeWeights, entity.blendJointTransforms)
                    state = .readyToProcess
                case .readyToProcess:
                    // If we're not currently processing, start the asynchronous process.
                    state = .processing
                    asset.updateBlendedMeshInstance(self, entity.blendShapeWeights, entity.blendJointTransforms) {
                        // When the process completes, see if we need to immediately start the next one.
                        if self.state == .updatePending && entity.parent != nil {
                            PolySpatialRealityKit.instance.skinnedMeshManager.dirtyBlendedMeshInstances.insert(entity)
                        }
                        self.state = .readyToProcess
                    }
                case .processing:
                    // If we're currently processing, note that we have another update pending.
                    state = .updatePending
                case .updatePending:
                    // If we already have an update pending, the state remains the same.
                    break
            }
        }
    }

    @MainActor
    class UnityVideoPlayer: Component {
        // AVPlayer status isn't always immediately ready to play right after
        // load. This observer tracks and ensures that the clip is prerolled
        // as needed when the player is ready.
        class VideoPlayerStatusObserver: NSObject {
            @objc var player: AVPlayer
            var statusObserver: NSKeyValueObservation?

            init(object: AVPlayer, playerComponent: UnityVideoPlayer) {
                player = object
                super.init()

                statusObserver = observe(
                    \.player.status,
                    options: []
                ) { object, change in
                    Task { @MainActor in
                        playerComponent.prerollIfNeeded()
                    }
                }
            }

            deinit {
                statusObserver?.invalidate()
            }
        }

        // an entity with this unity video player will have a special video material applied to it.
        public var id: PolySpatialInstanceID
        public var state: PolySpatialVideoPlayerState = .isStopped
        public var videoUrl: URL
        public var videoMaterial: VideoMaterial
        public var player: AVQueuePlayer
        public var playerItem: AVPlayerItem
        public var avPlayerLooper: AVPlayerLooper?
        public var shouldPreroll: Bool
        var observerObject: VideoPlayerStatusObserver?

        // A special mesh with inverted UVs is required for video material to work, since the video material is an RK-native material.
        public var meshAsset: MeshResource?
        public var meshAssetId: PolySpatialAssetID = .invalidAssetId

        public init(_ id: PolySpatialInstanceID,
                    _ url: URL,
                    _ shouldPreroll: Bool) {
            self.id = id
            self.shouldPreroll = shouldPreroll
            videoUrl = url
            playerItem = AVPlayerItem(asset: AVURLAsset(url: videoUrl))
            player = AVQueuePlayer(items: [playerItem])
            videoMaterial = VideoMaterial(avPlayer: player)
            // videoMaterial.controller.audioInputMode = .spatial
            observerObject = .init(object: player, playerComponent: self)
        }

        deinit {
            player.cancelPendingPrerolls()
        }

        public func changeUrl(_ url: URL) {
            videoUrl = url
            player.pause()
            state = .isStopped
            player.remove(playerItem)
            playerItem = AVPlayerItem(asset: AVURLAsset(url: videoUrl))
            player.insert(playerItem, after: nil)

            // Need to set this to nil otherwise it'll continue looping the old clip.
            avPlayerLooper?.disableLooping()
            avPlayerLooper = nil

            videoMaterial = VideoMaterial(avPlayer: player)

            // If this player had been set to preroll, the user might change the url too quickly for preroll to finish, so finish it here.
            if (shouldPreroll) {
                player.cancelPendingPrerolls()
            }
        }

        public func setState(_ state: PolySpatialVideoPlayerState, _ looping: Bool) {
            self.state = state
            switch state {
                case .isStopped:
                    // avPlayerLooper does not work well with player seeking. Disable if a stop command comes in.
                    avPlayerLooper?.disableLooping()
                    avPlayerLooper = nil

                    player.seek(to: CMTime.zero)
                    player.pause()
                case .isPaused:
                    player.pause()
                default:
                    if player.rate == 0 {
                        // Restart the looper up if we should be looping, or remove it now.
                        setLooping(looping)
                        player.play()
                    }
            }
        }

        public func setLooping(_ looping: Bool) {
            if !looping {
                avPlayerLooper?.disableLooping()
                avPlayerLooper = nil
            } else if avPlayerLooper == nil {
                avPlayerLooper = .init(player: player, templateItem: playerItem)
            }
        }

        public func prerollIfNeeded() {
            if (player.rate == 0 &&
                player.status == .readyToPlay &&
                self.shouldPreroll) {

                player.preroll(atRate: player.defaultRate,
                               completionHandler:({ (wasSuccess: Bool) -> Void in
                    Task { @MainActor in
                        var assetStatus: PolySpatialVideoAssetStatus = .prerolled
                        if (!wasSuccess) {
                            assetStatus = .failedToPreroll
                        }

                        withUnsafePointer(to: self.id) { id in
                            var assetStatusRawValue = assetStatus.rawValue
                            PolySpatialRealityKit.instance.SendHostCommand(PolySpatialHostCommand.updateVideoAssetStatus, id, &assetStatusRawValue)
                        }
                    }
                }))
            }
        }

        public func invertAndCacheMesh(_ mesh: MeshResource, _ assetId: PolySpatialAssetID) -> Bool {
            if self.meshAssetId != assetId {
                self.meshAsset = PolySpatialRealityKit.instance.invertMeshUV(mesh, assetId)
                self.meshAssetId = assetId

                return true
            }
            return false
        }
    }

    class ParticleBackingEntity: Component {
        var entity: PolySpatialEntity

        init (_ entity: PolySpatialEntity) {
            self.entity = entity
        }
    }

    class LineRendererBackingEntity: Component {
        var entity: PolySpatialEntity

        init (_ entity: PolySpatialEntity) {
            self.entity = entity
        }
    }

    class TrailBackingEntity: Component {
        var entity: PolySpatialEntity

        init (_ entity: PolySpatialEntity) {
            self.entity = entity
        }
    }

    struct SkinnedBackingEntity: Component {
        let entity: PolySpatialEntity

        init(_ entity: PolySpatialEntity) {
            self.entity = entity
        }
    }

    struct RaycastTargetBackingEntity: Component {
        let entity: PolySpatialEntity

        init(_ entity: PolySpatialEntity) {
            self.entity = entity
        }
    }

    struct StaticBatchElementInfo: Component {
        let rootId: PolySpatialInstanceID

        init(_ rootId: PolySpatialInstanceID) {
            self.rootId = rootId
        }
    }

    class StaticBatchRootInfo: Component {
        let entity = Entity()
        var elements: Set<PolySpatialEntity> = []

        func clearContents() {
            // Despite the expectation of copy-on-write semantics that we usually have with Swift, it turns out that
            // removing children while iterating over them modifies the result of iteration, so we use the subscript
            // to dispose them in reverse order.  We've reported this to Apple as part of FB15593507.
            while entity.children.count > 0 {
                (entity.children[entity.children.count - 1] as! PolySpatialEntity).dispose()
            }
        }
    }
}
