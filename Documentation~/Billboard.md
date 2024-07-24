---
uid: psl-vos-billboard
---
# Billboard

The **VisionOSBillboard** component ensures an object always faces the user, even in modes where head position isn't directly available, such as shared mode. This is particularly useful for text, UI, and other oriented content.  In visionOS, this maps directly to the [BillboardComponent](https://developer.apple.com/documentation/realitykit/billboardcomponent), and is ignored on other platforms. In  Unity play mode, we provide similar functionality which will show only the Game view targeting the main camera.

| **Property** | **Description** |
| --- | --- |
| **Blend Factor** | "Degree" that entity rotates towards camera.  |
| **Forward Direction** | Vector in local space that will point towards camera. |
| **Up Direction** | Direction in local space to align with world up. |
| **Rotation Axis** | World space axis to rotate around, if any. |
