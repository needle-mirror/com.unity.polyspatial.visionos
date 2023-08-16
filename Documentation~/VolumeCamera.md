---
uid: psl-vos-volume-camera
---
# Volume Camera
PolySpatial provides a new Unity component called a `Volume Camera` to interact with the modes and volumes provided by the visionOS environment. Volume cameras are similar to regular Unity cameras in that they indicate which content should be visible to the user, but differ in that they capture 3D content rather than a 2D image.

Add a VolumeCamera component to an object in a scene to specify how and what content is to be presented to the user. The transform of the GameObject that holds the VolumeCamera (e.g. scale) affects the size of the volume that is displayed to the user. In-editor preview bounds for VolumeCamera can help visualize what content should be rendered.

Typically, this content is then displayed on a host platform by a corresponding "volume renderer", by mapping this canonical volume out to the host volume renderer's own distinct OBB. The effect is that 3D content within the volume camera's bounds is transformed, rotated, stretched and/or squashed to fill the volume renderer's bounds.

 When `Mode` is set to `Unbounded`, everything works similar to a typical Unity camera, except that the volume camera and volume renderer each define an unbounded 3-space rather than a bounded 3-space volume.

![VolumeCamera](images/ReferenceGuide/VolumeCamera.png)

The **VolumeCamera** component exposes the following properties:

| **Property** | **Description** |
| --- | --- |
| **Mode** | Specifies the mode of the volume.|
| &nbsp;&nbsp;&nbsp;&nbsp;*Bounded*| The volume camera has finite bounds defined by its dimensions. Any number of volume cameras can be in "bounded" mode. |
| &nbsp;&nbsp;&nbsp;&nbsp;*Unbounded*| The volume camera captures everything regardless of position, and the dimensions field is disabled and ignored. Only one volume camera can be in unbounded mode at a given time for a given app. Setting the mode of a volume camera to Unbounded is equivalent to requesting your app switch to "exclusive" mode.|
| **Dimensions** | Defines the (unscaled) size of the camera's bounding box, with the box centered at the position of the **VolumeCamera**’s transform. The world space dimensions are calculated by element-wise multiplication of Dimensions and the transform's scale. |
| **CullingMask** | Defines a bitmask of Unity layers. Only objects belonging to the specified layers will be displayed by the volume camera. As for typical Unity cameras and CullingMask workflows, this can be used to specify which object(s) are visible to each individual volume camera. For example, an inventory volume camera could be used to render a 3D inventory within one volume by defining an "inventory" layer, while a "minimap" layer might be used to render a bird's eye view of the entire scene within a second volume. |
