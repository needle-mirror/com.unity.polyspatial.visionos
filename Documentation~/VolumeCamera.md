---
uid: psl-vos-volume-camera
---
# Volume cameras

PolySpatial provides a new Unity component called a **Volume Camera**, which determines how Unity apps interact with the modes and volumes of visionOS. Volume cameras are similar to regular Unity cameras in that they specify what portion of your Unity scene will be visible and interactable to a user. However, while traditional cameras flatten 3D content into 2D images, Volume Cameras preserve the 3D nature of the content they capture. Just as traditional cameras are associated with a 2D viewport or texture, volume cameras are associated with a (3D) Volume Window.

Volume cameras support both **Bounded** and **Unbounded** modes. When a volume camera's **Mode** is set to **Unbounded**, your entire Unity scene is shown in a visionOS Immersive Space.

In contrast, a camera in **Bounded** mode corresponds to a visionOS Volume Window, and only content contained within the camera's bounding box appears inside your Volume Window. Unity content inside a volume camera's bounds is scaled up or down to fit inside its Volume Window, and objects that overlap the window boundary are subject to GPU clipping. The **VolumeCamera** component displays preview bounds in the Scene view to help visualize what content will be rendered in this mode.

You can alter or animate a volume camera's transform and dimensions to dynamically change which subregion of your scene will appear inside its associated visionOS Volume Window. However, to switch between modes or to alter the size of the Volume Window itself, you must change the [Volume Camera Window Configuration](#volume-camera-window-configuration-assets) referenced by the volume camera. You cannot modify the properties of a Volume Camera Window Configuration at runtime.

An application can have multiple `Volume Cameras`, but no more than one volume camera can be set to **Unbounded** mode. The presence of an **Unbounded** camera will put the app in an exclusive/immersive mode and subsequent **Unbounded** cameras will be ignored. Each **Bounded** volume camera will be mapped to a visionOS Volume Window, and will render a subregion of your scene, dependent on bounds and **CullingMask**. Each volume camera in a multiple volume camera scene has the same features as a single volume camera would - including subscribing to **WindowEvents**, panning or scaling the volume camera, changing the **Volume Camera Window Configuration**, etc.

A scene may have as many as 255 **Bounded** volume cameras and one **Unbounded** volume camera per scene. However, each additional **Bounded** volume camera will increase the scene's memory usage and may decrease performance. **CullingMasks** can be used to selectively control what each volume camera renders and may mitigate these issues.

Each volume camera renders objects independently of each other, and objects from the scene can appear simultaneously in multiple volume cameras at once. For example, if two bounded volume cameras encapsulate a single sphere in their respective bounding boxes, the sphere will appear in both volume camera windows.

Input events can only originate from one volume camera at a time. For example, if a user holds the pinch gesture on an object in one volume, then looks at another volume's object and attempts a pinch gesture with a second hand, the first input event will end and the second pinch gesture will take its place.

> [!NOTE]
> Only one `Volume Camera` is allowed per GameObject. To create multiple `Volume Camera` components, they must be placed on different GameObjects.
>
> In addition, a current limitation of the system is that, if there are multiple components of a certain type, they must be placed on separate GameObjects to work properly. Components include:
>
> - VisionOSVideoComponent (This restriction does not apply to Unity's VideoPlayer)
> - VisionOSHoverEffect
> - VisionOSGroundingShadow
> - VisionOSImageBasedLight
> - VisionOSImageBasedLightReceiver
> - VisionOSEnvironmentLightingConfiguration
> - VisionOSLightSettings
> - VisionOSSortingGroup
> - VisionOSNativeText
>
> For example, if there are two VisionOSVideoComponents in the scene, they must be placed on separate GameObjects. Any other mix of components on a single GameObject is allowable, so long as there are no duplicate components.
>
> This limitation does not apply to Colliders, and multiple Collider components can be placed on a single GameObject.
>
> Even if multiple volume cameras are not used, this limitation still applies.

## Volume camera properties

![VolumeCamera](images/ReferenceGuide/VolumeCamera.png)

The **VolumeCamera** component exposes the following properties:

| **Property**                    | **Description**      |
| :------------------------------ | :------------------- |
| **CullingMask**                 | Defines a bitmask of Unity layers. Only objects belonging to the specified layers are displayed by the volume camera. You can use the CullingMask to specify which objects the volume camera should display. To be visible in a **Bounded** volume, the GameObjects must also be within the volume camera's bounding box (as specified by its **Dimensions** property and transform scale. Refer to [Layers](xref:Layers) for more information about layers and layer masks in Unity. |
| **Dimensions**                  | Defines the (unscaled) size of the camera's bounding box. When you set the volume camera **Mode** to **Bounded**, the camera only displays GameObjects within the scaled bounding box. The bounding box is centered at the position of the **VolumeCamera**’s transform. The world space dimensions of the bounding box are calculated by multiplying the **Dimensions** by the transform's scale. The **Dimensions** are ignored when you set the **Mode** to **Unbounded**, because there is no bounding box in that mode. |
| **Scale Content With Window**   | This option is only available for a volume camera in **Bounded** mode. If enabled, the volume camera’s contents scale with the volume window size. If disabled, the volume camera’s contents will scale independently of the volume window’s size, and resizing the window using the window’s interface controls will reveal more of the scene. |
| **Open Window On Load**         | If enabled, the volume camera opens its volume automatically when loaded. Otherwise, you must open the volume manually using the [VolumeCamera.OpenWindow()](xref:Unity.PolySpatial.VolumeCamera.OpenWindow) method. |
| **Target Display**              | The display in the Game tab that will be used to render the contents of the volume while in play mode. This allows you to switch between volumes when developing a multi-volume application. |
| **Volume Window Configuration** | Defines the size and mode of the volume window to which the volume camera is connected. If you do not set a configuration, then the volume camera uses the configuration specified for **Default Volume Camera Configuration** in your [PolySpatial Settings](#volume-camera-polyspatial-settings) when it opens its volume window. |

For example, you could render a 3D inventory within one volume by assigning the inventory GameObjects to an "inventory" layer, and use a "minimap" layer to render a bird's eye view of the entire scene within a second volume.

## Implementation details and intuitions

Just as a traditional camera specifies both a source size (field of view) and target size (viewport dimensions), a volume camera specifies both source dimensions and target dimensions. A volume camera's dimensions are somewhat akin to field of view: they define how much of the scene is visible. Likewise, its output dimensions are akin to viewport size: they determine how big the content appears to the user.

A volume camera maps content from a source oriented bounding box (OBB) within Unity to the corresponding target OBB of a visionOS Volume Window as follows:

The source OBB is centered and oriented according to the transform of the volume camera's GameObject, and its size is equal to its dimensions multiplied by the scale of its GameObject. All Unity content within this OBB will be replicated to visionOS. Adjusting the source dimensions is akin to zooming a camera in or out - it affects *both* how much content you see *and* how big that content will appear. The dimensions and transform of a volume camera can be freely modified during runtime.

The target OBB -- the visionOS volume window -- can only be positioned and rotated by a user or the OS, but its size is determined by the **Output Dimensions** of the Volume Camera's [Volume Camera Window Configuration](#volume-camera-window-configuration-assets). Changing the output dimensions *only* scales the real-world size of the final rendered content, *not* how much content is visible.

At runtime, you cannot change the dimensions of a bounded volume window directly. When you change the [Volume Camera Window Configuration](#volume-camera-window-configuration-assets) of a Volume Camera component to one with different **Output Dimensions**, PolySpatial replaces the existing volume window with a new one.

The **Scale Content With Window** Volume Camera property can be changed at runtime. When toggling this property during runtime, the content may appear to change size and positioning. When **Scale Content With Window** is enabled, the content will automatically resize to maintain proportionality - in other words, content that is half the size of your volume's bounding box in the editor will scale so that it is half the size of your volume window's size during runtime. When this property is disabled, content will scale independently of the volume window size, and will be the same size as it would've been within an **Unbounded** volume window.

Additionally, while **Scale Content With Window** is disabled, the content may appear to shift upwards or downwards in space when the volume window is resized - this is due to the volume itself getting larger. For example, any content fixed at position 0x0x0 (the middle of the volume) will appear to move upwards relative to world space as the volume gets larger. To compensate for this, while **Scale Content With Window** is disabled, subscribe to **WindowStateChanged** to get the true size of the volume window and shift the content either upwards or downwards to compensate for the changing size of the volume window.

<a id="volume-camera-events"></a>
## Volume camera events

The **VolumeCamera** has the following events that can be subscribed to:

`WindowStateChanged` An event that is triggered when this volume camera's window changes state - in other words, it is triggered whenever the window is opened, closed, resized, receives focus, or loses focus. When a change has occurred, the event will supply a `WindowState` struct that encapsulates information on the window's state change.

The `WindowState` struct has the following properties:

| **Property**                           | **Description**      |
|:---------------------------------------| :------------------- |
| **WindowEvent**                        | The change in state that just occurred for this window. |
| &nbsp;&nbsp;&nbsp;&nbsp;*Opened*       | The volume camera window was opened. |
| &nbsp;&nbsp;&nbsp;&nbsp;*Resized*      | The volume camera window was resized. See the `OutputDimensions` and `ContentDimensions` to figure out what the volume camera window was resized to.|
| &nbsp;&nbsp;&nbsp;&nbsp;*Focused*      | The volume camera window either received focus or lost focus.|
| &nbsp;&nbsp;&nbsp;&nbsp;*Backgrounded* | The volume camera window was closed due to being backgrounded.|
| &nbsp;&nbsp;&nbsp;&nbsp;*Closed*       | The volume camera window was closed due to being dismissed.|
| **OutputDimensions**                   | The actual dimensions of the window in world space, or `Vector3.zero` if the volume is unbounded. |
| **ContentDimensions**                  | The actual dimensions of the content, which may be different due to aspect ratio mapping, in world space, or `Vector3.zero` if the volume is unbounded. |
| **Mode**                               | The mode this volume camera will display its content in, Bounded or Unbounded. |
| **IsFocused**                          | When windowEvent is set to `WindowEvent.Focused`, this will indicate whether it has received focus or lost it. |
| **SessionID**                          | A value to identify the PolySpatial session that the volume camera generating the event belongs to. This is useful for multi-session applications (such as Play-to-Device), where the scene exists both locally and on the device. When the Session ID is 0, the event came from a volume in the local session. When the ID is greater than 0, it came from a volume in a remote session (such as on the device). |

The following table provides examples of the sequence in which `WindowStateChanged` is called when a volume window changes state because of a User or OS action. For example, when the OS opens a window while launching an app, `WindowStateChanged` is invoked twice, once with `WindowEvent.Opened`, and once with `WindowEvent.Resized`.

Note that these events may differ from backend to backend. The events listed below are when running an app on Vision OS. When running an app on the Unity editor, there are no `UnityEvent.Focused` events triggered, nor are there `UnityEvent.Backgrounded` events.

Additionally, some of the ordering may be subject to change in the future, particularly **Changing the Volume Window Configuration**.

| **User / OS Actions**                             | **OnWindowEvents triggered (in order)**   |
|:--------------------------------------------------|:------------------------------------------|
| **Opening the app for the first time**            | WindowEvent.Opened |
| **Changing the `Volume Window Configuration`**     | WindowEvent.Closed<br>WindowEvent.Opened<br>WindowEvent.Resized                        |
| **Opening the Vision Pro's home view**            | WindowEvent.Focused, IsFocused = false    |
| **Bringing the app back into focus**              | WindowEvent.Focused, IsFocused = true     |
| **Tapping the `x` button next to the window bar** | WindowEvent.Focused, IsFocused = false<br>WindowEvent.Backgrounded                  |
| **Reopening the app from the home view**          | WindowEvent.Opened<br>WindowEvent.Focused, IsFocused = true     |

`ViewpointChanged` An event that is triggered when the user's viewpoint of the volume changes. This event will only trigger for volumes with the bounded window configuration mode. The possible viewpoints are left, right, front, and back. When the user steps to the left of the bounded volume, this event will trigger and indicate that the user is to the left of the volume.

This event will only trigger once a viewpoint change has happened. Currently, when the volume is first created, this event will not trigger.

`ImmersionChanged` An event that is triggered when the user turns  the **Digital Crown** to change the immersion level. The VolumeCamera must be set to **Unbounded** **Mode** and the **Immersion Style** must be set to **Progressive** in Project Settings.

When the user rotates the dial, this event provides two optional decimal values in the range [0, 1] indicating the old and new immersion states. A value of 1.0 means full, 100% immersion and the app will behave as if it had been set to **Full** immersion style. A value of `null` means that immersion is disabled. When immersion is enabled, the initial value will be 0.55 before the user rotates the dial.

> [!NOTE]
> Apple visionOS 2.0 added support for the `onImmersionChange` SwiftUI modifier. This modifier is not available in earlier visionOS versions. Refer to the [Developer Documentation](https://developer.apple.com/documentation) for additional information.

<a id="volume-camera-window-configuration-assets"></a>
## Volume Camera Window Configuration assets

Because visionOS requires all possible Volume Window dimensions to be predeclared at build time, you must specify all Volume Window setups ahead of time as Volume Camera Window Configuration assets. To change the mode or size of your app's volume window, you must change your volume camera to reference a different (predefined) Volume Camera Window Configuration asset. You cannot modify the properties of Volume Camera Window Configurations at runtime.

Volume Camera Window Configuration assets support the following properties:

| **Property**                                             | **Description**                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|:---------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Mode**                                                 | Whether the camera should restrict the rendered content to objects within its bounding box or be unbounded.                                                                                                                                                                                                                                                                                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;*Bounded*                        | The volume camera has finite bounds defined by its dimensions.                                                                                                                                                                                                                                                                                                                                                                                                    |
| &nbsp;&nbsp;&nbsp;&nbsp;*Unbounded*                      | The volume camera captures everything regardless of position, and the dimensions field is disabled and ignored. Setting the mode of a volume camera to Unbounded is equivalent to requesting your app switch to "exclusive" mode.                                                                                                                                                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;*Metal*                          | For use with hybrid apps. See [PolySpatial Hybrid Apps on visionOS](PolySpatialHybridApps.md) for more information.                                                                                                                                                                                                                        |
| **Window World Alignment**                               | For **Bounded** volumes, determines the alignment of the volume when the volume is lifted above eye-level of the user. If this is set to Adaptive, the volume will tilt so that the front is facing the user. If this is set to Gravity Aligned the volume will stay parallel to the ground.                                                                                                                 |
| **Output Dimensions**                                    | For **Bounded** volumes, determines the size of the displayed volume in meters. For example, if you set the output dimensions to 3x3x3, the Volume Window opened in the app is a cube measuring 3 meters on each side. The content within the volume camera's bounding box is scaled to fill the Volume Window(Ignored for **Unbounded** volumes).                                                                                                                |
| **Window Resizing Limits**                               | For **Bounded** volumes, determines whether the volume should have a minimum size and a maximum size. This minimum and maximum will take effect when the volume is resized using the window's interface controls.                                                                                                                                                                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;*Fixed Size*                     | This resizing limitation disables volume window resizing, locking the volume window size to its **Output Dimensions**. The values in Min/Max Window Size will be ignored.                                                                                                                                                                                                                                                                                         |
| &nbsp;&nbsp;&nbsp;&nbsp;*Limit Minimum Size*             | This resizing limitation allows for setting a minimum size for a volume window, but places no limitations on the window's maximum size. The value in Max Window Size will be ignored.                                                                                                                                                                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;*Limit Minimum and Maximum Size* | This resizing limitation allows for setting a minimum and a maximum size for a volume window.                                                                                                                                                                                                                                                                                                                                                                     |
| **Min/Max Window Size**                                  | For **Bounded** volumes, determines the minimum and maximum volume window size when it is resized using the window's interface controls. If the minimum window size is higher than the **Output Dimensions**, or the maximum window size is lower than the **Output Dimensions**, then the values will be clamped to **Output Dimensions**. For best results, the minimum and maximum volume window size should have the same ratio as the **Output Dimensions**. |

> [!NOTE]
> The visionOS operating system is free to set the volume window dimensions as it sees fit. The actual window dimensions are reported in [WindowStateChanged](#volume-camera-events) when `WindowEvent` is Opened. This also applies to the Min/Max Window Size - setting a high maximum or low minimum window size does not necessarily guarantee the volume window can be resized to that value.

Create volume camera configuration assets using the **Create** menu: **Assets &gt; Create &gt; PolySpatial &gt; Volume Camera Window Configuration**. You must store these assets within a folder named `Resources` and they must exist when you start the build -- they cannot be added as a build process or post-process. Refer to [Special Folder names](xref:SpecialFolders) for more information about `Resources` folders in Unity. All volume camera configuration assets that you intend to use must be included in the build. You cannot create them dynamically at runtime.

Within each project, there can only be a maximum of one Metal and one Unbounded **Volume Camera Window Configuration**. There can be multiple Bounded **Volume Camera Window Configuration**s within a project, but they all must have different `OutputDimensions`. During a build, if a duplicate is detected, a warning will be logged for the duplicate.

Once created, you can swap between configurations at runtime, but you cannot modify the output properties of a Volume Camera directly. You can only change these properties by referencing a different volume camera configuration asset.

Switching between volume camera configurations is as easy as assigning a new volume camera configuration to your volume camera, either through script or through the inspector window.  It is possible to switch between an unbounded and a bounded volume configuration, and vice-versa.

If you do not assign a configuration asset to a volume camera, it uses the asset specified by the **Default Volume Camera Window Configuration** property of your project's **PolySpatial** settings. (To change this property, open the **Project Settings** window (menu **Edit &gt; Project Settings**) and select the **PolySpatial** section.)

<a id="volume-camera-polyspatial-settings"></a>
## Volume camera PolySpatial settings

The general [PolySpatial Settings](PolySpatialSettings.md) include the following settings that pertain to volume cameras:

| **Setting**                             | **Description**                                                                                                                                            |
| :-------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Default Volume Camera Configuration** | Defines the default **Volume Camera Configuration** asset that a volume camera uses to open its volume window if you have not assigned a configuration asset to the volume camera. If you do not identify a default configuration, any volume camera without a configuration attempts to open its volume window in **Unbounded** mode. This also determines the start-up scene for the application. For example, a project with the default Unbounded Volume Camera Window Configuration will start with an `ImmersiveSpace`, hiding other applications and the virtual environment. |
| **Auto-Create Volume Camera**           | When enabled, PolySpatial creates a volume camera automatically if there is no volume camera after scene load. Disable this property if you create the initial volume camera from a script after the scene loads. |

Access these settings in the **PolySpatial** section of your **Project Settings** (menu: **Edit &gt; Project Settings**).
