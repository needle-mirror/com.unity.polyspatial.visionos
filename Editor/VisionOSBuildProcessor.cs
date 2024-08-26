#if (UNITY_VISIONOS || UNITY_IOS || POLYSPATIAL_INTERNAL) && (UNITY_EDITOR_OSX || UNITY_EDITOR_WIN)
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
using UnityEditor.PolySpatial.Utilities;
using UnityEditor.UnityLinker;
using UnityEditor.XR.VisionOS;
using UnityEngine;
using UnityEngine.SceneManagement;
using Debug = UnityEngine.Debug;

namespace Unity.PolySpatial.Internals.Editor
{
    internal class VisionOSBuildProcessor : IPreprocessBuildWithReport, IPostprocessBuildWithReport
    {
        internal const string k_XcodeProjName = "Unity-VisionOS.xcodeproj";

        public int callbackOrder => 150; // 150 is after the plugin builder (?)

        public void OnPreprocessBuild(BuildReport report)
        {
            DoPreprocessBuild(report);
        }

        public void OnPostprocessBuild(BuildReport report)
        {
            DoPostprocessBuild(report);
        }

        static bool ShouldProcessWithRuntime(BuildReport report, out bool runtimeEnabled)
        {
            if (report.summary.platform != BuildTarget.VisionOS)
            {
                runtimeEnabled = false;
                return false;
            }

            var xrSettings = VisionOSSettings.currentSettings;
            var autoMeansEnabled = xrSettings != null && xrSettings.appMode == VisionOSSettings.AppMode.MR;

            BuildUtils.GetRuntimeFlagsForAuto(autoMeansEnabled, out runtimeEnabled, out var runtimeLinked);

            return runtimeLinked;
        }

        List<string> m_InjectedScenePaths = new();
        List<string> m_swiftAppSupportPaths = new();

        [Conditional("UNITY_VISIONOS")]
        public void DoPreprocessBuild(BuildReport report)
        {
            if (!ShouldProcessWithRuntime(report, out var _))
                return;

#if POLYSPATIAL_INTERNAL && UNITY_EDITOR_OSX
            if (!File.Exists("Packages/com.unity.xr.visionos/Runtime/Plugins/visionos/Device/arm64/libUnityVisionOS.a"))
            {
                Debug.LogWarning($"visionOS XR provider library not built; building.");
                RealityKitPluginBuilder.BuildVisionOSXRPlugin();
            }
#endif

            m_InjectedScenePaths.Clear();
            m_swiftAppSupportPaths.Clear();

            // Capture .swift files that we need to move around later on
            var allPlugImporters = PluginImporter.GetAllImporters();
            foreach (var importer in allPlugImporters)
            {
                if (!importer.GetCompatibleWithPlatform(BuildTarget.VisionOS) || !importer.ShouldIncludeInBuild())
                    continue;

                if (importer.assetPath.EndsWith("InjectedScene.swift"))
                {
                    m_InjectedScenePaths.Add(importer.assetPath);
                }

                if (importer.assetPath.Contains("/SwiftAppSupport/"))
                {
                    m_swiftAppSupportPaths.Add(importer.assetPath);
                }
            }
        }

        public static bool isSimulator => PlayerSettings.VisionOS.sdkVersion == VisionOSSdkVersion.Simulator;

        [Conditional("UNITY_VISIONOS")]
        public void DoPostprocessBuild(BuildReport report)
        {
            if (!ShouldProcessWithRuntime(report, out var runtimeEnabled))
                return;

            try
            {
                var InjectedSceneTypeNames = Array.Empty<string>();

                if (m_InjectedScenePaths.Count > 0)
                {
                    InjectedSceneTypeNames = m_InjectedScenePaths.Select(Path.GetFileNameWithoutExtension).ToArray();
                }

                var outputPath = report.summary.outputPath;
                WriteVisionOSSettings(outputPath, InjectedSceneTypeNames);

                if (runtimeEnabled)
                {
                    var bootConfig = new BootConfigBuildUtility(report);
                    bootConfig.SetValue("polyspatial", "1");
                    bootConfig.Write();
                }

                Dictionary<string, string> extraSourceFiles = new Dictionary<string, string>()
                {
                    { "MainApp/UnityVisionOSSettings.swift", null }
                };

                SwiftAppShellProcessor.ConfigureXcodeProject(report.summary.platform, outputPath,
                    k_XcodeProjName,
                    staticLibraryPluginName: isSimulator ? "libPolySpatial_xrsimulator.a" : "libPolySpatial_xros.a",
                    extraSourceFiles: extraSourceFiles,
                    pathsToMoveToSwiftApp: m_InjectedScenePaths.Concat(m_swiftAppSupportPaths).Distinct().ToArray()
                );

                FilterXcodeProj(outputPath, k_XcodeProjName);
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

        // Create a ImmersiveSpace or WindowGroup entry for the specified volume camera configuration. Optionally pass in a name for this entry, or
        // opt to use the one that DimensionsToSwiftStrings() provides.
        static string CreateWindowConfigurationEntry(
            Vector3 dim,
            VolumeCamera.PolySpatialVolumeCameraMode mode,
            string configName)
        {
            DimensionsToSwiftStrings(dim, out var dimsVec3, out var dimsSizeParams, out var _);

            var windowType = "";
            var windowStyle = "";
            var limbVisibility = VisionOSSettings.currentSettings.upperLimbVisibility;
            var upperLimbVisibility = $".upperLimbVisibility({VisionOSSettings.UpperLimbVisibilityToString(limbVisibility)})";
            switch (mode)
            {
                case VolumeCamera.PolySpatialVolumeCameraMode.Bounded:
                    windowType = "WindowGroup";
                    windowStyle = $".windowStyle(.volumetric).defaultSize({dimsSizeParams})";
                    // The entry in the App Scene for these types of windows
                    return $@"
                    {windowType}(id: ""{configName}"", for: UUID.self) {{ uuid in
                        PolySpatialContentViewWrapper()
                            .environment(\.pslWindow, PolySpatialWindow(uuid.wrappedValue, ""{configName}"", {dimsVec3}))
                        KeyboardTextField().frame(width: 0, height: 0).modifier(LifeCycleHandlerModifier())
                    }} defaultValue: {{ UUID() }} {windowStyle} {upperLimbVisibility}";

                case VolumeCamera.PolySpatialVolumeCameraMode.Unbounded:
                    windowType = "ImmersiveSpace";
                    windowStyle = "";

                    var immersionStyle = VisionOSSettings.currentSettings.mrImmersionStyle;
                    var immersionStyleString = VisionOSSettings.ImmersionStyleToString(immersionStyle);
                    // The entry in the App Scene for these types of windows
                    return $@"
                    {windowType}(id: ""{configName}"", for: UUID.self) {{ uuid in
                        PolySpatialContentViewWrapper()
                            .environment(\.pslWindow, PolySpatialWindow(uuid.wrappedValue, ""{configName}"", {dimsVec3}))
                        KeyboardTextField().frame(width: 0, height: 0).modifier(LifeCycleHandlerModifier())
                    }} defaultValue: {{ UUID() }} {windowStyle} {upperLimbVisibility}
                    .immersionStyle(selection: .constant({immersionStyleString}), in: {immersionStyleString})";

                default:
                    throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {mode}");
            }
        }

        [Conditional("PLAY_TO_DEVICE")]
        static void ConfigurePlayToDevice(List<string> allAvailableConfigs, List<string> availableConfigsForMatch, List<string> sceneContent)
        {
            // TODO LXR-2979: hardcoded for now, will be moved somewhere else.
            Vector3[] possibleDimValues = {
                new Vector3(0.25f, 0.25f, 0.25f),
                new Vector3(0.5f, 0.5f, 0.5f),
                new Vector3(1.0f, 1.0f, 1.0f),
                new Vector3(2.0f, 2.0f, 2.0f),
                new Vector3(3.0f, 3.0f, 3.0f),
                new Vector3(1.33f, 1.0f, 1.0f), // 4:3:3
                new Vector3(1.77f, 1.0f, 1.0f), // 16:9:9
                new Vector3(2.0f, 1.0f, 1.0f), // 2:1:1
                new Vector3(1.0f, 1.0f, 2.0f), // 1:1:2
                new Vector3(1.0f, 1.0f, 1.41f), // 1:1:1.41
            };

            foreach (var dim in possibleDimValues)
            {
                // Create an entry for this in both the list for all volume cameras
                // and the list for the the matchable volume cameras.
                DimensionsToSwiftStrings(dim, out var swiftVec3, out var _, out var configName);

                allAvailableConfigs.Add(configName);
                availableConfigsForMatch.Add(swiftVec3);

                // Create an entry for this bounded volume camera.
                var swift = CreateWindowConfigurationEntry(dim, VolumeCamera.PolySpatialVolumeCameraMode.Bounded, configName);
                sceneContent.Add(swift);
            }
        }

        static void WriteVisionOSSettings(string outputPath, IEnumerable<string> extraWindowGroups)
        {
            List<VolumeCameraWindowConfiguration> configurations = new();

            // TODO -- load referenced items from scenes
            configurations.AddRange(Resources.LoadAll<VolumeCameraWindowConfiguration>(""));

            var initialConfig = GetDefaultVolumeConfig();

            if (!configurations.Contains(initialConfig))
            {
                configurations.Add(initialConfig);
            }

            // Make sure only one Unbounded configuration remains, but if it's also the initial config then make sure
            // that's the one that stays. This is all to avoid multiple ImmersiveSpace scene elements.
            var unbounded =
                    initialConfig.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ?
                    initialConfig :
                    configurations.FirstOrDefault((cfg) => cfg.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded);
            if (unbounded != null)
            {
                // remove any but this first one we found
                configurations.RemoveAll((cfg) =>
                    cfg.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded &&
                    cfg != unbounded);
            }

            List<string> sceneContent = new();
            List<string> allAvailableConfigs = new();

            foreach (var config in configurations)
            {
                var configName = NameForVolumeConfig(config);

                // for Unbounded, we always treat is as 1.0 (?)
                var dim = config.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ? Vector3.one : config.Dimensions;
                var swift = CreateWindowConfigurationEntry(dim, config.Mode, configName);

                // The default/initial configuration needs to be first in the Scene list,
                // because this is what the OS will open on launch. Otherwise just append to the string.
                if (config == initialConfig)
                    sceneContent.Insert(0, swift);
                else
                    sceneContent.Add(swift);

                allAvailableConfigs.Add(configName);
            }

            List<string> availableConfigsForMatch = new();

            ConfigurePlayToDevice(allAvailableConfigs, availableConfigsForMatch, sceneContent);

            // For every Swift plugin that ends in "InjectedScene.swift", add it to the
            // scene content and move it to the SwiftApp in the xcode project. This allows
            // developers to add their own SwiftUI or other windows to the app.
            foreach (var InjectedScenePath in extraWindowGroups)
            {
                var name = Path.GetFileNameWithoutExtension(InjectedScenePath);
                sceneContent.Add($"\n        {name}.scene");
            }

            var parameters = PolySpatialSettings.instance.DeviceDisplayProviderParameters;

            var displayProviderParametersInit = GetDisplayProviderParamametersInitString(parameters);

            StringBuilder mainSceneDeclaration = new();

            if (sceneContent.Count > 100)
            {
                throw new BuildFailedException("Too many volume camera or injected window configurations. The maximum is 100.");
            }

            // a SceneBuilder can take a max of 10 args (declarations), but they can be nested.
            // Split up the declaration into chunks of 10, giving us a max of 100.
            int mainSceneCount = 0;
            for (int i = 0; i < sceneContent.Count; i += 10)
            {
                var sceneContentSlice = sceneContent.Skip(i).Take(10);
                mainSceneDeclaration.Append($@"
    @SceneBuilder
    var mainScenePart{mainSceneCount}: some Scene {{
{String.Join("", sceneContentSlice)}
    }}
");
                mainSceneCount++;
            }

            mainSceneDeclaration.AppendLine($@"
    @SceneBuilder
    var mainScene: some Scene {{");
            for (int i = 0; i < mainSceneCount; i++)
            {
                mainSceneDeclaration.AppendLine($"        mainScenePart{i}");
            }

            mainSceneDeclaration.AppendLine("    }");

// ==============================
// the template of the entire file.
            var content = $@"// GENERATED BY BUILD
import Foundation
import SwiftUI
import PolySpatialRealityKit
import UnityFramework

extension UnityPolySpatialApp {{
    func initialWindowName() -> String {{ return ""{NameForVolumeConfig(initialConfig)}"" }}

    func getAllAvailableWindows() -> [String] {{ return [{String.Join(", ", allAvailableConfigs.Select(s => $"\"{s}\""))}] }}

    func getAvailableWindowsForMatch() -> [simd_float3] {{ return [{String.Join(", ", availableConfigsForMatch)}] }}

    func displayProviderParameters() -> DisplayProviderParameters {{ return {displayProviderParametersInit} }}

    {mainSceneDeclaration}

    struct LifeCycleHandlerModifier: ViewModifier {{
        func body(content: Content) -> some View {{
            content
                .onOpenURL(perform: {{ url in
                    UnityLibrary.instance?.setAbsoluteUrl(url.absoluteString)
                }})
        }}
    }}
}}
";
// ==============================

            File.WriteAllText(Path.Combine(outputPath, "MainApp", "UnityVisionOSSettings.swift"), content);
        }

        static string ToSwift(Vector3 pos) { return $".init(x: {pos.x}, y: {pos.y}, z: {pos.z})"; }
        static string ToSwift(Quaternion quat) { return $".init(x: {quat.x}, y: {quat.y}, z: {quat.z}, w: {quat.w})"; }
        static string ToSwift(PolySpatialSettings.ProjectionHalfAngles angles) { return $".init(left: {angles.left}, right: {angles.right}, top: {angles.top}, bottom: {angles.bottom})"; }

        static string GetDisplayProviderParamametersInitString(PolySpatialSettings.DisplayProviderParameters parameters)
        {
            return $@".init(
            framebufferWidth: {parameters.dimensions.x},
            framebufferHeight: {parameters.dimensions.y},
            leftEyePose: .init(position: {ToSwift(parameters.leftEyePose.position)},
                               rotation: {ToSwift(parameters.leftEyePose.rotation)}),
            rightEyePose: .init(position: {ToSwift(parameters.rightEyePose.position)},
                                rotation: {ToSwift(parameters.rightEyePose.rotation)}),
            leftProjectionHalfAngles: {ToSwift(parameters.leftProjectionHalfAngles)},
            rightProjectionHalfAngles: {ToSwift(parameters.rightProjectionHalfAngles)}
        )
   ";
        }

        static VolumeCameraWindowConfiguration GetDefaultVolumeConfig()
        {
            var initialConfig = PolySpatialSettings.instance.DefaultVolumeCameraWindowConfiguration;
            if (initialConfig == null)
            {
                // handle projects without this setting that have never opened the PolySpatial Settings window
                initialConfig = Resources.Load<VolumeCameraWindowConfiguration>("Default Unbounded Configuration");
            }

            return initialConfig;
        }

        static string NameForVolumeConfig(VolumeCameraWindowConfiguration config)
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

                    // We have lots of exported-symbol goop in the UnityFramework target for the simulator.
                    // It's not necessary, and actually causes problems because it requires all exported
                    // symbols to be specified that way. Remove these here until we get rid of them in the
                    // template.
                    var existing = pbx.GetBuildPropertyForConfig(cfguid, "OTHER_LDFLAGS") ?? null;
                    if (existing != null)
                    {
                        if (!existing.Contains("-exported_symbol"))
                            continue;
                        // This split is not 100% correct, individual elements may be "" quoted. But
                        // we re-join with a " " at the end, and we don't handle backslash-escapes,
                        // so this should be fine in 99.99999999% of cases
                        var items = existing.Split(" ");
                        items = items.Where(s => !s.Contains("-exported_symbol")).ToArray();
                        pbx.SetBuildPropertyForConfig(cfguid, "OTHER_LDFLAGS", string.Join(" ", items));
                    }

                    // TODO: remove this from the template (sets to YES)
                    pbx.SetBuildPropertyForConfig(cfguid, "INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "NO");

                    var cflags = pbx.GetBuildPropertyForConfig(cfguid, "OTHER_CFLAGS") ?? "";

                    // Add TARGET_OS_XR define which was renamed to TARGET_OS_VISION in visionOS beta 2 (Xcode beta 5)
                    cflags = $"-DTARGET_OS_XR=1 {cflags}";

                    // Add UNITY_POLYSPATIAL for stub
                    cflags = $"-DUNITY_POLYSPATIAL=1 {cflags}";

                    pbx.SetBuildPropertyForConfig(cfguid, "OTHER_CFLAGS", cflags);
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
}
#endif
