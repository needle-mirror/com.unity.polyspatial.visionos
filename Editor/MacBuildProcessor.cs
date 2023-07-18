#if POLYSPATIAL_INTERNAL && (UNITY_IOS || UNITY_VISIONOS || UNITY_STANDALONE_OSX) && UNITY_EDITOR_OSX
using System;
using System.IO;
using NUnit.Framework;
using Unity.PolySpatial.Internals.Editor;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEngine;

namespace Unity.PolySpatial.Internals.Editor
{
    internal class PolySpatialMacBuildProcessor : IPostprocessBuildWithReport
    {
        const int k_BuildTimeoutSeconds = 15 * 60;
        const string k_MacOSMinVersion = "10.13";
        const string k_MacOSSDKVersion = "13.1";

        public int callbackOrder => 150;

        static readonly string k_ExtraFrameworksPath = "/opt/UnitySrc/PolySpatialExtraFrameworks";

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.StandaloneOSX)
                return;

            if (!PolySpatialSettings.instance.EnablePolySpatialRuntime
#if POLYSPATIAL_INTERNAL
                && !PolySpatialSettings.instance.ForceLinkPolySpatialRuntime
#endif
               )
            {
                return;
            }

            if (!Directory.Exists("Packages/com.unity.polyspatial.visionos/Lib~/PolySpatial-macOS.bundle"))
            {
#if POLYSPATIAL_INTERNAL
                Debug.LogWarning("Expected to find PolySpatial-macOS.bundle, but it doesn't exist");
#endif
                return;
            }


            try
            {
                CopyMacPlugin(report);
                SetupBootConfig(report);
                AddEnvironment(report);

                // TODO (LXR-1480): Remove this workaround when SDK 13.1 is supported in trunk.
                UpdateMacOSBuildVersion(report);
            }
            catch (Exception e)
            {
                throw new BuildFailedException(e);
            }
        }

        void CopyMacPlugin(BuildReport report)
        {
            var path = report.summary.outputPath;
            var projectName = PlayerSettings.productName;

            var pluginBundle = Path.GetFullPath(Path.Combine("Packages", "com.unity.polyspatial.visionos", "Lib~", $"PolySpatial-macOS.bundle"));
            if (Path.GetExtension(path) == ".app")
            {
                BuildUtils.CopyDirectoryTo(pluginBundle, Path.Combine(path, "Contents", "PlugIns"));
            }
            else
            {
                BuildUtils.CopyDirectoryTo(pluginBundle, Path.Combine(path, projectName, "PlugIns"));

                var pbxPath = Path.Combine(path, Path.GetFileName(path) + ".xcodeproj", "project.pbxproj");
                var proj = new PBXProject();
                proj.ReadFromFile(pbxPath);

                var target = BuildUtils.FindTargetGuidByName(proj, projectName);
                var pluginGuid = BuildUtils.AddFileToProject(proj, $"{projectName}/PlugIns/PolySpatial-macOS.bundle");
                foreach (var phaseGuid in proj.GetAllBuildPhasesForTarget(target))
                {
                    if (proj.GetBuildPhaseName(phaseGuid) == "CopyPlugIns")
                    {
                        proj.AddFileToBuildSection(target, phaseGuid, pluginGuid);
                        break;
                    }
                }

                proj.WriteToFile(pbxPath);
            }
        }

        void AddEnvironment(BuildReport report)
        {
            var projectName = PlayerSettings.productName;

            // Add it to LSEnvironment in the Info.plist; this takes into affect
            // only when executed from the Finder or via `open` on the command line.
            // But also when Unity itself launches it (without an xcode build).
            var infoPlistInXcode =
                Path.Combine(report.summary.outputPath, projectName, "Info.plist");
            var infoPlistInApp =
                Path.Combine(report.summary.outputPath, "Contents", "Info.plist");

            foreach (var plist in new[] { infoPlistInApp, infoPlistInXcode })
            {
                if (!File.Exists(plist))
                    continue;

                // plutil -insert LSEnvironment -dictionary Info.plist
                // plutil -insert LSEnvironment.DYLD_FRAMEWORK_PATH -string /opt/UnitySrc/PolySpatialExtraFrameworks Info.plist
                // Note: these will fail if the key exists, which could be a problem for LSEnvironment; Unity doesn't set anything there by default.
                if (!File.ReadAllText(plist).Contains("DYLD_FRAMEWORK_PATH"))
                {
                    BuildUtils.RunCommand("plutil", $"-insert LSEnvironment -dictionary \"{plist}\"");
                    BuildUtils.RunCommand("plutil",
                        $"-insert LSEnvironment.DYLD_FRAMEWORK_PATH -string {k_ExtraFrameworksPath} \"{plist}\"");
                }
            }

            var pbxPath = Path.Combine(report.summary.outputPath,
                Path.GetFileName(report.summary.outputPath) + ".xcodeproj", "project.pbxproj");
            if (File.Exists(pbxPath))
            {
                // Xcode doesn't use launch services, so LSEnvironment doesn't take effect, which is really annoying.
                // Hack in the -Wl,-dyld_env arg into the pbxproj.
                var pbxStr = File.ReadAllText(pbxPath);
                if (pbxStr.IndexOf($"dyld_env={k_ExtraFrameworksPath}") == -1)
                {
                    pbxStr = pbxStr.Replace(
                        "PRODUCT_BUNDLE_IDENTIFIER =",
                        $"OTHER_LDFLAGS = \"-Wl,-dyld_env,DYLD_FRAMEWORK_PATH={k_ExtraFrameworksPath}\";\nPRODUCT_BUNDLE_IDENTIFIER ="
                    );

                    File.WriteAllText(pbxPath, pbxStr);
                }
            }
        }

        void UpdateMacOSBuildVersion(BuildReport report)
        {
            var path = report.summary.outputPath;
            if (Path.GetExtension(path) != ".app")
                return;

            var projectName = PlayerSettings.productName;
            var targetFile = $"{path}/Contents/MacOS/{projectName}";
            var updatedTargetFile = $"{path}/Contents/MacOS/{projectName}_updated";
            try
            {
                BuildUtils.RunCommand("vtool", $"-set-build-version macos {k_MacOSMinVersion} {k_MacOSSDKVersion} " +
                    $@"-output ""{updatedTargetFile}"" ""{targetFile}""");
                BuildUtils.CopyFile(updatedTargetFile, targetFile, true, true);
                BuildUtils.RunCommand("codesign", $@"-s - -f ""{targetFile}""");
            }
            catch (Exception e)
            {
                Debug.LogError($"Failed to update MacOS build version in {targetFile}. Is there junk in the bundle root? {e}");
            }
        }

        void SetupBootConfig(BuildReport report)
        {
            if (!PolySpatialSettings.instance.EnablePolySpatialRuntime)
                return;

            var projectName = PlayerSettings.productName;

            var bootConfigInXcode =
                Path.Combine(report.summary.outputPath, projectName, "Resources", "Data", "boot.config");
            var bootConfigInApp =
                Path.Combine(report.summary.outputPath, "Contents", "Resources", "Data", "boot.config");

            string bootConfigPath;
            if (File.Exists(bootConfigInApp))
            {
                bootConfigPath = bootConfigInApp;
            }
            else if (File.Exists(bootConfigInXcode))
            {
                bootConfigPath = bootConfigInXcode;
            }
            else
            {
                Debug.LogError(
                    $"Couldn't find boot.config for player built in {report.summary.outputPath}, PolySpatial not enabled");
                return;
            }

            var bootConfig = File.ReadAllText(bootConfigPath);
            if (bootConfig.IndexOf("polyspatial=1") == -1)
            {
                Assert.AreEqual(bootConfig[bootConfig.Length - 1], '\n');
                bootConfig += "polyspatial=1\n";
                File.WriteAllText(bootConfigPath, bootConfig);
            }
        }
    }
}
#endif
