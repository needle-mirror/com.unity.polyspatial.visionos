---
uid: psl-vos-tutorial-new-project
---
# Starting a new visionOS project from scratch
<a name="starting-a-new-visionos-mr-project-from-scratch"></a>

Make sure to switch the  build platform for visionOS (experimental)

## Fully Immersive Virtual Reality 

Make sure you have the **xr.sdk.visionos** package installed

1. Select **Edit &gt; Project Settings**…
2. Open the **XR Plug-in Manager** menu
3. Check the vision OS check box <!-- #{Placeholder insert pic about Platform SDK}# -->
4. Select **File &gt; Build Settings**…
	1. Add Scenes (SampleScene)
	2. Select **Build**.

Your app will render a full immersive space and you should see the Unity skybox (or your app) running in the Apple Vision Pro simulator.

Refer to [Fully Immersive VR](VRApps.md) docs for more information

## Mixed Reality and Shared Space

Make sure you have the **com.unity.polyspatial**, **com.unity.polyspatial.visionos**, and **com.unity.polyspatial.xr** packages installed

1. Create a Volume Camera in your scene
	</br> 1. Open the scene tooling / XR Building Blocks Menu and click **Volume Camera**
	</br> 2. Create an empty GameObject and add a **Volume Camera** component
2. Configure the volume camera for bounded or unbounded mode and adjust the dimensions
	</br> 1. Dimensions will adjust the rendering scale of your content
	</br> 2.. For bounded apps make sure something is visible within the dimensions of the volume camera
3. Open **Project Settings > PolySpatial**...
	1. check the Enable PolySpatial Runtime box

**Unbounded apps** </br>
For unbounded apps that want to use ARKit features you will need to enable visionOS in the XR Plug-in Management settings and make sure you have the **AR Foundation package** in your project. For ARKit Hands make sure you have **XR Hands package** in your project.

4. Select **File &gt; Build Settings**…
	1. Add Scenes (SampleScene)
	2. Select **Build**.

For bounded apps your app can exist alongside other apps in the shared space, for unbounded apps your app will be the only content visible. 

Note: the Apple Vision Pro simulator does not provide any ARKit data so planes, meshes, tracked hands, etc will not work. 

Refer to [PolySpatial MR Apps](PolySpatialMRApps.md) docs for more information