---
uid: psl-vos-supported-features
---
# Supported Unity Features & Components
<a name="supported-unity-features-and-components"></a>
The majority of Unity components will work without modification on this platform - including most custom MonoBehaviours, animation logic, physics, input handling, asset management, AI, and so forth. However, components that need to be rendered require special support. Consequently, some components offer a reduced feature set on this platform; others are not currently supported. The tables below summarize the current state of various rendering component support on this platform.

For more information about converting legacy projects, see also [Porting Unity Projects to PolySpatial XR](PortingUnityProjectsToPolySpatialXR.md)

## Unity Simulation Components / Systems
It's impossible to list all the systems and packages that Unity exposes in this page but the table below lists the status of support for a range of core Unity features:

| **Component**             | **Status**            |
|---------------------------|-----------------------|
| **Transform**             | Supported             |
| **Audio**                 | Not Fully Spatialized |
| **MeshFilter**            | Supported             |
| **Animation / Animators** | Supported             |
| **2D Physics**            | Supported             |
| **3D Physics**            | Supported             |
| **Scripts**               | Supported             |
| **AI & Navmesh**          | Supported             |
| **Terrain**               | Experimental Support  |

`MonoBehaviours` are expected to work but they will depend on a case by case basis depending on which other components your scripts interact with.

## Rendering Components / Systems
<a name="rendering-components-systems"></a>

| **Component**             | **Status**                                                                                                                                                              |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **MeshRenderer**          | Lighting must be set up via material      No support for this component in Immediate mode     No support for "Additional Settings" (dynamic occlusion, rendering layer) |
| **SkinnedMeshRenderer**   | Unoptimized animation only (the **Optimize Game Objects** option on the Rig tab of the Model Import inspector must be ticked off if it appears.)                        |
| **Particle Systems**      | Partial Support; see [Particle Systems](#particle-systems) below                                                                                                        |
| **Trail Renderer**        | Partial Support; see [Particle Systems](#particle-systems) below                                                                                                        |
| **Light**                 | Supported; See [PolySpatial Lighting](PolySpatialLighting.md) for details                                                                                               |
| **Camera**                | Not Supported                                                                                                                                                           |
| **Halo**                  | Not Supported                                                                                                                                                           |
| **Lens Flare**            | Not Supported                                                                                                                                                           |
| **Line Renderer**         | Partial Support; View-Aligned Line Renderers will only achieve proper alignment in unbounded mode with an ARSession in the scene                                        |
| **Projector**             | Not Supported                                                                                                                                                           |
| **Visual Effects**        | Not Supported                                                                                                                                                           |
| **Lens Flare**            | Not Supported                                                                                                                                                           |
| **Level of Detail (LoD)** | Not Supported                                                                                                                                                           |
| **Occlusion Area**        | Not Supported                                                                                                                                                           |
| **Occlusion Portal**      | Not Supported                                                                                                                                                           |
| **Skybox**                | Not Supported                                                                                                                                                           |
| **URP Decal projector**   | Not Supported                                                                                                                                                           |
| **Tilemap Renderer**      | Not Supported                                                                                                                                                           |
| **Video Player**          | Limited Support                                                                                                                                                         |
| **Graphics Raycaster**    | Not Supported                                                                                                                                                           |
| **Shaderlab Shaders**     | Not Supported                                                                                                                                                           |
| **Post Processors**       | Not Supported                                                                                                                                                           |
| **Lightmapping**          | Limited support through [PolySpatial Lighting Node](PolySpatialLighting.md)                                                                                             |
| **Baked Lighting**        | Limited support through [PolySpatial Lighting Node](PolySpatialLighting.md)                                                                                             |
| **Enlighten**             | Not Supported                                                                                                                                                           |
| **Light Probes**          | Limited support through [PolySpatial Lighting Node](PolySpatialLighting.md)                                                                                             |
| **Reflection Probes**     | Limited support through [PolySpatial Lighting Node](PolySpatialLighting.md)                                                                                             |
| **Trees**                 | Not Supported                                                                                                                                                           |
| **Fog**                   | Not Supported                                                                                                                                                           |

Some of these features are not supported due to platforms constraints (for example, full screen graphics post processors aren't compatible with the idea of a shared rendering system), while others are areas of ongoing or planned development.

### Particle systems
<a name="particle-systems"></a>
Support for Unity's built-in particles under PolySpatial is actively being developed. Currently, it offers several alternate modes, each with its own set of quality and performance tradeoffs. You can configure these modes project-wide under `Project Settings > PolySpatial > Particle Mode`.

### Supported Modes:
- **Replicate Properties**: This mode aims to map Unity particle system properties to the native particle systems offered by RealityKit. While it offers relatively good performance, visual quality can vary significantly, especially for particles that utilize advanced features. Custom shaders are not supported in this mode.

**Note:** The size of particle systems may differ in RealityKit since RealityKit specifies particle properties like speed and size in meters. Additionally, particle systems in RealityKit inherit scale from its GameObject and all its parents.

- **Bake to Mesh**: In this mode, a dynamic mesh is baked for every particle system every frame. It closely aligns the visuals with Unity rendering, allowing leverage of most features of Unity's built-in particle systems, including custom shaders authored with ShaderGraph. However, this mode currently imposes a significant performance overhead. We are actively working to improve performance for baked particles.

**Note:** Baked Mesh billboard particles only face the camera when in an unbounded volume camera and an ARSession exists in the scene. You can add an ARSession to the scene by right-clicking in the Editor **Hierarchy** window and selecting **XR &gt; AR Session** from the context menu.

- **Bake to Texture**: In this mode, a texture is baked for every particle system every frame. This mode is more performant for large particle systems than Bake to Mesh, while maintaining close visual parity with Unity rendering. This mode is currently limited to billboard and mesh particle render modes, and incurs a longer shader warm time. Billboarded particles in this mode will orient toward the camera properly. This mode currently requires a camera in the scene with a `MainCamera` tag on it's GameObject.

**Note:** VFXGraph is not currently supported in PolySpatial.

#### Replicate Properties Support
When using the "Replicate Properties" particle mode in PolySpatial, Particle System modules are supported to varying degrees. Other modes will not have these limitations, but may come with heavier performance costs. These limitations are summarized in the table below:

| **Module**                       | **Status**                                                                                                                                                                                                                                                                                       |
|----------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Main Module**                  | Partially Supported <br/>- Duration<br/>- Looping<br/>- Prewarm<br/>- StartSpeed<br/>- StartLifetime<br/> - StartSize<br/>- IsStartRotation3D<br/>- StartRotation<br/>- StartColor<br/>- GravityModifier<br/>- SimulationSpace                                                                   |
| **Emission**                     | Partially Supported <br/>- RateOverTime                                                                                                                                                                                                                                                          |
| **Shape**                        | Partially Supported <br/>- Shape (with some approximations)<br/> - DonutRadius<br/>- Angle (used to compute SpreadingAngle in RK for cone and coneVolume shapes)<br/>- Arc (used to compute radialAmount in RK for cone, coneVolume, and donut shapes)<br/>- Position<br/>- Rotation<br/>- Scale |
| **Velocity over lifetime**       | Partially Supported <br/>- Linear Speed (X, Y, Z)<br/>- Space                                                                                                                                                                                                                                    |
| **Limit Velocity over lifetime** | Partially Supported <br/>- Speed (no separate axes support)  <br/>- Dampen<br/>- Drag                                                                                                                                                                                                            |
| **Inherit velocity**             | Not Supported                                                                                                                                                                                                                                                                                    |
| **Force over lifetime**          | Not Supported                                                                                                                                                                                                                                                                                    |
| **Color over lifetime**          | Partially Supported <br/>- Color                                                                                                                                                                                                                                                                 |
| **Color by speed**               | Not Supported                                                                                                                                                                                                                                                                                    |
| **Size over lifetime**           | Partially Supported <br/>- Size (no separate axes support)                                                                                                                                                                                                                                       |
| **Size by speed**                | Not Supported                                                                                                                                                                                                                                                                                    |
| **Rotation over lifetime**       | Partially Supported <br/>- AngularVelocity (no separate axes support)                                                                                                                                                                                                                            |
| **Rotation by speed**            | Not Supported                                                                                                                                                                                                                                                                                    |
| **External Forces**              | Not Supported                                                                                                                                                                                                                                                                                    |
| **Noise**                        | Partially Supported <br/>- Strength (no separate axes support) <br/>- PositionAmount<br/>- ScrollSpeed                                                                                                                                                                                           |
| **Collision**                    | Not Supported                                                                                                                                                                                                                                                                                    |
| **Triggers**                     | Not Supported                                                                                                                                                                                                                                                                                    |
| **Sub Emitters**                 | Partially Supported; Only one subemitter is supported in RealityKit, and is limited to a few number of exposed properties. Namely, speed or emitter shape on a sub-emitter in RK.                                                                                                                |
| **Texture sheet animation**      | Partially Supported <br/>- TilesX<br/>- TilesY<br/>- Animation<br/>- StartFrame<br/>- TimeMode<br/>- FPS                                                                                                                                                                                         |
| **Lights**                       | Not Supported                                                                                                                                                                                                                                                                                    |
| **Trails**                       | Not Supported                                                                                                                                                                                                                                                                                    |
| **Custom Data**                  | Not Supported                                                                                                                                                                                                                                                                                    |
| **Renderer**                     | Partially Supported <br/>- SortMode<br/>- RenderMode (limited to Billboard, HorizontalBillboard, and VerticalBillboard)<br/>- RenderingLayerMask<br/>- ShadowCastingMode <br/>- Material (limited to particle lit/unlit shaders)                                                                 |


**Note:** MinMaxCurves have limited support. In most cases only the first value in the curve is used. The exceptions are when the last value in the curve can be utilized for a separate property to approximate the same result. This is currently only the case for startSize and sizeOverLifetime curves, as the final values in the curves can be used to compute RealityKit’s sizeMultiplierAtEndOfLifespan.

## User Interface (UI)
[Unity UI](https://docs.unity3d.com/Manual/com.unity.ugui.html) works in world space, but screen space UI and advanced visual features like masking, shadowing, etc do not currently work. The table below summarizes the supprot status for other UI features:

| **Component**        | **Status**                                                                         |
|----------------------|------------------------------------------------------------------------------------|
| **TextMesh**         | Supported                                                                          |
| **Canvas Renderer**  | Partially Supported                                                                |
| **Sprite Renderer**  | Supported                                                                          |
| **TextMesh Pro**     | &#8226; Partially Supported<br/>&#8226; SDF only<br/> &#8226; No custom shaders |
| **Rect Transform**   | No specific support for sizing                                                     |
| **Platform Text**    | See [Platform Text Rendering](PlatformText.md)                                     |
| **Masking** .        | Image masking is supported. Please see the note below in regards to support.       |

**Note**: Image masking is supported but there may be fidelity issues that come up. Straight image masking using simple images should work fairly well out of the box, though there may be some slight sizing differences due to the ability to support correct mapping. For 9-Slice sprite, Tile or other mesh based images, there will be some definite issues in how the mask is applied. Currently we do not support handling of the mesh information and instead just apply the mask as if it is a simple image based mask.

**Note**: Image masking does not affect clip box/collider hit testing when running. While the image mask may only show a portion of the item being masked, the clipping/collider testing still extends to the full rectangle that covers the masked portion of any UGUI item.

**Note**: By default, Dropdown and ScrollView will not apply image masking to their children due to the format of masking image they use by default. If you want to use masking with these components, you will need to change their mask image.

**Note**: Hover transitions on UGUI Selectables (Buttons, Dropdowns, Toggles, etc.) are subject to limitations on visionOS.  See the documentation for [Hover Effects](HoverEffect.md#ugui-selectable-hover-transitions) for more information.

# Final thoughts
Unity has many more components, but the main parts of the average XR app were covered in this section. Generally speaking, your existing Unity projects will likely require work to port to PolySpatial XR.

You will need to experiment, investigate, and adapt to the PolySpatial XR requirements and constraints by either writing your own PolySpatial XR-compatible systems or finding workarounds to these limitations to support your existing features.
