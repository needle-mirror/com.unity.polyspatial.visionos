import UnityFramework
import SwiftUI
import PolySpatialRealityKit

@_silgen_name("SetPolySpatialNativeAPIImplementation")
private func SetPolySpatialNativeAPIImplementation(_ api: UnsafeRawPointer, _ size: Int32)

class UnityPolySpatialAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    var unity: UnityLibrary

    private(set) public var bootConfig: [String: String]

    var uuidToScene: [UUID: UIScene] = [:]

    // Scenes that are currently in the foreground. When the last scene enters the background we call UnityLibrary.didEnterBackground.
    var foregroundScenes = Set<UIScene>()

    // Scenes that are currently active. When the last scene resigns we call UnityLibrary.didResignActive.
    var activeScenes = Set<UIScene>()

    // If there are volume matches pending when the last scene resigns or enters the background we don't want to notify the app.
    // This means there's another scene coming in right behind it, so it's not truly the last scene.
    var skippedEnterBackground = false
    var skippedResignedActive = false

    override init() {
        // read bootconfig
        bootConfig = .init()
        let bootconfigPath = Bundle.main.path(forResource: "Data/boot", ofType: "config")!
        let content = try! String(contentsOfFile: bootconfigPath, encoding: .ascii)
        for line in content.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "=")
            if parts.count == 2 {
                bootConfig[parts[0]] = parts[1]
            }
        }

        unity = UnityLibrary.getInstance()!

        super.init()

        let api = PolySpatialRealityKitAccess.getApiData()
        let size = PolySpatialRealityKitAccess.getApiSize()
        SetPolySpatialNativeAPIImplementation(api, size)

        PolySpatialRealityKitAccess.register()
    }

    // Called by UnityTest.
    @objc
    func setQuitHandler(_ handler: @escaping () -> Void) {
        UnityFramework.getInstance().appController().quitHandler = handler
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        var arguments = CommandLine.arguments

        // unityStartInBatchMode will be defined in UnityVisionOSSettings.swift, which is generated during the Unity Player build process
        if unityStartInBatchMode {
            arguments.append("-batchmode")
        }

        unity.run(arguments: arguments)

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = connectingSceneSession.configuration
        let polySpatialSceneDelegate = PolySpatialRealityKit.PolySpatialSceneDelegate.self
        configuration.delegateClass = polySpatialSceneDelegate
        polySpatialSceneDelegate.sceneWillEnterForeground = sceneWillEnterForeground(scene:)
        polySpatialSceneDelegate.sceneDidEnterBackground = sceneDidEnterBackground(scene:)
        polySpatialSceneDelegate.sceneDidDisconnect = sceneDidDisconnect(scene:)
        polySpatialSceneDelegate.sceneDidBecomeActive = sceneDidBecomeActive(scene:)
        polySpatialSceneDelegate.sceneWillResignActive = sceneWillResignActive(scene:)
        return configuration
    }

    private func application(_ application: UIApplication, didDiscardSceneSession: UISceneSession) {
    }

    func sceneWillEnterForeground(scene: UIScene) {
        // Skip the call to willEnterForeground if we previously skipped didEnterBackground.
        if foregroundScenes.count == 0 && !skippedEnterBackground {
            UnityLibrary.instance?.willEnterForeground()
        }

        // Reset skippedEnterBackground flag now that we have a foreground scene again.
        skippedEnterBackground = false

        foregroundScenes.insert(scene)
    }

    func sceneDidEnterBackground(scene: UIScene) {
        // Guard against sceneDidDisconnect and sceneDidEnterBackground coming in out of order; don't call
        // onRemoveForegroundScene more than once for the same scene, or if the the scene was not tracked
        // in the first place.
        if foregroundScenes.remove(scene) != nil {
            onRemoveForegroundScene(scene)
        }
    }

    func sceneDidDisconnect(scene: UIScene) {
        // It's possible for a scene to disconnect without a call to sceneDidEnterBackground or sceneWillResignActive,
        // so we need to try removing it from our tracking sets and calling Unity callbacks just in case.
        if foregroundScenes.remove(scene) != nil {
            onRemoveForegroundScene(scene)
        }

        if activeScenes.remove(scene) != nil {
            onRemoveActiveScene(scene)
        }
    }

    func sceneDidBecomeActive(scene: UIScene) {
        // Skip the call to didBecomeActive if we previously skipped willResignActive.
        if activeScenes.count == 0 && !skippedResignedActive {
            UnityLibrary.instance?.didBecomeActive()
        }

        // Reset the skippedResignedActive flag now that we have an active scene again.
        skippedResignedActive = false

        activeScenes.insert(scene)
    }

    func sceneWillResignActive(scene: UIScene) {
        // Guard against sceneDidDisconnect and sceneWillResignActive coming in out of order; don't call
        // onRemoveActiveScene more than once for the same scene, or if the the scene was not tracked
        // in the first place.
        if activeScenes.remove(scene) != nil {
            onRemoveActiveScene(scene)
        }
    }

    func onRemoveForegroundScene(_ scene: UIScene) {
        // If there are pending volumes, do not send didEnterBackground--there will be a new foreground scene immediately after this
        if PolySpatialSceneDelegate.hasPendingVolumes() {
            skippedEnterBackground = true
            return
        }

        // If this is the last scene to enter the background, notify Unity as if the whole app has entered the background.
        if foregroundScenes.count == 0 {
            UnityLibrary.instance?.didEnterBackground()
        }
    }

    func onRemoveActiveScene(_ scene: UIScene) {
        // If there are pending volumes, do not send willResignActive--there will be a new active scene immediately after this
        if PolySpatialSceneDelegate.hasPendingVolumes() {
            skippedResignedActive = true
            return
        }

        // If this is the last scene to resign, notify Unity as if the whole app has resigned.
        if activeScenes.count == 0 {
            if let instance = UnityLibrary.instance {
                // If runInBackground is true, do not call willResignActive, which results in pausing Unity
                if !instance.shouldRunInBackground() {
                    instance.willResignActive()
                }
            }
        }
    }
}
