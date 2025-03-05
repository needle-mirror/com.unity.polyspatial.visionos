#ifndef UnityGraphicsFormat_h
#define UnityGraphicsFormat_h

#import <Metal/Metal.h>

#ifdef __cplusplus
extern "C" {
#endif

// Keep in sync with Runtime/Graphics/Format.h
typedef enum UnityGraphicsFormat
{
    kFormatUnknown = -1,
    kFormatNone = 0, kFormatFirst = kFormatNone,

    // sRGB formats
    kFormatR8_SRGB,
    kFormatR8G8_SRGB,
    kFormatR8G8B8_SRGB,
    kFormatR8G8B8A8_SRGB,

    // 8 bit integer formats
    kFormatR8_UNorm,
    kFormatR8G8_UNorm,
    kFormatR8G8B8_UNorm,
    kFormatR8G8B8A8_UNorm,
    kFormatR8_SNorm,
    kFormatR8G8_SNorm,
    kFormatR8G8B8_SNorm,
    kFormatR8G8B8A8_SNorm,
    kFormatR8_UInt,
    kFormatR8G8_UInt,
    kFormatR8G8B8_UInt,
    kFormatR8G8B8A8_UInt,
    kFormatR8_SInt,
    kFormatR8G8_SInt,
    kFormatR8G8B8_SInt,
    kFormatR8G8B8A8_SInt,

    // 16 bit integer formats
    kFormatR16_UNorm,
    kFormatR16G16_UNorm,
    kFormatR16G16B16_UNorm,
    kFormatR16G16B16A16_UNorm,
    kFormatR16_SNorm,
    kFormatR16G16_SNorm,
    kFormatR16G16B16_SNorm,
    kFormatR16G16B16A16_SNorm,
    kFormatR16_UInt,
    kFormatR16G16_UInt,
    kFormatR16G16B16_UInt,
    kFormatR16G16B16A16_UInt,
    kFormatR16_SInt,
    kFormatR16G16_SInt,
    kFormatR16G16B16_SInt,
    kFormatR16G16B16A16_SInt,

    // 32 bit integer formats
    kFormatR32_UInt,
    kFormatR32G32_UInt,
    kFormatR32G32B32_UInt,
    kFormatR32G32B32A32_UInt,
    kFormatR32_SInt,
    kFormatR32G32_SInt,
    kFormatR32G32B32_SInt,
    kFormatR32G32B32A32_SInt,

    // HDR formats
    kFormatR16_SFloat,
    kFormatR16G16_SFloat,
    kFormatR16G16B16_SFloat,
    kFormatR16G16B16A16_SFloat,
    kFormatR32_SFloat,
    kFormatR32G32_SFloat,
    kFormatR32G32B32_SFloat,
    kFormatR32G32B32A32_SFloat,

    // Luminance and Alpha format
    kFormatL8_UNorm,
    kFormatA8_UNorm,
    kFormatA16_UNorm,

    // BGR formats
    kFormatB8G8R8_SRGB,
    kFormatB8G8R8A8_SRGB,
    kFormatB8G8R8_UNorm,
    kFormatB8G8R8A8_UNorm,
    kFormatB8G8R8_SNorm,
    kFormatB8G8R8A8_SNorm,
    kFormatB8G8R8_UInt,
    kFormatB8G8R8A8_UInt,
    kFormatB8G8R8_SInt,
    kFormatB8G8R8A8_SInt,

    // 16 bit packed formats
    kFormatR4G4B4A4_UNormPack16,
    kFormatB4G4R4A4_UNormPack16,
    kFormatR5G6B5_UNormPack16,
    kFormatB5G6R5_UNormPack16,
    kFormatR5G5B5A1_UNormPack16,
    kFormatB5G5R5A1_UNormPack16,
    kFormatA1R5G5B5_UNormPack16,

    // Packed formats
    kFormatE5B9G9R9_UFloatPack32,
    kFormatB10G11R11_UFloatPack32,

    kFormatA2B10G10R10_UNormPack32,
    kFormatA2B10G10R10_UIntPack32,
    kFormatA2B10G10R10_SIntPack32,
    kFormatA2R10G10B10_UNormPack32,
    kFormatA2R10G10B10_UIntPack32,
    kFormatA2R10G10B10_SIntPack32,
    kFormatA2R10G10B10_XRSRGBPack32,
    kFormatA2R10G10B10_XRUNormPack32,
    kFormatR10G10B10_XRSRGBPack32,
    kFormatR10G10B10_XRUNormPack32,
    kFormatA10R10G10B10_XRSRGBPack32,
    kFormatA10R10G10B10_XRUNormPack32,

    // ARGB formats... TextureFormat legacy
    kFormatA8R8G8B8_SRGB,
    kFormatA8R8G8B8_UNorm,
    kFormatA32R32G32B32_SFloat,

    // Depth Stencil for formats
    kFormatD16_UNorm,
    kFormatD24_UNorm,
    kFormatD24_UNorm_S8_UInt,
    kFormatD32_SFloat,
    kFormatD32_SFloat_S8_UInt,
    kFormatS8_UInt,

    // Compression formats
    kFormatRGBA_DXT1_SRGB, kFormatDXTCFirst = kFormatRGBA_DXT1_SRGB,
    kFormatRGBA_DXT1_UNorm,
    kFormatRGBA_DXT3_SRGB,
    kFormatRGBA_DXT3_UNorm,
    kFormatRGBA_DXT5_SRGB,
    kFormatRGBA_DXT5_UNorm, kFormatDXTCLast = kFormatRGBA_DXT5_UNorm,
    kFormatR_BC4_UNorm, kFormatRGTCFirst = kFormatR_BC4_UNorm,
    kFormatR_BC4_SNorm,
    kFormatRG_BC5_UNorm,
    kFormatRG_BC5_SNorm, kFormatRGTCLast = kFormatRG_BC5_SNorm,
    kFormatRGB_BC6H_UFloat, kFormatBPTCFirst = kFormatRGB_BC6H_UFloat,
    kFormatRGB_BC6H_SFloat,
    kFormatRGBA_BC7_SRGB,
    kFormatRGBA_BC7_UNorm, kFormatBPTCLast = kFormatRGBA_BC7_UNorm,

    kFormatRGB_PVRTC_2Bpp_SRGB, kFormatPVRTCFirst = kFormatRGB_PVRTC_2Bpp_SRGB,
    kFormatRGB_PVRTC_2Bpp_UNorm,
    kFormatRGB_PVRTC_4Bpp_SRGB,
    kFormatRGB_PVRTC_4Bpp_UNorm,
    kFormatRGBA_PVRTC_2Bpp_SRGB,
    kFormatRGBA_PVRTC_2Bpp_UNorm,
    kFormatRGBA_PVRTC_4Bpp_SRGB,
    kFormatRGBA_PVRTC_4Bpp_UNorm, kFormatPVRTCLast = kFormatRGBA_PVRTC_4Bpp_UNorm,

    kFormatRGB_ETC_UNorm, kFormatETCFirst = kFormatRGB_ETC_UNorm, kFormatETC1First = kFormatRGB_ETC_UNorm, kFormatETC1Last = kFormatRGB_ETC_UNorm,
    kFormatRGB_ETC2_SRGB, kFormatETC2First = kFormatRGB_ETC2_SRGB,
    kFormatRGB_ETC2_UNorm,
    kFormatRGB_A1_ETC2_SRGB,
    kFormatRGB_A1_ETC2_UNorm,
    kFormatRGBA_ETC2_SRGB,
    kFormatRGBA_ETC2_UNorm, kFormatETCLast = kFormatRGBA_ETC2_UNorm, kFormatETC2Last = kFormatRGBA_ETC2_UNorm,

    kFormatR_EAC_UNorm, kFormatEACFirst = kFormatR_EAC_UNorm,
    kFormatR_EAC_SNorm,
    kFormatRG_EAC_UNorm,
    kFormatRG_EAC_SNorm, kFormatEACLast = kFormatRG_EAC_SNorm,

    kFormatRGBA_ASTC4X4_SRGB, kFormatASTCFirst = kFormatRGBA_ASTC4X4_SRGB,
    kFormatRGBA_ASTC4X4_UNorm,
    kFormatRGBA_ASTC5X5_SRGB,
    kFormatRGBA_ASTC5X5_UNorm,
    kFormatRGBA_ASTC6X6_SRGB,
    kFormatRGBA_ASTC6X6_UNorm,
    kFormatRGBA_ASTC8X8_SRGB,
    kFormatRGBA_ASTC8X8_UNorm,
    kFormatRGBA_ASTC10X10_SRGB,
    kFormatRGBA_ASTC10X10_UNorm,
    kFormatRGBA_ASTC12X12_SRGB,
    kFormatRGBA_ASTC12X12_UNorm, kFormatASTCLast = kFormatRGBA_ASTC12X12_UNorm,

    // Video formats
    kFormatYUV2,

    // Automatic formats, back-end decides
    kFormatDepthAuto_removed_donotuse,
    kFormatShadowAuto_removed_donotuse,
    kFormatVideoAuto_removed_donotuse,

    kFormatRGBA_ASTC4X4_UFloat, kFormatASTCHDRFirst = kFormatRGBA_ASTC4X4_UFloat,
    kFormatRGBA_ASTC5X5_UFloat,
    kFormatRGBA_ASTC6X6_UFloat,
    kFormatRGBA_ASTC8X8_UFloat,
    kFormatRGBA_ASTC10X10_UFloat,
    kFormatRGBA_ASTC12X12_UFloat, kFormatASTCHDRLast = kFormatRGBA_ASTC12X12_UFloat,

    kFormatD16_UNorm_S8_UInt,

    kFormatLast = kFormatD16_UNorm_S8_UInt, // Remove?
} UnityGraphicsFormat;

MTLPixelFormat UnityGraphicsFormatToMetalPixelFormat(UnityGraphicsFormat fmt, bool isAppleGPU, UnityGraphicsFormat* outDstFormat);

// Keep in sync with Mono* types in SharedTextureData.h
typedef struct UnitySharedTextureData {
    void* opaquePtr;
    int32_t width;
    int32_t height;
    uint64_t imageSize;
    uint32_t imageCount;
    uint32_t mipCount;
    UnityGraphicsFormat format;
    void* data;
} UnitySharedTextureData;

typedef struct UnityImageReference {
    UnityGraphicsFormat format;
    int32_t width;
    int32_t height;
    int32_t pitch;
    int32_t dataSize;
    void* data;
} UnityImageReference;

#ifdef __cplusplus
}
#endif

#endif /* UnityGraphicsFormat_h */
