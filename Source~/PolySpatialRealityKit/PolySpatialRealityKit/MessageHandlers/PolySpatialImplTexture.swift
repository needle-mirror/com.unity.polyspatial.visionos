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

    func CreateOrUpdateTextureAsset(_ id: PolySpatialAssetID, _ texdata: PolySpatialTextureData, _ pixelData: UnsafeMutableRawBufferPointer?) -> Bool {
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
            switch UnityGraphicsFormat(rawValue: Int32(texdata.unityGraphicsFormat)) {
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
                case .texture2D: try! .init(image: createImage(0), options: options)
                case .textureCube: try! .cube(slices: createSlices(), options: options)
                case .texture2Darray: try! .texture2DArray(slices: createSlices(), options: options)
                case .texture3D: try! .texture3D(slices: createSlices(), options: options)
            }

            let sampler = CreateTextureSampler(texdata.filterMode, texdata.wrapModeU, texdata.wrapModeV)
            let size = simd_make_float3(Float(texdata.width), Float(texdata.height), Float(texdata.depth))

            UpdateTextureDefinition(id, .init(.init(rsrc, sampler: sampler), size))

            return true
        }

        let graphicsFormat = UnityGraphicsFormat.init(rawValue: Int32(texdata.unityGraphicsFormat))
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

        do {
            let rsrc: TextureResource = switch texdata.shape {
                case .texture2D: try .init(
                    dimensions: .dimensions(width: Int(texdata.width), height: Int(texdata.height)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mipsAsBuffer!.map { mip in
                        .mip(unsafeBuffer: mbuf, offset: Int(mip.dataOffset), size: Int(mip.dataSize),
                            bytesPerRow: Int(mip.bytesPerRow))
                    }))
                case .textureCube: try .init(
                    dimensions: .dimensions(faceSize: Int(texdata.width)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mipsAsBuffer!.map { mip in
                        .mip(slices: (0..<6).map { slice in
                            .slice(unsafeBuffer: mbuf, offset: Int(mip.dataOffset) + slice * Int(mip.bytesPerImage),
                                size: Int(mip.bytesPerImage), bytesPerRow: Int(mip.bytesPerRow))
                        })
                    }))
                case .texture2Darray: try .init(
                    dimensions: .dimensions(
                        width: Int(texdata.width), height: Int(texdata.height), length: Int(texdata.depth)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mipsAsBuffer!.map { mip in
                        .mip(slices: (0..<Int(texdata.depth)).map { slice in
                            .slice(unsafeBuffer: mbuf, offset: Int(mip.dataOffset) + slice * Int(mip.bytesPerImage),
                                size: Int(mip.bytesPerImage), bytesPerRow: Int(mip.bytesPerRow))
                        })
                    }))
                case .texture3D: try .init(
                    dimensions: .dimensions(
                        width: Int(texdata.width), height: Int(texdata.height), depth: Int(texdata.depth)),
                    format: .raw(pixelFormat: metalFormat),
                    contents: .init(mipmapLevels: texdata.mipsAsBuffer!.map { mip in
                        .mip(unsafeBuffer: mbuf, offset: Int(mip.dataOffset), size: Int(mip.dataSize),
                            bytesPerRow: Int(mip.bytesPerRow), bytesPerImage: Int(mip.bytesPerImage))
                    }))
            }

            let sampler = CreateTextureSampler(texdata.filterMode, texdata.wrapModeU, texdata.wrapModeV)
            UpdateTextureDefinition(id, .init(.init(rsrc, sampler: sampler),
                .init(Float(texdata.width), Float(texdata.height), Float(texdata.depth))))
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
