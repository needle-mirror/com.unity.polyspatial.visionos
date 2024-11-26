---
uid: psl-vos-tutorial-new-project
---
# Start a new visionOS project from scratch

This page describes how to start a project from scratch using one or more of the available modes.

## Requirements

Before starting, ensure you meet the [Hardware and Software Requirements](Requirements.md).

<a name="starting-a-new-visionos-realitykit-project-from-scratch"></a>

## Windowed App

1. Open the **Build Profiles** window (menu: **File &gt; Build Profiles**).
2. Select the **visionOS** platform.
3. If necessary, click **Switch Platform** to change to the visionOS platform.
4. Add and select any Scenes you want to include in the build. (For example, SampleScene.)
5. Click the **Build** button.

By default, Unity builds that target visionOS will be set up to run in windowed mode. If you install XR or PolySpatial support (by following steps 1-8 from **Fully Immersive Virtual Reality** below), you need to manually configure your App Mode in order to build and deploy a 2D windowed application:

1. Open the **Project Settings** window (menu:**Edit &gt; Project Settings**).
2. Select the **Apple visionOS** settings section under **XR Plug-in Management**.
3. Set the **App Mode** to **Windowed - 2D Window**.

Windowed Apps use Unity's own rendering pipeline, such as the Built-in Render Pipeline or Universal Render Pipeline. See [Windowed Apps](WindowedApps.md) for details.

## Metal Rendering with Compositor Services (Fully Immersive Virtual and Mixed Reality)

1. Open the **Project Settings** window (menu:**Edit &gt; Project Settings**).
2. Select the **XR Plug-in Management** section.
3. If necessary, click the button to **Install XR Plug-in Management**.
4. Select the tab for the **visionOS** target build platform.
5. Enable the **Apple visionOS** Plug-in Provider.
7. Select the **Apple visionOS** settings section under **XR Plug-in Management**..
8. Set the **App Mode** to **Metal Rendering with Compositor Services**.
9. Correct any errors listed under **Project Validation**.

   1. Select **Project Validation** under **XR Plug-in Management** on the **Player Settings** window.
   2. Review and correct any errors listed.

   > [!TIP]
   > In many cases, you can click **Fix All** to resolve any validation problems.

10. Open the **Build Profiles** window (menu: **File &gt; Build Profiles**).
    1. Select the **visionOS** platform.
    2. If necessary, click **Switch Platform** to change to the visionOS platform.
    3. Add and select any Scenes you want to include in the build. (For example, SampleScene.)
    4. Under **Platform Settings**, set **Target SDK** to **Device SDK** to run on the Apple Vision Pro device or **Simulator SDK** to run on the simulator.
    5. Click the **Build** button.

Your app will render a full immersive space and you should see the Unity skybox (or your app) running in the Apple Vision Pro simulator.

Refer to [Metal-based Apps on visionOS](MetalApps.md) docs for more information

> [!NOTE]
> To ensure that the latest version of `com.unity.xr.visionos` has been installed, open the **Package Manager**. This should be <code class="long_version">X.Y.Z</code>. If not, then upgrade to this version by using `Install Package By Name...` and specifying the version.


## RealityKit with PolySpatial (Shared and Immersive MR Spaces)

For bounded apps, your app can exist alongside other apps in the shared space. For unbounded apps, your app will be the only content visible.

1. Follow steps from [Metal Rendering with Compositor Services](#metal-rendering-with-compositor-services-fully-immersive-virtual-and-mixed-reality) above up until setting the **App Mode**.
2. Reopen the **Package Manager**. Using `Install Package By Name...` install `com.unity.polyspatial.visionos`, specifying the latest version (<code class="long_version">X.Y.Z</code>). Alternatively, you can use the following link: <a class="kharma">com.unity.polyspatial.visionos</a>. Installing this package will automatically install the other required packages with the appropriately matching versions (`com.unity.polyspatial`, `com.unity.polyspatial.visionos`, and `com.unity.polyspatial.xr`).
3. In the project properties, under **XR Plug-in Management**, select the **Apple visionOS** setting section and switch the **App Mode** to **RealityKit with PolySpatial**.
4. Create a Volume Camera in your scene.
    1. From the **GameObject &gt; XR &gt; Setup** menu or the **XR Building Blocks** overlay, click **Volume Camera**.
    2. Add a **VolumeCameraWindowConfiguration** asset to your project with **Create &gt; PolySpatial &gt; Volume Camera Window Configuration**. You must store this asset in one of your project's **Resources** folders. (Refer to [Special Folders](xref:SpecialFolders) for more information about **Resources** folders.)
    3. Assign the volume camera window configuration to the **Volume Window Configuration** of the volume camera.
5. Configure the volume camera window configuration for bounded or unbounded mode and adjust the output dimensions (if bounded).
    - Output Dimensions adjust the rendering scale of your content.
    - For bounded apps, make sure something is visible within the dimensions of the volume camera.
6. Depending on which mode you would to use when your app starts, set the **Default Volume Camera Window Config** in **Project Settings** to the **VolumeCameraWindowConfiguration** which should be used at startup.
    1. Open the **Project Settings** window (menu: **Edit &gt; Project Settings**) and select the **PolySpatial** section.
    2. Drag the desired **VolumeCameraWindowConfiguration** asset into the **Default Volume Camera Window Config** field (or use the asset browser).
7. Open the **Build Profiles** window (menu: **File &gt; Build Profiles**).
    1. Select the **visionOS** platform.
    2. If necessary, click **Switch Platform** to change to the visionOS platform.
    3. Add and select any Scenes you want to include in the build. (For example, SampleScene.)
    4. Under **Platform Settings**, set **Target SDK** to **Device SDK** to run on the Apple Vision Pro device or **Simulator SDK** to run on the simulator.
    5. Click the **Build** button.

### Unbounded apps

For unbounded apps that use ARKit features, add the **com.unity.xr.arfoundation** package to your project. To use skeletal hand tracking data, add the **com.unity.xr.hands** package to your project. Refer to [XR packages](xref:xr-support-packages) for more information about Unity's XR packages.

> [!NOTE]
> The Apple Vision Pro simulator does not provide any ARKit data, so planes, meshes, tracked hands, etc. do not work in the simulator.

Refer to [RealityKit apps on visionOS](RealityKitApps.md) docs for more information

## Hybrid apps

Hybrid apps combine the capabilities of [Metal](MetalApps.md) and [RealityKit](RealityKitApps.md) apps. To create a Hybrid app, follow the above same steps for [RealityKit with PolySpatial](#realitykit-with-polyspatial-shared-and-immersive-mr-spaces), but set **App Mode** to **Hybrid - Switch between Metal and RealityKit**.

To switch to Metal mode, use a **VolumeCameraWindowConfiguration** with **Mode** set to **Metal**. If you would like the app to start in Metal mode, set a **VolumeCameraWindowConfiguration** with **Mode** set to **Metal** as the **Default Volume Camera Window Config** in **Project Settings**.

Refer to [PolySpatial Hybrid Apps](PolySpatialHybridApps.md) docs for more information
