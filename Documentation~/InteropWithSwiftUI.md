---
uid: psl-vos-interop-with-swiftui
---

# Using SwiftUI together with Unity

On visionOS, it is possible to use SwiftUI together with a Unity application. The [Samples](Samples.md) contain a `SwiftUI`
sample that demonstrates one approach.

For detailed information, please review the comments in the following files in the sample:

* `SwiftUIDriver.cs`
  * A MonoBehaviour that drives the interop with SwiftUI. It uses `DllImport` to access methods defined in Swift.
* `SwiftUISamplePlugin.swift`
  * Swift code that interfaces with `SwiftUIDriver` to provide the ability to pass information back and forth between C# and Swift.
* `SwiftUISampleInjectedScene.swift`
  * A Swift type that defines a SwiftUI `Scene` that is injected into the top-level App's Scenes. Swift files ending in `...InjectedScene.swift` are automatically injected, removing the need to modify the generated the top-level App.
* `HelloWorldContentView.swift`
  * A Swift `View` that is used by the `WindowGroup` defined in `SwiftUISampleInjectedScene`. This file is in a directory called `SwiftAppSupport`. All Swift files under a `SwiftAppSupport` directory will be made available in the top-level App (instead of `UnityFramework` in the Xcode project).

By using an approach similar to the sample, you can take advantage of SwiftUI for platform-native UI in separate windows while displaying 3D content from Unity in a volumetric window.

Mixing SwiftUI elements with Unity-managed content in a single volumetric window is not supported.
