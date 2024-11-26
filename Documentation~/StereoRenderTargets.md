---
uid: psl-vos-stereo-render-targets
---

# Stereo Render Targets

Enables a camera to render into a single-pass stereo framebuffer and then display this in various ways in visionOS RealityKit mode.

> [!NOTE]
> This feature is currently considered experimental, subject to change and considerable future improvement. It is currently only available in Unity 6+ utilizing the Universal Render Pipeline (URP) RenderGraph.

## Samples

1. You must be on Unity 6.
2. URP must be installed in your project.
3. URP needs to be set to use the RenderGraph. Ensure **Project Settings > Graphics > Render Graph > Compatibility Mode (Render Graph Disabled)** is **unchecked**.
4. Stereo render targets rely on a custom **ScriptableRendererFeature** called **PolySpatialStereoFramebufferFeature**. You can add this to your URP Renderer Features list yourself. Or place the preconfigured asset `Samples/StereoRenderer/Settings/StereoRendererURPAsset` into **Project Settings > Graphics > Default Render Pipeline** and **Project Settings > Quality > Rendering > Render Pipeline Asset**. Ensure under **Project Settings > Quality > Levels** you have selected the **Quality Level** which you are using on device before you fill in the **Render Pipeline Asset** reference.
5. Add all of the sample scenes within `PolySpatial Extensions/Samples/StereoRenderer/Scenes` to your **Build Settings** list.
6. Name **User Layer 20** to `DisabledTracking`. Then set **Project Settings > PolySpatial > Ignored Objects Layer Mask** to include the `DisabledTracking` layer.
7. Build and deploy to visionOS.

| Sample Scene Name                          | Description                                                                                                                                                                                                                                                                                                                                                                                                       |
|--------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Depth Reprojection Head Tracked**        | Uses the depth buffer to reproject a stereo framebuffer into it's correct world position in RealityKit unbounded mode. This lets you render content with Unity's Universal Render Pipeline and have it be displayed in proper perspective in mixed reality.  This technique is similar to current VR compositors where depth is used to displace vertex positions on a plane.                                  |
| **Flat Stereoscopic Head Tracked**         | Displays the stereo framebuffer on a flat surface with the texture placement controlled by a head tracked camera in RealityKit unbounded mode. This enables the creation of a portal-like effect through which the content is in proper perspective.                                                                                                                                                          |
| **Flat Stereoscopic Transparent**          | Displays the stereo framebuffer on a transparent flat surface with a statically fixed camera. The **Focus Depth** of the stereo framebuffer can be adjusted on the flat surface.                                                                                                                                                                                                                                |
| **Flat Stereoscopic Curved Opaque**        | Displays the stereo framebuffer on an opaque curved surface with a statically fixed camera. The **Focus Depth** of the stereo framebuffer can be adjusted on the curved surface.                                                                                                                                                                                                                                |
| **Depth Reprojection Bounded**             | Similar to **Depth Reprojection Head Tracked** except this is in bounded mode with a static camera, instead of a head tracked camera, because head tracking data is not available in bounded mode. Lack of head tracking with this technique does produce artifacting if you look at the side of the reprojected framebuffer, however there may still be creative ways to utilize this in bounded mode. |
| **Flat Stereoscopic Transparent Bounded**  | Similar to **Flat Stereoscopic Transparent** but in bounded mode. This technique works in bounded mode the same as it does in unbounded mode.                                                                                                                                                                                                                                                                     |
| **Flat Sterescopic Curved Opaque Bounded** | Similar to **Flat Stereoscopic Curved Opaque** but in bounded mode. This technique works in bounded mode the same as it does in unbounded mode.                                                                                                                                                                                                                                                                   |
| **Flat Stereoscopic Billboard Bounded**    | Displays the stereo framebuffer on a flat surface which always orients itself at the camera in bounded mode.                                                                                                                                                                                                                                                                                                   |

## Components

* [PolySpatialStereoFramebufferCamera](#polySpatial-stereo-framebuffer-camera)
   * Captures the stereo framebuffer from a camera.
* [PolySpatialStereoFramebufferRenderer](#polySpatial-stereo-framebuffer-renderer)
   * Displays a stereo framebuffer.
* [PolySpatialStereoFramebufferFeature](#polySpatial-stereo-framebuffer-feature)
   * Must be added as an URP RenderFeature to enable stereo framebuffer capture.

<a id="polySpatial-stereo-framebuffer-camera"></a>
### PolySpatial Stereo Framebuffer Camera

Place this component on the same GameObject as a **Camera** component to capture the camera's stereo framebuffer.

You can add a **Tracked Pose Driver (Input System)** which uses the `<XRHMD>/devicePosition` and `<XRHMD>/deviceRotation` to have the camera follow the head pose of the user in unbounded RealityKit mode. The head pose approximately represents the location of the user's current view but is not perfectly aligned and in sync with the view matrix.

> [!NOTE]
> The head tracked position is approximate, not exact, and it does have a delay to roundtrip from visionOS, to Unity and back to visionOS with the rendered
> stereo framebuffer. **Depth Reprojection** mode uses depth data to keep the stereo framebuffer in proper
> perspective despite this delay.

| Setting  | Description |
|----------|-------------|
| **Generate G Buffer** | Generates data from the depth buffer to support **Depth Reprojection**. If you are not using **Depth Reprojection**, you can disable this option to save some overhead. |
| **Framebuffer Updated** | Event fired when stereo framebuffer is initialized. |

<a id="polySpatial-stereo-framebuffer-renderer"></a>
### PolySpatial Stereo Framebuffer Renderer

Place this component on the GameObject that should display the rendered stereo framebuffer (not on the Camera).

| Setting | Description |
|---------|-------------|
| **Stereo Framebuffer Camera** | Specify the **PolySpatial Stereo Framebuffer Camera** which you want this renderer to display. |
| **Mode** | Different ways to display the stereo framebuffer. |
| &nbsp;&nbsp;&nbsp;&nbsp;Flat Stereoscopic Static | Display the stereo framebuffer on a flat surface which you manually place in the scene. You can also use an arbitrary mesh by setting it in the associated MeshFilter. The **UV** values of the mesh must be set up correctly. |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Add Focus Distance To Offsets | Automatically offsets the left and right eye framebuffers to make the stereo framebuffer converge, and appear focused on, the specified depth. |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Focus Distance | The specified depth to focus on. |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Scale To Aspect Ratio | Automatically scale the surface to aspect ratio of the framebuffer to get rid of any stretching. |
| &nbsp;&nbsp;&nbsp;&nbsp;Flat Stereoscopic Projected | Display the stereo framebuffer on a flat surface which you manually place in the scene. The placement of the stereo framebuffer will be projected from the camera which it is rendering from, meaning the camera must be aimed at this surface. You can optionally use any mesh by setting it in the associated MeshFilter. |
| &nbsp;&nbsp;&nbsp;&nbsp;Depth Reprojection | Uses the depth buffer to reproject the stereo framebuffer into the proper world position. The position of the reprojected framebuffer is determined by the world position of objects rendered into the stereo framebuffer. |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Generate Reprojection Mesh | ***Do not disable this unless you have good reason.*** A mesh with a certain numbers of vertices and other constraints is required for the reprojection shader. This will auto-generate that mesh dependent on the specifics of the stereo framebuffer it should display. |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Reprojection Mesh Bounds | ***Do not set this higher than necessary as it can introduce artifacts in the reprojection.*** These bounds need to be big enough to encapsulate the area in which the reprojected framebuffer should be visible. |

> [!NOTE]
> You can also access the framebuffer data directly from the **PolySpatial Stereo Framebuffer Camera** component by subscribing to its **Framebuffer Updated** event.

<a id="polySpatial-stereo-framebuffer-feature"></a>
## PolySpatial Stereo Framebuffer Feature

Add the **PolySpatial Stereo Framebuffer Feature** asset to the **Renderer Features** list in your URP **Universal Render Data** settings. This feature retrieves each camera's stereo framebuffer from the XR Display Subsystem and processes them for proper display in visionOS.

| Setting | Description |
|---------|-------------|
| **G Buffer Pixel To Vertex Ratio** | ***Do not change unless you have good reason.*** This controls the resolution of GBuffer, and therefore the vertex count, in **Depth Reprojection** mode. Setting a lower ratio produces a higher resolution reprojection. However, this will be at the expense of performance and greater artifacts in the reprojection. |
| **Device Display Provider Parameters** | The view frustum for all **Stereo Framebuffer Cameras**. These values must be set in a particular way for the framebuffer to appear correctly on device. ***It is not recommend you change these yourself.*** The defaults represent the Vision Pro setup of the average user.  |

## Known Issues

> [!NOTE]
> All cameras rendering into a stereo render target must all share the same resolution, FOV and frustum settings. This is not by design, but rather a limitation
  of URP and the current XR rendering stack. There is a longer development thread currently underway to get rid of this constraint which can then be made
  available through this package. This is unfortunately limiting, however there is still much that can be done with this limitation, so we wanted to make this
  available in it's experimental state for people to explore.

> [!NOTE]
> You cannot track the head position in visionOS Bounded Mode. This means the samples labelled `HeadTracked` cannot work the same in bounded mode. Modes like
  DepthReprojection and FlatStereoscopicProjection unfortunately have to be constrained to statically placed camera in bounded mode. This may never change as it
  is a constraint of visionOS itself.
