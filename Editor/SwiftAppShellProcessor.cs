#if UNITY_IOS || UNITY_VISIONOS || UNITY_STANDALONE_OSX
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEngine;
using static Unity.PolySpatial.Internals.Editor.BuildUtils;

namespace Unity.PolySpatial.Internals.Editor
{
    internal static class SwiftAppShellProcessor
    {
        private static readonly string MODULE_MAP = "UnityFramework.modulemap";

        private static readonly string UNITY_RK_PACKAGE_PATH = Path.GetFullPath(Path.Combine("Packages", "com.unity.polyspatial.visionos"));
        private static readonly string UNITY_RK_SRC_PATH = Path.Combine(UNITY_RK_PACKAGE_PATH, "Source~");

        // Paths both on disk relative to project file, and logical inside relevant xcode projects
        private static readonly string XCODE_POLYSPATIAL_RK_PATH = Path.Combine("Libraries", "com.unity.polyspatial.visionos");
        private static readonly string XCODE_POLYSPATIAL_RK_PLUGIN_PATH = Path.Combine("Libraries", "com.unity.polyspatial.visionos", "Plugins");

        private static readonly string ARM_WORKAROUND_ORIGINAL = "--additional-defines=IL2CPP_DEBUG=";
        private static readonly string ARM_WORKAROUND_REPLACEMENT = "--additional-defines=IL2CPP_LARGE_EXECUTABLE_ARM_WORKAROUND=1,IL2CPP_DEBUG=";

        public static void ConfigureXcodeProject(BuildTarget buildTarget, string path, string projectName,
            bool il2cppArmWorkaround = false,
            string staticLibraryPluginName = null,
            // name in project -> actual filename. If actual filename is null, file is assumed to already be in
            // the right place in project structure. If filename is not-null, it's copied from there.
            // If the project path starts with MainApp, then it goes into the app target, otherwise to UnityFramework
            Dictionary<string, string> extraSourceFiles = null)
        {
            var xcodePath = Path.Combine(path, projectName, "project.pbxproj");

            var proj = new PBXProject();
            proj.ReadFromFile(xcodePath);

            var extraHeaders = new StringBuilder();
            #pragma warning disable 0219
            bool actuallyHasARKit = false;

            var unityFrameworkTarget = proj.GetUnityFrameworkTargetGuid();
            var swiftAppTarget = proj.GetUnityMainTargetGuid();
            var doAppend = false; // args.options & BuildOptions.AcceptExternalModificationsToPlayer
            var symlinkInsteadOfCopy = PlayerSettingsBridge.GetSymlinkTrampolineBuildSetting();

            void CopyAndAddToBuildTarget(string targetGuid, string fileName, string srcPath, string projectPath)
            {
                var projectFile = Path.Combine(projectPath, fileName);
                CopyFileTo(fileName, srcPath, Path.Combine(path, projectPath), append: doAppend, symlinkInstead: symlinkInsteadOfCopy);
                BuildUtils.AddFileToBuildTarget(proj, projectFile, targetGuid, projectFile);
            }

            void RemoveFileFromProjectAndDelete(string projectFileName)
            {
                RemoveFileFromProject(proj, projectFileName);
                var filePath = Path.Combine(path, projectFileName);
                if (File.Exists(filePath))
                    File.Delete(filePath);
            }

            if (staticLibraryPluginName != null)
            {
                string pluginSrcPath = Path.Combine(UNITY_RK_PACKAGE_PATH, $"Lib~");
                string pluginDstXcodePath = Path.Combine(path, XCODE_POLYSPATIAL_RK_PLUGIN_PATH);

                CopyAndAddToBuildTarget(swiftAppTarget, staticLibraryPluginName, pluginSrcPath, XCODE_POLYSPATIAL_RK_PLUGIN_PATH);
                // copy the swiftmodule directory to where it'll be expected
                CopyDirectoryTo(Path.Combine(pluginSrcPath, $"PolySpatialRealityKit.swiftmodule"), pluginDstXcodePath);
            }

            CopyAndAddToBuildTarget(swiftAppTarget, "UnitySwiftUIAppDelegate.swift", UNITY_RK_SRC_PATH, "MainApp");
            CopyAndAddToBuildTarget(swiftAppTarget, "UnitySwiftUIiPhoneApp.swift", UNITY_RK_SRC_PATH, "MainApp");
            CopyAndAddToBuildTarget(swiftAppTarget, "UnityLibrary.swift", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);
            CopyAndAddToBuildTarget(swiftAppTarget, "Shaders.metal", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);

            if (buildTarget == BuildUtils.tmp_BuildTarget_VisionOS)
            {
                // remove the input system iOS step counter implementation
                RemoveFileFromProjectAndDelete("Libraries/com.unity.inputsystem/InputSystem/Plugins/iOS/iOSStepCounter.mm");
                // and add a dummy one
                CopyAndAddToBuildTarget(unityFrameworkTarget, "iOSStepCounterDummy.mm", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);
            }

            // we added our own Swift shell
            RemoveFileFromProjectAndDelete("MainApp/main.mm");

            foreach (var item in extraSourceFiles)
            {
                var filepathinproj = item.Key;

                if (item.Value != null)
                {
                    Directory.CreateDirectory(Path.Combine(path, Path.GetDirectoryName(filepathinproj)));
                    FileUtil.CopyFileOrDirectory(item.Value, Path.Combine(path, filepathinproj));
                }

                var target = item.Key.StartsWith("MainApp") ? swiftAppTarget : unityFrameworkTarget;
                BuildUtils.AddFileToBuildTarget(proj, filepathinproj, target, filepathinproj);
            }

            // Configure Unity Framework; add a modulemap file to allow access from Swift,
            // and tweak build settings.
            {
                var moduleProjectPath = "UnityFramework/UnityFramework.modulemap";
                var moduleFileDestPath = Path.Combine(path, moduleProjectPath);
                WriteTextIfChanged(moduleFileDestPath,
                    File.ReadAllText(Path.Combine(UNITY_RK_SRC_PATH, MODULE_MAP))
                        .Replace("__EXTRA_HEADERS__", extraHeaders.ToString()));
                proj.AddFile(moduleFileDestPath, moduleProjectPath);

                proj.AddBuildProperty(unityFrameworkTarget, "MODULEMAP_FILE", "$(SRCROOT)/" + moduleProjectPath);
                proj.SetBuildProperty(unityFrameworkTarget, "DEFINES_MODULE", "YES");
                proj.SetBuildProperty(unityFrameworkTarget, "ENABLE_BITCODE", "NO");
            }

            // These are hacks -- both of these are required, and Unity doesn't properly
            // fill them out in the iPhone project.
            // TODO fix this in new project generation
            if (buildTarget == BuildUtils.tmp_BuildTarget_VisionOS) {
#if UNITY_VISIONOS
                var swiftAppConfigGuids = proj.BuildConfigNames()
                    .Select(name => proj.BuildConfigByName(swiftAppTarget, name))
                    .Where(p => !String.IsNullOrEmpty(p)).ToArray();
                // These must be valid, or the project won't run.
                var buildNumber = String.IsNullOrEmpty(PlayerSettings.VisionOS.buildNumber) ? "1" : PlayerSettings.VisionOS.buildNumber;
                var bundleVersion = String.IsNullOrEmpty(PlayerSettings.bundleVersion) ? "1.0" : PlayerSettings.bundleVersion;
                proj.AddBuildPropertyForConfig(swiftAppConfigGuids, "CURRENT_PROJECT_VERSION", buildNumber);
                proj.AddBuildPropertyForConfig(swiftAppConfigGuids, "MARKETING_VERSION", bundleVersion);
#else
                throw new BuildFailedException("Didn't step into visionOS specific code when expected to");
#endif
            }

            var xcodePlatformName = GetXcodePlatformName(buildTarget);

            ConfigureMainAppTarget(proj, swiftAppTarget, xcodePlatformName);

            var projContents = proj.WriteToString();

            if (il2cppArmWorkaround)
            {
                projContents = projContents.Replace(ARM_WORKAROUND_ORIGINAL, ARM_WORKAROUND_REPLACEMENT)
                // A full-debug (i.e. non-optimized) IL2CPP build is very prone to trigger the "ARM64 branch out of range" link error
                // Here we force basic optimizations (-O1) for Debug builds, and keep the usual full-opt (-O3) for Release builds.
                //    .Replace("IL2CPP_CONFIG=\\\"Debug\\\"", "IL2CPP_CONFIG=\\\"Debug\\\" IL2CPP_OPTIM=\\\"-O1\\\"")
                //    .Replace("IL2CPP_CONFIG=\\\"Release\\\"", "IL2CPP_CONFIG=\\\"Release\\\" IL2CPP_OPTIM=\\\"-O3\\\"")
                //    .Replace("--configuration=\\\"$IL2CPP_CONFIG\\\"", "--configuration=\\\"$IL2CPP_CONFIG\\\" --compiler-flags=\\\"$IL2CPP_OPTIM\\\"")
                    ;
            }

            File.WriteAllText(xcodePath, projContents);
        }

        public static void RestoreXcodeProject(string path, string projectName)
        {
            // For append builds, we need to restore the original command line so that the Unity
            // build process doesn't see it as missing and add a duplicate to replace it.
            var xcodePath = Path.Combine(path, projectName, "project.pbxproj");
            if (!File.Exists(xcodePath))
                return;

            var projContents = File.ReadAllText(xcodePath);

            projContents = projContents.Replace(ARM_WORKAROUND_REPLACEMENT, ARM_WORKAROUND_ORIGINAL);

            File.WriteAllText(xcodePath, projContents);
        }

        public static void ConfigureMainAppTarget(PBXProject proj, string mainAppTarget, string xcodePlatformName)
        {
            string pluginXcodePath = XCODE_POLYSPATIAL_RK_PLUGIN_PATH;

            proj.AddBuildProperty(mainAppTarget, "HEADER_SEARCH_PATHS", $"$(PROJECT_DIR)/{pluginXcodePath}");
            proj.AddBuildProperty(mainAppTarget, "LIBRARY_SEARCH_PATHS", $"$(PROJECT_DIR)/{pluginXcodePath}");
            proj.AddBuildProperty(mainAppTarget, "SWIFT_INCLUDE_PATHS", $"$(PROJECT_DIR)/{pluginXcodePath}");

            string resourcesBuildPhase = proj.GetResourcesBuildPhaseByTarget(mainAppTarget);
            proj.AddFileToBuildSection(mainAppTarget, resourcesBuildPhase, proj.FindFileGuidByProjectPath("LaunchScreen-iPhone.storyboard"));
            proj.AddFileToBuildSection(mainAppTarget, resourcesBuildPhase, proj.FindFileGuidByProjectPath("LaunchScreen-iPad.storyboard"));
            proj.SetBuildProperty(mainAppTarget, "ENABLE_BITCODE", "NO");
            proj.SetBuildProperty(mainAppTarget, "SWIFT_VERSION", "5.0");
            proj.SetBuildProperty(mainAppTarget, "CLANG_ENABLE_MODULES", "YES");
            proj.SetBuildProperty(mainAppTarget, "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES", "YES");
            proj.SetBuildProperty(mainAppTarget, "GENERATE_INFOPLIST_FILE", "YES");
            proj.SetBuildProperty(mainAppTarget, "INFOPLIST_KEY_NSCameraUsageDescription", "Augmented Reality");
            proj.SetBuildProperty(mainAppTarget, "INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "YES");
            proj.SetBuildProperty(mainAppTarget, "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents", "YES");

        }

        public static bool IsSimulator()
        {
            return PlayerSettings.iOS.sdkVersion != iOSSdkVersion.DeviceSDK;
        }

        public static string GetXcodePlatformName(BuildTarget target)
        {
            if (target == BuildTarget.iOS)
                return IsSimulator() ? "iphonesimulator" : "iphoneos";

            if (target == BuildUtils.tmp_BuildTarget_VisionOS)
                return IsSimulator() ? "xrsimulator" : "xros";

            throw new InvalidOperationException("Unknown build target");
        }
    }
}
#endif
