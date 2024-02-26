#if UNITY_VISIONOS || UNITY_IOS || UNITY_EDITOR_OSX
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
using UnityEditor.XR.VisionOS;
using UnityEngine;
using static Unity.PolySpatial.Internals.Editor.BuildUtils;

namespace Unity.PolySpatial.Internals.Editor
{
    internal static class SwiftAppShellProcessor
    {
        private static readonly string MODULE_MAP = "UnityFramework.modulemap";

        private static readonly string UNITY_RK_PACKAGE_PATH = BuildUtils.PathToUnixPath(Path.GetFullPath(Path.Combine("Packages", "com.unity.polyspatial.visionos")));
        private static readonly string UNITY_RK_SRC_PATH = BuildUtils.PathToUnixPath(Path.Combine(UNITY_RK_PACKAGE_PATH, "Source~"));

        // Paths both on disk relative to project file, and logical inside relevant xcode projects
        private static readonly string XCODE_POLYSPATIAL_RK_PATH = BuildUtils.PathToUnixPath(Path.Combine("Libraries", "com.unity.polyspatial.visionos"));
        private static readonly string XCODE_POLYSPATIAL_RK_PLUGIN_PATH = BuildUtils.PathToUnixPath(Path.Combine("Libraries", "com.unity.polyspatial.visionos", "Plugins"));

        public static void ConfigureXcodeProject(BuildTarget buildTarget, string path, string projectName,
            string staticLibraryPluginName = null,
            // name in project -> actual filename. If actual filename is null, file is assumed to already be in
            // the right place in project structure. If filename is not-null, it's copied from there.
            // If the project path starts with MainApp, then it goes into the app target, otherwise to UnityFramework
            Dictionary<string, string> extraSourceFiles = null,
            // these are files that are already in the xcode project, but should be moved to the Swift app target from
            // UnityFramework target. The paths are plugin paths, so they need some massaging to turn into Xcode paths.
            string[] pathsToMoveToSwiftApp = null
        )
        {
            var xcodePath = Path.Combine(path, projectName, "project.pbxproj");

            var proj = new PBXProject();
            proj.ReadFromFile(xcodePath);

            var extraHeaders = new StringBuilder();
            var unityFrameworkTarget = proj.GetUnityFrameworkTargetGuid();
            var swiftAppTarget = proj.GetUnityMainTargetGuid();
            var doAppend = false; // args.options & BuildOptions.AcceptExternalModificationsToPlayer
            var symlinkInsteadOfCopy = PlayerSettingsBridge.GetSymlinkTrampolineBuildSetting();

            void CopyAndAddToProject(string fileName, string srcPath, string projectPath)
            {
                var projectFile = Path.Combine(projectPath, fileName);
                CopyFileTo(fileName, srcPath, Path.Combine(path, projectPath), append: doAppend, symlinkInstead: symlinkInsteadOfCopy);
                BuildUtils.AddFileToProject(proj, projectFile, projectFile);
            }

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

            void MoveProjectFileToTarget(string projPath, string oldTargetGuid, string newTargetGuid)
            {
                var fileGuid = proj.FindFileGuidByProjectPath(projPath);
                if (fileGuid == null)
                {
                    throw new BuildFailedException($"File {projPath} is expected to be in the generated Xcode project, but it is missing");
                }

                proj.RemoveFileFromBuild(oldTargetGuid, fileGuid);
                proj.AddFileToBuild(newTargetGuid, fileGuid);
            }

            if (staticLibraryPluginName != null)
            {
                string pluginSrcPath = Path.Combine(UNITY_RK_PACKAGE_PATH, $"Lib~");
                string pluginDstXcodePath = Path.Combine(path, XCODE_POLYSPATIAL_RK_PLUGIN_PATH);

                CopyAndAddToBuildTarget(swiftAppTarget, staticLibraryPluginName, pluginSrcPath, XCODE_POLYSPATIAL_RK_PLUGIN_PATH);
                // copy the swiftmodule directory to where it'll be expected
                CopyDirectoryTo(Path.Combine(pluginSrcPath, $"PolySpatialRealityKit.swiftmodule"), pluginDstXcodePath);
            }

            CopyAndAddToBuildTarget(swiftAppTarget, "UnityPolySpatialAppDelegate.swift", UNITY_RK_SRC_PATH, "MainApp");
            CopyAndAddToBuildTarget(swiftAppTarget, "UnityPolySpatialApp.swift", UNITY_RK_SRC_PATH, "MainApp");
            CopyAndAddToBuildTarget(swiftAppTarget, "UnityLibrary.swift", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);

            // VisionOS does not support surface shaders (CustomMaterial).
            if (buildTarget == BuildTarget.StandaloneOSX)
                CopyAndAddToBuildTarget(swiftAppTarget, "Shaders.metal", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);

            CopyAndAddToBuildTarget(swiftAppTarget, "ComputeShaders.metal", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);

            if (buildTarget == BuildTarget.VisionOS)
            {
                // remove the input system iOS step counter implementation
                RemoveFileFromProjectAndDelete("Libraries/com.unity.inputsystem/InputSystem/Plugins/iOS/iOSStepCounter.mm");

                // and add a dummy one
                CopyAndAddToBuildTarget(unityFrameworkTarget, "iOSStepCounterDummy.mm", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);
                CopyAndAddToBuildTarget(swiftAppTarget, "ScreenOverlay.usda", UNITY_RK_SRC_PATH, XCODE_POLYSPATIAL_RK_PATH);

                CopyAndAddToProject("Unity-VisionOS-Bridging-Header.h", UNITY_RK_SRC_PATH, "");
                proj.SetBuildProperty(swiftAppTarget, "SWIFT_OBJC_BRIDGING_HEADER", "Unity-VisionOS-Bridging-Header.h");
            }

            // we added our own Swift shell
            RemoveFileFromProjectAndDelete("MainApp/main.mm");

            if (extraSourceFiles != null)
            {
                foreach (var item in extraSourceFiles)
                {
                    var filePathInProject = item.Key;

                    if (item.Value != null)
                    {
                        Directory.CreateDirectory(Path.Combine(path, Path.GetDirectoryName(filePathInProject)));
                        FileUtil.CopyFileOrDirectory(item.Value, Path.Combine(path, filePathInProject));
                    }

                    var target = item.Key.StartsWith("MainApp") ? swiftAppTarget : unityFrameworkTarget;
                    AddFileToBuildTarget(proj, filePathInProject, target, filePathInProject);
                }
            }

            if (pathsToMoveToSwiftApp != null)
            {
                foreach (var item in pathsToMoveToSwiftApp)
                {
                    // these paths will be in Unity's filesystem namespace, i.e. "Assets/..." or "Packages/...".
                    // These get put into "Libraries/ARM64/..." in the Xcode project.
                    var projectPath = "Libraries/ARM64/" + item;
                    MoveProjectFileToTarget(projectPath, unityFrameworkTarget, swiftAppTarget);
                }
            }

            // Configure Unity Framework; add a modulemap file to allow access from Swift,
            // and tweak build settings.
            {
                var moduleProjectPath = "UnityFramework/UnityFramework.modulemap";
                var moduleFileDestPath = Path.Combine(path, moduleProjectPath);
                WriteTextIfChanged(moduleFileDestPath,
                    File.ReadAllText(Path.Combine(UNITY_RK_SRC_PATH, MODULE_MAP))
                        .Replace("__EXTRA_HEADERS__", extraHeaders.ToString()));
                var fileGuid = proj.AddFile(moduleProjectPath, moduleProjectPath);

                proj.AddBuildProperty(unityFrameworkTarget, "MODULEMAP_FILE", "$(SRCROOT)/" + moduleProjectPath);
                proj.SetBuildProperty(unityFrameworkTarget, "DEFINES_MODULE", "YES");
                proj.SetBuildProperty(unityFrameworkTarget, "ENABLE_BITCODE", "NO");
            }

            // These are hacks -- both of these are required, and Unity doesn't properly
            // fill them out in the iPhone project.
            // TODO fix this in new project generation
            if (buildTarget == BuildTarget.VisionOS) {
                var swiftAppConfigGuids = proj.BuildConfigNames()
                    .Select(name => proj.BuildConfigByName(swiftAppTarget, name))
                    .Where(p => !String.IsNullOrEmpty(p)).ToArray();
                // These must be valid, or the project won't run.
                var buildNumber = String.IsNullOrEmpty(PlayerSettings.VisionOS.buildNumber) ? "1" : PlayerSettings.VisionOS.buildNumber;
                var bundleVersion = String.IsNullOrEmpty(PlayerSettings.bundleVersion) ? "1.0" : PlayerSettings.bundleVersion;
                proj.AddBuildPropertyForConfig(swiftAppConfigGuids, "CURRENT_PROJECT_VERSION", buildNumber);
                proj.AddBuildPropertyForConfig(swiftAppConfigGuids, "MARKETING_VERSION", bundleVersion);
            }

            var xcodePlatformName = GetXcodePlatformName(buildTarget);

            ConfigureMainAppTarget(proj, swiftAppTarget, xcodePlatformName);

            var projContents = proj.WriteToString();
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
            return PlayerSettings.VisionOS.sdkVersion != VisionOSSdkVersion.Device;
        }

        public static string GetXcodePlatformName(BuildTarget target)
        {
            if (target == BuildTarget.VisionOS)
                return IsSimulator() ? "xrsimulator" : "xros";

            throw new InvalidOperationException("Unknown build target");
        }

        // Can't be verbatim string. See https://github.com/dotnet/csharpstandard/issues/292
        // Seems that the code analyzer in current Unity will barf on the #define in the verbatim
        // string thinking that it's a real define. This is regardless of the fact that it's in a
        // define that should lock it out of compilation on Windows. The analyzers process all c# code
        // in the project regardless of compilation restrictions.
        //
        // This only seems to happen on Windows, not on Mac.
        static readonly string DUMMY_SUPPORT_FILE ="\n" +
"// WARNING: THIS FILE IS GENERATED. DO NOT MODIFY.\n" +
"\n" +
"#import <Foundation/Foundation.h>\n" +
"\n" +
"// This actually won't do anything, because it seems like if you use -exported_symbols on\n" +
"// the linker command line, it overrides _all_ visibility attributes (not just on those\n" +
"// symbols).\n" +
"#define EXPORTED_SYMBOL __attribute__((visibility(\"default\")))  __attribute__((__used__))\n" +
"\n" +
"extern \"C\" {\n" +
"\n" +
"void EXPORTED_SYMBOL SetPolySpatialNativeAPIImplementation(const void* lightweightApi, int size)\n" +
"{\n" +
"}\n" +
"\n" +
"void EXPORTED_SYMBOL GetPolySpatialNativeAPI(void* lightweightApi)\n" +
"{\n" +
"}\n" +
"\n" +
"} // extern \"C\"\n";

        internal static void WriteDummySupportFile(string projectPath, string projectName)
        {
            var xcodePath = Path.Combine(projectPath, projectName, "project.pbxproj");

            var proj = new PBXProject();
            proj.ReadFromFile(xcodePath);

            var unityFrameworkTarget = proj.GetUnityFrameworkTargetGuid();

            var projectFile = Path.Combine(projectPath, "UnityFramework", "PolySpatialPlatformAPI.mm");
            File.WriteAllText(projectFile, DUMMY_SUPPORT_FILE);
            BuildUtils.AddFileToBuildTarget(proj, projectFile, unityFrameworkTarget, projectFile);
            proj.WriteToFile(xcodePath);
        }
    }
}
#endif
