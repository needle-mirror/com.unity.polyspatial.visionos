---
uid: psl-vos-grounding-shadow
---
# PolySpatial Grounding Shadow

This component provides a hint to the platform to cast a shadow from this object onto surfaces below, as if from a directional light pointing straight downwards.  The object must have a `MeshRenderer` component.  The PolySpatial Grounding Shadow component acts as a direct proxy to RealityKit's [GroundingShadowComponent](https://developer.apple.com/documentation/realitykit/groundingshadowcomponent) on visionOS, and is not available on other platforms, such as in Unity play mode.

![PolySpatialGroundingShadow](images/ReferenceGuide/PolySpatialGroundingShadow.png)