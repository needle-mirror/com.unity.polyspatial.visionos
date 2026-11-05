// Exposes Unity's Metal command queue and a flush of its current command buffer, so that PolySpatial's
// native asset copies can be encoded on the queue Unity's upload blits are committed on: Metal executes
// a queue's command buffers in commit order, so an upload completes before a copy committed after it.

#import <Metal/Metal.h>

#include "IUnityInterface.h"
#include "IUnityGraphics.h"
#include "IUnityGraphicsMetal.h"

extern "C" void UnityRegisterRenderingPluginV5(UnityPluginLoadFunc loadPlugin, UnityPluginUnloadFunc unloadPlugin);

static IUnityGraphicsMetalV2* s_Metal;

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API PolySpatialNativeCopyFencePluginLoad(
    IUnityInterfaces* interfaces)
{
    s_Metal = interfaces->Get<IUnityGraphicsMetalV2>();
}

extern "C" void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API PolySpatialNativeCopyFencePluginUnload(void)
{
    s_Metal = nullptr;
}

// Registration is deferred to the first call rather than done from a static initializer: Unity's
// plugin registry does not exist yet while dyld is running initializers, and registering there
// dereferences null.
static void EnsureRegistered(void)
{
    static bool registered;
    if (registered)
        return;

    registered = true;
    UnityRegisterRenderingPluginV5(PolySpatialNativeCopyFencePluginLoad, PolySpatialNativeCopyFencePluginUnload);
}

// Unity's Metal command queue, the one its upload blits are committed on. Null until the graphics
// interface is available, in which case the caller falls back to its own queue.
extern "C" void* UNITY_INTERFACE_EXPORT PolySpatial_UnityCommandQueue(void)
{
    EnsureRegistered();
    return s_Metal != nullptr ? (__bridge void*)s_Metal->CommandQueue() : nullptr;
}

// Both calls are required: the encoder has to be closed before the buffer holding it can be submitted.
// Only safe to call while no render thread owns Unity's command buffer.
//
// Returns false when the graphics interface is unavailable and nothing was committed.
extern "C" bool UNITY_INTERFACE_EXPORT PolySpatial_FlushUnityCommandBuffer(void)
{
    EnsureRegistered();
    if (s_Metal == nullptr)
        return false;

    s_Metal->EndCurrentCommandEncoder();
    s_Metal->CommitCurrentCommandBuffer();
    return true;
}
