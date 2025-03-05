//
// This is a copy of the Unity conversion function, but with Unity specific #defines (e.g. PLATFORM_OSX)
// changed to generic ones.  We could probably switch the upstream to use the generic TARGET_ defines too.
//

#import <Foundation/Foundation.h>
#import "UnityGraphicsFormat.h"

MTLPixelFormat
UnityGraphicsFormatToMetalPixelFormat(UnityGraphicsFormat fmt, bool isAppleGPU, UnityGraphicsFormat* outDstFormat)
{
    *outDstFormat = fmt;

    if (isAppleGPU)
    {
        switch (fmt)
        {
// We're already doing a runtime check here and in metal::InitFormatUsageFlags for the basic set of pixel formats expected to work
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
            case kFormatR8_SRGB:        return MTLPixelFormatR8Unorm_sRGB;
            case kFormatR8G8_SRGB:      return MTLPixelFormatRG8Unorm_sRGB;

                // please note that for some weird reason we map kFormatB5G6R5_UNormPack16 to kTexFormatRGB565
                // but at the same time kFormatR4G4B4A4_UNormPack16 we map to kTexFormatRGBA4444
                // now i am honestly not sure which one should be correct but we MUST agree with TextureFormat for conversion to work
                // * i am totally lost in new GraphicsFormat but i assume we list "natural" order which is opposite (in 16bit case) to bit order due to being LE

                // note that 16bit formats are never supported on simulator
        #if TARGET_OS_SIMULATOR && (TARGET_OS_IOS || TARGET_OS_TVOS)
            case kFormatR4G4B4A4_UNormPack16: case kFormatB4G4R4A4_UNormPack16:
            case kFormatR5G6B5_UNormPack16: case kFormatB5G6R5_UNormPack16:
            case kFormatR5G5B5A1_UNormPack16: case kFormatB5G5R5A1_UNormPack16: case kFormatA1R5G5B5_UNormPack16:
                *outDstFormat = kFormatR8G8B8A8_UNorm; return MTLPixelFormatRGBA8Unorm;
        #else
            case kFormatR4G4B4A4_UNormPack16:   return MTLPixelFormatABGR4Unorm;
            case kFormatB4G4R4A4_UNormPack16:   *outDstFormat = kFormatR4G4B4A4_UNormPack16; return MTLPixelFormatABGR4Unorm;
            case kFormatR5G6B5_UNormPack16:     *outDstFormat = kFormatR5G6B5_UNormPack16;  return MTLPixelFormatB5G6R5Unorm;
            case kFormatB5G6R5_UNormPack16:     return MTLPixelFormatB5G6R5Unorm;
            case kFormatR5G5B5A1_UNormPack16:   return MTLPixelFormatA1BGR5Unorm;
            case kFormatB5G5R5A1_UNormPack16:   *outDstFormat = kFormatR5G5B5A1_UNormPack16; return MTLPixelFormatA1BGR5Unorm;
            case kFormatA1R5G5B5_UNormPack16:   return MTLPixelFormatBGR5A1Unorm;
        #endif

            // see InitDefaultFormat in GfxDeviceMetal.mm: we assume different formats for "extended range" on mobiles and macos
            //   simply because macos lacks "special" XR format so we go with RGBA half
            // TODO: should we use MTLPixelFormatBGR10A2Unorm for bgr10 xr on macos 10.13+?
            case kFormatA2R10G10B10_XRSRGBPack32:   *outDstFormat = kFormatR10G10B10_XRSRGBPack32; return MTLPixelFormatBGR10_XR_sRGB;
            case kFormatA2R10G10B10_XRUNormPack32:  *outDstFormat = kFormatR10G10B10_XRUNormPack32; return MTLPixelFormatBGR10_XR;
            case kFormatR10G10B10_XRSRGBPack32:     return MTLPixelFormatBGR10_XR_sRGB;
            case kFormatR10G10B10_XRUNormPack32:    return MTLPixelFormatBGR10_XR;
            case kFormatA10R10G10B10_XRSRGBPack32:  return MTLPixelFormatBGRA10_XR_sRGB;
            case kFormatA10R10G10B10_XRUNormPack32: return MTLPixelFormatBGRA10_XR;

            case kFormatRGB_PVRTC_2Bpp_SRGB:    return MTLPixelFormatPVRTC_RGB_2BPP_sRGB;
            case kFormatRGB_PVRTC_2Bpp_UNorm:   return MTLPixelFormatPVRTC_RGB_2BPP;
            case kFormatRGB_PVRTC_4Bpp_SRGB:    return MTLPixelFormatPVRTC_RGB_4BPP_sRGB;
            case kFormatRGB_PVRTC_4Bpp_UNorm:   return MTLPixelFormatPVRTC_RGB_4BPP;
            case kFormatRGBA_PVRTC_2Bpp_SRGB:   return MTLPixelFormatPVRTC_RGBA_2BPP_sRGB;
            case kFormatRGBA_PVRTC_2Bpp_UNorm:  return MTLPixelFormatPVRTC_RGBA_2BPP;
            case kFormatRGBA_PVRTC_4Bpp_SRGB:   return MTLPixelFormatPVRTC_RGBA_4BPP_sRGB;
            case kFormatRGBA_PVRTC_4Bpp_UNorm:  return MTLPixelFormatPVRTC_RGBA_4BPP;

            case kFormatRGB_ETC_UNorm:      return MTLPixelFormatETC2_RGB8;
            case kFormatRGB_ETC2_SRGB:      return MTLPixelFormatETC2_RGB8_sRGB;
            case kFormatRGB_ETC2_UNorm:     return MTLPixelFormatETC2_RGB8;
            case kFormatRGB_A1_ETC2_SRGB:   return MTLPixelFormatETC2_RGB8A1_sRGB;
            case kFormatRGB_A1_ETC2_UNorm:  return MTLPixelFormatETC2_RGB8A1;
            case kFormatRGBA_ETC2_SRGB:     return MTLPixelFormatEAC_RGBA8_sRGB;
            case kFormatRGBA_ETC2_UNorm:    return MTLPixelFormatEAC_RGBA8;
            case kFormatR_EAC_UNorm:        return MTLPixelFormatEAC_R11Unorm;
            case kFormatR_EAC_SNorm:        return MTLPixelFormatEAC_R11Snorm;
            case kFormatRG_EAC_UNorm:       return MTLPixelFormatEAC_RG11Unorm;
            case kFormatRG_EAC_SNorm:       return MTLPixelFormatEAC_RG11Snorm;

            case kFormatRGBA_ASTC4X4_SRGB:      return MTLPixelFormatASTC_4x4_sRGB;
            case kFormatRGBA_ASTC4X4_UNorm:     return MTLPixelFormatASTC_4x4_LDR;
            case kFormatRGBA_ASTC5X5_SRGB:      return MTLPixelFormatASTC_5x5_sRGB;
            case kFormatRGBA_ASTC5X5_UNorm:     return MTLPixelFormatASTC_5x5_LDR;
            case kFormatRGBA_ASTC6X6_SRGB:      return MTLPixelFormatASTC_6x6_sRGB;
            case kFormatRGBA_ASTC6X6_UNorm:     return MTLPixelFormatASTC_6x6_LDR;
            case kFormatRGBA_ASTC8X8_SRGB:      return MTLPixelFormatASTC_8x8_sRGB;
            case kFormatRGBA_ASTC8X8_UNorm:     return MTLPixelFormatASTC_8x8_LDR;
            case kFormatRGBA_ASTC10X10_SRGB:    return MTLPixelFormatASTC_10x10_sRGB;
            case kFormatRGBA_ASTC10X10_UNorm:   return MTLPixelFormatASTC_10x10_LDR;
            case kFormatRGBA_ASTC12X12_SRGB:    return MTLPixelFormatASTC_12x12_sRGB;
            case kFormatRGBA_ASTC12X12_UNorm:   return MTLPixelFormatASTC_12x12_LDR;

            case kFormatRGBA_ASTC4X4_UFloat:    return MTLPixelFormatASTC_4x4_HDR;
            case kFormatRGBA_ASTC5X5_UFloat:    return MTLPixelFormatASTC_5x5_HDR;
            case kFormatRGBA_ASTC6X6_UFloat:    return MTLPixelFormatASTC_6x6_HDR;
            case kFormatRGBA_ASTC8X8_UFloat:    return MTLPixelFormatASTC_8x8_HDR;
            case kFormatRGBA_ASTC10X10_UFloat:  return MTLPixelFormatASTC_10x10_HDR;
            case kFormatRGBA_ASTC12X12_UFloat:  return MTLPixelFormatASTC_12x12_HDR;
#pragma clang diagnostic pop // -Wunguarded-availability-new

            default: break;
        }
    }
    else
    {
        switch (fmt)
        {
            case kFormatR8_SRGB:        return MTLPixelFormatR8Unorm;
            case kFormatR8G8_SRGB:      return MTLPixelFormatRG8Unorm;

            case kFormatR4G4B4A4_UNormPack16:
            case kFormatB4G4R4A4_UNormPack16:
            case kFormatR5G6B5_UNormPack16:
            case kFormatB5G6R5_UNormPack16:
            case kFormatR5G5B5A1_UNormPack16:
            case kFormatB5G5R5A1_UNormPack16:
            case kFormatA1R5G5B5_UNormPack16:
                *outDstFormat = kFormatR8G8B8A8_UNorm; return MTLPixelFormatRGBA8Unorm;

            case kFormatA2R10G10B10_XRSRGBPack32:
            case kFormatA2R10G10B10_XRUNormPack32:
            case kFormatR10G10B10_XRSRGBPack32:
            case kFormatR10G10B10_XRUNormPack32:
            case kFormatA10R10G10B10_XRSRGBPack32:
            case kFormatA10R10G10B10_XRUNormPack32:
                *outDstFormat = kFormatR16G16B16A16_SFloat; return MTLPixelFormatRGBA16Float;

            case kFormatRGB_PVRTC_2Bpp_SRGB:
            case kFormatRGB_PVRTC_2Bpp_UNorm:
            case kFormatRGB_PVRTC_4Bpp_SRGB:
            case kFormatRGB_PVRTC_4Bpp_UNorm:
            case kFormatRGBA_PVRTC_2Bpp_SRGB:
            case kFormatRGBA_PVRTC_2Bpp_UNorm:
            case kFormatRGBA_PVRTC_4Bpp_SRGB:
            case kFormatRGBA_PVRTC_4Bpp_UNorm:

            case kFormatRGB_ETC_UNorm:
            case kFormatRGB_ETC2_SRGB:
            case kFormatRGB_ETC2_UNorm:
            case kFormatRGB_A1_ETC2_SRGB:
            case kFormatRGB_A1_ETC2_UNorm:
            case kFormatRGBA_ETC2_SRGB:
            case kFormatRGBA_ETC2_UNorm:
            case kFormatR_EAC_UNorm:
            case kFormatR_EAC_SNorm:
            case kFormatRG_EAC_UNorm:
            case kFormatRG_EAC_SNorm:

            case kFormatRGBA_ASTC4X4_SRGB:
            case kFormatRGBA_ASTC4X4_UNorm:
            case kFormatRGBA_ASTC5X5_SRGB:
            case kFormatRGBA_ASTC5X5_UNorm:
            case kFormatRGBA_ASTC6X6_SRGB:
            case kFormatRGBA_ASTC6X6_UNorm:
            case kFormatRGBA_ASTC8X8_SRGB:
            case kFormatRGBA_ASTC8X8_UNorm:
            case kFormatRGBA_ASTC10X10_SRGB:
            case kFormatRGBA_ASTC10X10_UNorm:
            case kFormatRGBA_ASTC12X12_SRGB:
            case kFormatRGBA_ASTC12X12_UNorm:

            case kFormatRGBA_ASTC4X4_UFloat:
            case kFormatRGBA_ASTC5X5_UFloat:
            case kFormatRGBA_ASTC6X6_UFloat:
            case kFormatRGBA_ASTC8X8_UFloat:
            case kFormatRGBA_ASTC10X10_UFloat:
            case kFormatRGBA_ASTC12X12_UFloat:
                return MTLPixelFormatInvalid;
            default: break;
        }
    }

    switch (fmt)
    {
        case kFormatNone:           return MTLPixelFormatInvalid;

        case kFormatR8G8B8_SRGB:    *outDstFormat = kFormatR8G8B8A8_SRGB; return MTLPixelFormatRGBA8Unorm_sRGB;
        case kFormatR8G8B8A8_SRGB:  return MTLPixelFormatRGBA8Unorm_sRGB;

        case kFormatR8_UNorm:       return MTLPixelFormatR8Unorm;
        case kFormatR8G8_UNorm:     return MTLPixelFormatRG8Unorm;
        case kFormatR8G8B8_UNorm:   *outDstFormat = kFormatR8G8B8A8_UNorm; return MTLPixelFormatRGBA8Unorm;
        case kFormatR8G8B8A8_UNorm: return MTLPixelFormatRGBA8Unorm;

        case kFormatR8_SNorm:       return MTLPixelFormatR8Snorm;
        case kFormatR8G8_SNorm:     return MTLPixelFormatRG8Snorm;
        case kFormatR8G8B8_SNorm:   *outDstFormat = kFormatR8G8B8A8_SNorm; return MTLPixelFormatRGBA8Snorm;
        case kFormatR8G8B8A8_SNorm: return MTLPixelFormatRGBA8Snorm;

        case kFormatR8_UInt:        return MTLPixelFormatR8Uint;
        case kFormatR8G8_UInt:      return MTLPixelFormatRG8Uint;
        case kFormatR8G8B8_UInt:    *outDstFormat = kFormatR8G8B8A8_UInt; return MTLPixelFormatRGBA8Uint;
        case kFormatR8G8B8A8_UInt:  return MTLPixelFormatRGBA8Uint;

        case kFormatR8_SInt:        return MTLPixelFormatR8Sint;
        case kFormatR8G8_SInt:      return MTLPixelFormatRG8Sint;
        case kFormatR8G8B8_SInt:    *outDstFormat = kFormatR8G8B8A8_SInt; return MTLPixelFormatRGBA8Sint;
        case kFormatR8G8B8A8_SInt:  return MTLPixelFormatRGBA8Sint;

        case kFormatR16_UNorm:          return MTLPixelFormatR16Unorm;
        case kFormatR16G16_UNorm:       return MTLPixelFormatRG16Unorm;
        case kFormatR16G16B16_UNorm:    *outDstFormat = kFormatR16G16B16A16_UNorm; return MTLPixelFormatRGBA16Unorm;
        case kFormatR16G16B16A16_UNorm: return MTLPixelFormatRGBA16Unorm;

        case kFormatR16_SNorm:          return MTLPixelFormatR16Snorm;
        case kFormatR16G16_SNorm:       return MTLPixelFormatRG16Snorm;
        case kFormatR16G16B16_SNorm:    *outDstFormat = kFormatR16G16B16A16_SNorm; return MTLPixelFormatRGBA16Snorm;
        case kFormatR16G16B16A16_SNorm: return MTLPixelFormatRGBA16Snorm;

        case kFormatR16_UInt:           return MTLPixelFormatR16Uint;
        case kFormatR16G16_UInt:        return MTLPixelFormatRG16Uint;
        case kFormatR16G16B16_UInt:     *outDstFormat = kFormatR16G16B16A16_UInt; return MTLPixelFormatRGBA16Uint;
        case kFormatR16G16B16A16_UInt:  return MTLPixelFormatRGBA16Uint;

        case kFormatR16_SInt:           return MTLPixelFormatR16Sint;
        case kFormatR16G16_SInt:        return MTLPixelFormatRG16Sint;
        case kFormatR16G16B16_SInt:     *outDstFormat = kFormatR16G16B16A16_SInt; return MTLPixelFormatRGBA16Sint;
        case kFormatR16G16B16A16_SInt:  return MTLPixelFormatRGBA16Sint;

        case kFormatR32_UInt:           return MTLPixelFormatR32Uint;
        case kFormatR32G32_UInt:        return MTLPixelFormatRG32Uint;
        case kFormatR32G32B32_UInt:     *outDstFormat = kFormatR32G32B32A32_UInt; return MTLPixelFormatRGBA32Uint;
        case kFormatR32G32B32A32_UInt:  return MTLPixelFormatRGBA32Uint;

        case kFormatR32_SInt:           return MTLPixelFormatR32Sint;
        case kFormatR32G32_SInt:        return MTLPixelFormatRG32Sint;
        case kFormatR32G32B32_SInt:     *outDstFormat = kFormatR32G32B32A32_SInt; return MTLPixelFormatRGBA32Sint;
        case kFormatR32G32B32A32_SInt:  return MTLPixelFormatRGBA32Sint;

        case kFormatR16_SFloat:             return MTLPixelFormatR16Float;
        case kFormatR16G16_SFloat:          return MTLPixelFormatRG16Float;
        case kFormatR16G16B16_SFloat:       *outDstFormat = kFormatR16G16B16A16_SFloat; return MTLPixelFormatRGBA16Float;
        case kFormatR16G16B16A16_SFloat:    return MTLPixelFormatRGBA16Float;

        case kFormatR32_SFloat:             return MTLPixelFormatR32Float;
        case kFormatR32G32_SFloat:          return MTLPixelFormatRG32Float;
        case kFormatR32G32B32_SFloat:       *outDstFormat = kFormatR32G32B32A32_SFloat; return MTLPixelFormatRGBA32Float;
        case kFormatR32G32B32A32_SFloat:    return MTLPixelFormatRGBA32Float;

        case kFormatL8_UNorm:   return MTLPixelFormatR8Unorm;
        case kFormatA8_UNorm:   return MTLPixelFormatA8Unorm;
        case kFormatA16_UNorm:  return MTLPixelFormatR16Unorm;

        // for some reason we were doing RGBA for BGR unorm/srgb texture format (not BGRA) - keep old behaviour for now
        // also note that only UNorm BGRA exists for metal

        case kFormatB8G8R8_SRGB:    *outDstFormat = kFormatR8G8B8A8_SRGB; return MTLPixelFormatRGBA8Unorm_sRGB;
        case kFormatB8G8R8A8_SRGB:  return MTLPixelFormatBGRA8Unorm_sRGB;
        case kFormatB8G8R8_UNorm:   *outDstFormat = kFormatR8G8B8A8_UNorm; return MTLPixelFormatRGBA8Unorm;
        case kFormatB8G8R8A8_UNorm: return MTLPixelFormatBGRA8Unorm;
        case kFormatB8G8R8_SNorm:   *outDstFormat = kFormatR8G8B8A8_SNorm; return MTLPixelFormatRGBA8Snorm;
        case kFormatB8G8R8A8_SNorm: *outDstFormat = kFormatR8G8B8A8_SNorm; return MTLPixelFormatRGBA8Snorm;
        case kFormatB8G8R8_UInt:    *outDstFormat = kFormatR8G8B8A8_UInt; return MTLPixelFormatRGBA8Uint;
        case kFormatB8G8R8A8_UInt:  *outDstFormat = kFormatR8G8B8A8_UInt; return MTLPixelFormatRGBA8Uint;
        case kFormatB8G8R8_SInt:    *outDstFormat = kFormatR8G8B8A8_SInt; return MTLPixelFormatRGBA8Sint;
        case kFormatB8G8R8A8_SInt:  *outDstFormat = kFormatR8G8B8A8_SInt; return MTLPixelFormatRGBA8Sint;

        case kFormatE5B9G9R9_UFloatPack32:  return MTLPixelFormatRGB9E5Float;
        case kFormatB10G11R11_UFloatPack32: return MTLPixelFormatRG11B10Float;

        case kFormatA2B10G10R10_UNormPack32:    return MTLPixelFormatRGB10A2Unorm;
        case kFormatA2B10G10R10_UIntPack32:     return MTLPixelFormatRGB10A2Uint;
        case kFormatA2B10G10R10_SIntPack32:     return MTLPixelFormatInvalid;

        case kFormatA2R10G10B10_UNormPack32:    return MTLPixelFormatBGR10A2Unorm;

        case kFormatA2R10G10B10_UIntPack32: case kFormatA2R10G10B10_SIntPack32: return MTLPixelFormatInvalid;

        // A8R8G8B8 are mapped back to *different* rt/texture formats
        // we pick TextureFormat, as RenderTextureFormat is actually handled higher level:
        // first of all: we now have concept of "default color RT format" which is BGRA on metal
        //               and is used in most places where kRTFormatARGB32 was used
        // second: kRTFormatARGB32 itself is mapped to R8G8B8A8 (in GetGraphicsFormat)
        // so the usage of kFormatA8R8G8B8 by itself is highly dubious and we go TextureFormat route
        case kFormatA8R8G8B8_SRGB:          *outDstFormat = kFormatR8G8B8A8_SRGB; return MTLPixelFormatRGBA8Unorm_sRGB;
        case kFormatA8R8G8B8_UNorm:         *outDstFormat = kFormatR8G8B8A8_UNorm; return MTLPixelFormatRGBA8Unorm;

        // for some reason we were doing that silently without returning "conversion needed"
        //case kFormatA32R32G32B32_SFloat:    *outDstFormat = kFormatR32G32B32A32_SFloat; return MTLPixelFormatRGBA32Float;
        case kFormatA32R32G32B32_SFloat:    return MTLPixelFormatRGBA32Float;

        case kFormatD16_UNorm:          return MTLPixelFormatDepth16Unorm;
        case kFormatD24_UNorm:          return MTLPixelFormatInvalid;
        case kFormatD24_UNorm_S8_UInt:  return MTLPixelFormatInvalid; //both nvidia and amd don't support this well on OSX so we removed it entirely.
        case kFormatD32_SFloat:         return MTLPixelFormatDepth32Float;
        case kFormatD32_SFloat_S8_UInt: return MTLPixelFormatDepth32Float_Stencil8;
        case kFormatS8_UInt:            return MTLPixelFormatStencil8;

#if TARGET_OS_OSX
        case kFormatRGBA_DXT1_SRGB:     return MTLPixelFormatBC1_RGBA_sRGB;
        case kFormatRGBA_DXT1_UNorm:    return MTLPixelFormatBC1_RGBA;
        case kFormatRGBA_DXT3_SRGB:     return MTLPixelFormatBC2_RGBA_sRGB;
        case kFormatRGBA_DXT3_UNorm:    return MTLPixelFormatBC2_RGBA;
        case kFormatRGBA_DXT5_SRGB:     return MTLPixelFormatBC3_RGBA_sRGB;
        case kFormatRGBA_DXT5_UNorm:    return MTLPixelFormatBC3_RGBA;
        case kFormatR_BC4_UNorm:        return MTLPixelFormatBC4_RUnorm;
        case kFormatR_BC4_SNorm:        return MTLPixelFormatBC4_RSnorm;
        case kFormatRG_BC5_UNorm:       return MTLPixelFormatBC5_RGUnorm;
        case kFormatRG_BC5_SNorm:       return MTLPixelFormatBC5_RGSnorm;
        case kFormatRGB_BC6H_UFloat:    return MTLPixelFormatBC6H_RGBUfloat;
        case kFormatRGB_BC6H_SFloat:    return MTLPixelFormatBC6H_RGBFloat;
        case kFormatRGBA_BC7_SRGB:      return MTLPixelFormatBC7_RGBAUnorm_sRGB;
        case kFormatRGBA_BC7_UNorm:     return MTLPixelFormatBC7_RGBAUnorm;
#else
        case kFormatRGBA_DXT1_SRGB: case kFormatRGBA_DXT1_UNorm: case kFormatRGBA_DXT3_SRGB: case kFormatRGBA_DXT3_UNorm:
        case kFormatRGBA_DXT5_SRGB: case kFormatRGBA_DXT5_UNorm: case kFormatR_BC4_UNorm: case kFormatR_BC4_SNorm:
        case kFormatRG_BC5_UNorm: case kFormatRG_BC5_SNorm: case kFormatRGB_BC6H_UFloat: case kFormatRGB_BC6H_SFloat:
        case kFormatRGBA_BC7_SRGB: case kFormatRGBA_BC7_UNorm:
            return MTLPixelFormatInvalid;
#endif

        case kFormatYUV2:   return MTLPixelFormatGBGR422;

        case kFormatDepthAuto_removed_donotuse:  return MTLPixelFormatDepth32Float_Stencil8;
        case kFormatShadowAuto_removed_donotuse: return MTLPixelFormatDepth32Float;
        case kFormatVideoAuto_removed_donotuse:  return MTLPixelFormatGBGR422;

        case kFormatD16_UNorm_S8_UInt:  return MTLPixelFormatInvalid;

        //default:    DebugAssertFormatMsg(false, "unknown GraphicsFormat: %d", (int)fmt);
        default: return MTLPixelFormatInvalid;
    }

    return MTLPixelFormatInvalid;
}
