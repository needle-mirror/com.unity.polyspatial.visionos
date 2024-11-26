#if (UNITY_VISIONOS ||  POLYSPATIAL_INTERNAL) && (UNITY_EDITOR_OSX || UNITY_EDITOR_WIN)
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
        struct VolumeWindowConfiguration
        {
            public VolumeCamera.PolySpatialVolumeCameraMode Mode;
            public VolumeCamera.PolySpatialWindowWorldAlignment WorldAlignment;
            public Vector3 OutputDimensions;
            public VolumeCamera.PolySpatialWindowResizeLimits ResizeLimits;
            public Vector3 MinSize;
            public Vector3 MaxSize;

            public VolumeWindowConfiguration(VolumeCameraWindowConfiguration configuration)
            {
                Mode = configuration.Mode;
                WorldAlignment = configuration.WorldAlignment;
                OutputDimensions = configuration.Dimensions;
                ResizeLimits = configuration.WindowResizeLimits;
                MinSize = configuration.MinWindowSize;
                MaxSize = configuration.MaxWindowSize;
            }
        }

        internal const string k_XcodeProjName = "Unity-VisionOS.xcodeproj";

        public int callbackOrder => 150; // 150 is after the plugin builder (?)

        const int m_PlayToDeviceVolumeSizeRange = 3;

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
            var mixedRealitySupported = xrSettings != null && xrSettings.appMode is VisionOSSettings.AppMode.RealityKit or VisionOSSettings.AppMode.Hybrid;
            BuildUtils.GetRuntimeFlagsForAuto(mixedRealitySupported, out runtimeEnabled, out var runtimeLinked);

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
        // Passing in each variable instead of the whole VolumeCameraWindowConfiguration class due to the fact that P2D uses this function
        // but doesn't have access to VolumeCameraWindowConfiguration scriptable objects - P2D uses hard-coded values.
        static string CreateWindowConfigurationEntry(
            VolumeWindowConfiguration configuration,
            string configName)
        {
            var worldAlignmentString = "";
            switch (configuration.WorldAlignment)
            {
                case VolumeCamera.PolySpatialWindowWorldAlignment.Adaptive:
                    worldAlignmentString = ".volumeWorldAlignment(.adaptive)";
                    break;
                case VolumeCamera.PolySpatialWindowWorldAlignment.GravityAligned:
                    worldAlignmentString = ".volumeWorldAlignment(.gravityAligned)";
                    break;
            }

            var windowSizeLimitString = "";
            var minWindowSize = configuration.MinSize;
            var maxWindowSize = configuration.MaxSize;
            switch (configuration.ResizeLimits)
            {
                case VolumeCamera.PolySpatialWindowResizeLimits.FixedSize:
                    // Fix min and max window size to output dimensions.
                    windowSizeLimitString = ".windowResizability(.contentSize)";
                    minWindowSize = configuration.OutputDimensions;
                    maxWindowSize = configuration.OutputDimensions;
                    break;
                case VolumeCamera.PolySpatialWindowResizeLimits.LimitMinimumSize:
                    windowSizeLimitString = ".windowResizability(.contentMinSize)";
                    break;
                case VolumeCamera.PolySpatialWindowResizeLimits.LimitMinimumAndMaximumSize:
                    windowSizeLimitString = ".windowResizability(.contentSize)";
                    break;
            }

            DimensionsToSwiftStrings(configuration.OutputDimensions, out var dimsVec3, out var dimsSizeParams, out var _);
            DimensionsToSwiftStrings(minWindowSize, out var minSizeString, out _, out _);
            DimensionsToSwiftStrings(maxWindowSize, out var maxSizeString, out _, out _);

            var windowType = "";
            var windowStyle = "";
            var limbVisibility = VisionOSSettings.currentSettings.upperLimbVisibility;
            var upperLimbVisibility = $".upperLimbVisibility({VisionOSSettings.VisibilityToString(limbVisibility)})";
            switch (configuration.Mode)
            {
                case VolumeCamera.PolySpatialVolumeCameraMode.Bounded:
                    windowType = "WindowGroup";
                    windowStyle = $".windowStyle(.volumetric).defaultSize({dimsSizeParams}){windowSizeLimitString}";
                    // The entry in the App Scene for these types of windows
                    return $@"
                    {windowType}(id: ""{configName}"", for: UUID.self) {{ uuid in
                        PolySpatialContentViewWrapper(minSize: {minSizeString}, maxSize: {maxSizeString})
                            .environment(\.pslWindow, PolySpatialWindow(uuid.wrappedValue, ""{configName}"", {dimsVec3}))
                        KeyboardTextField().frame(width: 0, height: 0).modifier(LifeCycleHandlerModifier())
                    }} defaultValue: {{ UUID() }} {windowStyle} {upperLimbVisibility} {worldAlignmentString}";

                case VolumeCamera.PolySpatialVolumeCameraMode.Unbounded:
                    windowType = "ImmersiveSpace";
                    windowStyle = "";

                    var overlayVisibility = VisionOSSettings.currentSettings.realityKitImmersiveOverlays;
                    var persistentSystemOverlays =
                        $".persistentSystemOverlays({VisionOSSettings.VisibilityToString(overlayVisibility)})";

                    var immersionStyle = VisionOSSettings.currentSettings.realityKitImmersionStyle;
                    var immersionStyleString = VisionOSSettings.ImmersionStyleToString(immersionStyle);
                    // The entry in the App Scene for these types of windows
                    return $@"
                    {windowType}(id: ""{configName}"", for: UUID.self) {{ uuid in
                        PolySpatialContentViewWrapper(minSize: {minSizeString}, maxSize: {maxSizeString})
                            .environment(\.pslWindow, PolySpatialWindow(uuid.wrappedValue, ""{configName}"", {dimsVec3}))
                            .onImmersionChange() {{ oldContext, newContext in
                                PolySpatialWindowManagerAccess.onImmersionChange(oldContext.amount, newContext.amount)
                            }}
                        KeyboardTextField().frame(width: 0, height: 0).modifier(LifeCycleHandlerModifier())
                    }} defaultValue: {{ UUID() }} {windowStyle} {upperLimbVisibility} {persistentSystemOverlays}
                    .immersionStyle(selection: .constant({immersionStyleString}), in: {immersionStyleString})";

                case VolumeCamera.PolySpatialVolumeCameraMode.Metal:
                    return "\n        unityVisionOSCompositorSpace";
                default:
                    throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {configuration.Mode}");
            }
        }

        [Conditional("PLAY_TO_DEVICE")]
        static void ConfigurePlayToDevice(HashSet<string> allAvailableConfigs, List<string> availableConfigsForMatch, List<string> sceneContent)
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
                // and the list for the matchable volume cameras.
                DimensionsToSwiftStrings(dim, out var swiftVec3, out var _, out var configName);

                if (!allAvailableConfigs.Add(configName))
                {
                    Debug.LogWarning($"One of the volume window configurations {configName} in the PlayToDevice project " +
                                     "conflicts with the PlayToDevice preset volume window configurations. Limit " +
                                     "overlaps between the configurations in the project and the configurations in the preset.");
                    continue;
                }

                availableConfigsForMatch.Add(swiftVec3);

                // Create an entry for this bounded volume camera. Min and max size are hardcoded to avoid creating multiple volume configurations
                // for every possible window size.
                var minWindowSize = new Vector3(
                    Mathf.Clamp(dim.x - m_PlayToDeviceVolumeSizeRange, 0.0f, float.MaxValue),
                    Mathf.Clamp(dim.y - m_PlayToDeviceVolumeSizeRange, 0.0f, float.MaxValue),
                    Mathf.Clamp(dim.z - m_PlayToDeviceVolumeSizeRange, 0.0f, float.MaxValue));
                var maxWindowSize = dim + (Vector3.one * m_PlayToDeviceVolumeSizeRange);

                var p2dConfig = new VolumeWindowConfiguration()
                {
                    Mode = VolumeCamera.PolySpatialVolumeCameraMode.Bounded,
                    WorldAlignment = VolumeCamera.PolySpatialWindowWorldAlignment.GravityAligned,
                    OutputDimensions = dim,
                    ResizeLimits = VolumeCamera.PolySpatialWindowResizeLimits.LimitMinimumSize,
                    MinSize = minWindowSize,
                    MaxSize = maxWindowSize,
                };
                var swift = CreateWindowConfigurationEntry(
                    p2dConfig,
                    configName);

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

            // Avoid multiple configs matching the initial configuration, that way we ensure the initial configuration is used.
            configurations.RemoveAll(cfg => NameForVolumeConfig(cfg) == NameForVolumeConfig(initialConfig) && cfg != initialConfig);

            List<string> sceneContent = new();
            HashSet<string> allAvailableConfigs = new();
            foreach (var config in configurations)
            {
                var configName = NameForVolumeConfig(config);

                // If a duplicate configuration has already been added, skip it.
                if (!allAvailableConfigs.Add(configName))
                {
                    Debug.LogWarning(@$"VolumeCameraWindowConfiguration {config.name} conflicts with another configuration in the project.
Please ensure the project does not have duplicate Metal or Unbounded configurations, and that each Bounded configuration has a different OutputDimension." );
                    continue;
                }

                // for Unbounded, we always treat is as 1.0 (?)
                var configurationEntry = new VolumeWindowConfiguration(config)
                {
                    OutputDimensions = config.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ? Vector3.one : config.Dimensions,
                    MinSize = config.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ? Vector3.zero : config.MinWindowSize,
                    MaxSize = config.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Unbounded ? Vector3.zero : config.MaxWindowSize
                };

                var swift = CreateWindowConfigurationEntry(
                    configurationEntry,
                    configName);

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

            // The transition from Unbounded RealityKit to Metal requires a window to be visible while the RealityKit space is closed, otherwise the app is backgrounded and the
            // user is presented with the home screen (as if the app has closed or crashed)
            // Note: if users modify the immersion style of the RealityKit ImmersiveSpace, they can hit this issue and get backgrounded. They will need to provide
            // their own loading window to compensate for this.
            // TODO: LXR-3770 Allow users to customize the behavior and content of the loading window
            sceneContent.Add("\n        WindowGroup(id: \"LoadingWindow\") {\n            Text(\"Loading...\")\n        }.defaultSize(width: 0.2, height: 0.15)");

            var parameters = PolySpatialSettings.Instance.DeviceDisplayProviderParameters;

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

            var settings = VisionOSSettings.currentSettings;

            // RealityKit mode will not need the graphics device, so we use batch mode to save CPU cycles
            var startInBatchMode = settings != null && settings.appMode == VisionOSSettings.AppMode.RealityKit;

// ==============================
// the template of the entire file.
            var content = $@"// GENERATED BY BUILD
import Foundation
import SwiftUI
import PolySpatialRealityKit
import UnityFramework

let unityStartInBatchMode = {(startInBatchMode ? "true" : "false")}

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
            var initialConfig = PolySpatialSettings.Instance.DefaultVolumeCameraWindowConfiguration;
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

                case VolumeCamera.PolySpatialVolumeCameraMode.Metal:
                    return "CompositorSpace";

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

                    // Define UNITY_POLYSPATIAL to allow compositor space from XR plugin to use PolySpatial APIs for mode switching
                    const string swiftFlagsProperty = "SWIFT_ACTIVE_COMPILATION_CONDITIONS";
                    var swiftFlags = pbx.GetBuildPropertyForConfig(cfguid, swiftFlagsProperty) ?? string.Empty;
                    swiftFlags = $"UNITY_POLYSPATIAL {swiftFlags}";
                    pbx.SetBuildPropertyForConfig(cfguid, swiftFlagsProperty, swiftFlags);
                }
            }

            pbx.WriteToFile(xcodePbx);
        }

        private void FilterPlist(string outputPath)
        {
            var settings = VisionOSSettings.currentSettings;
            if (settings.appMode == VisionOSSettings.AppMode.Metal)
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

                var immersionStyleString = GetImmersionStyleString(settings.realityKitImmersionStyle);
                dict.SetString("UISceneInitialImmersionStyle", immersionStyleString);

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
            else if (initialConfig.Mode == VolumeCamera.PolySpatialVolumeCameraMode.Metal)
            {
                sceneManifest.SetString("UIApplicationPreferredDefaultSceneSessionRole", "CPSceneSessionRoleImmersiveSpaceApplication");
                var sceneConfigs = sceneManifest.CreateDict("UISceneConfigurations");
                var array = sceneConfigs.CreateArray("CPSceneSessionRoleImmersiveSpaceApplication");
                var dict = array.AddDict();
                var immersionStyleString = GetImmersionStyleString(settings.metalImmersionStyle);
                dict.SetString("UISceneInitialImmersionStyle", immersionStyleString);

                // remove PreferredLaunchSize if present from previous build
                if (root.values.ContainsKey("UILaunchPlacementParameters"))
                {
                    var launchParams = root["UILaunchPlacementParameters"].AsDict();
                    launchParams.values.Remove("PreferredLaunchSize");
                }
            }
            else
            {
                throw new InvalidOperationException($"Unexpected VolumeCameraConfiguration mode {initialConfig.Mode}");
            }

            plist.WriteToFile(plistPath);
        }

        static string GetImmersionStyleString(VisionOSSettings.ImmersionStyle immersionStyle)
        {
            switch (immersionStyle)
            {
                case VisionOSSettings.ImmersionStyle.Automatic:
                    return "UIImmersionStyleMixed";
                case VisionOSSettings.ImmersionStyle.Full:
                    return "UIImmersionStyleFull";
                case VisionOSSettings.ImmersionStyle.Mixed:
                    return "UIImmersionStyleMixed";
                case VisionOSSettings.ImmersionStyle.Progressive:
                    return "UIImmersionStyleProgressive";
                default:
                    throw new ArgumentOutOfRangeException();
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
}
#endif
