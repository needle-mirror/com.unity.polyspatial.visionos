# PolySpatial Video Component
In order to support video content on visionOS, PolySpatial currently includes a custom `PolySpatialVideoComponent`. We expect to eventually support the stock video component, but this component provides key video functionality for visionOS in the interim. To use it, set the `Target Material Renderer` to the `GameObject` on whose `MeshRenderer` you want to display the video, and set `Clip` to point at the video asset you want to play, such as an `.mp4`

A limitation of the current system is that the clip must be manually copied into a `../StreamingAssets/PolySpatialVideoClips/` folder for full functionality on visionOS. Create this folder if it does not exist. Ensure that the clip is not just moved into this folder, but copied into it, so that there are two instances of it.

The `PolySpatialVideoComponent` component exposes the following properties:

| **Property** | **Description** |
| --- | --- |
| **TargetMaterialRenderer** | Reference to the MeshRenderer on which the video should render. The video will overwrite the current material on that MeshRenderer. |
| **Clip** | The video asset to be played. |
| **IsLooping** | Whether the video should repeat when playback reaches the end of the clip. |
| **PlayOnAwake** | Whether the video should start playing when `Awake()` is called.|
| **Mute** | When true, audio playback is suppressed; when false, the volume value is respected. |
| **Volume** | The current volume of audio playback for the clip, ranging between 0 and 1. |
