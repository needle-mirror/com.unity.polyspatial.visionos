#if (UNITY_VISIONOS ||  POLYSPATIAL_INTERNAL) && (UNITY_EDITOR_OSX || UNITY_EDITOR_WIN)
using NUnit.Framework;
using Unity.PolySpatial.Internals.Editor;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.TestTools;

namespace Unity.PolySpatial.RealityKit.EditorTests
{
    /// <summary>
    /// Validation tests for visionOS reality kit editor scripts.
    /// </summary>
    public class ValidationTests
    {
        const string k_SrcDirectoryName = "srcTestDirectory";
        const string k_DstDirectoryName = "dstTestDirectory";
        const string k_SrcFileName = "Test1.txt";
        const string k_DstFileName = "Test2.txt";

        /// <summary>
        /// Deletes files and directories that were created during tests
        /// </summary>
        [TearDown]
        public void TearDown()
        {
            File.Delete(k_SrcFileName);
            File.Delete(k_DstFileName);
            Assert.IsFalse(File.Exists(k_DstFileName));
            Assert.IsFalse(File.Exists(k_SrcFileName));

            if (Directory.Exists(k_SrcDirectoryName))
                Directory.Delete(k_SrcDirectoryName, true);

            if (Directory.Exists(k_DstDirectoryName))
                Directory.Delete(k_DstDirectoryName, true);
        }

        /// <summary>
        /// Ensures that a path with back slashes is converted to a path with forward slashes.
        /// </summary>
        [Test]
        public void BuildUtils_PathToUnixPath()
        {
            var path = "C:\\Users\\user\\Desktop\\file.txt";
            var expected = "C:/Users/user/Desktop/file.txt";
            var actual = BuildUtils.PathToUnixPath(path);
            Assert.AreEqual(expected, actual);
        }

        /// <summary>
        /// Validates that BuildUtils.CopyFile copies a file to a destination path and deletes the source file.
        /// </summary>
        [Test]
        public void BuildUtils_CopyFile()
        {
            var srcContents = "Hello, World!";
            var dstContents = "World, Hello!";

            File.WriteAllText(k_SrcFileName, srcContents);
            File.WriteAllText(k_DstFileName, dstContents);

            BuildUtils.CopyFile(k_SrcFileName, k_DstFileName, true, true);

            Assert.IsTrue(File.Exists(k_DstFileName));

            var copiedFileText = File.ReadAllText(k_DstFileName);
            Assert.AreEqual(srcContents, copiedFileText);
            Assert.IsFalse(File.Exists(k_SrcFileName));
        }

        /// <summary>
        /// Validates that BuildUtils.CopyDirectoryTo copies a directory with it's files to a destination path.
        /// </summary>
        [Test]
        public void BuildUtils_CopyDirectoryTo()
        {
            var testFileContents = "Hello, World!";

            Directory.CreateDirectory(k_SrcDirectoryName);
            Directory.CreateDirectory(k_DstDirectoryName);

            // Create a couple test files in the test directory
            var srcPath1 = Path.Combine(k_SrcDirectoryName, "Test1.txt");
            var srcPath2 = Path.Combine(k_SrcDirectoryName, "Test2.txt");
            File.WriteAllText(srcPath1, testFileContents);
            File.WriteAllText(srcPath2, testFileContents);

            BuildUtils.CopyDirectoryTo(k_SrcDirectoryName, k_DstDirectoryName);

            var combinedDirName = Path.Combine(k_DstDirectoryName, Path.GetFileName(k_SrcDirectoryName));

            Assert.IsTrue(Directory.Exists(combinedDirName));

            var dstPath1 = Path.Combine(combinedDirName, "Test1.txt");
            var dstPath2 = Path.Combine(combinedDirName, "Test2.txt");
            Assert.IsTrue(File.Exists(dstPath1));
            Assert.IsTrue(File.Exists(dstPath2));

            var copiedFileText1 = File.ReadAllText(dstPath1);
            var copiedFileText2 = File.ReadAllText(dstPath2);
            Assert.AreEqual(testFileContents, copiedFileText1);
            Assert.AreEqual(testFileContents, copiedFileText2);
        }

        /// <summary>
        /// Validates that BuildUtils.CopyFileTo copies a file to a destination directory via symlink.
        /// BuildUtils.CopyFileTo ignores the symlink flag on Windows.
        /// </summary>
        [UnityPlatform(exclude = new[] { RuntimePlatform.WindowsPlayer, RuntimePlatform.WindowsEditor })]
        [Test]
        public void BuildUtils_CopyFileTo_Symlink_IntoNewDir()
        {
            var srcContents = "Hello, World!";

            File.WriteAllText(k_SrcFileName, srcContents);

            BuildUtils.CopyFileTo(k_SrcFileName, "", k_DstDirectoryName, false, true);

            Assert.IsTrue(Directory.Exists(k_DstDirectoryName));
            var dstPath = Path.Combine(k_DstDirectoryName, k_SrcFileName);
            Assert.IsTrue(File.Exists(dstPath));

            var pathInfo = new FileInfo(dstPath);
            Assert.IsTrue(pathInfo.Attributes.HasFlag(FileAttributes.ReparsePoint));
        }

        /// <summary>
        /// Verifies that BuildUtils.WriteTextIfChanged writes text to a file when the contents have changed.
        /// </summary>
        [Test]
        public void BuildUtils_WriteTextIfChanged()
        {
            var srcContents = "Hello, World!";

            File.WriteAllText(k_SrcFileName, srcContents);

            BuildUtils.WriteTextIfChanged(k_SrcFileName, srcContents);
            srcContents = "Different stuff!";
            BuildUtils.WriteTextIfChanged(k_SrcFileName, srcContents);
            var text = File.ReadAllText(k_SrcFileName);
            Assert.AreEqual(srcContents, text);
        }

        /// <summary>
        /// Tests to see if BuildUtils.EnsureDirectoryExists creates a directory if it doesn't exist.
        /// </summary>
        [Test]
        public void BuildUtils_EnsureDirectoryExists()
        {
            BuildUtils.EnsureDirectoryExists(k_DstDirectoryName);
            Assert.IsTrue(Directory.Exists(k_DstDirectoryName));
        }

        /// <summary>
        /// Verifies that BuildUtils.GetRuntimeFlagsForAuto outputs the correct runtime flags.
        /// </summary>
        [Test]
        public void BuildUtils_RuntimeFlags()
        {
            BuildUtils.GetRuntimeFlagsForAuto(true, out var runtimeEnabled, out var runtimeLinked);

            Assert.IsTrue(runtimeEnabled, "RuntimeEnabled should be true");
            Assert.IsTrue(runtimeLinked, "RuntimeLinked should be true");

            BuildUtils.GetRuntimeFlagsForAuto(false, out runtimeEnabled, out runtimeLinked);

            Assert.AreEqual(PolySpatialSettings.RuntimeModeForceLinked, runtimeLinked);
            Assert.AreEqual(PolySpatialSettings.RuntimeModeForceEnabled, runtimeEnabled);
        }

#if UNITY_EDITOR_OSX
        /// <summary>
        /// Checks to see if the visionOSCallbackOrder is greater than the rkPluginCallbackOrder.
        /// </summary>
        [Test]
        public void VerifyBuildOrder()
        {
            var rkPluginBuilder = new RealityKitPluginBuilder();
            var rkPluginCallbackOrder = rkPluginBuilder.callbackOrder;
            var visionOSBuildProcessor = new VisionOSBuildProcessor();
            var visionOSCallbackOrder = visionOSBuildProcessor.callbackOrder;
            Assert.Greater(visionOSCallbackOrder, rkPluginCallbackOrder);
        }
#endif

        /// <summary>
        /// Validates that VisionOSBuildProcessor.isSimulator produces true when the visionOS sdkVersion is Simulator.
        /// </summary>
        [Test]
        public void BuildProcessor_IsSimulator()
        {
            var expectedIsSimulator = PlayerSettings.VisionOS.sdkVersion == VisionOSSdkVersion.Simulator;
            var isSimulator = VisionOSBuildProcessor.isSimulator;
            Assert.AreEqual(expectedIsSimulator, isSimulator);
        }
    }
}
#endif
