---
uid: psl-vos-unbounded-samples
---
# Unbounded samples

The unbounded samples demonstrate mixed reality using an unbounded volume camera. 

These samples use ARKit features that are not supported by the Apple visionOS simulator. You must run these samples on an Apple Vision Pro device.

The unbounded samples use the following, additional packages:

* [XR Interaction Toolkit](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@latest?subfolder=/manual/installation.html): The XR Interaction Toolkit package is a high-level, component-based, interaction system for creating VR, MR, and AR experiences.
* [XR Hands](https://docs.unity3d.com/Packages/com.unity.xr.handslatest?subfolder=/manual/project-setup/install-xrhands.html): The XR Hands package provides access to hand tracking data from ARKit on visionOS.

You can find instructions on how to install these packages at the links above.

> [!NOTE]
> On visionOS, Apple ARKit features are implemented by the [Apple visionOS XR Plugin](https://docs.unity3d.com/Packages/com.unity.xr.visionos@latest) package (com.unity.xr.visionos). You do not need the [Apple ARKit](https://docs.unity3d.com/Packages/com.unity.xr.arkit@latest) package (com.unity.xr.arkit), which implements ARKit features for iOS.

## Image Tracking

The **Image Tracking** scene allows users to spawn content using predefined, unique image markers in an unbounded application.

> [!NOTE]
> This sample uses ARKit features which are not supported in the VisionOS simulator, you must run it on device.


## Mixed Reality

The **Mixed Reality** scene allows users to spawn content using a custom ARKit hand gesture in an unbounded application. It also visualizes plane data information in the physical environment.

> [!NOTE]
> This sample uses ARKit features that are not supported in the VisionOS simulator, you must run it on device.


