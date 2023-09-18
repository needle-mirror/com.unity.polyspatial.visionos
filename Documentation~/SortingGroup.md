---
uid: psl-vos-sorting-group
---
# PolySpatial Sorting Group
This component provides a way to leverage visionOS' sorting group capabilities. While 2D components (such as SpriteRenderers and CanvasRenderers) have their own sorting mechanism, it may be beneficial in certain situations to sort non-2D renderers such as `MeshRenderers`. By placing these renderers into the sorting group, a user can get fine-grained control over which renderer is drawn first. 

This sort group is meant for sorting non-2D renderers with each other. Sorting non-2D renderers with 2D renderers may cause unexpected behavior - 2D renderers have their own sorting group. Each renderer can only belong to one sorting group at a time, and subsequent attempts to add a renderer to another sorting group will result in a warning.

Each game object can only have one `PolySpatialSortingGroup` and each component will correspond to a new and unique sorting group. It is advisable to set the component once - changing properties will effectively cause the component to be deleted and re-created, which could be an expensive operation if the `ApplyToDescendants` option was ticked. 

The `PolySpatialSortingGroup` component exposes the following properties:

| **Property** | **Description** |
| --- | --- |
| **DepthPass** | Controls when depth is drawn with respect to color. |
| **List of Renderers ** | A list of structs that reference the renderer to be sorted, and the sort order. |

Each renderer struct consists of the following properties.

| **Order** | The order this renderer should be drawn, with respect to other renderers in the group. |
| **Renderer** | A reference to the renderer's game object.|
| **ApplyToDescendants** | When true, the sort order will be applied to all child renderers. It is important, if `ApplyToDescendants` is true, to be careful of nested sorting groups - any subsequent attempts to add a renderer that is already a member of a different sorting group will be ignored, and a warning will show. |
