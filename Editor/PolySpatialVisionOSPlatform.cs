using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.XR.VisionOS;

namespace Unity.PolySpatial.Editor
{
    internal class PolySpatialVisionOSPlatform : IPolySpatialEditorPlatform
    {
        public static bool ShouldEnablePolySpatialRuntime()
        {
            // if the current active platform is visionos
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.VisionOS)
            {
                return false;
            }

            return EnableBasedOnSettings();
        }

        public static bool ShouldEnablePolySpatialRuntimeForBuild(BuildTarget target)
        {
            if (target != BuildTarget.VisionOS)
            {
                return false;
            }

            return EnableBasedOnSettings();
        }

        static bool EnableBasedOnSettings()
        {
            if (PolySpatialSettings.RuntimeModeAuto)
            {
                var xrSettings = VisionOSSettings.currentSettings;
                var mixedRealitySupported = xrSettings != null && xrSettings.appMode is VisionOSSettings.AppMode.RealityKit or VisionOSSettings.AppMode.Hybrid;
                if (mixedRealitySupported)
                {
                    return true;
                }
            }

            return false;
        }
    }
}
