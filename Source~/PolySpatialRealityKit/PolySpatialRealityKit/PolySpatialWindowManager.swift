import Foundation
import RealityKit
import SwiftUI
import Combine

// A protocol to be implemented by the toplevel Swift app, which can
// call openWindow/dismissWindow. It is passed via PolySpatialWindowManagerAccess
// to PolySpatialWindowManager.
public protocol PolySpatialWindowManagerDelegate {
    func getAllAvailableWindows() -> [String]

    func getAvailableWindowsForMatch() -> [simd_float3]

    // Ask the delegate to open a window with the given config
    func requestOpenWindow(_ config: String)

    // Ask the delegate to dismiss the given window
    func requestDismissWindow(_ window: PolySpatialWindow)

    // Notify the delegate that the window manager has been informed that this window
    // has been added, and it is ready to be used.
    func onWindowAdded(_ window: PolySpatialWindow)

    // Notify the delegate that the window manager has been informed that the window
    // has been removed (either via code or dismissed by the user).
    func onWindowRemoved(_ window: PolySpatialWindow)
}

@MainActor
public class PolySpatialWindowManagerAccess {
    public static var delegate: PolySpatialWindowManagerDelegate? = nil

    public static func entitiesForUnityInstanceId(id: Int32) -> [Entity] {
        PolySpatialRealityKit.instance.getEntities(unityInstanceId: id)
    }

    public static func entityForIdentifier(id: PackedIdentifier) -> Entity? {
        PolySpatialRealityKit.instance.TryGetEntity(.init(packed: id))
    }

    public static func identifierForEntity(entity: Entity) -> PackedIdentifier? {
        return (entity as? PolySpatialEntity)?.unityId.packed
    }

    // The ImmersiveSpace for Metal is defined outside of PolySpatialRealityKit, so it needs public APIs to inform
    // PolySpatialWindowManager when the ImmersiveSpace is opened
    public static func onCompositorSpaceOpened(_ window: PolySpatialWindow) {
        PolySpatialWindowManager.shared.on(windowAdded: window)
    }

    // The ImmersiveSpace for Metal is defined outside of PolySpatialRealityKit, so it needs public APIs to inform
    // PolySpatialWindowManager when the ImmersiveSpace is dismissed
    public static func onCompositorSpaceDismissed(_ window: PolySpatialWindow) {
        PolySpatialWindowManager.shared.on(windowDismissed: window.uuid)

        // Because opening the compositor space is async, we need to queue another update to continue matching
        // windows and volumes after the space is open
        PolySpatialWindowManager.shared.needsUpdate = true
    }

    public static func onImmersionChange(_ oldAmount: Double?, _ newAmount: Double?) {
        PolySpatialRealityKit.instance.notifyHostImmersionChange(oldAmount, newAmount)
    }
    
    public static func onAppStateChange(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        PolySpatialWindowManager.shared.on(scenePhase: newPhase)
    }
}

// PolySpatialWindowManager is responsible for matching volumes and
// windows, and creating new windows (or an immersive space) if no
// appropriate window is available for a volume that needs one.
//
// See the README.md in PolySpatialRealityKit for more information.
@MainActor
class PolySpatialWindowManager: ObservableObject, PolySpatialRealityKitDelegate {
    static var shared = PolySpatialWindowManager()

    //We get console errors about using these methods in this context, but they work...
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow

    // on visionOS, the first window is opened by the OS, so we need to wait for it
    var seenFirstWindow = false

    var allWindows: [UUID:PolySpatialWindow] = [:]
    var allSceneDelegates: [UUID:PolySpatialSceneDelegate] = [:]
    var allVolumes: Set<PolySpatialVolume> = .init()
    var freeWindows: Set<PolySpatialWindow> = .init()
    var orphanVolumes: Set<PolySpatialVolume> = .init()
    var backgroundWindows: Set<PolySpatialWindow> = .init()
    var closingWindows: Set<UUID> = .init()
    var volumesAwaitingWindow: Set<PolySpatialVolume> = .init()

    var cachedFittedDim: Dictionary<String, simd_float3> = .init()
    var allAvailableConfigurationsForMatch: [(dimension: simd_float3, volume: Float)] = .init()
    var smallestVolumeForMatch: (dimension: simd_float3, volume: Float) = (.one, 1)
    var largestVolumeForMatch: (dimension: simd_float3, volume: Float) = (.one, 1)
    
    // Each app can only have one immersive space. When the app is brought back after the scene has been backgrounded, we may need to manually call it back depending on its previous state.
    // This is modified only when the user requests an immersive space opened or closed. 
    var immersiveSpaceConfig: String = ""
    var immersiveSpaceWasClosed = false

    var needsUpdate = false

    private init() {
        PolySpatialRealityKit.instance.delegates.append(self)

        let configs = PolySpatialWindowManagerAccess.delegate?.getAvailableWindowsForMatch()

        // Cache largest and smallest volume - if a user requests a volume that's too small or too big, we can shortcut and reroute to these.
        var largestVolume: Float = 0
        var smallestVolume: Float = Float.greatestFiniteMagnitude
        for config in configs! {
            let size = config.x * config.y * config.z
            if (size < smallestVolume) {
                smallestVolumeForMatch = (config, size)
                smallestVolume = size
            }
            if (size > largestVolume) {
                largestVolumeForMatch = (config, size)
                largestVolume = size
            }
            allAvailableConfigurationsForMatch.append((config, size))
        }
    }
    
    func userRequestedAnImmersiveSpace() -> Bool {
        return immersiveSpaceConfig != ""
    }

    func notifyVolumeForWindow(_ uuid: UUID, windowEvent: WindowEvent, isFocused: Bool) {
        if let vol = allVolumes.first(where: { $0.assignedWindowUUID == uuid }) {
            PolySpatialRealityKit.instance.notifyHostWindowState(vol, windowEvent: windowEvent, focused: isFocused)
        }
    }

    func openWindowFor(volume: PolySpatialVolume) {
        assert(volume.assignedWindowUUID == nil, "Expected volume to not have a window open in openWindowFor")

        // If a window has already been requested for this volume, then don't set needsUpdate again to avoid requesting a 2nd unnecessary window that will just be closed
        if orphanVolumes.insert(volume).inserted {
            pslVolumeLog.trace("Requested open window for: id \(volume.id, privacy: .public) (desired: \(volume.desiredWindowConfiguration, privacy: .public))")
            needsUpdate = true
        }
    }

    func closeWindowFor(volume: PolySpatialVolume) {
        pslVolumeLog.trace("Requested close window for: id \(volume.id, privacy: .public) (desired: \(volume.desiredWindowConfiguration, privacy: .public))")
        guard let winuuid = volume.assignedWindowUUID else {
            assert(volume.assignedWindowUUID != nil, "Expected volume to have a window open in closeWindowFor")
            return
        }

        guard let win = allWindows[winuuid] else {
            pslVolumeLog.warning("Expected that the window to be closed is tracked in closeWindowFor")
            return
        }

        // tell the volume to detach itself from a window
        volume.update(window: nil, event: .closed)

        // that window is now free -- we'll reuse or close it in matchVolumesAndWindows()
        freeWindows.insert(win)

        allVolumes.remove(volume)
        orphanVolumes.remove(volume)
    }
    
    // Triggered when app-wide state change occurs. State change, in this case, refers to either the app becoming active or becoming inactive (is backgrounded)
    func on(scenePhase sceneState: ScenePhase)
    {
        if (sceneState == .active) {
            // When the app is being brought back from background state and this isn't the first time,
            // then manually open the immersive space if it was previously closed by the OS and the user still wants it around.
            // Additionally, check if multiple volumes exist - if the immersive space is the only volume that was requested by the user, the OS will automatically bring it back, which means the command below is redundant.
            let multipleVolumesPresent = allVolumes.count > 1
            if (userRequestedAnImmersiveSpace() &&
                immersiveSpaceWasClosed &&
                multipleVolumesPresent) {
                pslVolumeLog.trace("Reopening immersive space after it was closed by OS.")
                PolySpatialWindowManagerAccess.delegate?.requestOpenWindow(immersiveSpaceConfig)
            }
            
            immersiveSpaceWasClosed = false
        }
    }

    func on(volumeAdded volume: PolySpatialVolume) {
        pslVolumeLog.trace("Volume added: id \(volume.id, privacy: .public) (desired: \(volume.desiredWindowConfiguration, privacy: .public))")
        
        if (PolySpatialWindow.windowConfigurationIsImmersive(volume.desiredWindowConfiguration)) {
            PolySpatialWindowManager.shared.immersiveSpaceConfig = volume.desiredWindowConfiguration
        }

        allVolumes.insert(volume)
    }

    func on(volumeRemoved volume: PolySpatialVolume) {
        pslVolumeLog.trace("Volume removed: id \(volume.id, privacy: .public) (assigned to window uuid: \(volume.assignedWindowUUID?.description ?? "(none)", privacy: .public))")
        if volume.assignedWindowUUID != nil {
            closeWindowFor(volume: volume)
        } else {
            pslVolumeLog.error("Volume is missing assigned window UUID")
        }
        
        if (PolySpatialWindow.windowConfigurationIsImmersive(volume.desiredWindowConfiguration)) {
            PolySpatialWindowManager.shared.immersiveSpaceConfig = ""
        }

        allVolumes.remove(volume)
        orphanVolumes.remove(volume)
        volumesAwaitingWindow.remove(volume)

        needsUpdate = true
    }

    func on(volumeViewpointChanged window: PolySpatialWindow, _ viewpoint: Viewpoint3D) {
        if (window.windowConfiguration == "Unbounded") {
            // Viewpoint notifications only work for volumetric windows.
            return
        }

        if let vol = allVolumes.first(where: { $0.assignedWindowUUID == window.uuid}) {
            switch (viewpoint.squareAzimuth) {
                case .front:
                    PolySpatialRealityKit.instance.notifyHostVolumeViewpointChange(vol, volumeViewpoint: .front)
                case .back:
                    PolySpatialRealityKit.instance.notifyHostVolumeViewpointChange(vol, volumeViewpoint: .back)
                case .left:
                    PolySpatialRealityKit.instance.notifyHostVolumeViewpointChange(vol, volumeViewpoint: .left_)
                case .right:
                    PolySpatialRealityKit.instance.notifyHostVolumeViewpointChange(vol, volumeViewpoint: .right_)
                @unknown default:
                    PolySpatialRealityKit.instance.LogError("No PolySpatialVolumeViewpoint enum match for viewpoint \(viewpoint.squareAzimuth)")
            }
        }
    }

    func on(windowAdded window: PolySpatialWindow, _ delegate: PolySpatialSceneDelegate? = nil, _ actualDimensions: simd_float3? = nil) {
        pslVolumeLog.trace("Window added: uuid \(window.uuid, privacy: .public) as \(window.windowConfiguration, privacy: .public)")

        // ImmersiveSpaces using CompositorServices don't have a scene delegate. They provide their window ID by explicitly
        // calling PolySpatialWindowManagerAccess.onCompositorSpaceOpened(window) when they are opened
        if delegate != nil {
            delegate!.pslWindowUUID = window.uuid
        }

        // ImmersiveSpaces don't have actual dimensions, so fall back to 1x1x1 as "identity" size.
        if actualDimensions != nil {
            window.actualDimensions = actualDimensions!
        } else {
            window.actualDimensions = .init(1, 1, 1)
        }

        freeWindows.insert(window)
        allWindows[window.uuid] = window
        allSceneDelegates[window.uuid] = delegate

        // When the first window is opened, we haven't yet decided which display provider to use. Now we can decide based on the window configuration
        if (!seenFirstWindow) {
            let unityVisionOS = NSClassFromString("UnityVisionOS") as? NSObject.Type
            let useParameterizedProvider = window.windowConfiguration == "CompositorSpace" ? 0 : 1
            unityVisionOS?.perform(Selector(("setUseParameterizedDisplayProvider:")), with: useParameterizedProvider)
        }

        seenFirstWindow = true

        PolySpatialWindowManagerAccess.delegate?.onWindowAdded(window)

        // If we were transitioning into a compositor space from an Unbounded RealityKit ImmersiveSpace, we opened a loading window
        if window.windowConfiguration == "CompositorSpace" {
            dismissWindow(id: "LoadingWindow")
        }

        needsUpdate = true
    }

    func on(windowResized window: PolySpatialWindow, _ actualDimensions: simd_float3) {
        window.actualDimensions = actualDimensions

        if let vol = allVolumes.first(where: { $0.assignedWindowUUID == window.uuid}) {
            vol.update(hostDimensionsFromWindow: window)

            // Notify host that user has resized the volume via the chrome.
            PolySpatialRealityKit.instance.notifyHostWindowState(vol, windowEvent: .resized, focused: true)

            pslVolumeLog.trace("Volume \(vol.id, privacy: .public): window resized, uuid: \(window.uuid, privacy: .public) actualDimensions: \(actualDimensions, privacy: .public)")
        }
    }
    
    func on(sceneDidDisconnect uuid: UUID?) {
        guard let uuid else {
            return
        }
                
        guard let win = allWindows[uuid] else {
            pslVolumeLog.trace("   ... window not known")
            return
        }
        
        if (PolySpatialWindow.windowConfigurationIsImmersive(win.windowConfiguration)) {
            // Immersive space is being closed due to a user action or the OS. There's no way to
            // tell which initiated this window dismissal, so we need another check to see if the user
            // or OS closed it.
            pslVolumeLog.trace("Immersive space \(uuid, privacy: .public) is being closed.")
            immersiveSpaceWasClosed = true
        }
    }

    func on(windowDismissed uuid: UUID?) {
        guard let uuid else {
            return
        }

        pslVolumeLog.trace("Window removed: uuid \(uuid, privacy: .public)")

        guard let win = allWindows[uuid] else {
            pslVolumeLog.trace("   ... window not known")
            return
        }

        // If this window went to background, then keep the volume around.
        // Otherwise it's safe to assume the volume doesn't want a window
        // assigned.
        var addVolumeToOrphans = false
        if let _ = backgroundWindows.remove(win) {
            addVolumeToOrphans = true
        }

        removeWindow(win, addVolumeToOrphans: addVolumeToOrphans)

        // If we requested that this window be closed, allow new windows to be requested on the next call to matchVolumesAndWindows
        // Otherwise assume that this window is being dismissed by the OS and do nothing.
        if let _ = closingWindows.remove(uuid) {
            needsUpdate = true
        }
    }

    // These two functions (willBecomeActive and didResignActive will only invoke the event handlers for now.
    func on(windowDidBecomeActive uuid: UUID?) {
        guard let uuid else {
            return
        }

        notifyVolumeForWindow(uuid, windowEvent: .focused, isFocused: true)
    }

    func on(windowWillResignActive uuid: UUID?) {
        guard let uuid else {
            return
        }

        notifyVolumeForWindow(uuid, windowEvent: .focused, isFocused: false)
    }

    func on(windowWillEnterForeground uuid: UUID?) {
        guard let uuid else {
            return
        }

        if let win = allWindows[uuid] {
            backgroundWindows.remove(win)
        }

        notifyVolumeForWindow(uuid, windowEvent: .opened, isFocused: true)
    }

    func on(windowDidEnterBackground uuid: UUID?) {
        guard let uuid else {
            return
        }

        pslVolumeLog.trace("Window will enter background: uuid \(uuid, privacy: .public)")

        guard let win = allWindows[uuid] else {
            pslVolumeLog.trace("   ... a window we knew nothing about entered background!")
            return
        }

        notifyVolumeForWindow(uuid, windowEvent: .backgrounded, isFocused: false)
        backgroundWindows.insert(win)
    }

    private func removeWindow(_ win: PolySpatialWindow, addVolumeToOrphans: Bool) {
        let uuid = win.uuid
        if let vol = allVolumes.first(where: { $0.assignedWindowUUID == uuid}) {
            pslVolumeLog.trace("   ... window uuid \(uuid, privacy: .public) was assigned to \(vol.id, privacy: .public)")

            // A volume was assigned to this window; tell the volume the window is gone
            vol.update(window: nil, event: .closed)

            // Sanity check -- this window should not be marked as free
            assert(!freeWindows.contains(where: { $0.uuid == uuid }))

            if addVolumeToOrphans {
                // Put the volume back in orphanVolumes, typically because it wasn't a user/app-initiated dismissal.
                // the volume will get assigned back to a window if the app is relaunched, because the OS should
                // re-open the last used scene
                orphanVolumes.insert(vol)
            }
        }

        PolySpatialWindowManagerAccess.delegate?.onWindowRemoved(win)

        freeWindows.remove(win)
        allWindows.removeValue(forKey: uuid)
        allSceneDelegates.removeValue(forKey: uuid)
    }

    public func reset() {
        // when does this get called?
        allWindows.removeAll()
        allVolumes.removeAll()
        freeWindows.removeAll()
        orphanVolumes.removeAll()
    }
    
    // Check either the cache if we've already rerouted this particular output dimension request once before, or check to see if we have a direct window match for this request.
    public func findBestFitWindowForRequest(_ requestedDim: simd_float3, _ fittedDim: inout simd_float3) -> Bool
    {
        let requestedDimString = PolySpatialVolume.windowConfigurationStringFor(outputDimensions: requestedDim, outputMode: .bounded)
        
        if let cachedFit = cachedFittedDim[requestedDimString]
        {
            fittedDim = cachedFit
            return true
        }
        
        if (PolySpatialWindowManagerAccess.delegate?.getAllAvailableWindows().contains(requestedDimString) ?? false)
        {
            fittedDim = requestedDim
            return true
        }
        
        return false
    }

    // Look for a best fit for a requested volume camera in the list of available volume cameras, matching on aspect ratio and volume size. Algorithm determines a score for volume size and aspect ratio, and the higher their combined score is, the more likely a configuration will be chosen.
    // Unbounded volume cameras are not supported.
    public func fitToAvailableVolumeConfig(_ requestedVolumeDim: simd_float3) -> simd_float3 {
        let epsilon = 1e-6
        let maxScore: Double = 10000 // There technically is no upper bound, so capping it somewhat arbitrarily at 1 / 0.0001.

        let currentVolumeSize = requestedVolumeDim.x * requestedVolumeDim.y * requestedVolumeDim.z

        var bestMatch: simd_float3 = .one
        if currentVolumeSize <= smallestVolumeForMatch.volume {
            bestMatch = smallestVolumeForMatch.dimension
        } else if currentVolumeSize >= largestVolumeForMatch.volume {
            bestMatch = largestVolumeForMatch.dimension
        } else {
            var highestScore: Double = -Double.greatestFiniteMagnitude
            for config in allAvailableConfigurationsForMatch {
                // Scores are higher when closer to 0, invert it to get the highest score.
                let sizeDifference = abs(currentVolumeSize - config.volume)
                var sizeScore: Double = maxScore
                if (sizeDifference != 0) {
                    sizeScore = Double(1 / sizeDifference)
                }

                let normalizedRequested = simd_normalize(requestedVolumeDim)
                let normalizedMatch = simd_normalize(config.dimension)

                let aspectDifference = abs(1 - dot(normalizedRequested, normalizedMatch))
                var aspectScore: Double = maxScore
                if (aspectDifference != 0) {
                    aspectScore = Double(1 / aspectDifference)
                }

                let finalScore = aspectScore * sizeScore
                if (finalScore + epsilon) > highestScore {
                    bestMatch = config.dimension
                    highestScore = finalScore
                }
            }
        }
        
        let originalDim = PolySpatialVolume.windowConfigurationStringFor(outputDimensions: requestedVolumeDim, outputMode: .bounded)
        cachedFittedDim[originalDim] = bestMatch

        return bestMatch
    }

    // matchVolumesAndWindows is called after every EndFrame message is received. This is why we use needsUpdate to
    // decide whether to actually match windows and volumes. There are a few important platform constraints to keep
    // in mind when reading and modifying this method:
    // - dismissWindow will silently do nothing if you call it on the last open window or volume in your app
    // - Opening or dismissing an ImmersiveSpace is an async operation that takes a few seconds as content is faded in
    //   and out of view.
    // - When opening an ImmersiveSpace containing a CompositorLayer (or any space using ImmersionStyle.full), the system
    //   will prompt the user with a safety dialog warning them about bumping into obstacles. This dialog has three
    //   options, and can also be dismissed if the user gazes away from it and pinches their fingers. The three options are:
    //     - Don't show again: the immersive space will be opened and the user will not be prompted again in the future
    //     - Learn More: the immersive space will not be opened, the app is backgrounded, and a Safari window is opened
    //       showing a documentation page about fully immersive experiences. We currently rely on the user to re-open
    //       the app and trigger the mode transition again.
    //     - OK: the immersive space will be opened and the user will be prompted again in the future
    // - Only one ImmersiveSpace can be open at a time; You must wait for an open immersive space to finish closing
    //   before you can open the next one
    // - You cannot combine a CompositorServices CompositorLayer with any Views in a single UIScene, nor can you put
    //   a CompositorLayer in a WindowGroup; CompositorLayer is not a View
    //
    // Due to these constraints, we only update one volume at a time per call to this method, and block any further updates
    // while these PolySpatialWindows (which can describe a Volume or an ImmersiveSpace) are opening and closing. We also
    // need to ensure that there is always at least one window, volume, or immersive space is open, hence the need for a
    // loading window to bridge the gap between immersive spaces. This logic does not account for custom windows added by
    // user code.
    func matchVolumesAndWindows() {
        if !needsUpdate {
            return
        }

        // This can happen if user code tries to switch volume configurations too quickly--we need to delay the process
        // because we will encounter errors if we try to open and close windows while an immersive space is closing
        if (!closingWindows.isEmpty){
            pslVolumeLog.warning("Delay matching volumes; windows are not done closing")
            return
        }

        // Set this to false right away (as opposed to at the end of the function) in case one of our callbacks
        // sets it to true, indicating that we will need another update.
        needsUpdate = false

        // For each orphaned volume, search free windows for a match based on desiredWindowConfiguration. Once match has been found, move on to next orphaned volume.
        pslVolumeLog.trace("Matching windows and volumes -- \(self.orphanVolumes.count, privacy: .public) orphan volumes, \(self.freeWindows.count, privacy: .public) free windows, \(self.allWindows.count, privacy: .public) total windows")
        for (_, volume) in orphanVolumes.enumerated() {
            for (_, winconfig) in freeWindows.enumerated() {
                // Need to break out if all volumes have been assigned, otherwise one volume can accidentally be assigned to multiple windows.
                if (orphanVolumes.isEmpty) {
                    break
                }

                if winconfig.windowConfiguration != volume.desiredWindowConfiguration {
                    continue
                }

                pslVolumeLog.trace("   ... matching window \(winconfig.uuid, privacy: .public) \(winconfig.windowConfiguration, privacy: .public) to \(volume.id, privacy: .public)")
                freeWindows.remove(winconfig)
                orphanVolumes.remove(volume)

                volume.update(window: winconfig, event: .opened)
                if let _ = volumesAwaitingWindow.remove(volume) {
                    pslVolumeLog.trace(" ... removed opening volume \(winconfig.uuid)")
                } else {
                    pslVolumeLog.trace(" ... can't find opening window \(winconfig.uuid)")
                }

                // Notify host that this volume camera has been resized after the window open event notification.
                if (volume.assignedNewWindowConfiguration) {
                    PolySpatialRealityKit.instance.notifyHostWindowState(volume, windowEvent: .resized, focused: true)
                    volume.assignedNewWindowConfiguration = false
                }

                // At this point, the volume should have been assigned a
                // window, and we can move onto the next orphanedVolume.
                assert(volume.assignedWindowUUID != nil)

                // TODO: When supporting multiple volumes, we may need to set needsUpdate = true here if multiple
                // orphan volumes are created in a single frame
                break
            }
        }

        // if we haven't seen the first window, don't request any additional windows until it pops up
        if seenFirstWindow {
            // if we have any free windows at this point, they didn't match any volumes -- close them
            // requestDimissWindow might execute synchronously, so build up a list first to not
            // modify the set while we're iterating through it
            var toDismiss: [PolySpatialWindow] = []
            for window in freeWindows {
                if (allWindows.count == 0) {
                    pslVolumeLog.error("Error matching volumes, no windows appear to be open after we've seen the first window")
                    break;
                }

                // Don't remove the last volume--dismissWindow will fail if you try to close the last open window and
                // the app will be backgrounded if you close an immersive space with no open windows or volumes
                if allWindows.count == 1 {
                    let config = allWindows.first!.value.windowConfiguration
                    // If the last window is a compositor space, we can actually transition seamlessly
                    if (config != "CompositorSpace") {
                        if config == "Unbounded" {
                            // If we are replacing a RealityKit immersive space with a Compositor Space, use a window to bridge the gap
                            // For some reason, the opposite transition (Compositor Space -> Reality Kit Immersive Space) works fine
                            if orphanVolumes.count == 1 && orphanVolumes.first!.desiredWindowConfiguration == "CompositorSpace" {
                                openWindow(id: "LoadingWindow")
                            }
                        } else {
                            break
                        }
                    }
                }

                pslVolumeLog.trace("   ... requesting dismiss of unused window: uuid \(window.uuid, privacy: .public) \(window.windowConfiguration, privacy: .public)")
                toDismiss.append(window)
                closingWindows.insert(window.uuid)

                // Only dismiss one window at a time; we need to know whether the last open is an immersive space to handle the transition properly
                break
            }

            // Don't open new windows until any windows requested to be closed have done so. This it to prevent new windows from being placed incorrectly.
            if closingWindows.isEmpty {
                for volume in orphanVolumes {
                    pslVolumeLog.trace("   ... requesting open of new window for: \(volume.desiredWindowConfiguration)")
                    PolySpatialWindowManagerAccess.delegate?.requestOpenWindow(volume.desiredWindowConfiguration)
                    volumesAwaitingWindow.insert(volume)

                    // Early-out after requesting an open window in case it's an immersive space and we need to wait
                    return
                }
            }

            // Don't close windows until volumes which have already requested their window have matched an open window. This is to prevent
            // us from returning to the home screen, and to ensure `dismissWindow` will work properly
            if volumesAwaitingWindow.isEmpty {
                for window in toDismiss {
                    pslVolumeLog.trace("   ... requesting dismiss of window for: \(window.windowConfiguration)")
                    PolySpatialWindowManagerAccess.delegate?.requestDismissWindow(window)

                    // Early-out after requesting to dismiss a window in case it's an immersive space and we need to wait
                    return
                }
            }
        }
    }
}
