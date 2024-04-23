---
uid: psl-vos-requirements
---
# Unity visionOS Support Requirements & Limitations

## Requirements

### Unity Version Support 

This package is compatible with Unity 2022 LTS for Apple Silicon (2022.3.18f1 or newer).
Unity visionOS Support is not compatible with earlier LTS versions of Unity. 

Please ensure that the **visionOS Build Support** module is installed. 


### Xcode and visionOS version
This package is compatible with:
- Xcode 15.2 or newer
- visionOS 1.0 (21N301) SDK or newer

### Hardware

- An Apple Silicon Mac is currently required for development. 
- If you do not have access to Apple Vision Pro, you can also develop with the visionOS simulator included with compatible versions of Xcode (15.2 or newer). 

For more information about setting up your development environment, refer to [Development & Iteration](DevelopmentAndIteration.md).

### Graphics 

For Mixed Reality (Immersive) applications, Unity delegates all rendering to the platform so that the OS can provide the best performance, battery life, and rendering quality while taking into account all MR applications that are running concurrently. This imposes significant constraints on the graphics features that are available. While we are constantly working to improve visual equivalency between Unity and RealityKit, there will likely be some visual differences. 

Note that rendering for Virtual Reality (Fully Immersive) applications and Windowed applications is managed by Unity. 

#### Render pipeline

While your project can use either the Universal Render Pipeline (URP) or the Built-in Render Pipeline, we recommend using URP when developing for visionOS. Features like Foveated Rendering for VR and Stereo Render Targets will only be compatible with URP. Refer to our Migration guide to move from the Built-in pipeline to URP: [Move on over to the Universal Render Pipeline with our advanced guide | Unity Blog](https://blog.unity.com/technology/move-on-over-to-the-universal-render-pipeline-with-our-advanced-guide).

#### Color space

Your project must use [Linear color space](https://docs.unity3d.com/Manual/LinearRendering-LinearOrGammaWorkflow.html).

#### Shaders and Materials

You can author custom shaders for visionOS using a subset of the Unity ShaderGraph. Behind the scenes, this is converted to MaterialX. ShaderLab and other custom coded shaders are not supported, as RealityKit for visionOS doesn't expose a low-level shading language. 

Several important standard shaders for each pipeline have been mapped to their closest available RealityKit analog. Current support includes:
* Standard URP shaders: Lit, Simple Lit, Unlit, and shaders for sprites, UI, and particles.
* Standard Builtin shaders: Standard, Standard(Specular), and shaders for sprites, UI, and particles.

For more information, see [PolySpatial Material Support](Materials.md).

## Additional Information
For the latest list of features, fixes and changes, please refer to our changelog. 

For more information about feature compatibility, please refer to the section on [Supported Unity Features & Components](SupportedFeatures.md).

For information about materials supported on this platform, see [PolySpatial Material Support](Materials.md), and [Shader Graph Support](ShaderGraph.md) for details about implementing custom shaders via Unity Shader Graph and MaterialX.
