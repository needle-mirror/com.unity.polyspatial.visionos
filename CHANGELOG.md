---
uid: psvos-changelog
---
# Changelog
All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2023-10-26

### Added
- **Particle System Modes**: Developers can now select between particle system modes under `Project Settings > PolySpatial > Particle Mode`. The available modes offer tradeoffs between performance and quality:
  - **Bake to Mesh**: In this mode, a dynamic mesh is baked for every particle system every frame. It closely aligns the visuals with Unity rendering, allowing leverage of most features of Unity's built-in particle systems, including custom shaders authored with ShaderGraph. However, this mode currently imposes a significant performance overhead. We are actively working to improve performance for baked particles.

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
