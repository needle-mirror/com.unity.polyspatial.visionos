#if UNITY_IOS || UNITY_VISIONOS || UNITY_STANDALONE_OSX
using System;
using System.IO;
using NUnit.Framework;
using Unity.PolySpatial.Internals.Editor;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.XR.VisionOS;
using UnityEngine;

namespace Unity.PolySpatial.Internals.Editor
{
    internal class RealityKitPluginBuilder : IPreprocessBuildWithReport
    {
        const int k_BuildTimeoutSeconds = 15 * 60;
        const string k_MacOSMinVersion = "10.13";
        const string k_MacOSSDKVersion = "13.1";

        // must be early, but it doesn't affect the Unity build
        public int callbackOrder => 10;

        static internal readonly string k_ExtraFrameworksPath = "/opt/UnitySrc/PolySpatialExtraFrameworks";

        public static void XcodeBuildPolySpatialRealityKit(string args)
        {
            var buildArgs = "-project PolySpatialRealityKit.xcodeproj -quiet " + args;

#if POLYSPATIAL_INTERNAL
            if (Directory.Exists(k_ExtraFrameworksPath))
            {
                buildArgs += " FRAMEWORK_SEARCH_PATHS=" + k_ExtraFrameworksPath;
            }
#endif

            Debug.Log($"Running xcodebuild {buildArgs}\nin: {Path.GetFullPath("Packages/com.unity.polyspatial.visionos/Source~/PolySpatialRealityKit")}");

            var (success, output) = BuildUtils.RunCommandWithOutput("/usr/bin/xcodebuild", buildArgs,
                Path.GetFullPath("Packages/com.unity.polyspatial.visionos/Source~/PolySpatialRealityKit"),
                k_BuildTimeoutSeconds);

            if (!success)
            {
                Debug.LogError(output);
                throw new Exception($"xcodebuild failed, args: {buildArgs}.");
            }
        }

        static void XcodeBuild(string scheme, params string[] destinations)
        {
            int totalSteps = Math.Max(1, destinations.Length);
            for (int i = 0; i < totalSteps; i++)
            {
                float progress = (float)i / totalSteps;
                string progressText = destinations.Length == 0 ? $"Building" : $"Building for {destinations[i]}";

                EditorUtility.DisplayProgressBar($"Building {scheme}", progressText, progress);

                // only active arch hack for macOS
                var destarg = destinations.Length == 0 ? "ONLY_ACTIVE_ARCH=NO" : $"-destination 'generic/platform={destinations[i]}'";
                XcodeBuildPolySpatialRealityKit($"-scheme {scheme} {destarg} BUILD_FOR_DISTRIBUTION=YES");
            }

        }

        // Note: if you make changes to these xcodebuild commands, make corresponding changes to
        // the .yamato package-pack.yml, package-pack.metafile, and Tools/build_polyspatial_package.sh

        /// <summary>
        /// Run an external build to create the Mac PolySpatial Plugin.
        /// </summary>
#if POLYSPATIAL_INTERNAL
        [MenuItem("Window/PolySpatial/Build Mac Plugin")]
#endif
        public static void BuildMacPlugin()
        {
            if (BuildUtils.IsPackageImmutable())
                return;

            XcodeBuild("PolySpatial-macOS");
        }


        /// <summary>
        /// Run an external build to create an iOS PolySpatial Plugin.
        /// </summary>
#if POLYSPATIAL_INTERNAL
        [MenuItem("Window/PolySpatial/Build iOS Plugin")]
#endif
        public static void BuildiOSPlugin()
        {
            if (BuildUtils.IsPackageImmutable())
                return;

            XcodeBuild("PolySpatial-iOS", "iOS", "iOS Simulator");
        }

        /// <summary>
        /// Run an external build to create an iOS PolySpatial Plugin.
        /// </summary>
#if POLYSPATIAL_INTERNAL
        [MenuItem("Window/PolySpatial/Build visionOS Plugin")]
#endif
        public static void BuildVisionOSPlugin()
        {
            if (BuildUtils.IsPackageImmutable())
                return;

            XcodeBuild("PolySpatial-visionOS", "visionOS", "visionOS Simulator");
        }

        /// <inheritdoc/>
        public void OnPreprocessBuild(BuildReport report)
        {
            if (!PolySpatialSettings.instance.EnablePolySpatialRuntime)
                return;

            var settings = VisionOSSettings.currentSettings;
            if (settings.appMode == VisionOSSettings.AppMode.VR)
                return;

            try
            {
                bool shouldBuildPlugin = Directory.Exists("Packages/com.unity.polyspatial.visionos/Source~");

                if (shouldBuildPlugin)
                {
#if !POLYSPATIAL_INTERNAL
                    Debug.LogWarning("Building PolySpatial plugin without POLYSPATIAL_INTERNAL because Source is available");
#endif

                    if (report.summary.platform == BuildTarget.iOS)
                    {
                        BuildiOSPlugin();
                    }
                    else if (report.summary.platform == BuildUtils.tmp_BuildTarget_VisionOS)
                    {
                        BuildVisionOSPlugin();
                    }
                    else if (report.summary.platform == BuildTarget.StandaloneOSX)
                    {
                        BuildMacPlugin();
                    }
                }
            }
            catch (Exception e)
            {
                throw new BuildFailedException(e);
            }
        }
    }
}
#endif
