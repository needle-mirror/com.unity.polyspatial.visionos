---
uid: psvos-changelog
---
# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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

### Version Support Matrix

|PolySpatial package versions|Unity Version|Xcode Version|Device seed version|
|----------------------------|-------------|-------------|-------------------|
|0.1.0|2022.3.5f1|15 beta 2|1|
|0.1.0   |2022.3.5f1   |15 beta 2   |1|
|0.1.2   |2022.3.5f1   |15 beta 2   |1|
|0.2.2   |2022.3.5f1   |15 beta 5   |2 21N5207g|
|0.3.2   |2022.3.9f1   |15 beta 8   |3 21N5233f|
|0.3.3   |2022.3.9f1   |15 beta 8   |3 21N5233f|
|0.4.1   |2022.3.9f1 and above   |15.1 beta   |4 21N5259k|
|0.4.3   |2022.3.9f1 and above   |15.1 beta   |4 21N5259k|
|0.5.0   |2022.3.11f1 and 2022.3.12f1   |15.1 beta   |4 21N5259k|
|0.6.x|2022.3.11f1 to 2022.3.13f1   |15.1 beta   |4+ 21N5259k|

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.6.0] - 2023-11-08

### Added
- Particle property transfer render mode now supports StretchedBillboard->LengthScale, and has more accurate emitter shape representation.  

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

## Fixed
-- Slowdown in visionOS player introduced in 0.4.2 fixed.

## [0.4.2] - 2023-10-12
- Existing windows will now be reused if they are the correct configuration on scene load.
- Added fixes for host-side cleanup needed for PlayToDevice

## [0.4.1] - 2023-10-06

### Added
- Documentation for Volume Camera around configuration assets.

## [0.4.0] - 2023-10-04

## Added
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
