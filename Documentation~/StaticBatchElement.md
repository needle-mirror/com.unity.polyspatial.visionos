---
uid: psl-static-batch-element
---
# Static Batch Elements

The **PolySpatialStaticBatchElement** component provides a hint to the platform that a `GameObject` containing a `MeshRenderer` will never move relative to a root `GameObject` or to the scene root (depending on the value of the `Root` property).  This allows the platform to batch meshes that share the same root together, reducing the number of draw calls and (often) improving performance.  For more information on static batching, refer to the documentation for [StaticBatchingUtility](https://docs.unity3d.com/ScriptReference/StaticBatchingUtility.html).  GameObjects may also use the `Static` editor toggle to enable static batching relative to the root.  Note that on visionOS, PolySpatial cannot separately control the visibility of batch elements.  Elements with the same material and lighting parameters are simply combined into a single mesh and rendered together.

The `PolySpatial Static Batch Element` component exposes the following properties:

| **Property** | **Description** |
| --- | --- |
| **Root** | The root `GameObject` relative to which the element will stay fixed, or `None` if it will stay fixed relative to the scene root. |