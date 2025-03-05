using System;
using System.Runtime.InteropServices;
using AOT;
using Unity.Profiling;
using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.Rendering;
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
#if !UNITY_EDITOR && UNITY_VISIONOS
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
                // This makes the assumption that the RealityKitBackend always uses the latest version of HostCommands,
                // and that any downgrading of HostCommands is handled by downstream C#.
                s_Instance.NextHostHandler.HandleHostCommand(command, argCount, args, argSizes);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        public unsafe void HandleCommand(PolySpatialCommandHeader cmdHeader, int argCount, void** argValues, int* argSizes)
        {
            s_HandleCommandMarker.Begin();
            // This makes the assumption that the RealityKitBackend always uses the latest versions of Commands, and that
            // any upgrading of Commands is handled by the upstream C# code, so only the Command enum value is required.
            s_OldAPIPointers.SendClientCommand(cmdHeader.Command, argCount, argValues, argSizes);
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

        public bool CanReceiveNativeMesh(Mesh mesh)
        {
            // We can handle non-skinned meshes natively.  In order to let us transfer all vertices in one pass per
            // buffer, they must have Vector3 positions (if present), Vector3 normals (if present), Vector4 tangents
            // (if present), and Vector[2-4] UVs (if present).  This is the usual setup, but users can use arbitrary
            // formats for meshes, so we have to check.
            return mesh.blendShapeCount == 0 &&
                !mesh.HasVertexAttribute(VertexAttribute.BlendWeight) &&
                !mesh.HasVertexAttribute(VertexAttribute.BlendIndices) &&
                (!mesh.HasVertexAttribute(VertexAttribute.Position) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.Position) == 3 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.Position) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.Normal) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.Normal) == 3 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.Normal) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.Tangent) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.Tangent) == 4 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.Tangent) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord0) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord0) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord0) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord1) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord1) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord1) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord2) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord2) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord2) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord3) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord3) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord3) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord4) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord4) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord4) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord5) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord5) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord5) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord6) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord6) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord6) == VertexAttributeFormat.Float32)) &&
                (!mesh.HasVertexAttribute(VertexAttribute.TexCoord7) ||
                    (mesh.GetVertexAttributeDimension(VertexAttribute.TexCoord7) >= 2 &&
                    mesh.GetVertexAttributeFormat(VertexAttribute.TexCoord7) == VertexAttributeFormat.Float32));
        }
    }
}
