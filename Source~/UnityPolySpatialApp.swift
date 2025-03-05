import SwiftUI
import PolySpatialRealityKit
import RealityKit
import CompositorServices
typealias Scene = SwiftUI.Scene

@_silgen_name("UnityVisionOS_SetIsImmersiveSpaceReady")
private func UnityVisionOS_SetIsImmersiveSpaceReady(_ immersiveSpaceReady: Bool)

@_silgen_name("UnityVisionOS_SetLayerRenderer")
private func setLayerRenderer(_ layerRenderer: LayerRenderer?)

@main
struct UnityPolySpatialApp: App, PolySpatialWindowManagerDelegate {
    @UIApplicationDelegateAdaptor
    var delegate: UnityPolySpatialAppDelegate

    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.scenePhase) var scenePhase

    init() {
        PolySpatialWindowManagerAccess.delegate = self

        let _ = UnityLibrary.getInstance()
        let unityClass = NSClassFromString("UnityVisionOS") as? NSObject.Type
        var parameters = displayProviderParameters()
        let value = NSValue(bytes: &parameters, objCType: DisplayProviderParametersObjCType())
        unityClass?.perform(Selector(("setDisplayProviderParameters:")), with: value)
    }

    var body: some Scene {
        mainScene
            .onChange(of: scenePhase) { oldPhase, newPhase in
                PolySpatialWindowManagerAccess.onAppStateChange(oldPhase, newPhase)
            }
    }

    func requestOpenWindow(_ configuration: String) {
        let unityVisionOS = NSClassFromString("UnityVisionOS") as? NSObject.Type
        let useParameterizedProvider = configuration == "CompositorSpace" ? 0 : 1
        unityVisionOS?.perform(Selector(("setUseParameterizedDisplayProvider:")), with: useParameterizedProvider)
        if PolySpatialWindow.windowConfigurationIsImmersive(configuration) {
            Task {
                await openImmersiveSpace(id: configuration)
                // TODO: Handle failure case where user dismisses safety dialog without allowing the space to open
                // or clicks "Learn More," which will background the app and open Safari
            }
        } else {
            openWindow(id: configuration)
        }
    }

    func requestDismissWindow(_ window: PolySpatialWindow) {
        let configuration = window.windowConfiguration
        if PolySpatialWindow.windowConfigurationIsImmersive(configuration) {
            Task {
                await dismissImmersiveSpace()

                if configuration == "CompositorSpace" {
                    // Inform the Unity trampoline that we are turning off Metal rendering
                    let compositorBridge = NSClassFromString("UnityVisionOSCompositorBridge") as? NSObject.Type
                    compositorBridge?.perform(Selector(("setLayerRenderer:")), with: nil)

                    // Inform the XR plugin that we are turning off Metal rendering
                    setLayerRenderer(nil)

                    // Inform the window manager that we're closing the compositor space
                    PolySpatialWindowManagerAccess.onCompositorSpaceDismissed(window)

                    // Unpause Unity, which will have been paused when shutting down the compositor space
                    // We can't prevent this with the current architecture, because we need to keep rendering
                    // until the Metal space is dismissed, at which point Unity thinks the app is being backgrounded
                    // TODO: LXR-3764 Update trampoline to prevent pausing Unity in the first place
                    let unity = UnityLibrary.getInstance()
                    unity?.didBecomeActive()
                }
            }
        } else {
            dismissWindow(id: configuration, value: window.uuid)
        }
    }

    func onWindowAdded(_ window: PolySpatialWindow) {
        if PolySpatialWindow.windowConfigurationIsImmersive(window.windowConfiguration) {
            // Hook to let XR plugin know to set things up
            UnityVisionOS_SetIsImmersiveSpaceReady(true)
        }
    }

    func onWindowRemoved(_ window: PolySpatialWindow) {
        if PolySpatialWindow.windowConfigurationIsImmersive(window.windowConfiguration) {
            // Hook to let XR plugin know to the space is no longer ready
            UnityVisionOS_SetIsImmersiveSpaceReady(false)
        }
    }

    func reset() {
    }
}

// Wrapper around TextField in UnityFramework which is used to pop up the keyboard.
// This reference must be grabbed from UnityFramework and added into SwiftUI on
// Vision OS in order for it to register and pop up the keyboard.
struct KeyboardTextField: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextField {
        let textField = UnityLibrary.getInstance()!.keyboardTextField!
        textField.isHidden = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
    }
}
