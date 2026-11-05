import Foundation
import RealityKit
import UIKit
@_implementationOnly
import PolySpatialRealityKitC

class PolySpatialStreamingTextureSystem: System {
    required init(scene: Scene) {
    }

    func update(context: SceneUpdateContext) {
        PolySpatialRealityKit.instance.copyStreamingTextures()
    }
}

extension PolySpatialTextureFilterMode {
    func rkMinMag() -> MTLSamplerMinMagFilter {
        switch self {
            case .point: return .nearest
            case .bilinear, .trilinear: return .linear
        }
    }

    func rkMip() -> MTLSamplerMipFilter {
        switch self {
            case .point, .bilinear: return .nearest
            case .trilinear: return .linear
        }
    }
}

extension PolySpatialTextureWrapMode {
    func rk() -> MTLSamplerAddressMode {
        switch self {
            case .repeat_: return .repeat
            case .clamp: return .clampToEdge
            case .mirror: return .mirrorRepeat
            case .mirrorOnce: return .mirrorClampToEdge
        }
    }
}

extension PolySpatialRealityKit {
    // We don't really delete the asset, we just remove it from the
    // cache. Any entity still using the asset will keep it around
    // until that entity is either destroyed or someone changes the
    // assigned asset for it.
    func DeleteTextureAsset(_ id: PolySpatialAssetID) {
        guard textureAssets[id] != nil else {
            return
        }
        textureAssets.removeValue(forKey: id)
        streamingTextures.removeValue(forKey: id)
        textureObservers.removeValue(forKey: id)
    }

    static func unityToMetalFormat(_ ufmt: UnityGraphicsFormat, _ isAppleGPU: Bool = true) -> (MTLPixelFormat, UnityGraphicsFormat) {
        var conversionFormat = kFormatNone
        let mfmt = UnityGraphicsFormatToMetalPixelFormat(ufmt, isAppleGPU, &conversionFormat)

        return (mfmt, conversionFormat)
    }

    func CreateUninitializedTextureAsset(_ id: PolySpatialAssetID) -> TextureAsset {
        UpdateTextureDefinition(id, .init(.init(createTextureResource(
            magentaImage, .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll)))))
        return textureAssets[id]!
    }

    // Scratch and backing texture reused across an asset's dirty-region updates. Both are full-size, so
    // allocating them per update (and seeding the scratch with a whole-texture copy) would cost more than the
    // whole-texture upload this path replaces.
    // The bytes of the last whole-texture upload, with each level's position in them. applyDirtyRegions seeds
    // its scratch from this instead of copying the published resource back off the GPU.
    struct WholeTextureMirror {
        let bytes: [UInt8]
        // offset/bytesPerRow per mip level, in level order.
        let levels: [(offset: Int, bytesPerRow: Int)]
        let pixelFormat: MTLPixelFormat
        let width: Int
        let height: Int
    }

    @MainActor
    class DirtyRegionTextureState {
        // CPU-writable mirror of the texture's current contents, patched a rect at a time.
        let scratch: MTLTexture
        let lowLevelTexture: LowLevelTexture
        // The resource published from lowLevelTexture. A whole-texture update swaps the asset's resource without
        // going through us, so an identity mismatch means scratch no longer mirrors what's on screen.
        let resource: TextureResource
        // What the last blit wrote to. If replace(using:) hands back a different MTLTexture, it holds none of our
        // pixels and every level has to be blitted rather than just the patched rects.
        var destTexture: MTLTexture?
        // That blit reads scratch on the GPU, so it has to finish before the CPU patches scratch again.
        var blit: MTLCommandBuffer?

        init(scratch: MTLTexture, lowLevelTexture: LowLevelTexture, resource: TextureResource) {
            self.scratch = scratch
            self.lowLevelTexture = lowLevelTexture
            self.resource = resource
        }

        func matches(
            _ liveResource: TextureResource, _ pixelFormat: MTLPixelFormat, _ width: Int, _ height: Int,
            _ mipmapLevelCount: Int) -> Bool {
            resource === liveResource && scratch.pixelFormat == pixelFormat && scratch.width == width
                && scratch.height == height && scratch.mipmapLevelCount == mipmapLevelCount
        }
    }

    // Allocates the scratch and LowLevelTexture that applyDirtyRegions reuses, seeding the scratch from the
    // current contents so pixels no region touches survive. The caller publishes the resource once it has
    // blitted the seeded contents into the LowLevelTexture.
    func createDirtyRegionState(
        _ asset: TextureAsset, _ metalFormat: MTLPixelFormat, _ width: Int, _ height: Int,
        _ mipmapLevelCount: Int) -> DirtyRegionTextureState? {
        // Scratch texture we can both CPU-write (replace(region:)) and GPU mip-generate. Shared storage so the
        // CPU sub-rect copies are valid. An invalid metalFormat is caught here.
        let scratchDescriptor = MTLTextureDescriptor()
        scratchDescriptor.textureType = .type2D
        scratchDescriptor.pixelFormat = metalFormat
        scratchDescriptor.width = width
        scratchDescriptor.height = height
        scratchDescriptor.mipmapLevelCount = mipmapLevelCount
        scratchDescriptor.storageMode = .shared
        scratchDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let scratch = mtlDevice!.makeTexture(descriptor: scratchDescriptor) else { return nil }

        // Seed from the CPU mirror of the last whole-texture upload rather than copying the published resource back
        // with TextureResource.copy(to:). That copy runs on the GPU and returns success while writing nothing on
        // some devices -- CI publishes a texture blank apart from the rects each update patched, while the same
        // commit, SDK and runtime seed correctly on local hardware. A CPU write into shared storage has no such
        // failure mode. No mirror means we cannot reconstruct the untouched texels, so give up on patching: the
        // caller reports the upload as failed, which drops the host's baseline and resends the whole texture.
        // Patching an unseeded scratch would publish garbage for every untouched texel.
        guard let mirror = asset.wholeTextureMirror,
            mirror.pixelFormat == metalFormat, mirror.width == width, mirror.height == height,
            mirror.levels.count >= mipmapLevelCount else {
            LogWarning("Cannot seed the dirty-region scratch: no matching whole-texture mirror for this asset.")
            return nil
        }
        mirror.bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            for level in 0..<mipmapLevelCount {
                scratch.replace(
                    region: MTLRegionMake2D(0, 0, max(1, width >> level), max(1, height >> level)),
                    mipmapLevel: level,
                    withBytes: base + mirror.levels[level].offset,
                    bytesPerRow: mirror.levels[level].bytesPerRow)
            }
        }

        guard let lowLevelTexture = try? LowLevelTexture(descriptor: .init(
                textureType: .type2D,
                pixelFormat: metalFormat,
                width: width,
                height: height,
                mipmapLevelCount: mipmapLevelCount,
                textureUsage: .shaderRead)),
            let resource = try? TextureResource(from: lowLevelTexture) else {
            return nil
        }

        return .init(scratch: scratch, lowLevelTexture: lowLevelTexture, resource: resource)
    }

    // Applies app-supplied dirty regions (texdata.dirtyRegions) into an existing texture, each at its own mip level.
    // pixelData holds only the changed-region bytes, concatenated: each region's bytes start at its dataOffset
    // and are tightly packed (width * bytesPerPixel per row, height rows). We CPU-copy each region into its level
    // of the asset's cached scratch texture, then blit the patched rects into the cached LowLevelTexture backing the
    // published resource. A payload that carried no lower-mip regions (a mipmapped RenderTexture, whose partials are
    // mip-0 only) has its chain regenerated from mip 0 instead. Returns false (caller falls back to a whole-texture
    // upload) when there is no compatible cached asset, the format isn't a directly-copyable raw format, or any
    // Metal resource can't be created.
    func applyDirtyRegions(
        _ id: PolySpatialAssetID, _ texdata: PolySpatialTextureData,
        _ pixelData: UnsafeMutableRawBufferPointer?) -> Bool {
        guard let pixelData, let pixelBase = pixelData.baseAddress else { return false }

        // Only an existing 2D texture can be partially updated in place.
        guard let asset = textureAssets[id], texdata.shape == .texture2D || texdata.shape == .renderTexture else {
            return false
        }

        // The sender only emits partials in a directly-copyable raw format; an invalid metalFormat is caught when
        // the scratch texture is created.
        let graphicsFormat = UnityGraphicsFormat(rawValue: texdata.unityGraphicsFormat.rawValue)
        let (metalFormat, _) = PolySpatialRealityKit.unityToMetalFormat(graphicsFormat)

        let width = Int(texdata.width)
        let height = Int(texdata.height)

        // Derive bytes-per-pixel from mip 0's row stride, exactly as the sender does (bytesPerRow == width * bpp
        // for uncompressed formats). mips[] always carries the full-texture dimensions.
        guard let mip0 = texdata.mips.first, mip0.width > 0, mip0.bytesPerRow > 0,
            Int(mip0.bytesPerRow) % Int(mip0.width) == 0 else {
            return false
        }
        let bytesPerPixel = Int(mip0.bytesPerRow) / Int(mip0.width)

        let mipmapLevelCount = asset.texture.resource.mipmapLevelCount
        let isMipMapped = mipmapLevelCount > 1

        // Reuse the scratch and backing texture from previous updates while they still describe this texture; the
        // scratch already holds its contents, so steady state allocates nothing and copies only the dirty rects.
        var state = asset.dirtyRegionState
        if let current = state,
            !current.matches(asset.texture.resource, metalFormat, width, height, mipmapLevelCount) {
            state = nil
        }
        let isNewState = state == nil
        if isNewState {
            state = createDirtyRegionState(asset, metalFormat, width, height, mipmapLevelCount)
        }
        guard let state else { return false }

        // The previous update's blit reads the scratch, so let it finish before overwriting rects in it.
        state.blit?.waitUntilCompleted()
        state.blit = nil

        // CPU-copy each region's tightly-packed bytes into its own mip level of the scratch texture. Each region is
        // addressed against that level's dimensions.
        var patchedRegions: [(level: Int, region: MTLRegion)] = []
        var patchedLowerMip = false
        for index in 0..<texdata.dirtyRegions.count {
            let region = texdata.dirtyRegions[index]
            let level = Int(region.mipIndex)
            if level < 0 || level >= mipmapLevelCount {
                // Dropping a region silently leaves that level stale with no way to tell from the rendered result.
                LogWarning(
                    "Dropping dirty region for \(id): mip \(level) is outside the texture's \(mipmapLevelCount) " +
                    "level(s).")
                continue
            }
            let levelWidth = max(1, width >> level)
            let levelHeight = max(1, height >> level)
            let rx = Int(region.x)
            let ry = Int(region.y)
            let rw = Int(region.width)
            let rh = Int(region.height)
            if rw <= 0 || rh <= 0 || rx < 0 || ry < 0 || rx + rw > levelWidth || ry + rh > levelHeight {
                // Same here: a rect that doesn't fit its level would otherwise be dropped without a trace.
                LogWarning(
                    "Dropping dirty region for \(id): rect \(rx),\(ry) \(rw)x\(rh) does not fit mip \(level) " +
                    "(\(levelWidth)x\(levelHeight)).")
                continue
            }
            let bytesPerRow = rw * bytesPerPixel
            let regionSize = bytesPerRow * rh
            let dataOffset = Int(region.dataOffset)
            if dataOffset < 0 || dataOffset + regionSize > pixelData.count {
                // And here: a payload that can't hold the region's bytes must not fail quietly.
                LogWarning(
                    "Dropping dirty region for \(id): mip \(level) wants \(regionSize) byte(s) at offset " +
                    "\(dataOffset), past the \(pixelData.count)-byte payload.")
                continue
            }
            let mtlRegion = MTLRegionMake2D(rx, ry, rw, rh)
            state.scratch.replace(
                region: mtlRegion,
                mipmapLevel: level,
                withBytes: pixelBase + dataOffset,
                bytesPerRow: bytesPerRow)
            patchedRegions.append((level, mtlRegion))
            if level > 0 {
                patchedLowerMip = true
            }
        }

        let commandBuffer = mtlCommandQueue!.makeCommandBuffer()!
        let destTexture = state.lowLevelTexture.replace(using: commandBuffer)
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return false }
        // A mip-0-only payload has its chain regenerated from mip 0; a per-mip payload carries every level.
        let regenerateMips = isMipMapped && !patchedLowerMip
        if state.destTexture === destTexture {
            // The backing texture still holds what we last blitted, so only the patched rects have to move.
            for patched in patchedRegions {
                blitEncoder.copy(
                    from: state.scratch, sourceSlice: 0, sourceLevel: patched.level,
                    sourceOrigin: patched.region.origin,
                    sourceSize: patched.region.size,
                    to: destTexture, destinationSlice: 0, destinationLevel: patched.level,
                    destinationOrigin: patched.region.origin)
            }
        } else {
            // First blit into this texture: it holds none of our pixels, so seed the levels we own from the scratch.
            for level in 0..<(regenerateMips ? 1 : mipmapLevelCount) {
                blitEncoder.copy(
                    from: state.scratch, sourceSlice: 0, sourceLevel: level,
                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSize(width: max(1, width >> level), height: max(1, height >> level), depth: 1),
                    to: destTexture, destinationSlice: 0, destinationLevel: level,
                    destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
            }
        }
        if regenerateMips {
            blitEncoder.generateMipmaps(for: destTexture)
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        state.destTexture = destTexture
        state.blit = commandBuffer

        if isNewState {
            // Publish now that the seeded contents have been blitted. Replacing the TextureResource (rather than
            // relying on replace(with: LowLevelTexture)) keeps the shader graph parameters in sync (see FB16501956).
            asset.texture.resource = state.resource
            asset.lowLevelTexture = state.lowLevelTexture
            asset.dirtyRegionState = state
        }
        asset.cgImage = nil
        asset.flipped = nil
        UpdateTextureDefinition(id, asset)
        return true
    }

    func CreateOrUpdateTextureAsset(_ id: PolySpatialAssetID, _ texdata: PolySpatialTextureData, _ pixelData: UnsafeMutableRawBufferPointer?) -> Bool {
        // The optional dirtyRegions vector describes the changed sub-regions of the texture. When absent (or
        // empty), the entire texture is considered dirty. When present, pixelData carries only the concatenated
        // region bytes; apply them in place at each region's mip level. Do NOT fall through to the
        // whole-texture path on failure — pixelData is region-only, so that path (CFData / Metal mip mappings
        // using the full dataSize/dataOffset) would read out of bounds. Drop the update instead.
        if texdata.dirtyRegions.count > 0 {
            if applyDirtyRegions(id, texdata, pixelData) {
                return true
            }
            LogWarning("Dropping dirty-region texture update for \(id): could not apply regions in place.")
            return false
        }

        // We can only handle "fallback" textures: textures with no mipmaps
        // (because we will generate them) in one of two basic formats.
        if texdata.fallbackMode != .none_ {
            if let cachedAsset = textureAssets[id] {
                if cachedAsset.lowLevelTexture != nil || cachedAsset.texture.resource.drawableQueue != nil {
                    // Ignore fallback data for native/streaming textures.
                    return true
                }
            }
            var semantic: TextureResource.Semantic
            switch UnityGraphicsFormat(rawValue: texdata.unityGraphicsFormat.rawValue) {
                case kFormatB8G8R8A8_SRGB:
                    semantic = .color

                case kFormatB8G8R8A8_UNorm:
                    semantic = .raw

                default:
                    return false
            }
            let width = Int(texdata.width)
            let height = Int(texdata.height)
            let depth = Int(texdata.depth)

            let bytesPerRow = width * 4
            let bytesPerImage = height * bytesPerRow

            var bitmapInfoRaw: UInt32 = 0
            bitmapInfoRaw += CGImageAlphaInfo.first.rawValue
            bitmapInfoRaw += CGBitmapInfo.byteOrder32Little.rawValue

            func createImage(_ offset: Int) -> CGImage {
                let cfData = CFDataCreate(nil, pixelData!.baseAddress! + offset, bytesPerImage)
                return .init(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpace.init(name: CGColorSpace.displayP3)!,
                    bitmapInfo: .init(rawValue: bitmapInfoRaw),
                    provider: .init(data: cfData!)!,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: CGColorRenderingIntent.defaultIntent)!
            }

            func createSlices() -> [CGImage] {
                (0..<depth).map { createImage($0 * bytesPerImage) }
            }

            let mipmapsMode: TextureResource.MipmapsMode = switch texdata.fallbackMode {
                case .generateAllMips: .allocateAndGenerateAll
                default: .none
            }
            let options = TextureResource.CreateOptions(semantic: semantic, mipmapsMode: mipmapsMode)

            let rsrc: TextureResource = switch texdata.shape {
                case .texture2D, .renderTexture: try! .init(image: createImage(0), options: options)
                case .textureCube: try! .cube(slices: createSlices(), options: options)
                case .texture2Darray: try! .texture2DArray(slices: createSlices(), options: options)
                case .texture3D: try! .texture3D(slices: createSlices(), options: options)
                case .textureCubeArray: fatalError("Cube array textures not supported")
            }

            let sampler = CreateTextureSampler(texdata.filterMode, texdata.wrapModeU, texdata.wrapModeV)
            let size = simd_make_float3(Float(texdata.width), Float(texdata.height), Float(texdata.depth))

            UpdateTextureDefinition(id, .init(.init(rsrc, sampler: sampler), size))

            return true
        }

        let graphicsFormat = UnityGraphicsFormat.init(rawValue: texdata.unityGraphicsFormat.rawValue)
        let (metalFormat, conversionFormat) = PolySpatialRealityKit.unityToMetalFormat(graphicsFormat)

        if conversionFormat != graphicsFormat {
            LogWarning("Texture data conversion required for \(id): \(graphicsFormat) -> \(conversionFormat).  Not supported yet, falling back to readback.")
            return false
        }

        if metalFormat == MTLPixelFormat.invalid {
            LogError("Got MTLPixelFormat.invalid for GraphicsFormat \(graphicsFormat)!", false)
            return false
        }

        // Create the metal-side buffer and copy in our raw texture data
        // Note: Int/UInt are native-pointer-sized ints in swift
        let mbuf = mtlDevice!.makeBuffer(bytes: pixelData!.baseAddress!,
                                         length: pixelData!.count,
                                         options: .storageModeShared)!

        // Keep the payload so a later partial can seed its scratch from it (createDirtyRegionState). Only 2D
        // shapes take the dirty-region path, so only they are worth mirroring.
        var wholeTextureMirror: WholeTextureMirror?
        if texdata.shape == .texture2D || texdata.shape == .renderTexture {
            wholeTextureMirror = .init(
                bytes: [UInt8](UnsafeRawBufferPointer(start: pixelData!.baseAddress!, count: pixelData!.count)),
                levels: texdata.mips.map { (offset: Int($0.dataOffset), bytesPerRow: Int($0.bytesPerRow)) },
                pixelFormat: metalFormat,
                width: Int(texdata.width),
                height: Int(texdata.height))
        }

        do {
            let rsrc: TextureResource = switch texdata.shape {
                // Treat render texture like we would a texture2D in RK.
                case .texture2D, .renderTexture: try .init(
                    dimensions: .dimensions(width: Int(texdata.width), height: Int(texdata.height)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mips.map { mip in
                        .mip(unsafeBuffer: mbuf, offset: Int(mip.dataOffset), size: Int(mip.dataSize),
                            bytesPerRow: Int(mip.bytesPerRow))
                    }))
                case .textureCube: try .init(
                    dimensions: .dimensions(faceSize: Int(texdata.width)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mips.map { mip in
                        .mip(slices: (0..<6).map { slice in
                            .slice(unsafeBuffer: mbuf, offset: Int(mip.dataOffset) + slice * Int(mip.bytesPerImage),
                                size: Int(mip.bytesPerImage), bytesPerRow: Int(mip.bytesPerRow))
                        })
                    }))
                case .texture2Darray: try .init(
                    dimensions: .dimensions(
                        width: Int(texdata.width), height: Int(texdata.height), length: Int(texdata.depth)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mips.map { mip in
                        .mip(slices: (0..<Int(texdata.depth)).map { slice in
                            .slice(unsafeBuffer: mbuf, offset: Int(mip.dataOffset) + slice * Int(mip.bytesPerImage),
                                size: Int(mip.bytesPerImage), bytesPerRow: Int(mip.bytesPerRow))
                        })
                    }))
                case .texture3D: try .init(
                    dimensions: .dimensions(
                        width: Int(texdata.width), height: Int(texdata.height), depth: Int(texdata.depth)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mips.map { mip in
                        .mip(unsafeBuffer: mbuf, offset: Int(mip.dataOffset), size: Int(mip.dataSize),
                            bytesPerRow: Int(mip.bytesPerRow), bytesPerImage: Int(mip.bytesPerImage))
                    }))
                case .textureCubeArray: fatalError("Cube array textures not supported")
            }

            let sampler = CreateTextureSampler(texdata.filterMode, texdata.wrapModeU, texdata.wrapModeV)
            let asset = TextureAsset(.init(rsrc, sampler: sampler),
                .init(Float(texdata.width), Float(texdata.height), Float(texdata.depth)))
            asset.wholeTextureMirror = wholeTextureMirror
            UpdateTextureDefinition(id, asset)
        } catch {
            LogError("Failed to create native texture asset \(id): \(error)")
            return false
        }

        return true
    }

    func CreateOrUpdateNativeTextureAsset(
        _ id: PolySpatialAssetID, _ texturePtr: UnsafePointer<PolySpatialNativeTextureData>?) -> Bool {

        let texdata = texturePtr!.pointee
        let rawPointer = UnsafeRawPointer(bitPattern: UInt(texdata.nativeTexturePtr))
        let nativeTexture = Unmanaged<MTLTexture>.fromOpaque(rawPointer!).takeUnretainedValue()
        let size = simd_float3(Float(texdata.width), Float(texdata.height), Float(texdata.depth))
        let sampler = CreateTextureSampler(texdata.filterMode, texdata.wrapModeU, texdata.wrapModeV, texdata.wrapModeW)
        let currentAsset = textureAssets[id]

        // Streaming 2D textures use the older (and faster, but likely less memory efficient) DrawableQueue API.
        if texdata.isStreaming && nativeTexture.textureType == .type2D {
            let asset: TextureAsset
            if let currentAsset {
                currentAsset.size = size
                currentAsset.texture.sampler = sampler
                asset = currentAsset

            } else {
                // Start with a placeholder texture, as there's no way to create a
                // TextureResource directly from a DrawableQueue.
                asset = .init(.init(
                    createTextureResource(magentaImage, .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll)),
                    sampler: sampler), size)
                UpdateTextureDefinition(id, asset)
            }

            let mipmapsMode: TextureResource.MipmapsMode = (nativeTexture.mipmapLevelCount != 1) ? .allocateAll : .none
            if let currentDrawableQueue = asset.texture.resource.drawableQueue,
                currentDrawableQueue.pixelFormat == nativeTexture.pixelFormat,
                currentDrawableQueue.width == nativeTexture.width,
                currentDrawableQueue.height == nativeTexture.height,
                currentDrawableQueue.mipmapsMode == mipmapsMode {} else {

                // Replace the DrawableQueue unless its properties match those of the native texture.
                let drawableQueueDescriptor: TextureResource.DrawableQueue.Descriptor = .init(
                    pixelFormat: nativeTexture.pixelFormat,
                    width: nativeTexture.width,
                    height: nativeTexture.height,
                    usage: [.shaderRead, .renderTarget],
                    mipmapsMode: mipmapsMode)

                asset.texture.resource.replace(
                    withDrawables: try! TextureResource.DrawableQueue(drawableQueueDescriptor))
            }

            // Store the native texture to be copied in copyStreamingTextures.
            streamingTextures[id] = nativeTexture

            return true
        }

        // Non-streaming textures use the LowLevelTexture API.
        let lowLevelTexture: LowLevelTexture
        if let currentAsset, let currentLowLevelTexture = currentAsset.lowLevelTexture,
            currentLowLevelTexture.descriptor.textureType == nativeTexture.textureType,
            currentLowLevelTexture.descriptor.pixelFormat == nativeTexture.pixelFormat,
            currentLowLevelTexture.descriptor.mipmapLevelCount == nativeTexture.mipmapLevelCount,
            currentAsset.size == size {

            // Reuse the current LowLevelTexture if its properties match.
            lowLevelTexture = currentLowLevelTexture

        } else {
            // Otherwise, create a new one.
            lowLevelTexture = try! .init(descriptor: .init(
                textureType: nativeTexture.textureType,
                pixelFormat: nativeTexture.pixelFormat,
                width: nativeTexture.width,
                height: nativeTexture.height,
                depth: nativeTexture.depth,
                mipmapLevelCount: nativeTexture.mipmapLevelCount,
                arrayLength: nativeTexture.arrayLength,
                textureUsage: .shaderRead))
        }

        if let currentAsset {
            // Update/replace the current asset, if any.
            if currentAsset.lowLevelTexture !== lowLevelTexture {
                // We should we able to call TextureResource.replace(with: LowLevelTexture), but for whatever
                // reason that doesn't update the shader graph parameters as expected.  Instead, we must
                // replace the TextureResource and notify the listeners.  Reported to Apple as FB16501956.
                currentAsset.texture.resource = try! .init(from: lowLevelTexture)
                currentAsset.size = size
                currentAsset.lowLevelTexture = lowLevelTexture

                updatedTextureAssets[id] = currentAsset
            }
            currentAsset.texture.sampler = sampler

        } else {
            // Otherwise, register a new one.
            UpdateTextureDefinition(
                id, .init(.init(try! .init(from: lowLevelTexture), sampler: sampler), size, lowLevelTexture))
        }

        // Blit the native MTLTexture to the LowLevelTexture.
        let commandBuffer = mtlCommandQueue!.makeCommandBuffer()!
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitCommandEncoder.copy(from: nativeTexture, to: lowLevelTexture.replace(using: commandBuffer))
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()

        return true
    }

    func UpdateTextureDefinition(_ id: PolySpatialAssetID, _ texture: TextureAsset) {
        textureAssets[id] = texture
        updatedTextureAssets[id] = texture
        assetDeleters[id] = DeleteTextureAsset
    }

    func NotifyTextureObservers() {
        var combinedObservers: Set<TextureObserverElement> = []

        for textureID in updatedTextureAssets.keys {
            if let observers = textureObservers[textureID] {
                combinedObservers.formUnion(observers)
            }
        }

        for element in combinedObservers {
            element.observer.texturesUpdated(updatedTextureAssets)
        }

        updatedTextureAssets.removeAll()
    }

    func CreateTextureSampler(
        _ filterMode: PolySpatialTextureFilterMode,
        _ wrapModeU: PolySpatialTextureWrapMode,
        _ wrapModeV: PolySpatialTextureWrapMode,
        _ wrapModeW: PolySpatialTextureWrapMode = .clamp) -> MaterialParameters.Texture.Sampler {

        let descriptor = MTLSamplerDescriptor()
        let minMagFilter = filterMode.rkMinMag()
        descriptor.minFilter = minMagFilter
        descriptor.magFilter = minMagFilter
        descriptor.mipFilter = filterMode.rkMip()
        descriptor.sAddressMode = wrapModeU.rk()
        descriptor.tAddressMode = wrapModeV.rk()
        descriptor.rAddressMode = wrapModeW.rk()

        return .init(descriptor)
    }

    @MainActor func copyStreamingTextures() {
        if (streamingTextures.isEmpty) {
            return
        }

        var drawables: [TextureResource.Drawable] = []
        var commandBuffer: MTLCommandBuffer?
        var blitCommandEncoder: MTLBlitCommandEncoder?
        var postponedStreamingTextures: [PolySpatialAssetID: MTLTexture] = [:]
        for (id, nativeTexture) in streamingTextures {
            let asset = textureAssets[id]!

            // If for some reason we are unable to get a drawable this frame, try again next time.
            // TODO (LXR-1761): Remove this check if and when it becomes unnecessary, because it
            // seems like a bug on the RealityKit side.
            guard let drawable = try? asset.texture.resource.drawableQueue!.nextDrawable() else {
                postponedStreamingTextures[id] = nativeTexture
                continue
            }

            if (commandBuffer == nil) {
                commandBuffer = mtlCommandQueue!.makeCommandBuffer()
                blitCommandEncoder = commandBuffer!.makeBlitCommandEncoder()
            }

            blitCommandEncoder!.copy(from: nativeTexture, to: drawable.texture)

            drawables.append(drawable)
        }

        if (commandBuffer != nil) {
            blitCommandEncoder!.endEncoding()
            commandBuffer!.commit()
            commandBuffer!.waitUntilCompleted()
            for drawable in drawables {
                drawable.presentOnSceneUpdate()
            }
        }

        streamingTextures = postponedStreamingTextures
    }

    func createFlipped(_ asset: TextureAsset) -> TextureResource {
        createTextureResource(
            asset.getCGImage(),
            .init(
                semantic: .raw,
                mipmapsMode: asset.texture.resource.mipmapLevelCount > 1 ? .allocateAndGenerateAll : .none))
    }

    func createTextureResource(_ image: CGImage, _ options: TextureResource.CreateOptions) -> TextureResource {
        try! .init(image: image, options: options)
    }

    func createCGImage(
        _ asset: TextureAsset, _ computePipelineState: MTLComputePipelineState, _ width: Int) -> CGImage {

        var sourceTexture: MTLTexture?

        if let lowLevelTexture = asset.lowLevelTexture {
            sourceTexture = lowLevelTexture.read()
        }

        if sourceTexture == nil {
            let sourceDescriptor = MTLTextureDescriptor()

            // On visionOS (only), the source texture should be a cube map if the resource is one.
            sourceDescriptor.textureType = asset.texture.resource.textureType

            sourceDescriptor.width = asset.texture.resource.width
            sourceDescriptor.height = asset.texture.resource.height
            sourceDescriptor.usage = [.shaderWrite, .shaderRead]
            sourceTexture = PolySpatialRealityKit.instance.mtlDevice!.makeTexture(descriptor: sourceDescriptor)!
            try! asset.texture.resource.copy(to: sourceTexture!)
        }

        let destDescriptor = MTLTextureDescriptor()
        destDescriptor.width = width
        destDescriptor.height = asset.texture.resource.height
        destDescriptor.usage = .shaderWrite
        let destTexture = PolySpatialRealityKit.instance.mtlDevice!.makeTexture(descriptor: destDescriptor)!

        let commandBuffer = mtlCommandQueue!.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder(dispatchType: .concurrent)!

        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(sourceTexture, index: 0)
        commandEncoder.setTexture(destTexture, index: 1)
        commandEncoder.dispatchThreadgroups(
            .init(width: destDescriptor.width, height: destDescriptor.height, depth: 1),
            threadsPerThreadgroup: .init(
                width: computePipelineState.threadExecutionWidth,
                height: computePipelineState.maxTotalThreadsPerThreadgroup / computePipelineState.threadExecutionWidth,
                depth: 1))

        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let data = CFDataCreateMutable(nil, 0)!
        let bytesPerRow = destDescriptor.width * 4
        let bytesPerImage = bytesPerRow * destDescriptor.height
        CFDataSetLength(data, bytesPerImage)

        destTexture.getBytes(
            .init(CFDataGetMutableBytePtr(data)),
            bytesPerRow: bytesPerRow,
            bytesPerImage: bytesPerImage,
            from: MTLRegionMake2D(0, 0, destDescriptor.width, destDescriptor.height),
            mipmapLevel: 0,
            slice: 0)

        return .init(
            width: destDescriptor.width,
            height: destDescriptor.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            // We end up in linear space (linearDisplayP3) because the sRGB formats aren't writable.
            space: CGColorSpace.init(name: CGColorSpace.linearDisplayP3)!,
            bitmapInfo: .init(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrderDefault.rawValue),
            provider: .init(data: data)!,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)!
    }
}
