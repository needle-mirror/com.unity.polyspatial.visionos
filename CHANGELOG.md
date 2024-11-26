---
uid: psvos-changelog
---
# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

For general changes to PolySpatial, refer to the [PolySpatial Changelog](https://docs.unity3d.com/Packages/com.unity.polyspatial@latest?subfolder=/changelog/CHANGELOG.html).

## [2.1.2] - 2024-11-26

### Added

### Changed
- Restored `PolySpatialWindowManagerAccess.entityForIdentifier`/`identifierForEntity` that was removed when adding multi-volume support and added `entitiesForUnityInstanceId` to return Entities from all volumes.
- Improved performance of blend shapes by enabling asynchronous processing.
- Entities merged via static batching now include the source entities' synchronized components (sort groups, image based light receivers, environment lighting configurations, grounding shadows, and hover effects).
- Updated Metal Samples presentation image and added known limitations section to the Play to Device Section.

### Deprecated

### Removed

### Fixed
- Fixed edge cases with blend shape support: support meshes with no vertices and meshes with no bone weights.
- Fixed issue where raycastable UGUI components would not be removed from scene when hidden (when scrolling, e.g.)
- Fixed a bug with tracked images over play to device.

### Security

## [2.0.4] - 2024-09-25

### Added
- PlayToDevice will now limit the editor framerate to 45 by default in order to lower network congestion. The editor sending too many packets over PlayToDevice could cause significant lag and latency for some users. This limit can be changed in the PlayToDevice window.
- Fix issue of two scenes simultaneously existing for a frame when new scene is loaded.

### Changed
- XRTouchSpaceInteractor renamed to XRSpatialPointerInteractor.
- Update minimum Editor version to 6000.0.22f1.

### Deprecated

### Removed

### Fixed
- Bones are now parented to the parent of the RootBone instead of to the SkinnedMeshRenderer entity. This fixes an issue where if the SkinnedMeshRenderer was on a different hierarchy than the RootBone, the bones might not be affected by any transforms applied to the RootBone.
- Child colliders of XRBaseInteractables are now recognized when using XRTouchSpaceInteractor/XRSpatialPointerInteractor.

### Security

## [2.0.0-pre.11] - 2024-08-12

### Added

### Changed
- Duplicate VolumeCameraWindowConfigurations are not allowed - in each project, there can only be one of each of Metal and Unbounded configurations. There can be multiple Bounded configurations, but each Bounded configuration must have a different OutputDimension.
- We have narrowed down the conditions under which the package will compile from UNITY_VISIONOS || UNITY_IOS || UNITY_EDITOR_OSX to (UNITY_VISIONOS || UNITY_IOS) && UNITY_EDITOR_OSX.  This should eliminate compile errors in the case where you had the OSX editor but not the visionOS or iOS platform dependencies.

### Deprecated

### Removed

### Fixed
- Wrap all MonoPInvokeCallback methods in try/catch to avoid potential crashes in player builds.

### Security

## [2.0.0-pre.9] - 2024-07-24

### Added
- Added `Hybrid` app mode. This allows an application to switch between Metal and RealityKit mode at runtime. Hybrid mode requires PolySpatial. Refer to the **PolySpatial Hybrid apps on visionOS** section of the PolySpatial VisionOS documentation for more information.
- Added the ability to create multiple volume cameras. Refer to the **Volume cameras** section of the PolySpatial VisionOS documentation for more information.

### Changed
- Updated instructions for setting up 2.x prerelease packages. This currently requires manually pointing your project's manifest.json at the appropriate package versions.
- Several VisionOS prefixed components (such as VisionOSVideoComponent and VisionOSImageBasedLight) have had DisallowMultipleComponent applied to them, and cannot be added multiple times to the same GameObject.


## [2.0.0-pre.3] - 2024-04-22

### Added
- Added a loading screen during initial Play To Device loading
- Added support for procedural skinned meshes. Updating a skinned mesh will now notify all skinned mesh renderers using that mesh to update.
- Added support for adding new reference images at runtime, refer to [ARFoundation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@6.0/manual/features/image-tracking.html#add-new-reference-images-at-runtime) documentation.
- Added tracked image support to the "PolySpatial XR" Plug-in Provider, under XR Plug-in Managment.

### Changed

### Deprecated

### Removed

### Fixed
- Fix compilation issues when targeting tvOS.

### Security

## [1.1.4] - 2024-02-26

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [1.1.3] - 2024-02-22

### Added

### Changed
- Update min Unity version to 2022.3.19f1

### Deprecated

### Removed

### Fixed

### Security

## [1.1.2] - 2024-02-21

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [1.1.1] - 2024-02-15

### Added
- Added installation instructions to the documentation.
- Added VolumeCamera OnWindowEvent event handler. This is invoked whenever a volume camera's window has state changes, such as opening or becoming unfocused.
- Added a "PolySpatial XR" Plug-in Provider to XR Plug-in Managment in Project Settings.  Allows you to view ARPlane's and hands from device in editor while using Play To Device.

### Changed
- Improved documentation about samples.

### Deprecated
- Volume camera events other than OnWindowEvent are now obsolete and will be removed in later releases. OnWindowEvent will supply all the information the other OnWindow events would normally supply.

### Removed

### Fixed
- Updated ReplicateProperty Particle mode to better reflect opacity when using startColor or colorOverLifetime particle modules. Setting opacity to 0 at the start of a gradient or/and at the end will cause different opacityCurves to be applied to the RealityKit particle system.
- Updated ReplicateProperty Particle mode to better reflect startSize and sizeOverLifetime module.
- Corrected a few documentation errors.
- Fixed a crash that could occur if a game object that was being used as a bone in a skinned mesh renderer was deleted during runtime.
- Fixed VolumeCamera's OnWindowFocused and OnWindowResized event handlers not invoking.

### Security

## [1.0.3] - 2024-01-20

### Added

### Changed
- Updated documentation to address package version and Unity Editor version requirements.
- In the editor, PolySpatial preview and builds will only be enabled on platforms where it is supported (currently, visionOS MR).

### Deprecated

### Removed

### Fixed
- PolySpatial will only be enabled for the visionOS Mixed Reality build configuration.
- Fixed issue with not restarting ARSession when switching scenes.
- Fixed issue with incorrect transforms on volumes when Display -> Appearance -> Window Zoom setting was changed.
- Fixed issue with incorrect transforms on volumes when using a bounded Default Volume Camera Window Configuration.
- Fixed issue when certain skinned meshes would not show up when connecting to PlayToDevice.
- Fixed issues with building for visionOS MR on non-macOS editor platforms.

### Security

## [0.7.1] - 2023-12-13

### Added

### Changed
- All packages now require 2022.3.15f1 and later (rather than 2022.3.11f1 and later) to pick up fixes for various memory leaks made in 15f1.

### Deprecated

### Removed
- Removed Statistics docs and Asset finder docs since the tooling is not available anymore
- Support for Unity versions earlier than 2022.3.11f1.

### Fixed
- Fixed interaction ray direction on pointer events.
- Updated a note in the documentation about choosing Target SDK in Player Settings. Previously, the note explained that choosing the SDK was _not_ required, but now it is.

### Security

## [0.6.3] - 2023-11-28

### Added
- Added link from the Index page to the Requirements page for easier access to the required Unity versions for Polyspatial.
- Added instructions for upgrading/downgrading Play to Device Host app on TestFlight.

### Changed
- Moved the PolySpatial Unity Version Support matrix from the Changelog to the Requirements page in the docs.
- Play to device page no longer has a compatibility version matrix for each PolySpatial release but points to a google drive folder on where one can find the different Play To Device Host versions.

### Deprecated

### Removed

### Fixed
- Moving volume cameras will no longer recreate the window on every frame.
- Fixed crash due when Raycast Target is enabled on UGUI elements.
- Corrected docs for PolySpatial version in the Play To Device docs to 0.6.2 version (instead of 0.6.0).

### Security

## [0.6.2] - 2023-11-13

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.6.1] - 2023-11-09

Our latest release introduces a new feature called "Play To Device." Please read this [Discussion post](https://discussions.unity.com/t/play-to-device/309359) to learn more and visit the [documentation](https://docs.unity3d.com/Packages/com.unity.polyspatial.visionos@0.5/manual/PlayToDevice.html) page.

For those who are testing on devices at Apple's developer labs or via a developer kit, you should only be using the following **updated configuration**.
* Apple Silicon Mac for development
* Unity 2022 LTS (2022.3.11f1) and higher
* Xcode 15.1 beta 1
    * The Xcode 15 Release Candidate will _not_ work
* visionOS beta 4 (21N5259k) - SDK

To learn more about Unity's visionOS beta program, please refer to [this post](https://discussions.unity.com/t/welcome-to-unitys-visionos-beta-program/270282).

### Related Changelogs

- [com.unity.polyspatial](https://docs.unity3d.com/Packages/com.unity.polyspatial.visionos@0.6/changelog/CHANGELOG.html)
- [com.unity.polyspatial.xr](https://docs.unity3d.com/Packages/com.unity.polyspatial.xr@0.6/changelog/CHANGELOG.html)
- [com.unity.xr.visionos](https://docs.unity3d.com/Packages/com.unity.xr.visionos@0.6/changelog/CHANGELOG.html)


### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.6.0] - 2023-11-08

### Added
- Particle property transfer render mode now supports StretchedBillboard->LengthScale, and has more accurate emitter shape representation.
- Added `PolySpatialWindowManagerAccess.entityForIdentifier` in Swift and `PolySpatialObjectUtils.GetPolySpatialIdentifier` to C#, to allow accessing the RealityKit Entity corresponding to a Unity GameObject from Swift code. No guarantees are made about whether there is a RealityKit Entity for any given GameObject, or about the lifetime of the Entity.

### Changed

### Deprecated

### Removed

### Fixed

- Device Position input values are now converted to RealityKit coordinates (meters, instead of points)

### Security

## [0.5.0] - 2023-10-26

### Added
- **Particle System Modes**: Developers can now select between particle system modes under `Project Settings > PolySpatial > Particle Mode`. The available modes offer tradeoffs between performance and quality:
  - **Bake to Mesh**: In this mode, a dynamic mesh is baked for every particle system every frame. It closely aligns the visuals with Unity rendering, allowing leverage of most features of Unity's built-in particle systems, including custom shaders authored with ShaderGraph. However, this mode currently imposes a significant performance overhead. We are actively working to improve performance for baked particles.
- Added support for platform base text rendering through the new UnityPolySpatialPlatformText component.

### Changed

### Deprecated

### Removed

### Fixed
- Fixed an issue where projects with `com.unity.polyspatial.visionos` would fail to build when App Mode is set to Virtual Reality. Device builds were failing with the error `Undefined symbol: _GetPolySpatialNativeAPI`, and simulator builds failed to run with a similar error.

### Security

## [0.4.3] - 2023-10-13

### Fixed
-- Slowdown in visionOS player introduced in 0.4.2 fixed.

## [0.4.2] - 2023-10-12
- Existing windows will now be reused if they are the correct configuration on scene load.
- Added fixes for host-side cleanup needed for PlayToDevice

## [0.4.1] - 2023-10-06

### Added
- Documentation for Volume Camera around configuration assets.

## [0.4.0] - 2023-10-04

### Added
- Documentation for Volume Camera around configuration assets.
- Build error if trying to build for Simulator SDK in Unity prior to 2022.3.11f1.

## [0.4.0] - 2023-10-04

### Added
- PolySpatial now supports Xcode 15.1 beta 1 and visionOS 1.0 beta 4

## [0.3.2] - 2023-09-18

## [0.3.1] - 2023-09-15

## [0.3.0] - 2023-09-13

## [0.2.2] - 2023-08-28

## [0.2.1] - 2023-08-25

## [0.2.0] - 2023-08-21

## [0.1.2] - 2023-08-16

## [0.1.2] - 2023-08-16

## [0.1.0] - 2023-07-19

## [0.0.4] - 2023-07-18

## [0.0.3] - 2023-07-18

## [0.0.2] - 2023-07-17

## [0.0.1] - 2023-07-14

### Added
- Initial PolySpatial visionOS package.
