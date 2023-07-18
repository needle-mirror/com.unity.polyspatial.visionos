# visionOS Platform Overview
<a name="visionos-platform-overview"></a>
Unity’s support for **visionOS** combines the full power of Unity's Editor and runtime engine with the rendering capabilities provided by **RealityKit**. Unity’s core features - including scripting, physics, animation blending, AI, scene management, and more - are supported without modification. This allows game and application logic to run on **visionOS** like any other Unity-supported platform, and the goal is to allow existing Unity games or applications to be able to bring over their logic without changes.

For rendering, **visionOS** support support is provided through **RealityKit**. Core features such as meshes, materials, textures should work transparently. More complex features like particles are subject to limitations. Advanced features like full screen post processing and decals are currently unsupported, though this may change in the future. For more details, see [visionOS PolySpatial Requirements & Limitations](Requirements.md) and [Supported Unity Features & Components](SupportedFeatures.md). 

Building for the visionOS platform using PolySpatial in Unity adds new functionality to support XR content creation that runs on separate devices, while also having a seamless and effective development experience. Most importantly, Unity PolySpatial for visionOS reacts to real-world and other AR content by default like any other XR Unity app.

### visionOS Application Types
Unity supports several different application types on visionOS, each with their own advantages:
* If you're interested in creating fully immersive virtual reality (VR) apps for visionOS, refer to [Fully Immersive VR apps on visionOS](VRApps.md) for more information.
* If you're interested in creating immersive mixed reality (MR) apps for visionOS, refer to [PolySpatial MR Apps on visionOS](PolySpatialMRApps.md) for more information. These apps are built with Unity's newly developed PolySpatial technology, where apps are simulated with Unity, but rendered with RealityKit, the system renderer of visionOS.
* If you're interested in creating content that will run in a window on visionOS, refer to [Windowed Apps on visionOS](WindowedApps.md) for more information.
