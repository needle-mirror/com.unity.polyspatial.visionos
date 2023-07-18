# Unity PolySpatial ShaderGraph Support
You can use the Unity ShaderGraph to create custom materials for visionOS. These will previewed in their compiled form within Unity, but converted to MaterialX for display in simulator and on device. While MaterialX is very expressive, some ShaderGraph nodes have no analog in materialX. Within the ShaderGraph editor, unsupported nodes will be indicated by the presence of a `#` symbol.

For technical, security, and privacy reasons, visionOS does not allow Metal-based shaders or other low level shading languages to run when using AR passthrough. 

## Shader Graph limitations in visionOS
The following tables show the [current support status for Shader Graph nodes](https://docs.unity3d.com/Packages/com.unity.shadergraph@latest?subfolder=/manual/Built-In-Blocks.html) in PolySpatial for visionOS including a list of supported nodes and their various caveats. 

If a node doesn't appear here it means is not currently supported *Note that this list will be updated as we continue to add support for more nodes.*

## Artistic

| Section       | Node                | Notes                                                                                                                         |
|---------------|---------------------|-------------------------------------------------------------------------------------------------------------------------------|
| Adjustment    | Contrast            | Colors may not be consistent.                                                                                                 |
|               | Hue                 | Colors may not be consistent.                                                                                                 |
|               | Saturation          | Colors may not be consistent.                                                                                                 |
| Blend         | Blend               | Supports Difference, Subtract, Burn, Dodge, Linear Dodge, Overlay, Screen, Overwrite, Negation, Multiply                      |
| Filter        | Dither              | - Requires simulation of Screen Space Position.<br>- Doesn't work at the moment due to bug with curvelookup node definitions. |
| Normal        | Normal Blend        | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                      |
|               | Normal From Height  | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                      |
|               | Normal Reconstruct Z| <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                      |
|               | Normal Strength     | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                      |
|               | Normal Unpack       | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                      |
| Utility       | Colorspace Conversion| Not consistent - linear conversions not implemented.                                                                          |


### Channel

| Section   | Node       | Notes                                                                          |
|-----------|------------|--------------------------------------------------------------------------------|
| Channel   | Combine    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>       |
|           | Split      | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>       |
|           | Swizzle    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>       |

### Input

`Custom Interpolators` are limited to only this specific/names types:
* `Color`: Vector4
* `UV0`: Vector2
* `UV1`: Vector2
* `UserAttribute`: Vector4


  | Section   | Node                      | Notes                                                                                                                  |
  |-----------|---------------------------|------------------------------------------------------------------------------------------------------------------------|
  | Basic     | Boolean                   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Color                     | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Constant                  | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Integer                   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Slider                    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Time                      | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Float                     | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Vector2                   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Vector3                   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Vector4                   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  | Geometry  | Bitangent Vector          | Tangent and View space options are not standard.                                                                       |
  |           | Normal Vector             | Tangent and View space options are not standard.                                                                       |
  |           | Position                  | Tangent and View space options are not standard.                                                                       |
  |           | Screen Position           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Tangent Vector            | Tangent and View space options are not standard.                                                                       |
  |           | UV                        | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Vertex Color              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Vertex ID                 | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  | Gradient  | Gradient                  | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Sample Gradient           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  | Lighting  | Main Light Direction      | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  | Matrix    | ~~Matrix 3x3~~            | Doesn't work (due to bug in constant matrix node definitions)                                                          |
  |           | ~~Matrix 4x4~~            | Doesn't work (due to bug in constant matrix node definitions)                                                          |
  |           | Matrix Construction       | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Transformation Matrix     | Tangent and View space options are not standard.                                                                       |
  | Scene     | Camera                    | `Position` and `Direction` outputs supported (non-standard).                                                           |
  |           | Object                    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Scene Depth               | Platform doesn't allow have access to the depth buffer, this is just the camera distance in either clip or view space. |
  |           | Screen                    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  | Texture   | Sample Texture 2D         | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Sample Texture 2D LOD     | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Sampler State             | `MirrorOnce` wrap mode not supported.                                                                                  |
  |           | Texture 2D Asset          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |
  |           | Texture Size              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                               |


### Math

| Section       | Node                 | Notes                                                                                              |
|---------------|----------------------|----------------------------------------------------------------------------------------------------|
| Advanced      | Absolute             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Exponential          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Length               | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Log                  | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Modulo               | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Negate               | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Normalize            | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Basic         | Add                  | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Divide               | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Multiply             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Power                | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Square Root          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Subtract             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Interpolation | Inverse Lerp         | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Lerp                 | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Smoothstep           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Matrix        | Matrix Determinant   | Will flag as unsupported if using Matrix2.                                                         |
|               | Matrix Transpose     | Will flag as unsupported if using Matrix2.                                                         |
| Range         | Clamp                | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Fraction             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Maximum              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Minimum              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | One Minus            | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Random Range         | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Remap                | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Saturate             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Round         | Ceiling              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Floor                | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Round                | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Sign                 | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Step                 | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Trigonometry  | Arccosine            | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Arcsine              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Arctangent           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Arctangent2          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Cosine               | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Sine                 | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Tangent              | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
| Vector        | Cross Product        | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Distance             | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Dot Product          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Fresnel Effect       | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Reflection           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Rotate About Axis    | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |
|               | Transform            | Some spaces are simulated and not covered in tests.                                                |
| Wave          | Triangle Wave        | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                           |

### Procedural

| Section | Node             | Notes                                                                                                                                                                 |
|---------|------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Noise   | Gradient Noise   | - Can't be certain that target platform noise functions will behave the same. <br> - Frequency is currently off (scale is mapped to amplitude rather than frequency). |
|         | Voronoi          | - Can't be certain that target platform noise functions will behave the same.                                                                                         |
| Shapes  | Ellipse          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                                                                              |

### Utility

| Section | Node         | Notes                                                                                                                |
|---------|--------------|----------------------------------------------------------------------------------------------------------------------|
| Utility | Preview      | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                           |
|         | Split LR     | Non-standard shader graph node specific to Quantum. Implements the splitlr function as described in the MaterialX spec: https://materialx.org/assets/MaterialX.v1.38.Spec.pdf |
| Logic   | Branch       | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                           |
|         | Comparison   | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                           |
|         | Or           | <span style="color: green; font-weight: bold;">&#x2713; Supported</span>                                           |

### UV

| Section | Node              | Notes                                                                    |
|---------|-------------------|--------------------------------------------------------------------------|
| UV      | Flipbook          | <span style="color: green; font-weight: bold;">&#x2713; Supported</span> |
|         | Rotate            | Only Degrees are supported.                                              |
|         | Tiling and Offset | <span style="color: green; font-weight: bold;">&#x2713; Supported</span> |
|         | Triplanar         | <span style="color: green; font-weight: bold;">&#x2713; Supported</span> |