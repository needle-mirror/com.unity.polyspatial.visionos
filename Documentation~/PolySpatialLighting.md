---
uid: psl-vos-polyspatial-lighting
---

# Unity PolySpatial Lighting Support
VisionOS provides image based lighting as well as dynamic point, spot, and directional lights.  PolySpatial also includes a lighting solution available to shader graphs that provides a subset of the lighting features available in Unity.  The PolySpatial Lighting Node supports directional lightmaps, light probes, and up to four dynamic lights (point, spot, or directional).

## VisionOS Lighting
Lit materials (both standard shaders such as `Universal Render Pipeline/Lit` and shader graphs using Lit targets) use visionOS lighting by default.  This lighting comprises [image based lighting](ImageBasedLight.md) (derived from the device cameras and/or environment maps) and, optionally, dynamic point, spot, and directional lights.  Spot and directional lights support shadows.

Because visionOS uses different lighting calculations from Unity, the appearance of lit objects in visionOS will not exactly match that of objects rendered in the Unity editor.  To achieve a closer match for dynamic lights, you may wish to use the `PolySpatial Lighting Node`.

### VisionOS Light Settings
To control the default behavior for dynamic lights in visionOS, use the `Default VisionOS Lighting` option under `PolySpatial` in `Project Settings`.  This defaults to `Image Based Only`, but you can change it to `Image Based and Dynamic Lights` to enable point/spot/directional lights for standard Lit materials in visionOS, or to `Image Based, Dynamic Lights, and Shadows` to enable spot/directional shadows as well.

There are two additional settings that control shadow behavior specific to visionOS: 
* Because visionOS uses only a fixed depth bias for shadows (versus Unity's fixed plus directional biases), the `Default VisionOS Shadow Bias Offset` setting provides a means to add an additional depth bias amount to shadows on visionOS.
* Because visionOS does not use cascaded shadow maps for directional lights, it requires a maximum distance to be set relatively close to the camera.  The `Default VisionOS Directional Shadow Max Distance` setting controls the maximum distance away from the camera to render directional shadow maps.  Set this to a small value (such as 2-3 meters) for typical indoor bounded scenes in order to maximize the apparent resolution of the shadow map.

To control visionOS light behavior on a per-light basis, add an instance of the `VisionOS Light Settings` component to the `GameObject` containing the `Light` instance.  This has the same options as the defaults in the `PolySpatial` project settings.

## PolySpatial Lighting Node
To add PolySpatial lighting to a shader graph, create an instance of the `PolySpatial Lighting Node` using the `Create Node` command in the shader graph editor.

### Inputs
The inputs to the lighting node are largely the same as the inputs to the `Lit` shader graph target--`Base Color` (albedo), `Normal` (in tangent space), `Metallic`, `Smoothness`, `Emission`, and `Ambient Occlusion`--with the additional of a `Lightmap UV` input for lightmap texture coordinates.

### Output
The output (`Out`) of the lighting node is a single color result.  Depending on your application, you may wish to supply this output directly to the `Base Color` input of an `Unlit` target (if you wish to use only PolySpatial lighting) or to the `Emission` input of a `Lit` target (if you wish to combine PolySpatial lighting with visionOS's lighting).

### Limitations
Only static directional lightmaps with dLDR encoding are supported.

### Settings

#### Baked Lighting
The `Baked Lighting` setting has three options: `None` to omit baked lighting entirely, `Lightmap` to apply baked lightmaps, and `LightProbes` to obtain baked lighting from light probes.  Typically, static objects use lightmaps and dynamic objects use light probes.

#### Reflection Probes
The `Reflection Probes` setting has three options: `None` to omit contribution from reflection probes, `Simple` to use a single reflection probe, and `Blended` to blend the contributions of up to two reflection probes.

#### Dynamic Lighting
The `Dynamic Lighting` toggle determines whether dynamic point/spot/directional lights (that is, lights represented by non-baked [Light](https://docs.unity3d.com/ScriptReference/Light.html) components) affect the output.

### Light Selection
The [Render Mode](https://docs.unity3d.com/ScriptReference/Light-renderMode.html) property of Light components may be used to control which dynamic lights are applied.  Lights marked [Not Important](https://docs.unity3d.com/ScriptReference/LightRenderMode.ForceVertex.html) will never be included in the four lights used by the PolySpatial Lighting Node.  Other lights will be sorted by the following criteria, in descending order of precedence:

* Directional lights take priority over point/spot lights.
* Shadow casting lights take priority over non-shadow-casting lights.
* Lights marked [Important](https://docs.unity3d.com/ScriptReference/LightRenderMode.ForcePixel.html) take priority over lights marked [Auto](https://docs.unity3d.com/ScriptReference/LightRenderMode.Auto.html) (the default).
* Lights with positive instance IDs (typically loaded from scenes) take priority over lights with negative instance IDs (typically created at runtime).
* Lights with lower instance ID absolute values take priority over ones with higher absolute values (typically, this means lights created earlier take priority).

After sorting, the first four lights will be selected for use as dynamic lights.

## PolySpatial Environment Radiance Node
To access visionOS's image based lighting (in either `Lit` or `Unlit` shader graphs), create an instance of the `PolySpatial Environment Radiance Node`.  This accepts surface parameters (`BaseColor`, `Roughness`, `Specular`, `Metallic`, and `Normal`) and outputs `Diffuse Radiance` and `Specular Radiance` colors representing the lighting results.  For example, to get an approximation of the ambient light level, use a `BaseColor` of white, `Roughness` of 1.0, `Specular` and `Metallic` of 0.0, and the default `Normal`.  The `Diffuse Radiance` output will be approximately equal to the ambient light level.  Note that the output of `PolySpatial Enviroment Radiance` is entirely separate from the lighting applied to `Lit` targets; for instance, if you add the `Diffuse Radiance` and `Specular Radiance` outputs together and connect them to the `Emission` output of a `Lit` target, you will end up with twice the overall brightness.