---
uid: psl-vos-billboard
---
# Billboard

The **VisionOSBillboard** component ensures an object always faces the user, even in modes where head position isn't directly available, such as shared mode. This is particularly useful for text, UI, and other oriented content.  In visionOS, this maps directly to the [BillboardComponent](https://developer.apple.com/documentation/realitykit/billboardcomponent), and is ignored on other platforms. In Unity play mode, we provide similar functionality which will show only the Game view targeting the main camera.

The **VisionOSBillboard** component is mainly useful for Bounded volume situations.  Apple doesn’t give us an API to know the users head position for Bounded volumes, which means its the only option to have content face the user in that situation.  Unfortunately this also means we don’t know how to account for the transform it applies when doing input ray casts like we do for UGUI components.  Specifically, this means if you put anything on a VisionOSBillboard that is a raycast target, then after a certain angle of rotation you will no longer be able to interact with any content placed on it.  You should not expect UI input like buttons and sliders to work if their transform is affected by a VisionOSBillboard.

If you are using an unbounded scene consider using [Lazy Follow](https://docs.unity3d.com/Packages/com.unity.xr.interaction.toolkit@3.0/manual/lazy-follow.html) instead.  It’s an existing component we support that should face the users head and still support UGUI interactions.

| **Property** | **Description** |
| --- | --- |
| **Blend Factor** | "Degree" that entity rotates towards camera.  |
