# Development & Iteration

## Prerequisites
Please refer to [visionOS PolySpatial Requirements & Limitations](Requirements.md) for information about supported hardware, software, and Unity features.

<!-- TODO: ## Package Setup Instructions -->

## Enable PolySpatial runtime
visionOS support for Mixed Reality is provided by Unity PolySpatial, which can be toggled via the option **Edit &gt; Project Settings &gt; PolySpatial &gt; Enable PolySpatial Runtime**.

## Iteration and Preview
Unity provides several options for iterating and previewing content that targets visionOS. These options are on par with Unity's support for other non-desktop platforms.

### Play Mode
The fastest way to preview content is to enter Play Mode within the Unity Editor. This provides the fastest iteration cycle, but uses Unity's rendering system rather than RealityKit. This mode is optimized for rapid iteration, such as iterating on gameplay or UX, but may not always provide a faithful representation of the visuals or performance characteristics of a target platform. Visuals, optimization, and similar tasks typically benefit from other preview options provided by Unity. In addition, Play Mode doesn't currently preview volumes or the new input modalities provided by visionOS.

In order to better approximate the visionOS runtime, Play Mode for PolySpatial apps creates a parallel hierarchy of **backing** GameObjects  that are linked to your app's **simulation** GameObjects, but perform all the rendering. This means you will observe some differences based on the state of the `Enable PolySpatial Runtime` project setting. These differences are intentional, as they allow developers to better preview how their content will look on device.

### visionOS Player builds. 
Choose visionOS from the Build Settings window to target your build for visionOS. Most options in build settings are analogous to those provided for iOS. visionOS player builds will generate an Xcode project that needs to be compiled on a Mac (currently, this must be a Mac with Apple silicon), but may target either the visionOS simulator or an Apple Vision Pro headset connected to your Mac. 

Note: unlike iOS, there is no need to switch to a different SDK in Project Settings to run your content in the simulator.  Simply select the RealityDevice simulator target in Xcode.

For building to a development kit make sure you have setup a valid provisioning profile and signing certificate for Apple Development (that includes visionOS) platform. You will also need to make sure the device is correctly registered to your development account.

### Recording and playback
PolySpatial for visionOS supports a unique recording and playback workflow that allows you to record a session (including input commands) and then play it back within the Unity Editor. For more information, see information about [PolySpatial tooling](Tooling.md)

## Debugging Support
The standard debugging workflow works normally when using PolySpatial. You enable Script Debugging in the build settings and optionally Wait for Managed Debugger. Then attach a managed debugger/IDE to your running application and debug your script code.

## Building Blocks in PolySpatial XR
The building blocks system is an overlay window in the scene view that can help you quickly access commonly used items in your project. To open the building blocks overlay click on the hamburger menu on the scene view &gt; Overlay menu Or move the mouse over the scene view and press the "tilde" key. Afterwards just enable the Building Blocks overlay.

You can find more info about the building blocks system in the [XR Core Utils package](https://docs.unity3d.com/Packages/com.unity.xr.core-utils@latest).
