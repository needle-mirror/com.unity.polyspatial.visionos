---
uid: polyspatialxr-faq
---

# Frequently Asked Questions (FAQ)

## Q: I see different results running in the visionOS simulator than on Hardware
* Note that when running in Simulator, some hardware-specific features are not available - most notably AR data. This could mean that the simulated outcomes in the visionOS simulator may be different from the simulation on the Vision Pro headset. Check out Apple’s guide on running your app in the simulator to learn more. 
* Please note that Unity is still building towards feature parity with the Metal API on XCode, so you might observe warnings from Metal’s API validation layer. To work around this, you can turn off the Metal API Validation Layer via XCode’s scheme menu.

## Q: How can I bring an existing mobile project to the PolySpatial XR platform?
Please check the Project conversion guide on the [getting started page](GettingStarted.md#unity-project-conversion-guide-for-unity-polyspatial-xr) for information on enabling and using PolySpatial.

## Q: How can I bring an existing XR project to the PolySpatial XR platform?
You can check for a Project conversion guide on the [getting started page](GettingStarted.md#unity-project-conversion-guide-for-unity-polyspatial-xr)

## Q: I enter Play Mode and see no visual or execution difference in my project!
This may indicate you haven't yet turned on support for the PolySpatial Runtime. To do so, go to **Project Settings &gt; PolySpatial** and make sure that **Enable PolySpatial Runtime** is toggled.
 
## Q: The runtime is enabled, but nothing shows up!
* Ensure you have a Volume Camera in your scene.   An Unbounded Volume Camera with its origin positioned in the middle of your scene is a good starting point.
If one is not present a default one will be created that will include the bounds of every object in the scene, but this may cause objects in the scene within the bounds of the volume camera to be too small to see.
* Verify that the in-editor preview runtime is functioning.  Open the “DontDestroyOnLoad” scene in the hierarchy while playing, and check if there is a "PolySpatial Root” object present.  If there is not, ensure that the PolySpatial runtime is enabled.  If it is enabled and nothing shows up, please contact the Unity team.
* When using an Unbounded camera, the platform is responsible for choosing the (0,0,0) origin and may choose  position for it that is unexpected.  Look around (literally) to see if your content is somewhere other than here you think it should be. Rebooting the device can also help to reset its session space. It can be helpful to ensure that it is in a consistent location (for example, sitting on the desk, facing forward) every time you boot it up.

## Q: Skinned Meshes are not animating!
* On the **Animator** component, ensure **Culling Mode** is set to **Always Animate**. 
* If the model is imported, navigate to the **Import Settings** for the model. Under the **Rig** tab, ensure **Optimize Game Object** is unticked. Some models may not even have this setting; in that case, it should be good as-is.
* Certain models may contain a skeleton (a set of bones in a hierarchy) that are incompatible with RealityKit. To be compatible, a skeleton must have the following attributes:
	1. A group of bones must have a common ancestor GameObject in the transform hierarchy. 
	2. Each bone in the skeleton must be able to traverse up the transform hierarchy without passing any non-bone GameObjects. 
* In general, skeletons that have a non-bone GameObject somewhere in the skeleton (often used for scaling or offsets on bones) are not supported. 

## Q: I see an error on build about ScriptableSingleton
* This comes from the AR Foundation package and is benign. You can ignore this error.

## Q: I see a NULL ref or other issues in the log related to XXXX Tracker (Mesh Tracker, Sprite Tracker, etc)*
* Locate the Runtime flags option in the PolySpatial settings and select the tracker that is causing issues. This will disable changes from those types of objects in PolySpatial. Please flag the issue with the team so we can understand and fix the tracker type.

## Q: My TextMeshPro text shows up as Pink glyph blocks or My TextMeshPro text is blurry**
* Locate the shader graphs included in the visionOS Package (visionOS/Resources/Shaders) and right click -> Reimport. 

