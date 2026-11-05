---
uid: psl-vos-tooling
---
# PolySpatial Tooling

## Logging
PolySpatial logging messages are tagged by category and level to facilitate more targeted debugging. From **Project Settings > PolySpatial > Logging Categories**, you can toggle which categories are enabled and whether they should generate stack traces.

## Debug Links
To facilitate debugging in Play Mode, the PolySpatial runtime adds **DebugPolySpatialGameObjectLinks** components to connect each **simulation** GameObject to its corresponding **backing** GameObject(s) in the Unity SceneGraph. A **backing** GameObject will be created for each volume that the **simulation** GameObject is instanced into.

## Recording & Playback
<a name="recording-and-playback"></a>
Recording & Playback support ships in `com.unity.polyspatial.record`, and the Editor UI for recording and playing back sessions ships in `com.unity.polyspatial.playtest`. Add `com.unity.polyspatial.playtest` to your project to record a PolySpatial Play Mode session to a file and play it back; it brings in `com.unity.polyspatial.record` as a dependency.

For the window, recording options, playback, and recording compatibility, refer to [Recording and playing back a session](xref:ps-record-workflow) in the [PolySpatial Play Test](xref:ps-playtest-index) package documentation.
