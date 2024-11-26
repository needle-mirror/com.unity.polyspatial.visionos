using NUnit.Framework;
using Unity.PolySpatial.Internals;
using UnityEngine;
using UnityEngine.TestTools;

namespace Unity.PolySpatial.RealityKitTests
{
    /// <summary>
    /// Runtime isolation tests for com.unity.polyspatial.visionos package.
    /// Technically these aren't in total isolation but are as close as we can get.
    /// </summary>
    [TestFixture]
    public class IsolationTests
    {
        /// <summary>
        /// Verifies that the local backend is of type RealityKitBackend and tests if the NextHostHandler is not null.
        /// </summary>
        [Test]
        [UnityPlatform(RuntimePlatform.VisionOS)]
        public void LocalBackendIsRealityKit()
        {
            #if !UNITY_STANDALONE_WIN
            var backend = PolySpatialCore.LocalBackend;
            Assert.IsNotNull(backend);
            Assert.IsTrue(backend.GetType() == typeof(RealityKitBackend));
            var rkBackend = backend as RealityKitBackend;
            Assert.IsNotNull(rkBackend);
            Assert.IsNotNull(rkBackend.NextHostHandler);
            #endif
        }

        /// <summary>
        /// Tests using the RKRuntimeFuncs.GetPolySpatialNativeAPI function and verifies that the returned API is not null.
        /// </summary>
        [Test]
        [UnityPlatform(RuntimePlatform.VisionOS)]
        public void PolySpatialNativeAPIIsNotNull()
        {
#if !UNITY_STANDALONE_WIN
            RKRuntimeFuncs.GetPolySpatialNativeAPI(out var api);
            Assert.IsNotNull(api);
#endif
        }

        /// <summary>
        /// Tests that the RealityKitBackend.GetBackendPriority() is the expected value of 500.
        /// </summary>
        [Test]
        [UnityPlatform(RuntimePlatform.VisionOS)]
        public void GetBackendPriority()
        {
#if !UNITY_STANDALONE_WIN
            var priority = RealityKitBackend.GetBackendPriority();
            // Priority is hard-coded to be 500 (higher than PolySpatialUnityBackend).
            Assert.AreEqual(500, priority);
#endif
        }
    }
}
