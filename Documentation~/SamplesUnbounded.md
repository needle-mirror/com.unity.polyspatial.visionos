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

## Object Tracking

The **Object Tracking** scene allows users to spawn content using predefined, unique objects markers in an unbounded application.

See Apple's documentation for how you can generate your own reference objects [here](https://developer.apple.com/documentation/visionOS/implementing-object-tracking-in-your-visionOS-app).
Note, the iOS object tracking reference files are not compatible with those used for visionOS.

We provide a file called CubeTemplatePNG.png which you can print, cut out, fold, and glue together to make a cube.  This cube is the object that the Object Tracking sample is looking for when you run it.

If you would like another example you can download Apples sample [here](https://developer.apple.com/documentation/visionOS/exploring_object_tracking_with_arkit).
They provide a referenceobject file for an Apple Magic Keyboard in that sample.  We have tested that is sample also works in our sample but have not included it here due to the licencing restrictions in that sample.
If you make a copy of the referenceobject file, rename its extension to .zip and extract it, you can right click on it to show package contents to extract a USDZ file.
This file you can load in Xcode on your monitor.  We have confirmed if it is similarly sized you can have the object tracking demo track it on your monitor as well.

In this sample, when `trackingState` is `TrackingState.Limited`, we remove the tracked object.  Apple reports different tracking IDs after it loses tracking and does not send a removal event, so this is how we prevent spawning a new prefab every time tracking is lost.

> [!NOTE]
> This sample uses ARKit features which are not supported in the VisionOS simulator, you must run it on device.
