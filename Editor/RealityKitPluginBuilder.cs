#if (UNITY_VISIONOS ||  POLYSPATIAL_INTERNAL) && UNITY_EDITOR_OSX
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Unity.PolySpatial.Internals.Editor
{
    class RealityKitPluginBuilder : IPreprocessBuildWithReport
    {
        const int k_BuildTimeoutSeconds = 15 * 60;

        // must be early, but it doesn't affect the Unity build
        public int callbackOrder => 10;

        public static void DoPluginBuild(params string[] args)
        {
            int totalSteps = Math.Max(1, args.Length);
            for (int i = 0; i < totalSteps; i++)
            {
                float progress = (float)i / totalSteps;
                string plugin = args[i];
                string progressText = $"Building PolySpatial plugin for {plugin}";

                EditorUtility.DisplayProgressBar($"Building {plugin}", progressText, progress);

                bool success;
                string output;

                if (plugin == "xr-visionos") {
                    var xrSrcPath = Path.Combine(FileUtil.GetPhysicalPath("Packages/com.unity.xr.visionos"), "Source~");
                    if (!Directory.Exists(xrSrcPath))
                    {
                        throw new BuildFailedException($"{xrSrcPath} not found");
                    }

                    (success, output) = BuildUtils.RunCommandWithOutput(Path.Combine(xrSrcPath, "bee"), null, xrSrcPath, k_BuildTimeoutSeconds,
                            new () { ["XRSDK_USE_LOCAL_TOOLCHAIN"] = "1" });
                } else {
                    var pkgPath = FileUtil.GetPhysicalPath("Packages/com.unity.polyspatial.visionos");
                    var repoRoot = Path.Combine(pkgPath, "../..");
                    var scriptPath = FileUtil.GetPhysicalPath(Path.Combine(repoRoot, "Tools/build-binary-plugins.sh"));
                    if (!File.Exists(scriptPath))
                    {
                        throw new BuildFailedException($"{scriptPath} not found");
                    }

                    (success, output) = BuildUtils.RunCommandWithOutput(scriptPath, plugin, repoRoot, k_BuildTimeoutSeconds);
                }

                if (!success)
                {
                    Debug.LogError(output);
                    throw new BuildFailedException($"Plugin command build for {plugin} failed");
                }
            }
        }

        // Note: if you make changes to these xcodebuild commands, make corresponding changes to
        // the .yamato package-pack.yml, package-pack.metafile, and Tools/build_polyspatial_package.sh

        /// <summary>
        /// Run an external build to create an visionOS PolySpatial Plugin.
        /// </summary>
#if POLYSPATIAL_INTERNAL
        [MenuItem("Tools/Build PolySpatial visionOS Plugin", false, 100)]
#endif
        public static void BuildVisionOSPlugin()
        {
            if (BuildUtils.IsPackageImmutable())
                return;

            DoPluginBuild("visionos");
        }

#if POLYSPATIAL_INTERNAL
        [MenuItem("Tools/Build visionOS XR Plugin", false, 100)]
#endif
        public static void BuildVisionOSXRPlugin()
        {
            if (BuildUtils.IsPackageImmutable())
                return;

            DoPluginBuild("xr-visionos");
        }

        /// <inheritdoc/>
        public void OnPreprocessBuild(BuildReport report)
        {
            if (!PolySpatialRuntime.Enabled)
                return;

            try
            {
                bool shouldBuildPlugin = Directory.Exists("Packages/com.unity.polyspatial.visionos/Source~/PolySpatialRealityKit");

                if (shouldBuildPlugin)
                {
#if !POLYSPATIAL_INTERNAL
                    Debug.LogWarning("Building PolySpatial plugin without POLYSPATIAL_INTERNAL because source is available");
#endif

                    if (report.summary.platform == BuildTarget.VisionOS)
                    {
                        BuildVisionOSPlugin();
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
