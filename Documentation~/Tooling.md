---
uid: psl-vos-tooling
---
# PolySpatial Tooling

## Logging
PolySpatial logging messages are tagged by category and level to facilitate more targeted debugging. From the main menu of the Unity Editor, select **Window &gt; PolySpatial &gt; Logging** to open the PolySpatial Logging window. From here, you can toggle which categories are enabled, whether they should generate stack traces, and for categories for which stack traces are enabled, what levels will generate the traces. 

## PolySpatial Statistics
First, enable PolySpatial statistics tracking by enabling **Project Settings &gt; PolySpatial &gt; Enable Statistics**. The editor can then be found in Unity Editor main menu under **Window &gt; PolySpatial &gt; PolySpatial Statistics**. In Play Mode, this editor displays histogram tracking for timing, tracked objects, and assets that have been replicated to the PolySpatial host.

## Debug Links
To facilitate debugging in Play Mode, the PolySpatial runtime adds **DebugPolySpatialGameObjectLinks** components to connect each **simulation** GameObject to its corresponding **backing** GameObject in the Unity SceneGraph.

## Asset Finder
In Play Mode, the AssetFinder tracks all assets that have been replicated over to the host renderer. This can be useful for tracking down asset links. This editor can be found in the Unity Editor main menu under **PolySpatial &gt; Asset Finder**.

## Recording & Playback
<a name="recording-and-playback"></a>
To record a PolySpatial Play mode session, go to **Windows &gt; PolySpatial &gt; Recording and Playback**. Press `Record` to enter Play mode and start recording. Perform interactions and supply input normally, then exit play mode to stop recording. A new file will be added to the list; you can replay this recording by selecting it and then pressing the `Play` button. New input won't be processed, but the input encoded in the original recording will replay. 

Recordings are saved in `Library/PolySpatialRecordings` and should be playable on any machine using the same version of the PolySpatial package. Among other things, theses files can be submitted to Unity support allowing us to debug many project-specific issues without needing a full zip of your project.

