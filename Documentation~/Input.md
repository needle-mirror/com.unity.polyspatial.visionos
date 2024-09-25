---
uid: psl-vos-input
---
# Input
<a name="input"></a>

There are two ways to capture user intent on visionOS: 3D touch and skeletal hand tracking. In exclusive mode, developers can also access head tracking data.

## 3D Touch and TouchSpace

In both bounded and unbounded volumes, a 3D touch input is provided when the user looks at an object with an input collider and performs the “pinch” (touch thumb and index finger together to “**tap**” or “**drag**”) gesture. The **SpatialPointerDevice Input device** provides that information to the developer. If the user holds the pinch gesture, a drag is initiated and the application is provided “move” updates relative to the original start point. Users may also perform the pinch gesture directly on an object if it is within arms reach (without specific gaze).

3D touch events are exposed via the **SpatialPointerDevice Input device**, which is built on top of the `com.unity.inputsystem` package, otherwise known as the New Input System. Existing actions bound to a touchscreen device should work for 2D input. For 3D input, users can bind actions to the specific **SpatialPointerDevice** device for a 3D position vector.

A collider with the collision mask set to the PolySpatial Input layer is required on any object that can receive 3D touch events. Only touches against those events are reported. At this time, the platform does not make available the gaze ray at the start of a tap gesture.

This input device has a counterpart called **VisionOSSpatialPointerDevice** for gesture input captured by the Metal rendering layer. The primary difference between the two is that the interaction doesn't require colliders. Thus, **VisionOSSpatialPointerDevice** is missing input controls related to the interaction (`targetId`, `interactionPosition`, etc.).

Hybrid apps will need to use both **SpatialPointerDevice** and **VisionOSSpatialPointerDevice** to process 3D touch input. When Metal rendering is not active, only **SpatialPointerDevice** is needed, just like in RealityKit mode. When Metal mode _is_ active, **VisionOSSpatialPointerDevice** can be used on its own, unless you are combining Metal content with RealityKit content in a volume. If you do intend to display a RealityKit volume on top of Metal content, or if the same scripts will be used in Metal and RealityKit mode, both devices can and should be used simultaneously.

## Skeletal Hand Tracking

Skeletal hand tracking is provided by the **Hand Subsystem** in the **XR Hands Package**. Using a **Hand Visualizer** component in the scene, users can show a skinned mesh or per-joint geometry for the player’s hands, as well as physics objects for hand-based physics interactions. Users can write C# scripts against the **Hand Subsystem** directly to reason about the distance between bones and joint angles. The code for the **Hand Visualizer** component is available in the **XR Hands Package** and serves as a good jumping off point for code utilizing the **Hand Subsystem**.

## Head Tracking

Head tracking is provided by ARKit through the **VisionOS Package**. This can be setup in a scene using the create menu for mobile AR: **Create &gt; XR &gt; XR Origin (Mobile AR)**. The pose data comes through the new input system from **devicePosition \[HandheldARInputDevice\]** and **deviceRotation \[HandheldARInputDevice\]** .

## XR Interaction Toolkit

To use the XR Interaction Toolkit with PolySpatial, use the **XRSpatialPointerInteractor** provided in `com.unity.polyspatial.xr`. This custom [interactor](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@latest?subfolder=/manual/architecture.html#interactors) uses the input raycast provided by the [SpatialPointerDevice](xref:psl-vos-polyspatial-input#spatial-pointer-device-data) in visionOS to determine which **Interactable** the user selected. It uses the `targetId` [InputControl](xref:UnityEngine.InputSystem.InputControl) to obtain a direct reference to the [Interactable](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@latest?subfolder=/manual/interactable-components.html) that was targeted by the pinch or poke gesture.

> [!TIP]
> You should always use the `targetID` from the [SpatialPointerDevice](xref:psl-vos-polyspatial-input#spatial-pointer-device-data) on visionOS to avoid performing an additional raycast within Unity itself. Using the `targetID` not only avoids redundant operations, but also avoids the accidental selection of a different collider, which can happen if there are overlaps.
