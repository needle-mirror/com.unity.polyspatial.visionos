## Input
<a name="input"></a>

There are two ways to capture user intent on visionOS: 3D touch and skeletal hand tracking. In exclusive mode, developers can also access head tracking data.


### 3D Touch and TouchSpace

In both bounded and unbounded volumes, a 3D touch input is provided when the user looks at an object with an input collider and performs the “pinch” (touch thumb and index finger together to “**tap**” or “**drag**”) gesture. The **PolySpatialTouchSpace Input device** provides that information to the developer. If the user holds the pinch gesture, a drag is initiated and the application is provided “move” updates relative to the original start point. Users may also perform the pinch gesture directly on an object if it is within arms reach (without specific gaze).

3D touch events are exposed via the **PolySpatialTouchSpace Input device**, which is built on top of the `com.unity.inputsystem` package, otherwise known as the New Input System. Existing actions bound to a touchscreen device should work for 2D input. For 3D input, users can bind actions to the specific **PolySpatialTouchSpace** device for a 3D position vector.

A collider with the collision mask set to the PolySpatial Input layer is required on any object that can receive 3D touch events.  Only touches against those events are reported.  At this time, the platform does not make available the gaze ray at the start of a tap gesture.


### Skeletal Hand Tracking

Skeletal hand tracking is provided by the **Hand Subsystem** in the **XR Hands Package**. Using a **Hand Visualizer** component in the scene, users can show a skinned mesh or per-joint geometry for the player’s hands, as well as physics objects for hand-based physics interactions. Users can write C# scripts against the **Hand Subsystem** directly to reason about the distance between bones and joint angles. The code for the **Hand Visualizer** component is available in the **XR Hands Package** and serves as a good jumping off point for code utilizing the **Hand Subsystem**.


### Head Tracking

Head tracking is provided by ARKit through the **VisionOS Package**. This can be setup in a scene using the create menu for mobile AR: **Create &gt; XR &gt; XR Origin (Mobile AR)**. The pose data comes through the new input system from **devicePosition \[HandheldARInputDevice\]** and **deviceRotation \[HandheldARInputDevice\]** .
