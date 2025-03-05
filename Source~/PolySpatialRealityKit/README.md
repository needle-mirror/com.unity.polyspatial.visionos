#  PolySpatial RealityKit support

## Volume <> Window Mapping on visionOS

The visionOS build processor looks through all `VolumeConfiguration` scriptable objects in `Resources`, and generates `UnityVisionOSSettings.swift` which has a `WindowGroup` entry for every one (and an `ImmersiveSpace` if there's an Unbounded config).  They are named based on the volume diemensions -- TODO maybe, this could just be a GUID, but we don't pass along the concept of configurations down the protocol. (Note: `WindowGroup` is just a template for a single window. Multiple of the same win)

On the visionOS/Swift side, there is a `PolySpatialWindowManager` whose job it is to connect Windows with Volumes.  The way this works is:

- Whenever a Window is created (via automatic creation of the first Scene element, or `openWindow` -- provided to the `WindowManager` via delegate)
  - A `uuid` is assigned to that window. There's a `PolySpatialWindow' struct that has the `uuid`, the dimensions, etc. that is carried down the view hierarchy as an `Environment` parameter.
  - A `UIKit` `UISceneDelegate` (via the `UIApplicationDelegate`) is attached to each created window. A new `UISceneDelegate` is created for each `UIScene/UISceneSession` (`PolySpatialRealityKit.PolySpatialSceneDelegate` -- lives in the private library, but referenced from the App shell).  A `UISceneSession` corressponds to _one_ window/volume (not a set of them). This delegate registers the `uuid`-to-`UIScene` mapping with the `PolySpatialWindowManager`.
  - When the RealityView view is created (inside `XROSPolySpatialContentView`), there's' a closure that's supposed to set up the content of the scene -- that closure creates a root `Entity`, and notifies the `PolySpatialWindowManager` that there's a `PolySpatialWindow` (which has the uuid) and a new `Entity` to use as the root for that window.
  - The `PolySpatialWindowManager` adds the window to a set of free windows.
  - The volume/window matching process runs (see below)

- A `PolySpatialVolume` is created or updated because we receive a `SetVolumeCameraData` message
  - A configuration name is constructed by taking the mode/dimensions and converting it to either `"Unbounded"` or `"Bounded-X.xxxxY.yyyxZ.zzz"` format, which gets assigned as the `desiredWindowConfiguration` for that volume. This name matches the names that's generated in `UnityVisionOSSettings.swift`.
  - The PSL delegates are notified that a volume was added
  - `PolySpatialWindowManager` is one of those delegate receivers, and when a volume has been added, it adds it to a set of orphan volumes.
  - The volume-and-window matching process runs (see below)
  - If a volume camera configuration is changed for an existing volume camera, we treat that as a "Remove" followed by an "Add" on the RealityKit side. See below for what happens when a volume is removed.

- When a `PolySpatialVolume` is destroyed because we receive a `SetVolumeCameraData` message for it with `null` data:
  - The `PolySpatialWindowManager` receives notice of the volume removal via the volume delegate
  - If the volume was assigned a window, it tells the volume it should detach itself by calling `volume.update(window: nil)`
  - The volume is removed from all window manager tracking
  - The volume/window matching process runs (see below). This is what will ultimately destroy the window if it can't be reused.'

- When a Window is destroyed:
  - We find out about this from the system via the `PolySpatialSceneDelegate.sceneDidDisconnect()` callback.  That callback tells the `PolySpatialWindowManager` that a window with a given `uuid` was destroyed (`PolySpatialWindowManager.on(windowDismissed:)`)
  - The window manager sees it that window has a volume assigned to it. If it does, it tells the volume that its window was closed via `volume.update(window: nil)`.
    - Note that it _doesn't_ put the volume back into the orphan list. TODO: we need to actually do something here -- we don't have any process for what happens when a user closees a volume. We should really feed this back to Unity for user code to handle somehow. I don't think there's any way that content can prevent a volume from being closed.
  - It removes the window from all tracking.
  - Doesn't run the volume/window matching process.

- The volume/window matching process (`PolySpatialWindowManager.matchVolumesAndWindows`) runs whenever a new window or volume is added.
  - It goes through all the orphan volumes and free windows, looking for a free window that matches the configuration name needed by a volume. When it finds a match:
    - Removes the volume/window from the free/orphan list
    - It tells the volume that it got a `PolySpatialWindow` via `volume.update(window:)`
    - The volume then records the window uuid that it got assigned (`assignedwindowUUID`), updates its transform taking into account the host dimensions that it now knows (from the window data), and adds its root entity to the root entity of the window
  - If there are still orphan volumes, a request is made to open a window of each needed configuration
    - This only happens if we were notified that the first window was created. Otherwise, at app startup, we could have a volume get constructed before the window that the system is automatically creating at launch time, and we don't want to request an additional window. If that initial launch window doesn't match what the initial volume actually wants, it'll get handled as normal when matching runs as a result of the window or volume creation (by requesting a window of correct configuration, and destroying the wrong one).
  - If there are still free windows (that no volumes are waiting on), they are destroyed by requesting their destruction via the `WindowManager` delegate.


## App Backgrounding and Delegates

There is a good amount of complexity and nuance when it comes to backgrounding the app on VisionPro device, especially around which delegates actually get fired. The below attempts to encapsulate at least some of that, to make it easier to figure out which delegates are actually being fired when the app is backgrounded.

There are a few ways to background the app:
1. Take the headset off.
2. Press the digital crown button once at a time, until the Home View screen appears. Bring back content by clicking on app in Home View.
3. Press the digital crown button twice rapidly. Home View will not appear, but your content will disappear. If you press the Digital Crown twice rapidly again, content will reappear.

With the 2nd method, if there are multiple volumes in the scene, the first tap of the digital crown will background the immersive space (unbounded/metal), and then a subsequent tap will bring up the Home View while unfocusing the bounded volumes. The 3rd method will make all content disappear until you tap the digital crown twice again to bring it back.

Most of the PolySpatial delegates are listed in PolySpatialSceneDelegate.swift. Which delegate gets fired will depend on the method of backgrounding, and on whether there are multiple volumes. In general, if there is only one volume, the OS should bring it back after the app exits background state. If there are multiple volumes, including one immersive space, the OS will not bring that immersive space back, so we need to manually call it back (see function `on(scenePhase)`).

When the headset is taken off and put back on:
- Multiple volumes, including one immersive space
    - sceneWillResignActive -> sceneDidEnterBackground -> sceneWillEnterForeground -> sceneDidBecomeActive
- One immersive space
    - same as with multiple volumes.

When the digital crown is pressed one at a time until the Home View screen appears:
- Multiple volumes, including one immersive space
    - sceneWillResignActive -> sceneDidEnterBackground -> sceneDidDisconnect -> sceneDidBecomeActive
- One immersive space
    - sceneWillResignActive -> sceneDidEnterBackground -> sceneDidDisconnect, sceneWillEnterForeground -> sceneDidBecomeActive
Note that these delegates were recorded before the call to manually reopen the immersive space on app re-open was added. When there is a single immersive space in the app, the OS reopens it, causing sceneWillEnterForeground to be called. When there are multiple volumes, the OS assumes the bounded volumes are it, and doesn't reopen the immersive space.

The sceneDidDisconnect delegate is called when a window is closed for whatever reason. Window dismissal could be a result of the user directly requesting a window closure (through DestroyVolumeCamera) or it could be through the OS. There's no way, so far as I can see, to differentiate between a user-requested dismissal vs an OS dismissal.

When the digital crown is pressed twice rapidly:
- Multiple volumes, including one immersive space
    - sceneWillResignActive -> sceneDidBecomeActive
- One immersive space
    - same as with multiple volumes.
The OS seems to be simply fading the content from view - the background delegate (sceneDidEnterBackground) is not called, and neither is the window dismissal delegate (sceneDidDisconnect). If the user double clicks the digital crown again, the content will be restored as if nothing happened.

### Scene Phase
There is one additional delegate that is not linked to window lifespan. .onChange(of: scenePhase) is linked to scene lifecycle instead, and thus, when it gets invoked is different.

When the scene first appears, scenePhase will invoke once, and change from inactive->active.

When the headset is taken off and put back on:
- Multiple volumes, including one immersive space
    - active->inactive, followed by inactive->background
    - background->inactive, followed by inactive->active
- One immersive space
    - same as with multiple volumes.
- One bounded volume
    - same as with multiple volumes.

When the digital crown is pressed one at a time until the Home View screen appears:
- Multiple volumes, including one immersive space
    - active->inactive
    - inactive->active
- One immersive space
    - active->inactive, followed by inactive->background
    - background->inactive, followed by inactive->active
- One bounded volume
    - active->inactive
    - inactive->active

When the digital crown is pressed twice rapidly:
- Multiple volumes, including one immersive space
    - active->inactive
    - inactive->active
- One immersive space
    - same as with multiple volumes.
- One bounded volume
    - same as with multiple volumes.

