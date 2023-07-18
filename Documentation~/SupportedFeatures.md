# Supported Unity Features & Components
<a name="supported-unity-features-and-components"></a>
The majority of Unity components will work without modification on this platform - including most custom MonoBehaviours, animation logic, physics, input handling, asset management, AI, and so forth. However, components that need to be rendered require special support. Consequently, some components offer a reduced feature set on this platform; others are not currently supported. The tables below summarize the current state of various rendering component support on this platform. 

For more information about converting legacy projects, see also [Porting Unity Projects to PolySpatial XR](PortingUnityProjectsToPolySpatialXR.md)

## Unity Simulation Components / Systems
It's impossible to list all the systems and packages that Unity exposes in this page but the table below lists the status of support for a range of core Unity features: 

| **Component**             | **Status**               |
|---------------------------|--------------------------|
| **Transform**             | Supported                |
| **Audio**                 | No spatial audio support |
| **MeshFilter**            | Supported                |
| **Animation / Animators** | Supported                |
| **2D Physics**            | Supported                |
| **3D Physics**            | Supported                |
| **Scripts**               | Supported                |
| **AI & Navmesh**          | Supported                |
| **Terrain**               | Experimental support     |

`MonoBehaviours` are expected to work but they will depend on a case by case basis depending on which other components your scripts interact with.

## Rendering Components / Systems
<a name="rendering-components-systems"></a>

| **Component**             | **Status**               |
|---------------------------|--------------------------|
| **MeshRenderer**          | No support for "Lighting" (shadows, GI)     No support for "Probes"     No support for this component in Immediate mode     No support for "Additional Settings" (dynamic occlusion, rendering layer) |
| **SkinnedMeshRenderer**   |  Unoptimized animation only (the Optimize Game Object option on the Rig tab of the Model Import inspector must be ticked off if it appears.) |
| **Particle Systems**      | Partial support; see [Particle Systems](#particle-systems) below |
| **Light**                 | Not supported |
| **Camera**                | Not supported |
| **Halo**                  | Not supported |
| **Lens Flare**            | Not supported |
| **Line Rendering**        | Not supported |
| **Projector**             | Not supported |
| **Trail Renderer**        | Not supported |
| **Visual Effects**        | Not supported |
| **Lens Flare**            | Not supported |
| **Level of Detail (LoD)** | Not supported |
| **Occlusion Area**        | Not supported |
| **Occlusion Portal**      | Not supported |
| **Skybox**                | Not supported |
| **URP Decal projector**   | Not supported |
| **Tilemap Renderer**      | Not supported |
| **Video Player**          | Limited support |
| **Graphics Raycaster**    | Not supported |
| **Shaderlab Shaders**     | Not supported |
| **Post Processors**       | Not supported |
| **Lightmapping**          | Requires manual support |
| **Baked Lighting**        | Not supported |
| **Enlighten**             | Not supported |
| **Light Probes**          | Requires manual support |
| **Reflection Probes**     | Not supported |
| **Trees**                 | Not supported |
| **Fog**                   | Not supported |

Some of these features are not supported due to platforms constraints (for example, full screen graphics post processors aren't compatible with the idea of a shared rendering system), while others are areas of ongoing or planned development.

### Particle systems
<a name="particle-systems"></a>
Support for particles in PolySpatial XR is an on-going work in progress. The table below indicates the status of support for specific modules and settings currently supported by Unity's [Particle system](https://docs.unity3d.com/Manual/class-ParticleSystem.html):

| **Module**                       | **Status**          |
|----------------------------------|---------------------|
| **Emission**                     | Partially supported |
| **Shape**                        | Partially supported |
| **Velocity over lifetime**       | Partially supported |
| **Limit Velocity over lifetime** | Partially supported |
| **Inherit velocity**             | Partially supported |
| **Force over lifetime**          | Partially supported |
| **Color over lifetime**          | Partially supported |
| **Color by speed**               | Not Supported       |
| **Size over lifetime**           | Partially supported |
| **Size by speed**                | Not Supported       |
| **Rotation over lifetime**       | Partially supported |
| **Rotation by speed**            | Not Supported       |
| **External Forces**              | Not Supported       |
| **Noise**                        | Partially supported |
| **Collision**                    | Partially supported |
| **Triggers**                     | Not Supported       |
| **Sub Emitters**                 | Partially supported |
| **Texture sheet animation**      | Partially supported |
| **Lights**                       | Not Supported       |
| **Trails**                       | Not Supported       |
| **Custom Data**                  | Not Supported       |
| **Renderer**                     | Partially supported |

## User Interface (UI)
[Unity UI](https://docs.unity3d.com/Manual/com.unity.ugui.html) works in world space, but screen space UI and advanced visual features like masking, shadowing, etc do not currentl work. The table below summarizes the supprot status for other UI features:

| **Component**       | **Status**                                                                |
|---------------------|---------------------------------------------------------------------------|
| **TextMesh**        | Supported                                                       |
| **Canvas Renderer** | Partially Supported                                                       |
| **Sprite Renderer** | Supported                                                       |
| **TextMesh Pro**    | &#8226; Partially Supported<br/>&#8226; Raster only<br/> &#8226; No custom shaders |
| **Rect Transform**  | No specific support for sizing                                            |  

# Final thoughts
Unity has many more components, but the main parts of the average XR app were covered in this section. Generally speaking, your existing Unity projects will likely require work to port to PolySpatial XR.

You will need to experiment, investigate, and adapt to the PolySpatial XR requirements and constraints by either writing your own PolySpatial XR-compatible systems or finding workarounds to these limitations to support your existing features.