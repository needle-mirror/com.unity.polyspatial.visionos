#if POLYSPATIAL_INTERNAL && (UNITY_IOS || UNITY_VISIONOS || UNITY_STANDALONE_OSX) && UNITY_EDITOR_OSX
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using UnityEditor.UnityLinker;
using Debug = UnityEngine.Debug;

namespace Unity.PolySpatial.Internals.Editor
{
    internal class iOSBuildPreProcessor : IPreprocessBuildWithReport
    {
#if UNITY_2022_3_9 || UNITY_2022_3_10
        internal const string k_XcodeProjName = "Unity-iPhone.xcodeproj";
#else
        internal const string k_XcodeProjName = "Unity-VisionOS.xcodeproj";
#endif

        public int callbackOrder => 0;

        public void OnPreprocessBuild(BuildReport report)
        {
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

    internal class iOSBuildPostProcessor : IPostprocessBuildWithReport
    {
        public int callbackOrder => 150; // after the plugin builder

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS)
                return;

            if (!PolySpatialSettings.instance.EnablePolySpatialRuntime
#if POLYSPATIAL_INTERNAL
                && !PolySpatialSettings.instance.AlwaysLinkPolySpatialRuntime
#endif
            )
            {
                return;
            }

            if (!File.Exists("Packages/com.unity.polyspatial.visionos/Lib~/libPolySpatial_iphoneos.a"))
            {
#if POLYSPATIAL_INTERNAL
                Debug.LogWarning("Expected to find libPolySpatial_iphoneos.a, but it doesn't exist");
#endif
                return;
            }

            try
            {
                var outputPath = report.summary.outputPath;
                SwiftAppShellProcessor.ConfigureXcodeProject(report.summary.platform, outputPath,
                    iOSBuildPreProcessor.k_XcodeProjName,
                    il2cppArmWorkaround: true,
                    staticLibraryPluginName: $"libPolySpatial_{SwiftAppShellProcessor.GetXcodePlatformName(report.summary.platform)}.a");

                // Nothing to do
                //FilterXcodeProj(outputPath, xcodeProjName);
                //FilterPlist(outputPath);
            }
            catch (Exception e)
            {
                throw new BuildFailedException(e);
            }
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

            pbx.WriteToFile(xcodePbx);
        }

        private void FilterPlist(string outputPath)
        {
            var plistPath = outputPath + "/Info.plist";
            var plist = new PlistDocument();
            plist.ReadFromFile(plistPath);

            plist.WriteToFile(plistPath);
        }
    }
}
#endif
