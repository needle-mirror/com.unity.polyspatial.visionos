import Foundation
import SwiftUI
import RealityKit
import Combine

// A Scene Delegate receives events related to a particular UIScene, which
// is actually a window. Used to track the user dismissing a window.
//
// Users can create their own WindowGroups, and those will not have a
// pslWindowUUID attached to it. Ignore those.
public class PolySpatialSceneDelegate: NSObject, UISceneDelegate, ObservableObject
{
    // Expose delegates for scene lifecycle. These will be set by UnityPolySpatialAppDelegate when the application is configured
    public static var sceneWillEnterForeground: ((UIScene) -> Void)?
    public static var sceneDidEnterBackground: ((UIScene) -> Void)?
    public static var sceneDidDisconnect: ((UIScene) -> Void)?
    public static var sceneDidBecomeActive: ((UIScene) -> Void)?
    public static var sceneWillResignActive: ((UIScene) -> Void)?

    var pslWindowUUID: UUID?

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Future: create our own windows via UIKit -- however, currently, it's not
        // possible to set sizes or create immersive spaces this way. But if this was
        // possible, we'd be able to get rid of all the toplevel SwiftUI Scene/WindowGroup
        // stuff.
        //
        // guard let windowScene = (scene as? UIWindowScene) else { return }
        // window = UIWindow(windowScene: windowScene)
        // window!.rootViewController = UIHostingController(rootView: VolumeContent())
        // window!.makeKeyAndVisible()
        // self.windowScene = windowScene
    }

    // Sent when the scene is going into the foreground, before sceneDidBecomeActive.
    // Sent regardless of who (OS or user/self-initiated) creates the scene.
    // pslWindowID may be nil at this point during app startup.
    public func sceneWillEnterForeground(_ scene: UIScene) {
        pslVolumeLog.trace("Scene willEnterForeground: \(scene, privacy: .public), window uuid: \(self.pslWindowUUID?.description ?? "nil", privacy: .public)")
        PolySpatialWindowManager.shared.on(windowWillEnterForeground: pslWindowUUID)
        Self.sceneWillEnterForeground?(scene)
    }

    // Sent only if the OS puts the scene into the background.
    public func sceneDidEnterBackground(_ scene: UIScene) {
        pslVolumeLog.trace("Scene didEnterBackground: \(scene, privacy: .public)")
        PolySpatialWindowManager.shared.on(windowDidEnterBackground: pslWindowUUID)
        Self.sceneDidEnterBackground?(scene)
    }

    // Sent when the scene is destroyed, potentially after sceneDidEnterBackground.
    public func sceneDidDisconnect(_ scene: UIScene) {
        pslVolumeLog.trace("Scene disconnected: \(scene, privacy: .public)")
        PolySpatialWindowManager.shared.on(sceneDidDisconnect: pslWindowUUID)
        PolySpatialWindowManager.shared.on(windowDismissed: pslWindowUUID)
        Self.sceneDidDisconnect?(scene)
    }

    // Sent when the scene becomes active. Sent regardless of who creates the scene.
    // When the scene first becomes active, pslWindowUUID is nil, so we can't rely on this invoking the right event handler at start.
    public func sceneDidBecomeActive(_ scene: UIScene) {
        pslVolumeLog.trace("Scene became active: \(scene, privacy: .public)")
        PolySpatialWindowManager.shared.on(windowDidBecomeActive: pslWindowUUID)
        Self.sceneDidBecomeActive?(scene)
    }

    // Sent when the window is not focused.
    public func sceneWillResignActive(_ scene: UIScene) {
        pslVolumeLog.trace("Scene will resign active: \(scene, privacy: .public)")
        PolySpatialWindowManager.shared.on(windowWillResignActive: pslWindowUUID)
        Self.sceneWillResignActive?(scene)
    }

    // Used by UnityPolySpatialAppDelegate to determine whether or not to notify Unity about app lifecycle. Normally, when the last scene
    // enters the background or resigns, we trigger the equivalent app-level event (background or resign) in Unity. If there are pending
    // volumes waiting for a match, we should not trigger these events because that wasn't truly the last scene.
    public static func hasPendingVolumes() -> Bool {
        let windowManager = PolySpatialWindowManager.shared
        let orphanedVolumesAndWindows = windowManager.orphanVolumes.count + windowManager.allWindows.count

        // If the sum of orphaned volumes and windows is greater than the total sum of volumes, we are in the middle
        // of a transition, or otherwise in a situation where we should suppress pause messages
        return orphanedVolumesAndWindows > windowManager.allVolumes.count
    }
}
