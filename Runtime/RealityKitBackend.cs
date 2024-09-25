using System;
using System.Runtime.InteropServices;
using AOT;
using Unity.Profiling;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Scripting;
using Profiler = Unity.PolySpatial.Internals.PolySpatialProfiler;

namespace Unity.PolySpatial.Internals
{
    // Implements a local backend targeting RealityKit. Communicates with our RealityKit plugin via
    // a pair of function pointers, one to send commands down to it, and one we pass to our plugin
    // to call when it has host commands to send back to us.
    [Preserve]
    internal class RealityKitBackend : IPolySpatialCommandHandler, IPolySpatialHostCommandDispatcher,
        IPolySpatialLocalBackend, PolySpatialBackendExtraFeatures
    {
        static readonly ProfilerMarker s_HandleCommandMarker = new(Profiler.Name<RealityKitBackend>().HandleCommandName);

        public IPolySpatialHostCommandHandler NextHostHandler { get; set; }

        static Platform.PolySpatialNativeAPI s_OldAPIPointers;
        static RealityKitBackend s_Instance;

        static bool TryGetAPIPointers()
        {
            if (s_OldAPIPointers.SendClientCommand != null)
                return true;

            // try to load the API
            try
            {
                RKRuntimeFuncs.GetPolySpatialNativeAPI(out s_OldAPIPointers);
                if (s_OldAPIPointers.SendClientCommand == null)
                {
                    Debug.LogError($"Failed to get function pointers for PolySpatial RealityKit, disabling!");
                    return false;
                }
            }
            catch (Exception e)
            {
                if (e is DllNotFoundException)
                {
                    Debug.LogWarning($"Failed to find PolySpatial RealityKit plugin, disabling");
                }
                else
                {
                    Debug.LogException(e);
                }

                return false;
            }

            // higher than default Unity
            return true;
        }

        [Preserve]
        public static int GetBackendPriority()
        {
#if false // UNITY_EDITOR // Mac preview unfortunately doesn't work well in this way
            // if Mac preview is disabled in the editor, disable the platform
            if (!PolySpatialSettings.Instance.EnableMacRealityKitPreviewInPlayMode)
            {
                return -1;
            }
#elif !UNITY_EDITOR && (UNITY_VISIONOS || UNITY_STANDALONE_OSX)
            if (!TryGetAPIPointers())
                return -1;

            // higher than PolySpatialUnityBackend
            return 500;
#else
            return -1;
#endif
        }

        public unsafe RealityKitBackend()
        {
            if (s_Instance != null)
                throw new InvalidOperationException("There can be only one RealityKit Backend");

            Assert.IsTrue(TryGetAPIPointers());

            if (s_OldAPIPointers.SendClientCommand == null)
            {
                throw new InvalidOperationException("Failed to set up SendClientCommand");
            }

            // set up host API
            hostCallbackDelegate = HostCommandCallbackFromRealityKit;
            var simHostPtr = Marshal.GetFunctionPointerForDelegate(hostCallbackDelegate);

            var args = stackalloc void*[] { (void*)&simHostPtr };
            var sizes = stackalloc int[] { sizeof(IntPtr) };
            s_OldAPIPointers.SendClientCommand(PolySpatialCommand.SetSimulationHostAPI, 1, args, sizes);

            s_Instance = this;
        }

        HostCommandCallback hostCallbackDelegate;

        [MonoPInvokeCallback(typeof(HostCommandCallback))]
        private unsafe static void HostCommandCallbackFromRealityKit(PolySpatialHostCommand command, int argCount, void** args, int* argSizes)
        {
            // MonoPInvokeCallback methods will leak exceptions and cause crashes; always use a try/catch in these methods
            try
            {
                s_Instance.NextHostHandler.HandleHostCommand(command, argCount, args, argSizes);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        public unsafe void HandleCommand(PolySpatialCommand cmd, int argCount, void** argValues, int* argSizes)
        {
            s_HandleCommandMarker.Begin();
            s_OldAPIPointers.SendClientCommand(cmd, argCount, argValues, argSizes);
            s_HandleCommandMarker.End();
        }

        public unsafe bool GetCameraPose(out Pose pose)
        {
            fixed (Pose* pptr = &pose)
            {
                this.Command(PolySpatialCommand.GetCameraPose, pptr);
            }

            return true;
        }

        public bool ObsoleteTakeScreenshot(string path)
        {
            this.StringCommand(PolySpatialCommand.TakeScreenshot, path);
            return true;
        }

        public Texture2D TakeScreenshot(Camera camera, int width, int height)
        {
            throw new NotImplementedException();
        }
    }
}
