---
uid: psl-vos-faq
---

# Frequently Asked Questions (FAQ)

## Q: I see different results running in the visionOS simulator than on Hardware
* Note that when running in Simulator, some hardware-specific features are not available - most notably AR data. This could mean that the simulated outcomes in the visionOS simulator may be different from the simulation on the Vision Pro headset. Check out Apple’s guide on running your app in the simulator to learn more.
* Please note that Unity is still building towards feature parity with the Metal API on XCode, so you might observe warnings from Metal’s API validation layer. To work around this, you can turn off the Metal API Validation Layer via XCode’s scheme menu.

## Q: How can I bring an existing mobile project to the visionOS Mixed Reality platform?
Please check the Project conversion guide on the [getting started page](GettingStarted.md#porting-existing-projects) for information on enabling and using PolySpatial.

## Q: How can I bring an existing XR project to the visionOS Mixed Reality platform?
You can check for a Project conversion guide on the [getting started page](GettingStarted.md#porting-existing-projects)

## Q: I enter Play Mode and see no visual or execution difference in my project!
Ensure that you have **visionOS** as your active build target, and that **RealityKit** or **Hybrid** is selected as the current **App Mode** in **Project Settings &gt; XR Plugin-in Management &gt; Apple visionOS**.

## Q: I'm targeting visionOS with a RealityKit app, but nothing shows up!
* Ensure you have a Volume Camera in your scene. An Unbounded Volume Camera with its origin positioned in the middle of your scene is a good starting point.
If one is not present a default one will be created that will include the bounds of every object in the scene, but this may cause objects in the scene within the bounds of the volume camera to be too small to see.
* Verify that the in-editor preview runtime is functioning. Open the “DontDestroyOnLoad” scene in the hierarchy while playing, and check if there is a "PolySpatial Root” object present. If there is not, please contact the Unity team.
* When using an Unbounded camera, the platform is responsible for choosing the (0,0,0) origin and may choose a position for it that is unexpected. Look around (literally) to see if your content is somewhere other than where you think it should be. Rebooting the device can also help to reset its session space. It can be helpful to ensure that it is in a consistent location (for example, sitting on the desk, facing forward) every time you boot it up.

## Q: Skinned Meshes are not animating!
* On the **Animator** component, ensure **Culling Mode** is set to **Always Animate**.
* If the model is imported, navigate to the **Import Settings** for the model. Under the **Rig** tab, ensure **Optimize Game Objects** is unticked. Some models may not even have this setting; in that case, it should be good as-is.
* Certain models may contain a skeleton (a set of bones in a hierarchy) that are incompatible with RealityKit. To be compatible, a skeleton must have the following attributes:
    1. A group of bones must have a common ancestor GameObject in the transform hierarchy.
    2. Each bone in the skeleton must be able to traverse up the transform hierarchy without passing any non-bone GameObjects.
* In general, skeletons that have a non-bone GameObject somewhere in the skeleton (often used for scaling or offsets on bones) are not supported.

## Q: I see an error on build about ScriptableSingleton
* This comes from the AR Foundation package and is benign. You can ignore this error.

## Q: I see a NullReferenceException or other issues in the log related to XXXX Tracker (Mesh Tracker, Sprite Tracker, etc)*
* Please file a bug with reproduction steps using the bug reporter found in the Help menu. If this error is blocking you and you don't need the particular feature, you can disable the feature in Player Settings > PolySpatial > Disabled Features.

## Q: My TextMeshPro text shows up as Pink glyph blocks or My TextMeshPro text is blurry**
* Locate the shader graphs included in the visionOS Package (visionOS/Resources/Shaders) and right click -> Reimport.

## Q: My content is too dark in visionOS simulator**
* In the visionOS simulator, try using Device -> Erase All Content and Settings and/or switching to a different environment (Museum (Day) versus Living Room (Day), for instance).

## Q: Objects that are supposed to face the camera (transform.LookAt) are not working
* Head pose tracking on visionOS is provided via ARKit, and is only available when your application has an open [ImmersiveSpace](https://developer.apple.com/documentation/swiftui/immersivespace). In Unity, this is enabled by having a `VolumeCamera` active in `Unbounded` mode. You also need an `ARSession` component in your scene to start the ARKit session and enable head pose tracking. When these requirements are met, you can use a `TrackedPoseDriver` to update any transform based on head pose, and use that object as a `lookAt` target.

## Q: Transparent objects, sprites, or canvas elements are flickering with inconsistent sorting
* Flickering can occur in transparent objects, sprites, and canvas elements, especially when intermixed with each other. You can prevent this by explicitly setting the sorting order using a [VisionOSSortingGroup](SortingGroup.md) component.

## Q: I have built an XCode Project, but there is no option to run on the simulator
- Check that `Build Profiles > visionOS > Platform Settings > Target SDK` is set to `Simulator SDK`
- You can only create VisionOS builds with the Unity editor for Apple Silicon. Check that the title bar in Unity does **not** contain "\<Rosetta>". If it does, use the Unity Hub to download the Apple Silicon version.
- Make sure you have the VisionOS Simulator installed. In XCode, open `Window > Devices and Simulators`, and select the `Simulators` tab. If there is nothing listed, add one using the + button.

## Q: My RealityKit app uses too much memory
By default, PolySpatial maintains extra copies of resources such as textures and meshes in case they are modified after transferring them to RealityKit. If you know that a texture or mesh will not be modified, you can use the [PolySpatialObjectUtils.MarkFinal](https://docs.unity3d.com/Packages/com.unity.polyspatial@latest?subfolder=/api/Unity.PolySpatial.PolySpatialObjectUtils.html#methods) methods to indicate that Unity can free its copy, reducing overall memory usage.

# Common Errors

## Error: `xcrun: error: unable to find utility "actool", not a developer tool or in PATH`
- Make sure you have the correct XCode version installed
- Open XCode, navigate to `Settings > Locations > Command Line Tools` and ensure the expected XCode version is selected. You may need to de-select and re-select the XCode version for the change to take effect.

## Error: `Failed to find a suitable device for the type ...`
- This sometimes happens after an XCode upgrade. Restarting your computer usually fixes it.

## Error: `ARM64 branch out of range (-140497472 max is +/-128MB)`
- If you see this error when building in Xcode, try enabling `Project Settings > XR Plug-in Management > Apple visionOS > IL2CPP Large Exe Workaround` and rebuilding the Xcode project from Unity.

# Play to Device Host
**I'm having trouble connecting to the Play to Device Host**

- Make sure both the host machine and the mobile device are connected to the same LAN. Make sure you have added a direct connection using **Advanced Settings** in the Play To Device Editor Window.
- Make sure your firewall is not blocking the connection. If it is, then you may have to temporarily disable it using the appropriate tool for your OS.

**I'm observing lag, or my editor seems to hang.**

In Unity Editor, try enabling `Run in Background` under `Project Settings > Player > Resolution and Presentation`. While this setting is not currently exposed under the visionOS platform, it is shared for all build targets. You can enable it under the Standalone build target tab.

**My app doesn't seem to receive any input  once connected to the host.**

If your app is not receiving input from the Play To Device host (especially when using the visionOS Simulator), you may need to change your input settings. The PolySpatial package contains a preset input asset in its Package Manager samples, but the important settings to check are:
- `Background Behavior`: Ignore Focus
- `Play Mode Input Behavior`: All Device Input Always Goes To Game View
