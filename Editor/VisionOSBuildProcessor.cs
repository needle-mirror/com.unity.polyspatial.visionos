#if (UNITY_IOS || UNITY_VISIONOS || UNITY_STANDALONE_OSX) && UNITY_EDITOR_OSX
using System.Runtime;
using System.ComponentModel;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEditor.UnityLinker;
using UnityEditor.XR.VisionOS;
using UnityEngine;
using UnityEngine.SceneManagement;
using Debug = UnityEngine.Debug;

namespace Unity.PolySpatial.Internals.Editor
{
    internal class VisionOSBuildPreProcessor : IPreprocessBuildWithReport
    {
#if UNITY_2022_3_9 || UNITY_2022_3_10
        internal const string k_XcodeProjName = "Unity-iPhone.xcodeproj";
#else
        internal const string k_XcodeProjName = "Unity-VisionOS.xcodeproj";
#endif

        public int callbackOrder => 0;

        public void OnPreprocessBuild(BuildReport report)
        {
#if UNITY_2022_3_9 || UNITY_2022_3_10
            if (PlayerSettings.VisionOS.sdkVersion != VisionOSSdkVersion.Device)
            {
                throw new BuildFailedException("Unity versions prior to 2022.3.11f1 do not support a Target SDK of anything other than Device SDK. Please change the Target SDK setting in Player Settings to Device SDK.");
            }
#endif

            try
            {
                SwiftAppShellProcessor.RestoreXcodeProject(report.summary.outputPath, k_XcodeProjName);
            }
            catch (Exception e)
            {
                throw new BuildFailedException(e);
            }
        }
    }

    static class PListElementDictExtensions
    {
        internal static PlistElementDict GetOrCreateDict(this PlistElementDict dict, string key)
        {
            if (dict.values.ContainsKey(key))
                return dict[key].AsDict();
            return dict.CreateDict(key);
        }
    }

    internal class VisionOSBuildPostProcessor : IPostprocessBuildWithReport
    {
        public int callbackOrder => 150; // after the plugin builder

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.VisionOS)
                return;

            var outputPath = report.summary.outputPath;
            PatchIl2Cpp(outputPath);

            if (!PolySpatialSettings.instance.EnablePolySpatialRuntime
#if POLYSPATIAL_INTERNAL
                && !PolySpatialSettings.instance.AlwaysLinkPolySpatialRuntime
#endif
               )
            {
                return;
            }

            try
            {
#if UNITY_2022_3_9 || UNITY_2022_3_10
                bool isSimulator = false;
#else
                bool isSimulator = PlayerSettings.VisionOS.sdkVersion == VisionOSSdkVersion.Simulator;
#endif

                WriteVisionOSSettings(outputPath);

                var settings = VisionOSSettings.currentSettings;
                var appMode = VisionOSSettings.AppMode.MR;
                if (settings != null)
                    appMode = settings.appMode;

                Dictionary<string, string> extraSourceFiles = null;
                if (appMode == VisionOSSettings.AppMode.MR)
                {
                    extraSourceFiles = new Dictionary<string, string>()
                    {
                        { "MainApp/UnityVisionOSSettings.swift", null }
                    };
                }

                SwiftAppShellProcessor.ConfigureXcodeProject(report.summary.platform, outputPath,
                    VisionOSBuildPreProcessor.k_XcodeProjName, appMode,
                    il2cppArmWorkaround: true,
                    staticLibraryPluginName: isSimulator ? "libPolySpatial_xrsimulator.a" : "libPolySpatial_xros.a",
                    extraSourceFiles: extraSourceFiles
                );

                FilterXcodeProj(outputPath, VisionOSBuildPreProcessor.k_XcodeProjName);
                FilterPlist(outputPath);
            }
            catch (Exception e)
            {
                throw new BuildFailedException(e);
            }
        }

        // Convert the Vector3 dimensions into various snippets of Swift and identifiers we'll need
        static void DimensionsToSwiftStrings(Vector3 dim, out string swiftVec3, out string swiftSizeParams, out string volIdent)
        {
            // tostring with 3 decimal points, and convert to xxx.abc 3 digits of precision in meters consistently
            var dims = new string[] { dim.x.ToString("F3"), dim.y.ToString("F3"), dim.z.ToString("F3") };
            swiftVec3 = $".init({dims[0]}, {dims[1]}, {dims[2]})";
            swiftSizeParams = $"width: {dims[0]}, height: {dims[1]}, depth: {dims[2]}, in: .meters";
            volIdent = $"Bounded-{dims[0]}x{dims[1]}x{dims[2]}";
        }

        static void WriteVisionOSSettings(string outputPath)
        {
            List<VolumeCameraConfiguration> configurations = new();

            // TODO -- load referenced items from scenes
            configurations.AddRange(Resources.LoadAll<VolumeCameraConfiguration>(""));

            var initialConfig = GetDefaultVolumeConfig();

            if (!configurations.Contains(initialConfig))
            {
                configurations.Add(initialConfig);
            }

            StringBuilder sceneContent = new();

            foreach (var config in configurations)
            {
                string windowType = null;
                string windowStyle = null;
                var configName = NameForVolumeConfig(config);

                // for Unbounded, we always treat is as 1.0 (?)
                var dim = config.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ? Vector3.one : config.Dimensions;
                DimensionsToSwiftStrings(dim, out var dimsVec3, out var dimsSizeParams, out var _);

                switch (config.Mode)
                {
                    case VolumeCamera.PolySpatialVolumeCameraMode.Bounded:
                        windowType = "WindowGroup";
                        windowStyle = $".windowStyle(.volumetric).defaultSize({dimsSizeParams})";
                        break;
                    case VolumeCamera.PolySpatialVolumeCameraMode.Unbounded:
                        windowType = "ImmersiveSpace";
                        windowStyle = "";
                        break;
                    default:
                        throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {config.Mode}");
                }

                // The entry in the App Scene for these types of windows
                var swift = $@"
        {windowType}(id: ""{configName}"", for: UUID.self) {{ uuid in
            PolySpatialContentViewWrapper()
                .environment(\.pslWindow, PolySpatialWindow(uuid.wrappedValue, ""{configName}"", {dimsVec3}))
        }} defaultValue: {{ UUID() }} {windowStyle}
";

                // The default/initial configuration needs to be first in the Scene list,
                // because this is what the OS will open on launch. Otherwise just append to the
                // string.
                sceneContent.Insert(config == initialConfig ? 0 : sceneContent.Length, swift);
            }

// ==============================
// the template of the entire file.
            var content = $@"// GENERATED BY BUILD
import Foundation
import SwiftUI
import PolySpatialRealityKit

extension UnityPolySpatialApp {{
    func initialWindowName() -> String {{ return ""{NameForVolumeConfig(initialConfig)}"" }}

    @SceneBuilder
    var mainScene: some Scene {{
{sceneContent.ToString()}
    }}
}}
";
// ==============================

            File.WriteAllText(Path.Combine(outputPath, "MainApp", "UnityVisionOSSettings.swift"), content);
        }

        static VolumeCameraConfiguration GetDefaultVolumeConfig()
        {
            var initialConfig = PolySpatialSettings.instance.DefaultVolumeCameraConfiguration;
            if (initialConfig == null)
            {
                // handle projects without this setting that have never opened the PolySpatial Settings window
                initialConfig = Resources.Load<VolumeCameraConfiguration>("Default Unbounded Configuration");
            }

            return initialConfig;
        }

        static string NameForVolumeConfig(VolumeCameraConfiguration config)
        {
            switch (config?.Mode)
            {
                case VolumeCamera.PolySpatialVolumeCameraMode.Bounded:
                    DimensionsToSwiftStrings(config.Dimensions, out var _, out var _, out var volIdent);
                    return volIdent;

                case VolumeCamera.PolySpatialVolumeCameraMode.Unbounded:
                case null:
                    return "Unbounded";
            }

            throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {config.Mode}");
        }

        void ReplaceStrings(ref string contents, string[][] replacements)
        {
            foreach (var subs in replacements)
            {
                if (!contents.Contains(subs[0]))
                {
                    Debug.LogWarning($"BuildProcessor ReplaceStrings: couldn't find string '{subs[0]}'");
                }

                contents = contents.Replace(subs[0], subs[1]);
            }
        }

        void FilterXcodeProj(string outputPath, string xcodeProjName)
        {
            var xcodeProj = Path.Combine(outputPath, xcodeProjName);
            var xcodePbx = Path.Combine(xcodeProj, "project.pbxproj");

            var pbx = new PBXProject();
            pbx.ReadFromFile(xcodePbx);

            // add in -ld argument, for object file compat
            foreach (var tgt in new[] { pbx.GetUnityFrameworkTargetGuid(), pbx.GetUnityMainTargetGuid() })
            {
                foreach (var cfgname in pbx.BuildConfigNames())
                {
                    var cfguid = pbx.BuildConfigByName(tgt, cfgname);
                    if (cfguid == null)
                        continue;

                    var existing = pbx.GetBuildPropertyForConfig(cfguid, "OTHER_LDFLAGS") ?? "";
#if UNITY_2022_3_9 || UNITY_2022_3_10
                    pbx.SetBuildPropertyForConfig(cfguid, "OTHER_LDFLAGS", $"-ld64 {existing}");
#else
                    pbx.SetBuildPropertyForConfig(cfguid, "OTHER_LDFLAGS", $"-ld_classic -Wl,-exported_symbol,_SetPolySpatialNativeAPIImplementation {existing}");
#endif

                    // TODO: remove this from the template (sets to YES)
                    pbx.SetBuildPropertyForConfig(cfguid, "INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "NO");

                    // Add TARGET_OS_XR define which was renamed to TARGET_OS_VISION in visionOS beta 2 (Xcode beta 5)
                    existing = pbx.GetBuildPropertyForConfig(cfguid, "OTHER_CFLAGS") ?? "";
                    pbx.SetBuildPropertyForConfig(cfguid, "OTHER_CFLAGS", $"-DTARGET_OS_XR=1 {existing}");
                }
            }

            pbx.WriteToFile(xcodePbx);
        }

        private void FilterPlist(string outputPath)
        {
            var settings = VisionOSSettings.currentSettings;
            if (settings.appMode == VisionOSSettings.AppMode.VR)
                return;

            var plistPath = outputPath + "/Info.plist";
            var plist = new PlistDocument();
            plist.ReadFromFile(plistPath);

            var root = plist.root;

            // TODO -- remove these from template!
            root.values.Remove("UIRequiredDeviceCapabilities");
            root.values.Remove("UILaunchStoryboardName");
            root.values.Remove("UILaunchStoryboardName~iphone");
            root.values.Remove("UILaunchStoryboardName~ipad");
            root.values.Remove("UILaunchStoryboardName~ipod"); // lol?
            root.values.Remove("LSRequiresIPhoneOS");
            root.values.Remove("UIRequiresFullScreen");
            root.values.Remove("UIStatusBarHidden");
            root.values.Remove("UIViewControllerBasedStatusBarAppearance");

            PlistElementDict sceneManifest = root.GetOrCreateDict("UIApplicationSceneManifest");

            sceneManifest["UIApplicationSupportsMultipleScenes"] = new PlistElementBoolean(true);

            var initialConfig = GetDefaultVolumeConfig();

            if (initialConfig.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded)
            {
                sceneManifest.SetString("UIApplicationPreferredDefaultSceneSessionRole", "UISceneSessionRoleImmersiveSpaceApplication");
                var sceneConfigs = sceneManifest.CreateDict("UISceneConfigurations");
                var array = sceneConfigs.CreateArray("UISceneSessionRoleImmersiveSpaceApplication");
                var dict = array.AddDict();
                dict.SetString("UISceneConfigurationName", "Unbounded");
                dict.SetString("UISceneInitialImmersionStyle", "UIImmersionStyleMixed");

                // remove PreferredLaunchSize if present from previous build
                if (root.values.ContainsKey("UILaunchPlacementParameters"))
                {
                    var launchParams = root["UILaunchPlacementParameters"].AsDict();
                    launchParams.values.Remove("PreferredLaunchSize");
                }

            }
            else if (initialConfig.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Bounded)
            {
                sceneManifest.SetString("UIApplicationPreferredDefaultSceneSessionRole", "UIWindowSceneSessionRoleVolumetricApplication");

                float metersToPoints = 2834.65f;

                var launchParams = root.GetOrCreateDict("UILaunchPlacementParameters");
                var preferredSize = launchParams.GetOrCreateDict("PreferredLaunchSize");
                // these are always in points
                preferredSize.SetReal("Width", initialConfig.Dimensions.x * metersToPoints);
                preferredSize.SetReal("Height", initialConfig.Dimensions.y * metersToPoints);
                preferredSize.SetReal("Depth", initialConfig.Dimensions.z * metersToPoints);
            }
            else
            {
                throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {initialConfig.Mode}");
            }

            plist.WriteToFile(plistPath);
        }

        static void PatchIl2Cpp(string outputPath)
        {
            // Only 2022.3.9f1 can be patched to work with Xcode 15b8. Earlier versions will not work, and later versions do not require the patch
            if (Application.unityVersion != "2022.3.9f1")
                return;

            const string patchesDirectory = "Packages/com.unity.polyspatial.visionos/Patches~";
            if (!Directory.Exists(patchesDirectory))
            {
#if POLYSPATIAL_INTERNAL
                Debug.LogWarning("Expected to find patches directory, but it doesn't exist");
#endif
                return;
            }

            const string patchFileName = "Bee.Toolchain.Xcode.dll";
            const string il2CppPath = "Il2CppOutputProject/IL2CPP/build/deploy_arm64";
            var destFileName = Path.Combine(outputPath, il2CppPath, patchFileName);
            var sourceFileName = Path.Combine(patchesDirectory, patchFileName);
            File.Copy(sourceFileName, destFileName, true);
        }
    }
}
#endif
