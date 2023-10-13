import SwiftUI
import PolySpatialRealityKit
import RealityKit
typealias Scene = SwiftUI.Scene

#if !os(xrOS)

@main
struct UnityPolySpatialApp: App {
    @UIApplicationDelegateAdaptor
    var swiftUIdelegate: UnityPolySpatialAppDelegate

    @ObservedObject
    var polyspatialObserver = PolySpatialVolumeCoordinator()

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ForEach(0..<polyspatialObserver.volumes.count, id: \.self) { i in polyspatialObserver.volumes[i].view }
        }
    }
}

class PolySpatialVolumeCoordinator: ObservableObject, PolySpatialRealityKitDelegate {
    @Published var volumes: [PolySpatialVolume] = []

    init() {
        PolySpatialRealityKitAccess.addDelegate(self)
    }

    func on(volumeAdded: PolySpatialVolume) {
        self.volumes.append(volumeAdded)
    }

    func reset() {
    }
}

#else

@main
struct UnityPolySpatialApp: App, PolySpatialWindowManagerDelegate {
    @UIApplicationDelegateAdaptor
    var delegate: UnityPolySpatialAppDelegate

    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    init() {
        PolySpatialWindowManagerAccess.delegate = self
    }

    var body: some Scene {
        mainScene
    }

    func requestOpenWindow(_ config: String) {
        Task {
            if config == "Unbounded" {
                await openImmersiveSpace(id: config)
            } else {
                openWindow(id: config)
            }
        }
    }

    func requestDismissWindow(_ window: PolySpatialWindow, _ session: UISceneSession?) {
        // dismissWindow doesn't seem to function as expected; but the else
        // code below should be what we can do and avoid all the SceneSession goop
        #if true
        UIApplication.shared.requestSceneSessionDestruction(session!, options: nil)
        #else
        let config = window.windowConfiguration
        Task {
            if config == "Unbounded" {
                await dismissImmersiveSpace()
            } else {
                dismissWindow(value: window.uuid)
            }
        }
        #endif
    }

    func onWindowAdded(_ window: PolySpatialWindow) {
        if window.windowConfiguration == "Unbounded" {
            // Hook to let ARKit know to set things up
            let unityClass = NSClassFromString("UnityVisionOSNativeBridge") as? NSObject.Type
            let _ = unityClass?.perform(Selector(("setImmersiveSpaceReady")))
        }
    }

    func onWindowRemoved(_ window: PolySpatialWindow) {
    }

    func reset() {
    }
}

#endif
