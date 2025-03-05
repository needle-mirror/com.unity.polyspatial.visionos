import Foundation
import RealityKit
import AVFoundation
import OSLog
import CoreImage
import UIKit

@_implementationOnly import FlatBuffers
@_implementationOnly import PolySpatialRealityKitC

let pslLog = Logger(subsystem: "PolySpatial", category: "General")
let pslVolumeLog = Logger(subsystem: "PolySpatial", category: "Volumes")

typealias PolySpatialCommand = Unity_PolySpatial_Internals_PolySpatialCommand
typealias PolySpatialHostCommand = Unity_PolySpatial_Internals_PolySpatialHostCommand
typealias PolySpatialChangeListEntityData = Unity_PolySpatial_Internals_PolySpatialChangeListEntityData
typealias PolySpatialFrameData = Unity_PolySpatial_Internals_PolySpatialFrameData
typealias PolySpatialLightData = Unity_PolySpatial_Internals_PolySpatialLightData
typealias PolySpatialLightmapData = Unity_PolySpatial_Internals_PolySpatialLightmapData
typealias PolySpatialLightProbeData = Unity_PolySpatial_Internals_PolySpatialLightProbeData
typealias PolySpatialReflectionProbeData = Unity_PolySpatial_Internals_PolySpatialReflectionProbeData
typealias PolySpatialPointerEvent = Unity_PolySpatial_Internals_PolySpatialPointerEvent
typealias PolySpatialPointerPhase = Unity_PolySpatial_Internals_PolySpatialPointerPhase
typealias PolySpatialPointerKind = Unity_PolySpatial_Internals_PolySpatialPointerKind
typealias PolySpatialPointerModifierKeys = Unity_PolySpatial_Internals_PolySpatialPointerModifierKeys
typealias PolySpatialBlendingMode = Unity_PolySpatial_Internals_PolySpatialBlendingMode
typealias PolySpatialTexture = Unity_PolySpatial_Internals_PolySpatialTexture
typealias PolySpatialShaderData = Unity_PolySpatial_Internals_PolySpatialShaderData
typealias PolySpatialShaderPropertyMapData = Unity_PolySpatial_Internals_PolySpatialShaderPropertyMapData
typealias PolySpatialOpacityThreshold = Unity_PolySpatial_Internals_PolySpatialOpacityThreshold
typealias PolySpatialPBRMaterial = Unity_PolySpatial_Internals_PolySpatialPBRMaterial
typealias PolySpatialShaderMaterial = Unity_PolySpatial_Internals_PolySpatialShaderMaterial
typealias PolySpatialOcclusionMaterial = Unity_PolySpatial_Internals_PolySpatialOcclusionMaterial
typealias PolySpatialUnlitMaterial = Unity_PolySpatial_Internals_PolySpatialUnlitMaterial
typealias PolySpatialUnlitParticleMaterial = Unity_PolySpatial_Internals_PolySpatialUnlitParticleMaterial
typealias PolySpatialLitParticleMaterial = Unity_PolySpatial_Internals_PolySpatialLitParticleMaterial
typealias PolySpatialBlendShape = Unity_PolySpatial_Internals_PolySpatialBlendShape
typealias PolySpatialBlendShapeFrame = Unity_PolySpatial_Internals_PolySpatialBlendShapeFrame
typealias PolySpatialMesh = Unity_PolySpatial_Internals_PolySpatialMesh
typealias PolySpatialNativeMesh = Unity_PolySpatial_Internals_PolySpatialNativeMesh
typealias PolySpatialSubMesh = Unity_PolySpatial_Internals_PolySpatialSubMesh
typealias PolySpatialMeshTopology = Unity_PolySpatial_Internals_PolySpatialMeshTopology
typealias PolySpatialVertexAttribute = Unity_PolySpatial_Internals_PolySpatialVertexAttribute
typealias PolySpatialVertexAttributeFormat = Unity_PolySpatial_Internals_PolySpatialVertexAttributeFormat
typealias PolySpatialColliderData = Unity_PolySpatial_Internals_PolySpatialColliderData
typealias PolySpatialDestroyComponentData = Unity_PolySpatial_Internals_PolySpatialDestroyComponentData
typealias PolySpatialColliderOptions = Unity_PolySpatial_Internals_PolySpatialColliderOptions
typealias PolySpatialRenderData = Unity_PolySpatial_Internals_PolySpatialRenderData
typealias PolySpatialSkinnedRendererData = Unity_PolySpatial_Internals_PolySpatialSkinnedRendererData
typealias PolySpatialSkinnedBlendShapeData = Unity_PolySpatial_Internals_PolySpatialSkinnedBlendShapeData
typealias PolySpatialHostID = Unity_PolySpatial_Internals_PolySpatialHostID
typealias PolySpatialInstanceID = Unity_PolySpatial_Internals_PolySpatialInstanceID
typealias PolySpatialComponentID = Unity_PolySpatial_Internals_PolySpatialComponentID
typealias PolySpatialAssetID = Unity_PolySpatial_Internals_PolySpatialAssetID
typealias PolySpatialAssetCommandMetadata = Unity_PolySpatial_Internals_PolySpatialAssetCommandMetadata
typealias PolySpatialTrackingFlags = Unity_PolySpatial_Internals_PolySpatialTrackingFlags
typealias PolySpatialCullMode = Unity_PolySpatial_Internals_PolySpatialCullMode
typealias PolySpatialCameraData = Unity_PolySpatial_Internals_PolySpatialCameraData
typealias PolySpatialVolumeCameraData = Unity_PolySpatial_Internals_PolySpatialVolumeCameraData_v1
typealias PolySpatialVolumeCameraMode = Unity_PolySpatial_Internals_PolySpatialVolumeCameraMode
typealias PolySpatialBoneWeight = Unity_PolySpatial_Internals_PolySpatialBoneWeight
typealias PolySpatialCanvasRendererData = Unity_PolySpatial_Internals_PolySpatialCanvasRendererData
typealias PolySpatialMaskingOperation = Unity_PolySpatial_Internals_PolySpatialMaskingOperation
typealias PolySpatialSpriteRenderData = Unity_PolySpatial_Internals_PolySpatialSpriteRenderData
typealias PolySpatialSpriteMaskData = Unity_PolySpatial_Internals_PolySpatialSpriteMaskData
typealias PolySpatialSortingDepthPass = Unity_PolySpatial_Internals_PolySpatialSortingDepthPass
typealias PolySpatialSortingGroupData = Unity_PolySpatial_Internals_PolySpatialSortingGroupData
typealias PolySpatialUIGraphicData = Unity_PolySpatial_Internals_PolySpatialUIGraphicData
typealias PolySpatialBillboardData = Unity_PolySpatial_Internals_PolySpatialBillboardData
typealias PolySpatialImageBasedLightData = Unity_PolySpatial_Internals_PolySpatialImageBasedLightData
typealias PolySpatialImageBasedLightReceiverData = Unity_PolySpatial_Internals_PolySpatialImageBasedLightReceiverData
typealias PolySpatialEnvironmentLightingConfigurationData = Unity_PolySpatial_Internals_PolySpatialEnvironmentLightingConfigurationData
typealias PolySpatialAlignmentMarkerData = Unity_PolySpatial_Internals_PolySpatialAlignmentMarkerData
typealias PolySpatialHoverEffectData = Unity_PolySpatial_Internals_PolySpatialHoverEffectData
typealias PolySpatialParticleSystemData = Unity_PolySpatial_Internals_PolySpatialParticleSystemData
typealias PolySpatialShaderGlobalPropertyMap = Unity_PolySpatial_Internals_PolySpatialShaderGlobalPropertyMap
typealias PolySpatialShaderGlobalPropertyValues = Unity_PolySpatial_Internals_PolySpatialShaderGlobalPropertyValues
typealias PolySpatialParticleSubEmitterData = Unity_PolySpatial_Internals_PolySpatialParticleSubEmitter
typealias PolySpatialTextureFilterMode = Unity_PolySpatial_Internals_PolySpatialTextureFilterMode
typealias PolySpatialTextureWrapMode = Unity_PolySpatial_Internals_PolySpatialTextureWrapMode
typealias PolySpatialTextureShape = Unity_PolySpatial_Internals_PolySpatialTextureShape
typealias PolySpatialTextureFallbackMode = Unity_PolySpatial_Internals_PolySpatialTextureFallbackMode
typealias PolySpatialTextureData = Unity_PolySpatial_Internals_PolySpatialTextureData
typealias PolySpatialNativeTextureData = Unity_PolySpatial_Internals_PolySpatialNativeTextureData
typealias PolySpatialRuntimeFlags = Unity_PolySpatial_Internals_PolySpatialRuntimeFlags
typealias PolySpatialInputType = Unity_PolySpatial_Internals_PolySpatialInputType
typealias PolySpatialSessionData = Unity_PolySpatial_Internals_PolySpatialSessionData
typealias PolySpatialParticleReplicationMode = Unity_PolySpatial_Internals_ParticleReplicationMode
typealias PolySpatialSortGroup = Unity_PolySpatial_Internals_PolySpatialSortGroup
typealias PolySpatialPlatformTextData = Unity_PolySpatial_Internals_PolySpatialPlatformTextData
typealias PolySpatialScreenshotRequest = Unity_PolySpatial_Internals_PolySpatialScreenshotRequest
typealias PolySpatialScreenshotResult = Unity_PolySpatial_Internals_PolySpatialScreenshotResult
typealias PolySpatialFontAsset = Unity_PolySpatial_Internals_PolySpatialFontAsset
typealias PolySpatialWindowState = Unity_PolySpatial_Internals_PolySpatialWindowState
typealias WindowEvent = Unity_PolySpatial_Internals_WindowEvent
typealias PolySpatialImmersionData = Unity_PolySpatial_Internals_PolySpatialImmersionData
typealias VolumeViewpoint = Unity_PolySpatial_Internals_PolySpatialVolumeViewpoint
typealias PolySpatialGameObjectData = Unity_PolySpatial_Internals_PolySpatialGameObjectData
typealias PolySpatialLogWithMarkup = Unity_PolySpatial_Internals_LogWithMarkup
typealias PolySpatialConsoleLogMessageData = Unity_PolySpatial_Internals_ConsoleLogMessageData
typealias PolySpatialLineRendererData = Unity_PolySpatial_Internals_PolySpatialLineRendererData

// For changelists that don't contain EngineData
struct EmptyData {
}

// Matches the behavior of PolySpatialUtils.cs
internal struct PolySpatialUtils
{
    internal static func AlignSize(_ size: Int32) -> Int32 {
        return ((size - 1) & ~(kCommandAlignment-1)) + kCommandAlignment
    }

    internal static let kCommandAlignment: Int32 = {
        let commandAlignment: Int32 = 8
        assert(Int32(MemoryLayout<PolySpatialChangeListEntityData>.alignment) == commandAlignment)
        return commandAlignment
    }()

    internal static let kPaddedInt32Size: Int = {
        let paddedSize = 8
        assert(AlignSize(Int32(MemoryLayout<Int32>.size)) == paddedSize)
        return paddedSize
    }()
}

@MainActor
public protocol PolySpatialRealityKitDelegate {
    func on(volumeAdded: PolySpatialVolume)
    func on(volumeRemoved: PolySpatialVolume)
}

@MainActor
protocol PolySpatialNativeAPIProtocol {
    func OnSendClientCommand(_ cmd: PolySpatialCommand?,
                        _ argCount: Int32,
                        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
                        _ argSizes: UnsafeMutablePointer<UInt32>?)
}

@MainActor
protocol TextureObserver: AnyObject {
    func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, PolySpatialRealityKit.TextureAsset>)
}

@MainActor
extension PolySpatialNativeAPI {
    static func createFilled() -> PolySpatialNativeAPI {
        var inst = PolySpatialNativeAPI()
        inst.SendClientCommand = { (command, arg1, arg2, arg3) in
            let cmd = PolySpatialCommand.init(rawValue: command)
            PolySpatialRealityKit.instance.OnSendClientCommand(cmd, arg1, arg2, arg3) }

        // Convenient place to init
        SkinnedMeshManager.UnitySkeletonData.registerComponent()
        SkinnedMeshManager.UnityBoneComponent.registerComponent()

        PolySpatialRealityKit.overrideApi(0, &inst)
        return inst
    }
}

@MainActor
class PolySpatialRealityKit: PolySpatialNativeAPIProtocol {

    public static var instance = PolySpatialRealityKit()

    // Always use 'var' path for now
#if true
    // Development builds (var binding, changeable -- set by runtime flags)
    public static var abortOnError = true
#else
    // Release builds (let binding for compiler optimizations)
    public static let abortOnError = true
#endif

    public static let invisibleMaterial = {
        var material = UnlitMaterial()
        material.opacityThreshold = 2
        return material
    }()

    public static func reset() {
        let savedSimHost = instance.simHostAPI
        let savedDelegates = instance.delegates

        // this function is a pretty big hammer
        instance = .init()
        instance.delegates = savedDelegates
        instance.simHostAPI = savedSimHost

        PolySpatialRealityKitExtra.reset()
    }

    static func GetPolySpatialNativeAPIInstance() -> PolySpatialNativeAPIProtocol? {
        return instance
    }

    var polyspatialNativeAPI = PolySpatialNativeAPI()
    var simHostAPI = PolySpatialSimulationHostAPI()

    // "Abstract" base class for material assets.
    @MainActor
    class MaterialAsset: TextureObserver {
        let id: PolySpatialAssetID

        // This is an abstract property that should be implemented by subclasses to return the actual collection of
        // texture IDs used (the single color texture for UnlitMaterial, for instance, or the values of the map from
        // handle to texture ID for ShaderGraphMaterial).
        var textureIDs: any Collection<PolySpatialAssetID> {
            get {
                EmptyCollection()
            }
        }

        init(_ id: PolySpatialAssetID) {
            self.id = id

            for textureID in textureIDs {
                PolySpatialRealityKit.instance.AddTextureObserver(textureID, self)
            }
        }

        // Unsubscribes the material from the resources that it was listening to.  We can't use deinit, because
        // we need to retain a strong reference in the observer set (for comparison purposes), which prevents
        // the material from being reclaimed.  So, be sure to call this when replacing/destroying the material.
        func dispose() {
            for textureID in textureIDs {
                PolySpatialRealityKit.instance.RemoveTextureObserver(textureID, self)
            }
        }

        // Returns the resolved material for the asset.  If flip is true and the material supports the faceCulling
        // setting, the material will have its face culling property flipped (back to front, front to back).
        func getMaterial(_ flip: Bool = false) -> Material {
            PolySpatialRealityKit.instance.materialAssets[PolySpatialAssetID.invalidAssetId]!.getMaterial(flip)
        }

        func texturesUpdated(_ assets: Dictionary<PolySpatialAssetID, TextureAsset>) {
            PolySpatialRealityKit.instance.NotifyMeshOrMaterialObservers(id)
        }

        static func getFlippedCulling(
            _ faceCulling: MaterialParameterTypes.FaceCulling) -> MaterialParameterTypes.FaceCulling {

            switch faceCulling {
                case .back: .front
                case .front: .back
                default: faceCulling
            }
        }
    }

    @MainActor
    class TextureAsset {
        var texture: MaterialParameters.Texture
        var size: SIMD3<Float>
        var cgImage: CGImage?
        var environmentResource: EnvironmentResource?
        var flipped: TextureResource?
        var lowLevelTexture: LowLevelTexture?

        init(_ texture: MaterialParameters.Texture, _ size: SIMD3<Float>, _ lowLevelTexture: LowLevelTexture? = nil) {
            self.texture = texture
            self.size = size
            self.lowLevelTexture = lowLevelTexture
        }

        convenience init(_ texture: MaterialParameters.Texture) {
            self.init(texture, .init(Float(texture.resource.width), Float(texture.resource.height), 1.0))
        }

        func getFlipped() -> TextureResource {
            if let existingFlipped = flipped {
                return existingFlipped
            }
            let newFlipped = PolySpatialRealityKit.instance.createFlipped(self)
            flipped = newFlipped
            return newFlipped
        }

        func getCGImage() -> CGImage {
            if let existingCGImage = cgImage {
                return existingCGImage
            }
            let newCGImage = PolySpatialRealityKit.instance.createCGImage(
                self,
                PolySpatialRealityKit.instance.textureFlipVerticalCompute!,
                texture.resource.width)
            cgImage = newCGImage
            return newCGImage
        }

        func getEnvironmentResource() -> EnvironmentResource {
            if let existingResource = environmentResource {
                return existingResource
            }
            let newResource = PolySpatialRealityKit.instance.createEnvironmentResource(self)
            environmentResource = newResource
            return newResource
        }
    }

    var particleManager: ParticleManager
    var lineRendererManager = LineRendererManager()
    var skinnedMeshManager: SkinnedMeshManager
    var meshAssets: [PolySpatialAssetID: MeshAsset] = [:]
    // Stores the number of sets of texture coordinates - that info is difficult to obtain after the MeshResource is generated.
    var textureAssets: [PolySpatialAssetID: TextureAsset] = [:]
    var streamingTextures: [PolySpatialAssetID: MTLTexture] = [:]
    var materialAssets: [PolySpatialAssetID: MaterialAsset] = [:]
    var vfxMaterials: [PolySpatialAssetID: VfXMaterial] = [:] // Special case handling for vfx materials.
    var shaderGraphAssets: [PolySpatialAssetID: ShaderGraphData] = [:]
    var shaderPropertyMaps: [PolySpatialAssetID: ShaderPropertyMapData] = [:]
    var fontAssets: [PolySpatialAssetID: UIFont] = [:];
    var unlitAdditiveProgram: UnlitMaterial.Program?
    var physicallyBasedAdditiveProgram: PhysicallyBasedMaterial.Program?
    var unlitAlphaProgram: UnlitMaterial.Program?
    var physicallyBasedAlphaProgram: PhysicallyBasedMaterial.Program?
    var pendingUnlitAdditiveMaterialIds: Set<PolySpatialAssetID> = []
    var pendingPhysicallyBasedAdditiveMaterialIds: Set<PolySpatialAssetID> = []

    // Links the id that the video player is on with the id that the mesh renderer is on.
    var videoPlayerEntityMap: [PolySpatialInstanceID: PolySpatialInstanceID] = [:]

    // Out-Of-Order MeshColliders
    var meshIdToMeshCollider: [PolySpatialAssetID: Set<PolySpatialEntity>] = [:]

    var componentDeleters: [PolySpatialCommand: (PolySpatialInstanceID) -> Void] = [:]

    var assetDeleters: [PolySpatialAssetID: (PolySpatialAssetID) -> Void] = [:]

    // ViewSubGraphs stored using the HostVolumeIndex of their PolySpatialInstanceID
    // Entries for active SubGraphs will be non-nil.
    // Entries are set to nil when all of their entities are destroyed.
    var viewSubGraphs: [PolySpatialViewSubGraph?] = []

    public var delegates: [PolySpatialRealityKitDelegate] = []

    var runtimeFlags: PolySpatialRuntimeFlags = .none
    var particleRenderingMode: PolySpatialParticleReplicationMode? {
        return particleManager.particleRenderingMode
    }

    var mtlDevice: MTLDevice?
    var mtlLibrary: MTLLibrary?
    var mtlCommandQueue: MTLCommandQueue?
    var blendCompute: MTLComputePipelineState?
    var blendAndSkinCompute: MTLComputePipelineState?
    var copyMatrixToTextureCompute: MTLComputePipelineState?
    var textureFlipVerticalCompute: MTLComputePipelineState?
    var textureCubeToEquirectangularCompute: MTLComputePipelineState?
    var transferTriangleIndices16Compute: MTLComputePipelineState?
    var transferTriangleIndices32Compute: MTLComputePipelineState?
    var transferVertexAttributesCompute: MTLComputePipelineState?
    var flipTexCoordsCompute: MTLComputePipelineState?
    var batchIndicesCompute: MTLComputePipelineState?
    var batchVerticesCompute: MTLComputePipelineState?

    let sortingGroups: [PolySpatialSortGroup: ModelSortGroup] = [
        .sprite: .init(depthPass: .postPass),
        .canvas: .init(depthPass: .postPass),
        .particleSystem: .init(depthPass: .postPass)
    ]

    // Links custom sorting group instance id with sets of renderers that are a member of this custom sorting group.
    var customSortGroup: [PolySpatialInstanceID: Set<PolySpatialInstanceID>] = [:]

    // For a given mesh or material asset ID, the entities with a ModelComponent that references that asset.
    var meshOrMaterialReferences: [PolySpatialAssetID: Set<PolySpatialEntity>] = [:]

    // Wraps an instance of TextureObserver with object identity semantics.
    struct TextureObserverElement: Hashable {
        static func == (lhs: TextureObserverElement, rhs: TextureObserverElement) -> Bool {
            return lhs.observer === rhs.observer
        }

        let observer: TextureObserver

        init(_ observer: TextureObserver) {
            self.observer = observer
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(observer))
        }
    }

    // For a given texture asset ID, the observer objects wishing to be notified of updates.
    var textureObservers: [PolySpatialAssetID: Set<TextureObserverElement>] = [:]

    // Entities which have aggregated collision data changes and need to update the realitykit component
    var dirtyCollisionObservers: Set<PolySpatialEntity> = []

    // Maps texture IDs to texture assets updated on the current frame.
    var updatedTextureAssets: [PolySpatialAssetID: TextureAsset] = [:]

    // For non-XR platforms, a single perspective camera that will be shared by all volumes.
    var sharedPerspectiveCamera: PerspectiveCamera?

    // A counter that is incremented before each frame is processed.
    var frameCount = 0

    // The most recent values passed to notifyHostImmersionChange()
    var mostRecentOldImmersionAmount: Double?
    var mostRecentNewImmersionAmount: Double?

    let materialErrorColors: [UIColor] = [.cyan, .yellow, .purple, .red, .green, .blue, .orange, .brown, .gray]
    var materialErrorColorIndex = 0

    let magentaImage: CGImage
    let whiteTexture: TextureResource

    init() {
        PolySpatialComponents.registerComponents()

        // Populate default assets
        meshAssets[PolySpatialAssetID.invalidAssetId] = .init(
            MeshResource.generateBox(size: 0.5, cornerRadius: 0.5).contents)

        magentaImage = PolySpatialRealityKit.createSinglePixelImage(255, 0, 255, 255)
        textureAssets[PolySpatialAssetID.invalidAssetId] = .init(.init(try! .init(
            image: magentaImage, options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll))))

        whiteTexture = try! .init(
            image: PolySpatialRealityKit.createSinglePixelImage(255, 255, 255, 255),
            options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll))

        materialAssets[PolySpatialAssetID.invalidAssetId] = UnlitMaterialAsset(
            PolySpatialAssetID.invalidAssetId, .init(color: .magenta))

        mtlDevice = MTLCreateSystemDefaultDevice()
        mtlLibrary = mtlDevice?.makeDefaultLibrary()
        mtlCommandQueue = mtlDevice?.makeCommandQueue()

        blendCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "blend")!)
        blendAndSkinCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "blendAndSkin")!)
        copyMatrixToTextureCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "copyMatrixToTexture")!)
        textureFlipVerticalCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "textureFlipVertical")!)
        textureCubeToEquirectangularCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "textureCubeToEquirectangular")!)
        transferTriangleIndices16Compute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "transferTriangleIndices16")!)
        transferTriangleIndices32Compute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "transferTriangleIndices32")!)
        transferVertexAttributesCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "transferVertexAttributes")!)
        flipTexCoordsCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "flipTexCoords")!)
        batchIndicesCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "batchIndices")!)
        batchVerticesCompute = try! mtlDevice?.makeComputePipelineState(
            function: mtlLibrary!.makeFunction(name: "batchVertices")!)

        skinnedMeshManager = SkinnedMeshManager()
        componentDeleters[PolySpatialCommand.createOrUpdateSkinnedMeshRenderer] = skinnedMeshManager.CleanUpSkinnedMeshCaches

        particleManager = ParticleManager(sortingGroups)

        componentDeleters[PolySpatialCommand.createOrUpdateParticleSystem] = particleManager.destroyParticleSystem
        componentDeleters[PolySpatialCommand.createOrUpdateLineRenderer] = lineRendererManager.destroyLineRenderer
        componentDeleters[PolySpatialCommand.createOrUpdateVideoPlayer] = cleanUpVideoPlayer

        Task {
            // Additive unlit and PBR materials require "programs" that can only be loaded asynchronously.  Since
            // we only need one program per material type, we start loading them immediately on startup.  When they
            // finish loading, we return to the main thread and process any additive materials that have been waiting
            // for them to load.
            var unlitAdditiveDescriptor = UnlitMaterial.Program.Descriptor()
            unlitAdditiveDescriptor.blendMode = .add
            unlitAdditiveDescriptor.applyPostProcessToneMap = false

            var physicallyBasedAdditiveDescriptor = PhysicallyBasedMaterial.Program.Descriptor()
            physicallyBasedAdditiveDescriptor.blendMode = .add

            // Alpha-blended unlit and PBR materials can also use programs, and doing so speeds up material
            // updates.  In this case, we don't need to update existing materials when they finish loading, since
            // they will already be using the synchronously-loaded equivalents.
            var unlitAlphaDescriptor = UnlitMaterial.Program.Descriptor()
            unlitAlphaDescriptor.blendMode = .alpha
            unlitAlphaDescriptor.applyPostProcessToneMap = false

            var physicallyBasedAlphaDescriptor = PhysicallyBasedMaterial.Program.Descriptor()
            physicallyBasedAlphaDescriptor.blendMode = .alpha

            let (unlitAdditiveProgram, physicallyBasedAdditiveProgram,
                unlitAlphaProgram, physicallyBasedAlphaProgram) = await (
                    UnlitMaterial.Program(descriptor: unlitAdditiveDescriptor),
                    PhysicallyBasedMaterial.Program(descriptor: physicallyBasedAdditiveDescriptor),
                    UnlitMaterial.Program(descriptor: unlitAlphaDescriptor),
                    PhysicallyBasedMaterial.Program(descriptor: physicallyBasedAlphaDescriptor))

            Task { @MainActor in
                self.unlitAdditiveProgram = unlitAdditiveProgram
                for id in pendingUnlitAdditiveMaterialIds {
                    if let materialAsset = materialAssets[id] as? UnlitMaterialAsset {
                        materialAsset.program = unlitAdditiveProgram
                    }
                }
                pendingUnlitAdditiveMaterialIds.removeAll()

                self.physicallyBasedAdditiveProgram = physicallyBasedAdditiveProgram
                for id in pendingPhysicallyBasedAdditiveMaterialIds {
                    if let materialAsset = materialAssets[id] as? PhysicallyBasedMaterialAsset {
                        materialAsset.program = physicallyBasedAdditiveProgram
                    }
                }
                pendingPhysicallyBasedAdditiveMaterialIds.removeAll()

                self.unlitAlphaProgram = unlitAlphaProgram
                self.physicallyBasedAlphaProgram = physicallyBasedAlphaProgram
            }
        }
    }

    static func createSinglePixelImage(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> CGImage {
        .init(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32,
           bytesPerRow: 4, space: .init(name: CGColorSpace.sRGB)!,
           bitmapInfo: .init(rawValue: CGImageAlphaInfo.first.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
           provider: .init(data: CFDataCreate(nil, [r, g, b, a], 4))!, decode: nil,
           shouldInterpolate: false, intent: .defaultIntent)!
    }

    public static func registerAllSystems() {
        PolySpatialStatisticsSystem.registerSystem()
        PolySpatialStreamingTextureSystem.registerSystem()
        PolySpatialVolumeAlignmentSystem.registerSystem()
    }

    static func GetPolySpatialAPIStruct() -> UnsafePointer<PolySpatialNativeAPI> {
        return instance.GetPolySpatialNativeAPIStruct()
    }

    static func overrideApi<T: Numeric>(_ num: T, _ api: inout PolySpatialNativeAPI) { }

    func GetPolySpatialNativeAPIStruct() -> UnsafePointer<PolySpatialNativeAPI> {
        if polyspatialNativeAPI.SendClientCommand == nil {
            polyspatialNativeAPI = PolySpatialNativeAPI.createFilled()
        }

        return withUnsafePointer(to: &polyspatialNativeAPI) { ptr in
            return ptr
        }
    }

    func SetSimulationHostAPI(_ api: UnsafeMutablePointer<PolySpatialSimulationHostAPI>?) {
        simHostAPI = (api?.pointee)!
    }

    func GetRootEntity(_ id: PolySpatialInstanceID) -> Entity {
        let viewSubGraph = getViewSubGraph(id.hostVolumeIndex)
        return viewSubGraph.root
    }

    func getViewSubGraph(_ volumeIndex: UInt8) -> PolySpatialViewSubGraph {
        let viewSubGraph = tryGetViewSubGraph(volumeIndex)
        PolySpatialAssert(viewSubGraph != nil, "No ViewSubGraph found for index \(volumeIndex)")

        return viewSubGraph!
    }

    func tryGetViewSubGraph(_ volumeIndex: UInt8) -> PolySpatialViewSubGraph? {
        (volumeIndex < viewSubGraphs.count) ? viewSubGraphs[Int(volumeIndex)] : nil
    }

    func getOrCreateViewSubGraph(_ idx: UInt8) -> PolySpatialViewSubGraph {
        let vidx = Int(idx)
        if vidx < viewSubGraphs.count, let viewSubGraph = viewSubGraphs[vidx] {
            return viewSubGraph
        }

        while viewSubGraphs.count <= vidx {
            // expand volume array to fit new index
            viewSubGraphs.append(nil)
        }

        let viewSubGraph = PolySpatialViewSubGraph(idx)
        viewSubGraphs[vidx] = viewSubGraph
        return viewSubGraph
    }

    func tryGetVolume(_ id: PolySpatialInstanceID) -> PolySpatialVolume? {
        return tryGetViewSubGraph(id.hostVolumeIndex)?.volume
    }

    func getEntities(unityInstanceId: Int32) -> [PolySpatialEntity] {
        var entities: [PolySpatialEntity] = []
        for (vidx, viewSubGraph) in viewSubGraphs.enumerated() {
            guard let viewSubGraph = viewSubGraph else {
                continue
            }

            let id = PolySpatialInstanceID(
                id: .init(unityInstanceId), hostId: .localDefault, hostVolumeIndex: .init(vidx))

            guard let entity = viewSubGraph.entities[id] else {
                continue
            }

            entities.append(entity)
        }
        return entities
    }

    func TryGetEntity(_ id: PolySpatialInstanceID) -> PolySpatialEntity? {
        return getViewSubGraph(id.hostVolumeIndex).entities[id]
    }

    func GetEntity(_ id: PolySpatialInstanceID) -> PolySpatialEntity {
        guard let entity = TryGetEntity(id) else {
            LogError("Entity \(id) not found")
            return PolySpatialEntity()
        }

        return entity
    }

    func TryGetMeshForId(_ meshId: PolySpatialAssetID) -> MeshResource? {
        tryGetMeshAssetForId(meshId)?.mesh
    }

    func GetMeshForId(_ meshId: PolySpatialAssetID) -> MeshResource {
        getMeshAssetForId(meshId).mesh
    }

    func tryGetMeshAssetForId(_ meshId: PolySpatialAssetID) -> MeshAsset? {
        meshAssets[meshId]
    }

    func getMeshAssetForId(_ meshId: PolySpatialAssetID) -> MeshAsset {
        guard let meshAsset = tryGetMeshAssetForId(meshId) else {
            return CreateUninitializedMeshAsset(meshId)
        }
        return meshAsset
    }

    func TryGetTextureAssetForId(_ textureId: PolySpatialAssetID) -> TextureAsset? {
        textureAssets[textureId]
    }

    func GetTextureAssetForId(_ textureId: PolySpatialAssetID) -> TextureAsset {
        guard let tex = TryGetTextureAssetForId(textureId) else {
            return CreateUninitializedTextureAsset(textureId)
        }
        return tex
    }

    func AddTextureObserver(_ textureID: PolySpatialAssetID, _ observer: TextureObserver) {
        if textureID.isValid {
            textureObservers[textureID, default: []].insert(.init(observer))
        }
    }

    func RemoveTextureObserver(_ textureID: PolySpatialAssetID, _ observer: TextureObserver) {
        if textureID.isValid {
            textureObservers[textureID]?.remove(.init(observer))
        }
    }

    func TryGetMaterialForID(_ materialId: PolySpatialAssetID, _ flip: Bool = false) -> Material? {
        materialAssets[materialId]?.getMaterial(flip)
    }

    func GetMaterialForID(_ materialId: PolySpatialAssetID, _ flip: Bool = false) -> Material {
        guard let material = TryGetMaterialForID(materialId, flip) else {
            let uninitializedMaterial = CreateUninitializedMaterialAsset(materialId)
            return uninitializedMaterial.getMaterial(flip)
        }
        return material
    }

    func GetVfXMaterialForID(_ materialId: PolySpatialAssetID) -> VfXMaterial? {
        vfxMaterials[materialId]
    }

    func GetCameraPose(_ pose: UnsafeMutablePointer<UnityEngine_Pose>?) {
        pose?.pointee = .init()
    }

    func AddEntities(_ ids: UnsafeBufferPointer<PolySpatialInstanceID>) {
        PolySpatialAssert(ids.count > 0, "AddEntities with empty ids")

        let viewSubGraph = getOrCreateViewSubGraph(ids[0].hostVolumeIndex)

        for id in ids {
            PolySpatialAssert(viewSubGraph.volumeIndex == id.hostVolumeIndex, "AddEntity for unexpected hostVolumeIndex \(id.hostVolumeIndex)")
            PolySpatialAssert(viewSubGraph.entities[id] == nil, "AddEntity for \(id) but it already exists!")
            viewSubGraph.entities[id] = .init(id)
        }
    }

    func deleteEntities(_ ids: UnsafeBufferPointer<PolySpatialInstanceID>) {
        PolySpatialAssert(ids.count > 0, "DeleteEntities with empty ids")

        let viewSubGraph = getViewSubGraph(ids[0].hostVolumeIndex)

        for id in ids {
            PolySpatialAssert(viewSubGraph.volumeIndex == id.hostVolumeIndex, "DeleteEntity for unexpected hostVolumeIndex \(id.hostVolumeIndex)")
            if let entity = viewSubGraph.entities.removeValue(forKey: id) {
                entity.dispose()
            } else {
                LogError("deleteEntity for \(id) but it doesn't exist!")
            }
        }

        if viewSubGraph.entities.isEmpty {
            PolySpatialAssert(viewSubGraph.volume == nil, "All entities for \(viewSubGraph.volumeIndex) have been deleted, but the volume still exists!")
            viewSubGraphs[Int(viewSubGraph.volumeIndex)] = nil

            // Shrink the list back down so that state verification can match its length exactly.
            while !viewSubGraphs.isEmpty && viewSubGraphs.last == nil {
                viewSubGraphs.removeLast()
            }
        }
    }

    func SetEntityState(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ gameObjectData: UnsafeMutablePointer<PolySpatialGameObjectData>?) {
        if let objectData = gameObjectData?.pointee {
            let entity = GetEntity(id)
            let enabled = objectData.active
            entity.isEnabled = enabled

            let skinnedMeshEntity = entity.skinnedBackingEntity
            skinnedMeshEntity?.isEnabled = enabled;
        }
    }

    func SetEntityParents(_ ids: UnsafeBufferPointer<PolySpatialInstanceID>, _ parents: UnsafeBufferPointer<PolySpatialInstanceID>) {
        PolySpatialAssert(ids.count > 0, "SetEntityParents with empty ids")

        let viewSubGraph = getViewSubGraph(ids[0].hostVolumeIndex)

        for i in 0..<ids.count {
            let id = ids[i]
            let parentId = parents[i]
            guard let entity = viewSubGraph.entities[id] else {
                LogErrorWithMarkup("Attempt to update parent on missing entity %0", [.instanceIdtoGameObject], [id.id])
                continue
            }

            if !parentId.isValid {
                entity.setParent(GetRootEntity(id))
            } else if let parentEntity = viewSubGraph.entities[parentId] {
                entity.setParent(parentEntity)
            } else {
                LogErrorWithMarkup("Attempt to update parent on %0 to missing entity %1. Parenting to Root Entity instead.",
                                   [.instanceIdtoGameObject, .instanceIdtoGameObject], [id.id, parentId.id],
                                   false)
                entity.setParent(GetRootEntity(id))
            }
        }
    }

    func SetEntityDebugInfo(_ id: PolySpatialInstanceID, _ nameBuffer: UnsafeMutableBufferPointer<UInt8>) {
        let nameLength: UInt16 = nameBuffer.withUnsafeBytes {
            $0.load(as: UInt16.self)
        }

        let nameBytes = nameBuffer.dropFirst(2).prefix(Int(nameLength))
        if let name = String(bytes: nameBytes, encoding: .utf8) {
            let entity = GetEntity(id)
            entity.name = "\(name) - \(id.id):\(id.hostId)"
        } else {
            LogError("Failed to convert to debug info to UTF-8 string")
        }
    }

    func SetEntityTransforms(_ ids: UnsafeBufferPointer<PolySpatialInstanceID>, _ positions: UnsafeBufferPointer<PolySpatialVec3>,
                            _ rotations: UnsafeBufferPointer<PolySpatialQuaternion>, _ scales: UnsafeBufferPointer<PolySpatialVec3>) {
        for (index, id) in ids.enumerated() {
            let position = ConvertPolySpatialVec3PositionToFloat3(positions[index])
            let rotation = ConvertPolySpatialQuaternionToRotation(rotations[index])
            let scale = ConvertPolySpatialVec3VectorToFloat3(scales[index])

            guard let entity = TryGetEntity(id) else {
                LogError("Missing entity in SetEntityTransforms!")
                continue
            }

            entity.setTransform(.init(scale: scale, rotation: rotation, translation: position))

            // TODO (LXR-2703): This method is causing excessive slowdown.
            // Find a more efficient way to deal with offsets.
            // entity.updateCollisionOffsets()
            PolySpatialRealityKit.instance.skinnedMeshManager.MarkSkeletonDirty(entity)
        }

        PolySpatialRealityKit.instance.skinnedMeshManager.UpdateDirtySkeletons()
    }

    func AddEntitiesWithTransforms(_ ids: UnsafeBufferPointer<PolySpatialInstanceID>, _ parents: UnsafeBufferPointer<PolySpatialInstanceID>,
                                   _ positions: UnsafeBufferPointer<PolySpatialVec3>, _ rotations: UnsafeBufferPointer<PolySpatialQuaternion>,
                                   _ scales: UnsafeBufferPointer<PolySpatialVec3>, _ states: UnsafeBufferPointer<PolySpatialGameObjectData>) {
        PolySpatialAssert(ids.count > 0, "AddEntitiesWithTransforms with empty ids")

        let viewSubGraph = getOrCreateViewSubGraph(ids[0].hostVolumeIndex)

        for id in ids {
            PolySpatialAssert(viewSubGraph.entities[id] == nil, "AddEntity for \(id) but it already exists!")
            viewSubGraph.entities[id] = .init(id)
        }

        for (index, id) in ids.enumerated() {
            let parentId = parents[index]
            let position = ConvertPolySpatialVec3PositionToFloat3(positions[index])
            let rotation = ConvertPolySpatialQuaternionToRotation(rotations[index])
            let scale = ConvertPolySpatialVec3VectorToFloat3(scales[index])

            let entity = viewSubGraph.entities[id]!

            if !parentId.isValid {
                entity.setParent(GetRootEntity(id))
            } else if let parentEntity = TryGetEntity(parentId) {
                entity.setParent(parentEntity)
            } else {
                LogErrorWithMarkup("Attempt to set parent on %0 to missing entity %1. Parenting to Root Entity instead.",
                                   [.instanceIdtoGameObject, .instanceIdtoGameObject], [id.id, parentId.id],
                                   false)
                entity.setParent(GetRootEntity(id))
            }

            entity.setTransform(.init(scale: scale, rotation: rotation, translation: position))

            entity.isEnabled = states[index].active
        }
    }

    func createOrUpdateCamera(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ cameraData: UnsafeMutablePointer<PolySpatialCameraData>?)
    {
        let data = cameraData!.pointee

        // find an existing, possibly auto-created camera
        if sharedPerspectiveCamera == nil {
            sharedPerspectiveCamera = .init()
            sharedPerspectiveCamera!.name = "Auto-created 2D camera"
        }

        let rootEntity = GetRootEntity(id)
        sharedPerspectiveCamera!.setParent(rootEntity)
        configure2DCamera(sharedPerspectiveCamera!, data, rootEntity)
    }

    func destroyCamera(_ id: PolySpatialInstanceID) {
        // ignore "deletions" of a 2D camera for now
    }

    func configure2DCamera(_ camera: PerspectiveCamera, _ data: PolySpatialCameraData, _ rootEntity: Entity)
    {
        camera.setPosition(ConvertPolySpatialVec3PositionToFloat3(data.worldPosition), relativeTo: rootEntity)
        camera.setOrientation(ConvertPolySpatialQuaternionToRotation(data.worldRotation), relativeTo: rootEntity)
        camera.camera.fieldOfViewInDegrees = data.fieldOfViewY
        // TODO Unity & RK znear/zfar don't seem to agree; possibly Z sign?
        // camera.camera.near = data.nearClip
        // camera.camera.far = data.farClip
    }

    @MainActor
    func createOrUpdateVolumeCamera(
        _ id: PolySpatialInstanceID,
        _ trackingFlags: Int32,
        _ volumeCameraData: UnsafeMutablePointer<PolySpatialVolumeCameraData>?)
    {
        let viewSubGraph = getViewSubGraph(id.hostVolumeIndex)

        let data = volumeCameraData!.pointee

        var changedWindowConfig = false

        // If we have a direct match for this requested dimension, just return that, otherwise we have to try and fit it to the best available option.
        let requestedDim = data.outputDimensions.rk()
        var fittedDim: simd_float3 = .zero
        if !(PolySpatialWindowManager.shared.findBestFitWindowForRequest(requestedDim, &fittedDim)) {
            fittedDim = PolySpatialWindowManager.shared.fitToAvailableVolumeConfig(requestedDim)
            pslVolumeLog.trace("Exact volume configuration missing for \(requestedDim, privacy: .public), best fit is \(fittedDim, privacy: .public).")
        }

        if let existing = viewSubGraph.volume {
            if existing.id == id {
                // try to update the existing volume with the new data. If it succeeds,
                // we're done. If it doesn't, then treat this as a remove and add.
                if existing.update(cameraData: data, fittedDim) {
                    return
                }

                changedWindowConfig = true
            } else {
                LogError("A Volume with ID \(existing.id) already exists for HostVolumeIndex \(id.hostVolumeIndex), cannot create new Volume with ID \(id)")
                return
            }

            // The volume camera is being reconfigured;
            // delete the current one, and re-add it down below.
            delegates.forEach { $0.on(volumeRemoved: existing) }
            viewSubGraph.volume = nil
        }

        let volume = PolySpatialVolume.init(id, viewSubGraph.root)
        _ = volume.update(cameraData: data, fittedDim)
        viewSubGraph.volume = volume

        // This isn't the first time this volume was opened, and it is being matched with a window with new output dimensions - propagate this so that we can invoke WindowStateChanged WindowResized after this volume has had a window assigned and opened.
        if (changedWindowConfig) {
            volume.assignedNewWindowConfiguration = true
        }

        delegates.forEach { $0.on(volumeAdded: volume) }
    }

    func destroyVolumeCamera(_ id: PolySpatialInstanceID)
    {
        let viewSceneGraph = getViewSubGraph(id.hostVolumeIndex)

        if let volume = viewSceneGraph.volume {
            if volume.id != id {
                LogError("Error destroying volume camera \(id), a volume with id \(volume.id) is using that index")
                return
            }

            delegates.forEach { $0.on(volumeRemoved: volume) }
            viewSceneGraph.volume = nil
        }
    }

    func RegisterEntityWithMeshOrMaterial(_ id: PolySpatialAssetID, _ entity: PolySpatialEntity) {
        if id.isValid {
            meshOrMaterialReferences[id, default: []].insert(entity)
        }
    }

    func UnregisterEntityWithMeshOrMaterial(_ id: PolySpatialAssetID, _ entity: PolySpatialEntity) {
        if id.isValid {
            meshOrMaterialReferences[id]!.remove(entity)
        }
    }

    func NotifyMeshOrMaterialObservers(_ id: PolySpatialAssetID, _ referencePreserved: Bool = false) {
        meshOrMaterialReferences[id]?.forEach { e in e.meshOrMaterialUpdated(id, referencePreserved) }
    }

    func NotifyCollisionObservers() {
        dirtyCollisionObservers.forEach { e in e.updateCollisionComponent() }
        dirtyCollisionObservers.removeAll(keepingCapacity: true)
    }

    func createOrUpdateMeshRenderer(_ id: PolySpatialInstanceID, _ renderInfo: UnsafeMutablePointer<PolySpatialRenderData>?) {
        let entity = GetEntity(id)

        // Clear any old static batch mapping the entity may have.
        entity.clearStaticBatchElementInfo()

        // Set the static batch mapping before the render info so that the entity knows not
        // to bother creating a ModelComponent.
        let info = renderInfo!.pointee
        if let staticBatchRootId = info.staticBatchRootId {
            // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
            let remappedStaticBatchRootId = PolySpatialInstanceID(
                id: staticBatchRootId.id, hostId: id.hostId, hostVolumeIndex: id.hostVolumeIndex)

            entity.setStaticBatchElementInfo(remappedStaticBatchRootId)
        }

        let mids = info.hasMaterialIds ? Array(info.materialIdsAsBuffer!) : []
        let reflectionProbes = info.hasReflectionProbes ? Array(info.reflectionProbesAsBuffer!) : nil
        entity.setRenderMeshAndMaterials(
            info.meshId!, mids, info.shadowCastingMode != .off, info.lightmap, info.lightProbe, reflectionProbes)

        if let sortingGroup = sortingGroups[info.sortingGroup] {
            entity.setModelSortGroupBase(.init(group: sortingGroup, order: .init(info.sortingOrder)))
        } else if info.sortingGroup != .default_ {
            assertionFailure("Unsupported sorting group \(info.sortingGroup)")
        }
    }

    func destroyMeshRenderer(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.clearStaticBatchElementInfo()
        entity.setRenderMeshAndMaterials(PolySpatialAssetID.invalidAssetId, [])
    }

    func createOrUpdateSkinnedMeshRenderer(_ id: PolySpatialInstanceID, _ skinnedRenderInfo: UnsafeMutablePointer<PolySpatialSkinnedRendererData>?) {
        let info = skinnedRenderInfo!.pointee

        guard let renderData = info.renderData else {
            LogException("No render info available for \(id).")
            return
        }

        let entity = GetEntity(id)
        let reflectionProbes = renderData.hasReflectionProbes ? Array(renderData.reflectionProbesAsBuffer!) : nil
        if (info.skeletonBonesChanged) {
            if (entity.skinnedBackingEntity != nil) {
                // Have to delete it if a pre-existing skeleton was set up.
                skinnedMeshManager.CleanUpSkinnedMeshCaches(id)
            }

            // Set up skeleton.
            let boneCount = info.skeletonBoneIdsCount

            // Generate the skinned mesh now.
            skinnedMeshManager.GenerateSkinnedMesh(renderData.meshId!, boneCount)

            // Set up a mapping between the bones in the newly generated skeleton and the polyspatial ids, so when transforms come in, they are redirected to the right skeleton bone. There is an assumption that the order of the bones in boneIds and the order of the bones in the RK skeleton/parent indices are the same.
            let backingEntity = skinnedMeshManager.InitializeBoneMapping(info, entity, id, Int(boneCount))
            backingEntity.blendLocalBounds = info.localBounds.rk()

            // Apply skinned mesh to backing entity now.
            let mids = renderData.hasMaterialIds ? Array(renderData.materialIdsAsBuffer!) : []
            backingEntity.setRenderMeshAndMaterials(
                renderData.meshId!, mids, renderData.shadowCastingMode != .off,
                renderData.lightmap, renderData.lightProbe, reflectionProbes)

            // Update all transforms now in case this SMR doesn't actually have an animation to update from.
            skinnedMeshManager.UpdateDirtySkeletons()
        } else {
            let backingEntity = entity.skinnedBackingEntity!
            backingEntity.blendLocalBounds = info.localBounds.rk()
            let mids = renderData.hasMaterialIds ? Array(renderData.materialIdsAsBuffer!) : []
            backingEntity.setRenderMeshAndMaterials(
                renderData.meshId!, mids, renderData.shadowCastingMode != .off,
                renderData.lightmap, renderData.lightProbe, reflectionProbes)
        }
    }

    func destroySkinnedMeshRenderer(_ id: PolySpatialInstanceID) {
        skinnedMeshManager.CleanUpSkinnedMeshCaches(id)
    }

    func setEntitySkinnedBlendShapeInfo(_ id: PolySpatialInstanceID, _ skinnedBlendShapeInfo: UnsafeMutablePointer<PolySpatialSkinnedBlendShapeData>?) {
        guard let info = skinnedBlendShapeInfo?.pointee else {
            return
        }
        GetEntity(id).skinnedBackingEntity!.blendShapeWeights = .init(info.weightsAsBuffer!)
    }

    func removeLightComponents(_ entity: PolySpatialEntity) {
        entity.components.remove(PointLightComponent.self)
        entity.components.remove(SpotLightComponent.self)
        entity.components.remove(SpotLightComponent.Shadow.self)
        entity.components.remove(DirectionalLightComponent.self)
        entity.components.remove(DirectionalLightComponent.Shadow.self)
    }

    func createOrUpdateLight(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ lightInfo: UnsafeMutablePointer<PolySpatialLightData>?) {

        let entity = GetEntity(id)

        // Remove existing light components
        removeLightComponents(entity)

        let info = lightInfo!.pointee

        // Don't bother creating the light on visionOS if we only want image-based lighting.
        if info.visionOsmode == .disabled {
            return
        }

        // RealityKit point and spot light intensities are in lumens;
        // multiply by a value determined by experimentation
        let experimentalLumensPerIntensity: Float = 20000.0

        switch info.lightType {
            case .spot:
                entity.components.set(
                    SpotLightComponent(color: .init(info.color),
                                       intensity: info.intensity * experimentalLumensPerIntensity,
                                       innerAngleInDegrees: info.innerAngle,
                                       outerAngleInDegrees: info.outerAngle,
                                       attenuationRadius: info.range))
                if info.shadows != .none_ && info.visionOsmode == .enabledWithShadows {
                    var shadow = SpotLightComponent.Shadow()
                    shadow.depthBias = info.shadowBias + info.visionOsshadowBiasOffset
                    shadow.zNear = .fixed(info.shadowNearPlane)
                    shadow.zFar = .fixed(info.range)
                    entity.components.set(shadow)
                }
            case .directional:
                // RealityKit directional intensities are in lumens/square meter (lux);
                // multiply by a value determined by experimentation
                let experimentalLuxPerIntensity: Float = 1850.0
                entity.components.set(
                    DirectionalLightComponent(color: .init(info.color),
                        intensity: info.intensity * experimentalLuxPerIntensity))
                if info.shadows != .none_  && info.visionOsmode == .enabledWithShadows {
                    entity.components.set(
                        DirectionalLightComponent.Shadow(
                            shadowProjection: .automatic(maximumDistance: info.range),
                            depthBias: info.shadowBias + info.visionOsshadowBiasOffset))
                }
            case .point:
                entity.components.set(
                    PointLightComponent(color: .init(info.color),
                        intensity: info.intensity * experimentalLumensPerIntensity,
                        attenuationRadius: info.range))
            }
    }

    func destroyLight(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)

        removeLightComponents(entity)
    }

    func createOrUpdateUIGraphic(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ graphicInfo: UnsafeMutablePointer<PolySpatialUIGraphicData>?) {
        let info = graphicInfo!.pointee
        let entity = GetEntity(id)
        entity.raycastTarget = info.raycastTarget
    }

    func destroyUIGraphic(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.raycastTarget = false
    }

    func createOrUpdateHoverEffect(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ hoverEffectInfo: UnsafeMutablePointer<PolySpatialHoverEffectData>?) {
        let entity = GetEntity(id)
        let info = hoverEffectInfo!.pointee
        switch info.type
        {
            case .highlight:
                entity.components.set(HoverEffectComponent(.highlight(.init(
                    color: .init(info.color), strength: info.intensityMultiplier))))
                entity.clearMaskedHoverColors()
            case .spotlight:
                entity.components.set(HoverEffectComponent(.spotlight(.init(
                    color: .init(info.color), strength: info.intensityMultiplier))))
                entity.clearMaskedHoverColors()
            case .shader:
                entity.components.set(HoverEffectComponent(.shader(.init(
                    fadeInDuration: TimeInterval(info.fadeInDuration),
                    fadeOutDuration: TimeInterval(info.fadeOutDuration)))))
                entity.setMaskedHoverColors(info.selectableNormalColor.cgColor(), info.color.cgColor())
        }
        entity.updateBackingEntityComponents(HoverEffectComponent.self)
    }

    func destroyHoverEffect(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.components.remove(HoverEffectComponent.self)
        entity.clearMaskedHoverColors()
        entity.updateBackingEntityComponents(HoverEffectComponent.self)
    }

    func createOrUpdateBillboard(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ billboardInfo: UnsafeMutablePointer<PolySpatialBillboardData>?) {
        let entity = GetEntity(id)
        entity.components.remove(BillboardComponent.self)

        if let info = billboardInfo?.pointee {
            var billboard = BillboardComponent()

            billboard.blendFactor = info.blendFactor;

            entity.components.set(billboard)
        }
    }

    func destroyBillboard(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.components.remove(BillboardComponent.self)
    }

    func createOrUpdateGroundingShadow(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ groundingShadowInfo: UnsafeMutablePointer<EmptyData>?) {
        let entity = GetEntity(id)
        if !entity.components.has(GroundingShadowComponent.self) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
        }
        entity.updateBackingEntityComponents(GroundingShadowComponent.self)
    }

    func destroyGroundingShadow(_ id: PolySpatialInstanceID) {
        let entity = GetEntity(id)
        entity.components.remove(GroundingShadowComponent.self)
        entity.updateBackingEntityComponents(GroundingShadowComponent.self)
    }

    func createOrUpdateCollider(_ id: PolySpatialInstanceID, _ trackingFlags: Int32, _ colliderInfo: UnsafeMutablePointer<PolySpatialColliderData>?) {
        let entity = GetEntity(id)
        entity.createOrUpdateCollision(info: UnsafePointer(colliderInfo!), trackingFlags: trackingFlags)
    }

    func destroyCollider(_ destroyColliderData: PolySpatialDestroyComponentData) {
        let entity = GetEntity(destroyColliderData.instanceId)
        entity.destroyCollision(info: destroyColliderData)
    }

    func createOrUpdateVideoPlayer(_ id: PolySpatialInstanceID, _ videoInfo: UnsafeMutablePointer<PolySpatialVideoPlayerData>?) {
        let info = videoInfo!.pointee
        // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
        let remappedMeshRendererId = PolySpatialInstanceID(id: info.meshRendererEntityId!.id, hostId: id.hostId, hostVolumeIndex: id.hostVolumeIndex)

        guard let rendererEntity = TryGetEntity(remappedMeshRendererId) else {
            // The render entity doesn't exist, so just return. This could happen if the renderer was set to none.
            // Also check to see if there was an existing system that we should now cleanup.
            cleanUpVideoPlayer(id)
            return
        }

        var firstTimeSetup = false
        // If the mesh entity has changed, then set up a new component.
        if videoPlayerEntityMap[id] == nil {
            // Set up a new component
            setVideoComponent(info, rendererEntity)
            videoPlayerEntityMap[id] = remappedMeshRendererId
            firstTimeSetup = true
        } else if videoPlayerEntityMap[id] != remappedMeshRendererId {
            // Delete old component and set up a new component.
            cleanUpVideoPlayer(id)

            setVideoComponent(info, rendererEntity)
            videoPlayerEntityMap[id] = remappedMeshRendererId
        }

        updateVideoComponent(info, rendererEntity, firstTimeSetup)
    }

    func destroyVideoPlayer(_ id: PolySpatialInstanceID) {
        cleanUpVideoPlayer(id)
    }

    func DeleteComponent(_ id: PolySpatialInstanceID, _ type: Int32) {
        let cmd = PolySpatialCommand.init(rawValue: type)!
        guard let deleter = componentDeleters[cmd] else {
            LogError("No deleter found for component of type \(cmd)!")
            return
        }

        deleter(id)
    }


    func DeleteAsset(_ id: PolySpatialAssetID) {
        if let deleter = assetDeleters.removeValue(forKey: id) {
            deleter(id)
        } else {
            LogError("Unable to find an asset for asset id \(id) to delete")
        }
    }

    // Handle a ChangeListSerialized (as described in ChangeList.cs) containing changes from managed data
    // serialized as flatbuffer tables.  Expects there to be 1 arg, which will be a variable length buffer.
    // entryCallback will be called for every entry.
    func HandleChangeListSerializedArg<T: FlatBufferObject>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
        entryCallback: (PolySpatialInstanceID, UnsafeMutablePointer<T>?) -> Void) {
        var dataPtrBuf: UnsafeMutableBufferPointer<UInt8>?
        ExtractArgs(argCount, args, argSizes, &dataPtrBuf)
        let totalSize = Int32(argSizes![0])
        var remaining = totalSize
        var dataPtr = dataPtrBuf?.baseAddress

        while remaining > 0 {
            // layout for each entry is:
            // int32    size (total size including size, padding, entityData and engineData. Padded to maintain alignment of kCommandAlignment)
            // PolySpatialChangeListEntityData  entityData
            // [raw data serialized as flatbuffer]   engineData
            let sizePtr = UnsafeMutableRawPointer(dataPtr!).bindMemory(to: Int32.self, capacity: 1)
            let entrySize = sizePtr.pointee
            let dataSize = Int(entrySize)
                - PolySpatialUtils.kPaddedInt32Size
                - MemoryLayout<PolySpatialChangeListEntityData>.stride
            PolySpatialAssert(entrySize != 0 && dataSize >= 0, "CORRUPT CHANGE LIST: got entrySize of \(entrySize), dataSize of \(dataSize). totalSize: \(totalSize), remaining: \(remaining)")
            let entityDataPtr = UnsafeMutableRawPointer(sizePtr + 2).bindMemory(to: PolySpatialChangeListEntityData.self, capacity: 1)
            let entityData = entityDataPtr.pointee
            if dataSize > 0 && !PolySpatialRealityKit.TrackingDisabledOrDestroyedOrInactive(entityData.trackingFlags) {
                let engineDataPtr = UnsafeMutableRawPointer(entityDataPtr + 1).bindMemory(to: UInt8.self, capacity: dataSize)
                var buf = ByteBuffer(assumingMemoryBound: engineDataPtr, capacity: Int(dataSize))
                var engineData: T = getRoot(byteBuffer: &buf)
                entryCallback(entityData.instanceId, &engineData)
            } else {
                entryCallback(entityData.instanceId, nil)
            }
            let alignedSize = PolySpatialUtils.AlignSize(entrySize)
            remaining -= alignedSize
            dataPtr = dataPtr! + Int(alignedSize)
        }
    }

    // Handle a ChangeList (as described in ChangeList.cs) containing changes from managed data,
    // not serialized as flatbuffer tables.  Expects there to be 1 arg, which will be a variable length buffer.
    // Each element in the buffer is the same size.
    func HandleChangeListArg<T>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
                                _ argSizes: UnsafeMutablePointer<UInt32>?,
                                entryCallback: (PolySpatialInstanceID, Int32, UnsafeMutablePointer<T>?) -> Void) {
        var dataPtrBuf: UnsafeMutableBufferPointer<UInt8>?
        ExtractArgs(argCount, args, argSizes, &dataPtrBuf)
        let totalSize = Int32(argSizes![0])
        var remaining = totalSize
        let entrySize = Int32(MemoryLayout<PolySpatialChangeListEntityData>.stride + MemoryLayout<T>.stride)
        var dataPtr = dataPtrBuf?.baseAddress

        while remaining > 0 {
            // layout for each entry is:
            // PolySpatialChangeListEntityData  entityData
            // T   engineData
            let entityDataPtr = UnsafeMutableRawPointer(dataPtr!).bindMemory(to: PolySpatialChangeListEntityData.self, capacity: 1)
            let entityData = entityDataPtr.pointee
            let engineDataPtr = UnsafeMutableRawPointer(entityDataPtr + 1).bindMemory(to: T.self, capacity: 1)

            entryCallback(entityData.instanceId, entityData.trackingFlags, engineDataPtr)

            remaining -= entrySize
            dataPtr = dataPtr! + Int(entrySize)
        }
    }

    func handleDestroyListArg<T>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
                                 _ argSizes: UnsafeMutablePointer<UInt32>?,
                                 entryCallback: (T) -> Void) {

        var destroyListPtr: UnsafeMutableBufferPointer<T>?
        ExtractArgs(argCount, args, argSizes, &destroyListPtr)
        for destroyData in destroyListPtr! {
            entryCallback(destroyData)
        }
    }

    func SetRuntimeFlags(_ flags: UInt32) {
        runtimeFlags = .init(rawValue: flags)
        PolySpatialStatistics.shared.displayOverlay = runtimeFlags.contains(.debugOverlayEnabled)
        PolySpatialRealityKit.abortOnError = !runtimeFlags.contains(.dontAbortOnError)
    }

    func takeScreenshot(_ request: PolySpatialScreenshotRequest) {
        do {
            let pngData: Data? = nil
#if false
            let renderer = try RealityRenderer()

            let width = Int(request.resolution!.x)
            let height = Int(request.resolution!.y)

            let tmpCamera = PerspectiveCamera()
            tmpCamera.setParent(rootEntity)
            configure2DCamera(tmpCamera, request.camera!)

            renderer.activeCamera = tmpCamera
            // make sure the background color has alpha = 1.0
            var bgColor = request.camera!.backgroundColor.cgColor().copy(alpha: 1.0)!
            //renderer.cameraSettings.colorBackground = .color(bgColor)
            renderer.cameraSettings.colorBackground = .color(.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))

            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.width = width
            textureDescriptor.height = height

            let texture = mtlDevice!.makeTexture(descriptor: textureDescriptor)!

            let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))


            let completionSemaphore = DispatchSemaphore(value: 0)

            try renderer.updateAndRender(deltaTime: 0.0, cameraOutput: output, onComplete: { _ in
                let ciImage = CIImage(mtlTexture: texture, options: nil)!

                // Convert CIImage to UIImage
                let uiImage = UIImage(ciImage: ciImage)
                // TODO

                completionSemaphore.signal()
            })

            // Wait until the screenshot is done
            while completionSemaphore.wait(timeout: .now()) != .success {
                RunLoop.current.run(mode: .default, before: .now)
            }

            tmpCamera.removeFromParent()
#endif

            if let pngData {
                // Send reply message while still in the context of the request message
                pngData.withUnsafeBytes { pngRawBytes in
                    let pngBytes = pngRawBytes.assumingMemoryBound(to: UInt8.self)

                    var replyBuilder = FlatBufferBuilder(initialSize: Int32(pngBytes.count) + 128)

                    let dataOffset = replyBuilder.createVector(Array(pngBytes))

                    let start = PolySpatialScreenshotResult.startPolySpatialScreenshotResult(&replyBuilder)
                    PolySpatialScreenshotResult.add(id: request.id, &replyBuilder)
                    PolySpatialScreenshotResult.addVectorOf(data: dataOffset, &replyBuilder)
                    let end = PolySpatialScreenshotResult.endPolySpatialScreenshotResult(&replyBuilder, start: start)

                    replyBuilder.finish(offset: end)

                    self.SendHostCommand(PolySpatialHostCommand.screenshotResult, replyBuilder.sizedBuffer)
                }
            } else {
                throw "No PNG data"
            }
        } catch {
            LogWarning("Failed to render screenshot: \(error)")
            var replyBuilder = FlatBufferBuilder(initialSize: 32)

            let start = PolySpatialScreenshotResult.startPolySpatialScreenshotResult(&replyBuilder)
            PolySpatialScreenshotResult.add(id: request.id, &replyBuilder)
            let end = PolySpatialScreenshotResult.endPolySpatialScreenshotResult(&replyBuilder, start: start)

            replyBuilder.finish(offset: end)

            self.SendHostCommand(PolySpatialHostCommand.screenshotResult, replyBuilder.sizedBuffer)
        }
    }

    func notifyHostWindowState(_ volume: PolySpatialVolume,
                               windowEvent: WindowEvent,
                               focused: Bool)
    {
        // As a workaround for a crash that happens when we have a video playing when we switch between volume
        // configurations (or a video stoppage that happens when we switch to unbounded mode), we reset all
        // video players in the volume when the window is opened.
        if windowEvent == .opened {
            resetVideoPlayers(volume.id)
        }

        // Actual size of volume in worldspace, inclusive of any resizing the user may have done via the chrome UI.
        let volumeDim = volume.hostDimensions

        // Size of the content within the volume, relative to Unity's size. If ScaleContentWithWindow is ticked false, this should be constant and won't change with volume dimensions.
        let contentDim = volume.rootEntity.scale

        let state = PolySpatialWindowState(iid: volume.id,
                                           outputDimensions: .init(x: volumeDim.x, y: volumeDim.y, z: volumeDim.z),
                                           contentDimensions: .init(x: contentDim.x, y: contentDim.y, z: contentDim.z),
                                           outputMode: volume.mode,
                                           windowEvent: windowEvent,
                                           isFocused: focused,
                                           _Padding0: 0,
                                           _Padding1: 0)

        self.SendHostCommand(PolySpatialHostCommand.updateWindowState, state)
    }

    func notifyHostVolumeViewpointChange(_ volume: PolySpatialVolume,
                                   volumeViewpoint: VolumeViewpoint) {
        withUnsafePointer(to: volume.id) { volId in
            var viewpoint = volumeViewpoint.rawValue
            self.SendHostCommand(PolySpatialHostCommand.updateVolumeViewpoint, volId, &viewpoint)
        }
    }

    func notifyHostImmersionChange(_ oldAmount: Double?, _ newAmount: Double?)
    {
        mostRecentOldImmersionAmount = oldAmount
        mostRecentNewImmersionAmount = newAmount

        // The initial immersion callback happens before the simHostAPI is initialized
        if simHostAPI.SendHostCommand == nil {
            return;
        }

        let oldAmt = oldAmount ?? 0.0
        let oldHasValue = oldAmount != nil
        let newAmt = newAmount ?? 0.0
        let newHasValue = newAmount != nil

        let immersionData = PolySpatialImmersionData.init(
            oldAmount: oldAmt,
            newAmount: newAmt,
            oldHasValue: oldHasValue,
            newHasValue: newHasValue,
            _Padding0: 0,
            _Padding1: 0
        )

        self.SendHostCommand(PolySpatialHostCommand.updateImmersionAmount, immersionData)
    }

    func UpdateConsoleLogMessages(_ consoleLogMessageData: PolySpatialConsoleLogMessageData) {
        assert(consoleLogMessageData.hasLogLevel && consoleLogMessageData.hasText && consoleLogMessageData.hasStackTrace)
        assert(consoleLogMessageData.logLevelCount == consoleLogMessageData.textCount && consoleLogMessageData.logLevelCount == consoleLogMessageData.stackTraceCount)

        for i in 0..<consoleLogMessageData.textCount {
            if let logLevel = consoleLogMessageData.logLevel(at: i),
               let messageType = PolySpatialConsoleLogType(rawValue: logLevel.rawValue),
               let message = consoleLogMessageData.text(at: i),
               let stackTrace = consoleLogMessageData.stackTrace(at: i) {
                let item = PolySpatialConsoleLogItem.init(messageType: messageType, message: message, stackTrace: stackTrace)
                PolySpatialConsoleLog.instance.messages.append(item)
            }
        }
    }

    func OnSendClientCommand(_ cmd: PolySpatialCommand?,
                        _ argCount: Int32,
                        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
                        _ argSizes: UnsafeMutablePointer<UInt32>?) {
        switch cmd {
        case .beginSession:
            // poke shared to make sure this gets initialized
            let _ = PolySpatialWindowManager.shared
            var idPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &idPtr, &data)
            // Set an initial particle replication mode. While the global setting is now transmitted per-particle system in setParticleSystemData
            // in order to support unit tests switching between global modes, the particle material commands still operate conditionally on this mode.
            // This will be removed when we fully migrate to user-defined per-particle system replication modes.
            let sessionData: PolySpatialSessionData = getRoot(byteBuffer: &data!)
            particleManager.particleRenderingMode  = sessionData.particleReplicationMode
            // Send the most recent immersion values since the HostAPI may not have been set, or a remote simulation may want the values
            notifyHostImmersionChange(mostRecentOldImmersionAmount, mostRecentNewImmersionAmount)
            break
        case .setRuntimeFlags:
            var runtimeFlagsPtr: UnsafeMutablePointer<UInt32>?
            ExtractArgs(argCount, args, argSizes, &runtimeFlagsPtr)
            SetRuntimeFlags(runtimeFlagsPtr!.pointee)
            break
        case .setSimulationHostApi:
            var ptr: UnsafeMutablePointer<PolySpatialSimulationHostAPI>?
            ExtractArgs(argCount, args, argSizes, &ptr)
            SetSimulationHostAPI(ptr)
            break
        case .verifyState:
            var expectedStates = String()
            ExtractArgs(argCount, args, argSizes, &expectedStates)
            SendHostCommand(.stateVerificationResult, verifyState(expectedStates))
            break
        case .beginConnection:
            var idPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
            var connectionData: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &idPtr, &connectionData)
            break
        case .endSession:
            PolySpatialConsoleLog.instance.messages.removeAll()
            break
        case .endConnection:
            break
        case .createOrUpdateReferenceImageLibrary:
            break;
        case .addTrackedImage:
            break;
        case .getCameraPose:
            var ptr: UnsafeMutablePointer<UnityEngine_Pose>?
            ExtractArgs(argCount, args, argSizes, &ptr)
            GetCameraPose(ptr)
            break
        // asset APIs
        case .createOrUpdateMeshAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var assetCommandMetadataPtr: UnsafeMutablePointer<PolySpatialAssetCommandMetadata>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &assetCommandMetadataPtr, &data)

            let meshId = assetIdPtr!.pointee
            var mesh: PolySpatialMesh = getRoot(byteBuffer: &data!)
            CreateOrUpdateMeshAsset(meshId, &mesh)

            if PolySpatialRealityKit.instance.meshIdToMeshCollider[meshId] != nil {
                for entity in PolySpatialRealityKit.instance.meshIdToMeshCollider[meshId]! {
                    entity.updateMeshCollisionShape(meshId: meshId)
                }
            }
            break
        case .createOrUpdateNativeMeshAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data)

            let meshId = assetIdPtr!.pointee
            var mesh: PolySpatialNativeMesh = getRoot(byteBuffer: &data!)
            createOrUpdateNativeMeshAsset(meshId, &mesh)
            break
        case .createOrUpdateTextureAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var assetCommandMetadataPtr: UnsafeMutablePointer<PolySpatialAssetCommandMetadata>?
            var data: ByteBuffer?
            var pixelData: UnsafeMutableRawBufferPointer?

            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &assetCommandMetadataPtr, &data, &pixelData)

            let texdata: PolySpatialTextureData = getRoot(byteBuffer: &data!)
            let success = CreateOrUpdateTextureAsset(assetIdPtr!.pointee, texdata, pixelData)

            let successInt = success ? Int32(1) : Int32(0)
            withUnsafePointer(to: successInt) {
                SendHostCommand(PolySpatialHostCommand.textureUploadResult, assetIdPtr, $0)
            }
            break
        case .createOrUpdateNativeTextureAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var texturePtr: UnsafeMutablePointer<PolySpatialNativeTextureData>?

            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &texturePtr)

            let success = CreateOrUpdateNativeTextureAsset(assetIdPtr!.pointee, texturePtr)

            let successInt = success ? Int32(1) : Int32(0)
            withUnsafePointer(to: successInt) {
                SendHostCommand(PolySpatialHostCommand.textureUploadResult, assetIdPtr, $0)
            }
            break
        case .createOrUpdateFontMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialUnlitMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdateFontMaterialAsset(assetIdPtr!.pointee, materialPtr)
            break
        case .createOrUpdateUnlitMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialUnlitMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdateUnlitMaterialAsset(assetIdPtr!.pointee, materialPtr)
            break
        case .createOrUpdatePbrmaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialPBRMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdatePBRMaterialAsset(assetIdPtr!.pointee, materialPtr)
            break
        case .createOrUpdateShaderMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data)

            CreateOrUpdateShaderGraphMaterialAsset(assetIdPtr!.pointee, &data!)
            break
        case .createOrUpdateOcclusionMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialOcclusionMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdateOcclusionMaterialAsset(assetIdPtr!.pointee, materialPtr)
            break
        case .createOrUpdateUnlitParticleMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialUnlitParticleMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdateUnlitParticleMaterialAsset(assetIdPtr!.pointee, _materialPtr: materialPtr)
            break
        case .createOrUpdateLitParticleMaterialAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var materialPtr: UnsafeMutablePointer<PolySpatialLitParticleMaterial>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &materialPtr)
            CreateOrUpdateLitParticleMaterialAsset(assetIdPtr!.pointee, _materialPtr: materialPtr)
            break
        case .createShaderPropertyMap:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data)

            var shaderGraphPropertyMap: PolySpatialShaderPropertyMapData = getRoot(byteBuffer: &data!)
            CreateShaderPropertyMapAsset(assetIdPtr!.pointee, &shaderGraphPropertyMap)
            break
        case .createShaderAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data)

            var shaderData: PolySpatialShaderData = getRoot(byteBuffer: &data!)
            CreateShaderGraphAsset(assetIdPtr!.pointee, &shaderData, nil)
            break
        case .createShaderAssetAsync:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            var asyncId: UnsafeMutablePointer<PolySpatialAssetID>?

            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data, &asyncId)

            var shaderData: PolySpatialShaderData = getRoot(byteBuffer: &data!)
            CreateShaderGraphAsset(assetIdPtr!.pointee, &shaderData, asyncId?.pointee)
            break
        case .createOrUpdateFontAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            var fontData: UnsafeMutableRawBufferPointer?

            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data, &fontData)
            let fontAsset : PolySpatialFontAsset = getRoot(byteBuffer: &data!)
            CreateOrUpdateFontAsset(assetIdPtr!.pointee, fontAsset, fontData)
            break;

        case .deleteAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr)
            DeleteAsset(assetIdPtr!.pointee)
            break

        // entity APIs
        case .setEntityTransforms:
            var lengthPtr: UnsafeMutablePointer<Int32>?
            var ids: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            var positions: UnsafeMutableBufferPointer<PolySpatialVec3>?
            var rotations: UnsafeMutableBufferPointer<PolySpatialQuaternion>?
            var scales: UnsafeMutableBufferPointer<PolySpatialVec3>?
            ExtractArgs(argCount, args, argSizes, &lengthPtr, &ids, &positions, &rotations, &scales)
            SetEntityTransforms(.init(ids!), .init(positions!), .init(rotations!), .init(scales!))
            break

        case .addEntities:
            var lengthPtr: UnsafeMutablePointer<Int32>?
            var ids: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            ExtractArgs(argCount, args, argSizes, &lengthPtr, &ids)
            AddEntities(.init(ids!))
            break
        case .deleteEntities:
            var lengthPtr: UnsafeMutablePointer<Int32>?
            var ids: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            ExtractArgs(argCount, args, argSizes, &lengthPtr, &ids)
            deleteEntities(.init(ids!))
            break
        case .createOrUpdateVolumeCamera:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateVolumeCamera)
            break
        case .destroyVolumeCamera:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyVolumeCamera)
            break
        case .setEntitiesState:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: SetEntityState)
            break
        case .setEntityParents:
            var lengthPtr: UnsafeMutablePointer<Int32>?
            var ids: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            var parentIds: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            ExtractArgs(argCount, args, argSizes, &lengthPtr, &ids, &parentIds)
            SetEntityParents(.init(ids!), .init(parentIds!))
            break
        case .setEntityDebugInfo:
            var idPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
            var namePtr: UnsafeMutableBufferPointer<UInt8>?
            ExtractArgs(argCount, args, argSizes, &idPtr, &namePtr)
            SetEntityDebugInfo(idPtr!.pointee, namePtr!)
            break
        case .addEntitiesWithTransforms:
            var lengthPtr: UnsafeMutablePointer<Int32>?
            var ids: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            var parents: UnsafeMutableBufferPointer<PolySpatialInstanceID>?
            var positions: UnsafeMutableBufferPointer<PolySpatialVec3>?
            var rotations: UnsafeMutableBufferPointer<PolySpatialQuaternion>?
            var scales: UnsafeMutableBufferPointer<PolySpatialVec3>?
            var states: UnsafeMutableBufferPointer<PolySpatialGameObjectData>?
            ExtractArgs(argCount, args, argSizes, &lengthPtr, &ids, &parents, &positions, &rotations, &scales, &states)
            AddEntitiesWithTransforms(.init(ids!), .init(parents!), .init(positions!), .init(rotations!), .init(scales!), .init(states!))
            break
        case .createOrUpdateLight:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateLight)
            break
        case .destroyLight:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyLight)
            break
        case .createOrUpdateCollider:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateCollider)
            break
        case .destroyCollider:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyCollider)
            break
        case .createOrUpdateVideoPlayer:
            HandleChangeListSerializedArg(argCount, args, argSizes, entryCallback: createOrUpdateVideoPlayer)
            break
        case .destroyVideoPlayer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyVideoPlayer)
            break
        case .createOrUpdateVisionOsnativeText:
            HandleChangeListSerializedArg(argCount, args, argSizes, entryCallback: createOrUpdateEntityText)
            break
        case .destroyVisionOsnativeText:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyEntityText)
            break
        case .createOrUpdateMeshRenderer:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: createOrUpdateMeshRenderer)
            break
        case .destroyMeshRenderer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyMeshRenderer)
            break
        case .createOrUpdateSkinnedMeshRenderer:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: createOrUpdateSkinnedMeshRenderer)
            break
        case .destroySkinnedMeshRenderer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroySkinnedMeshRenderer)
            break
        case .setSkinnedMeshBlendShapeData:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: setEntitySkinnedBlendShapeInfo)
            break
        case .createOrUpdateParticleSystem:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: particleManager.createOrUpdateParticleSystem)
            break
        case .createOrUpdateLineRenderer:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: lineRendererManager.createOrUpdateLineRenderer)
            break
        case .destroyLineRenderer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: lineRendererManager.destroyLineRenderer)
            break
        case .destroyParticleSystem:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: particleManager.destroyParticleSystem)
            break
        case .createOrUpdateCanvasRenderer:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: createOrUpdateCanvasRenderer)
            break
        case .destroyCanvasRenderer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyCanvasRenderer)
            break
        case .createOrUpdateAlignmentMarker:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateAlignmentMarker)
            break
        case .destroyAlignmentMarker:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyAlignmentMarker)
            break
        case .createOrUpdateSpriteRenderer:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: createOrUpdateSpriteRenderer)
        case .destroySpriteRenderer:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroySpriteRenderer)
            break
        case .createOrUpdateSpriteMask:
            HandleChangeListSerializedArg(argCount, args, argSizes,
                entryCallback: createOrUpdateSpriteMask)
        case .destroySpriteMask:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroySpriteMask)
            break
        case .createOrUpdateVisionOssortingGroup:
            HandleChangeListSerializedArg(argCount, args, argSizes, entryCallback: createOrUpdateSortingGroup)
            break
        case .destroyVisionOssortingGroup:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroySortingGroup)
            break
        case .createOrUpdateUigraphic:
            HandleChangeListArg(argCount, args, argSizes,
                entryCallback: createOrUpdateUIGraphic)
            break
        case .destroyUigraphic:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyUIGraphic)
            break
        case .createOrUpdateVisionOshoverEffect:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateHoverEffect)
            break
        case .destroyVisionOshoverEffect:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyHoverEffect)
            break
        case .createOrUpdateVisionOsbillboard:
            HandleChangeListArg(argCount, args, argSizes,
                entryCallback: createOrUpdateBillboard)
            break
        case .destroyVisionOsbillboard:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyBillboard)
            break
        case .createOrUpdateVisionOsgroundingShadow:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateGroundingShadow)
            break
        case .destroyVisionOsgroundingShadow:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyGroundingShadow)
            break
        case .createOrUpdateVisionOsimageBasedLight:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateImageBasedLight)
            break
        case .destroyVisionOsimageBasedLight:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyImageBasedLight)
            break
        case .createOrUpdateVisionOsimageBasedLightReceiver:
            HandleChangeListArg(argCount, args, argSizes, entryCallback: createOrUpdateImageBasedLightReceiver)
            break
        case .destroyVisionOsimageBasedLightReceiver:
            handleDestroyListArg(argCount, args, argSizes, entryCallback: destroyImageBasedLightReceiver)
            break
        case .createOrUpdateVisionOsenvironmentLightingConfiguration:
            HandleChangeListArg(
                argCount, args, argSizes, entryCallback: createOrUpdateEnvironmentLightingConfiguration)
            break
        case .destroyVisionOsenvironmentLightingConfiguration:
            handleDestroyListArg(
                argCount, args, argSizes, entryCallback: destroyEnvironmentLightingConfiguration)
            break
        case .deleteComponent:
            var instanceIdPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
            var typePtr: UnsafeMutablePointer<Int32>?
            ExtractArgs(argCount, args, argSizes, &instanceIdPtr, &typePtr)
            DeleteComponent(instanceIdPtr!.pointee, typePtr!.pointee)
            break
        case .echoConsoleLogMessage:
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &data)
            let consoleLogMessageData: PolySpatialConsoleLogMessageData = getRoot(byteBuffer: &data!)
            UpdateConsoleLogMessages(consoleLogMessageData)
            break;
        case .beginAppFrame:
            frameCount += 1
        case .endAppFrame:
            PolySpatialWindowManager.shared.matchVolumesAndWindows()
            StaticBatchManager.instance.updateStaticBatches()
            particleManager.updateSubEmitters()
            NotifyTextureObservers()
            NotifyCollisionObservers()
        case .screenshot:
            var buf = ByteBuffer(assumingMemoryBound: args![0]!, capacity: Int(argSizes![0]))
            let ssRequest: PolySpatialScreenshotRequest = getRoot(byteBuffer: &buf)
            takeScreenshot(ssRequest)

        // VisionOS doesn't handle these commands, but we don't need to issue a warning about them.
        case .createOrUpdateCamera, .destroyCamera, .setRenderSettings:
            break

        // The following assets are known, but not supported.
        case .createOrUpdateRenderingVolumeProfileAsset, .createOrUpdateTmpFontAsset:
            var assetIdPtr: UnsafeMutablePointer<PolySpatialAssetID>?
            var data: ByteBuffer?
            ExtractArgs(argCount, args, argSizes, &assetIdPtr, &data)

            // We don't do anything with these assets (yet), but we need a deleter to avoid throwing an error when
            // we receive the corresponding deleteAsset message.
            assetDeleters[assetIdPtr!.pointee] = { _ in }
            break

        case .createOrUpdateRenderingVolume, .destroyRenderingVolume:
            LogWarning("RealityKit does not support UnityEngine.Rendering.Volumes.")

        // Any other commands will generate an error.
        default:
            LogError("Unknown command: \(String(describing: cmd)).  Add to PolySpatialRealityKit.OnSendClientCommand.")
            break
        }
    }
}
