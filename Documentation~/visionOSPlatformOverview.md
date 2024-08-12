---
uid: psl-vos-platform-overview
---
# visionOS Platform Overview

visionOS is the operating system of the Apple Vision Pro, Apple's latest spatial computing device. Unity developers can leverage existing 3D scenes and assets to build games or applications for visionOS. For general information about visionOS, see Apple's [visionOS Overview](https://developer.apple.com/visionos/learn).

visionOS provides a few different ways in which apps can display their content:

- **Windows**: visionOS windows are flat displays, like their desktop equivalents, but floating in space. You can use windows to present 2D or 3D content, without stereo rendering.
- **Volumes**: visionOS Volumes are 3D displays, which either have distinct bounds (similar to a window, only with a third dimension), or have no bounds (and can freely fill the space around the user). When you use volumes, users of your app have the flexibility to walk around and interact with 3D content from any angle.
- **Spaces**: Depending on application mode, visionOS apps can run in either a **Shared Space** or a **Immersive Space**. This space determines whether users can view and interact with multiple apps or are restricted to a single app:
  - **Shared Space**: The shared space is a multitasking environment similar to the desktop of a personal computer. In this mode, users can see and interact with windows and bounded volumes from multiple different applications simultaneously.
  - **Immersive Space**: An immersive space shows content exclusively from only one application, allowing for a more immersive and cohesive experience. ARKit data such as head and hand tracking is only passed to application code when it runs in an immersive space.

When developing apps in Unity, you can choose from one of several **App Modes**. These **App Modes** can be accessed in the Apple visionOS Project Settings (under XR Plug-in Management). Below is a description of each app mode, along with a short summary on their respective capabilities and limitations. Each app mode has a more detailed documentation page, describing how to use the app mode and further information on capabilities and limitations.

### Metal Rendering with Compositor Services

**Metal Rendering with Compositor Services** app mode allows apps to create content using metal-based graphics features supported by Unity. Rendering and simulation are entirely managed by Unity, resulting in low overhead. PolySpatial and RealityKit will not be used in applications set to this mode. This mode allows the quickest path to port existing XR applications to visionOS.

Apps created with this mode will launch in **Immersive Space**, and other applications will be backgrounded when a Metal-based app is launched.

> [!TIP]
> If you're interested in creating metal-based apps for visionOS, or porting existing content to visionOS, refer to [Metal-based Apps on visionOS](MetalApps.md) for more information.

### RealityKit with PolySpatial

**RealityKit with PolySpatial** app mode allows apps to take full advantage of visionOS's capabilities. These apps are built with Unity's newly developed PolySpatial technology, where apps are simulated with Unity, but rendered with RealityKit, the system renderer of visionOS. 

In this mode, apps can run side by side with other apps in visionOS's **Shared Spaces**, utilize visionOS components such as volumes, and create content with the same look and feel as other visionOS applications. Additionally, the full complement of PolySpatial debug tooling, such as Play To Device, Recording and Playback, and Shader Graph debugging, will be available. 

However, some Unity features may only partially work or may not work at all. Additionally, as compared to **Metal Rendering with Compositor Services** mode, there may be additional overhead. See [Supported Unity Features & Components](SupportedFeatures.md) for more information on which features are supported. 

Apps created with this mode can be launched into either the **Shared Space** or into an **Immersive Space**.

> [!TIP]
> If you're interested in creating RealityKit apps for visionOS, refer to [RealityKit on visionOS](RealityKitApps.md) for more information.

### Windowed

**Windowed** app mode allows apps to create and use windows, upright planes that can be used to present 2D or 3D content. This is most similar to traditional windowed content, and can provide a quick path to port existing windowed apps to visionOS. 

However, ARKit features will not be usable in this mode. 

Windowed apps will always be launched within the **Shared Space**.

> [!TIP]
> If you're interested in creating content that will run in a window on visionOS, refer to [Windowed Apps on visionOS](WindowedApps.md) for more information.

## Advanced Features

### Hybrid

**Hybrid** app mode combines the capabilities of the Metal and RealityKit app modes, allowing apps to switch between the two modes at runtime, or to blend content from each mode together. This flexibility comes at a performance cost that scales in part with the complexity of the scene.

> [!TIP]
> If you're interested in creating Hybrid apps, refer to [PolySpatial Hybrid Apps on visionOS](PolySpatialHybridApps.md) for more information.

## PolySpatial on visionOS

<a name="visionos-platform-overview"></a>
PolySpatial's support for **visionOS** combines the benefits of Unity's Editor and runtime engine with the rendering capabilities provided by **RealityKit**. Unity’s core features - including scripting, physics, animation blending, AI, scene management, and more - are supported without modification. This allows game and application logic to run on visionOS like any other Unity-supported platform, and the goal is to allow existing Unity games or applications to be able to bring over their logic without changes.

For rendering, visionOS support is provided through RealityKit. Core features such as meshes, materials, textures should work as expected. More complex features like particles are subject to limitations. Advanced features like full screen post processing and decals are currently unsupported, though this may change in the future. For more details, see [visionOS PolySpatial Requirements & Limitations](Requirements.md) and [Supported Unity Features & Components](SupportedFeatures.md).

Building for the visionOS platform using PolySpatial in Unity adds new functionality to support XR content creation that runs on separate devices, while also having a seamless and effective development experience. Most importantly, Unity PolySpatial for visionOS reacts to real-world and other AR content by default like any other XR Unity app.

## AR Authorizations

Some ARKit features can track or record information that could compromise user privacy. To ensure that a user is aware of this possibility, Apple requires that your app prompt the user for authorization before one of these features can be enabled. These prompts will display a customizable usage description, which must be provided in the **Project Settings** for Apple visionOS (under **XR Plug-in Management**).

On visionOS, two types of AR features require user authorization:

- Hand Tracking
- World Sensing

As the name implies, hand tracking authorization is needed to make use of ARKit's hand tracking capabilities, and is exposed in Unity via the XR Hands package (`com.unity.xr.hands`). The World Sensing authorization applies to the remaining ARKit features like planes, meshes, image tracking, and world anchors. Note that head pose is exposed via ARKit, and is the one exception as it does not require any authorization.

These authorizations are requested automatically by the visionOS XR Plugin as features are needed. For example, when an `ARPlaneManager` is enabled, and the user has not already been prompted to authorize the app to use World Sensing features, a dialog will appear showing the world sensing usage description, with buttons labeled `Allow` or `Deny`. Once the user responds to this dialog, the authorization is stored along with other app metadata, and the authorization will remain valid until the app is uninstalled, or the user manually navigates to the app in Settings to change a particular authorization.


We provide scripting APIs for querying the state of a particular authorization. You can either call [VisionOS.QueryAuthorizationStatus](xref:UnityEngine.XR.VisionOS.VisionOS.QueryAuthorizationStatus)) to get the status of a particular authorization type, or you can subscribe to the [VisionOS.AuthorizationChanged](xref:UnityEngine.XR.VisionOS.VisionOS.AuthorizationChanged)) event in order to be informed of authorization changes. Usage of these APIs is demonstrated by the `Debug` UI panel in the main package sample scene for `com.unity.xr.visionos`.
