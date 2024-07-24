---
uid: psl-vos-platform-overview
---
# visionOS Platform Overview

visionOS is the operating system of the Apple Vision Pro, Apple's latest spatial computing device. Unity developers can leverage existing 3D scenes and assets to build games or applications for visionOS. For more information about visionOS, see Apple's [visionOS Overview](https://developer.apple.com/visionos/learn).

visionOS provides a few different modes in which apps can be displayed: Windows, Volumes, and Spaces. You can use Windows to present 2D or 3D content (without stereo), or use Volumes to present 3D content and objects. When you use Volumes, users of your app have the flexibility to walk around and interact with 3D content from any angle.

Depending on application type, visionOS apps can run in either a **Shared Space** or a **Full Space**. The Shared Space is a multitasking environment similar to the desktop of a personal computer. In this mode, users can see and interact with Windows and Volumes from multiple applications simultaneously. To create a more immersive experiences, you can target your applications for a dedicated **Full Space**, which displays content exclusively from one app at time. Windowed apps developed in Unity always run in a Shared Space. Metal-based content always runs in an Immersive Space, while RealityKit content can switch between the Shared Space and an Immersive Space.

# PolySpatial on visionOS

<a name="visionos-platform-overview"></a>
PolySpatial's support for **visionOS** combines the full power of Unity's Editor and runtime engine with the rendering capabilities provided by **RealityKit**. Unity’s core features - including scripting, physics, animation blending, AI, scene management, and more - are supported without modification. This allows game and application logic to run on visionOS like any other Unity-supported platform, and the goal is to allow existing Unity games or applications to be able to bring over their logic without changes.

For rendering, visionOS support is provided through RealityKit. Core features such as meshes, materials, textures should work as expected. More complex features like particles are subject to limitations. Advanced features like full screen post processing and decals are currently unsupported, though this may change in the future. For more details, see [visionOS PolySpatial Requirements & Limitations](Requirements.md) and [Supported Unity Features & Components](SupportedFeatures.md). 

Building for the visionOS platform using PolySpatial in Unity adds new functionality to support XR content creation that runs on separate devices, while also having a seamless and effective development experience. Most importantly, Unity PolySpatial for visionOS reacts to real-world and other AR content by default like any other XR Unity app.

### visionOS Application Types
Unity supports several different application types on visionOS, each with their own advantages:
* If you're interested in creating metal-based apps for visionOS, or porting existing content to visionOS, refer to [Metal-based Apps on visionOS](MetalApps.md) for more information.
* If you're interested in creating RealityKit apps for visionOS, refer to [RealityKit on visionOS](RealityKitApps.md) for more information. These apps are built with Unity's newly developed PolySpatial technology, where apps are simulated with Unity, but rendered with RealityKit, the system renderer of visionOS.
* If you're interested in combining the capabilities of Metal and RealityKit apps, refer to [PolySpatial Hybrid Apps on visionOS](PolySpatialHybridApps.md) for more information. These apps can take advantage of Metal rendering with Unity as well as RealityKit rendering for mixed reality.
* If you're interested in creating content that will run in a window on visionOS, refer to [Windowed Apps on visionOS](WindowedApps.md) for more information.

### AR Authorizations
In order to use ARKit features like hand tracking and world sensing, your app must prompt the user for authorization. These prompts will display a customizable usage description, which must be provided in the visionOS settings under `Project Settings > XR Plug-in Management > Apple visionOS`. Unity apps can make use of ARKit features on visionOS by using [AR Foundation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@latest) components like `ARPlaneManager`. For visionOS specifically, there are two types of AR Authorization:
- Hand Tracking
- World Sensing
As the name implies, hand tracking authorization is needed to make use of ARKit's hand tracking capabilities, and is exposed in Unity via the XR Hands package (`com.unity.xr.hands`). The World Sensing authorization applies to the remaining ARKit features like planes, meshes, image tracking, and world anchors. Note that head pose is exposed via ARKit, and is the one exception as it does not require any authorization.

These authorizations are requested automatically by the visionOS XR Plugin as features are needed. For example, when an `ARPlaneManager` is enabled, and the user has not already been prompted to authorize the app to use World Sensing features, a dialog will appear showing the world sensing usage description, with buttons labeled `Allow` or `Deny`. Once the user responds to this dialog, the authorization is stored along with other app metadata, and the authorization will remain valid until the app is uninstalled, or the user manually navigates to the app in Settings to change a particular authorization.


We provide scripting APIs for querying the state of a particular authorization. You can either call [VisionOS.QueryAuthorizationStatus](xref:UnityEngine.XR.VisionOS.VisionOS.QueryAuthorizationStatus)) to get the status of a particular authorization type, or you can subscribe to the [VisionOS.AuthorizationChanged](xref:UnityEngine.XR.VisionOS.VisionOS.AuthorizationChanged)) event in order to be informed of authorization changes. Usage of these APIs is demonstrated by the `Debug` UI panel in the main package sample scene for `com.unity.xr.visionos`.
