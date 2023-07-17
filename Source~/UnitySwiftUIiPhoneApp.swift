import SwiftUI
import PolySpatialRealityKit
import RealityKit
typealias Scene = SwiftUI.Scene

#if !os(xrOS)

@main
struct UnitySwiftUIiPhoneApp: App {
    @UIApplicationDelegateAdaptor
    var swiftUIdelegate: UnitySwiftUIAppDelegate

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
struct UnitySwiftUIiPhoneApp: App {
    @UIApplicationDelegateAdaptor
    var swiftUIdelegate: UnitySwiftUIAppDelegate

    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    @Environment(\.physicalMetrics) var physicalMetrics

    var polyspatialObserver: PolySpatialVolumeCoordinator? = nil

    init() {
        polyspatialObserver = .init(openWindow)
    }

    @SceneBuilder
    var immersiveScene: some Scene {
        WindowGroup(id: "LaunchWindow") {
            Spacer()
                .onAppear {
                    Task { @MainActor in
                        await openImmersiveSpace(id: "ImmersiveSpace")
                        dismissWindow(id: "LaunchWindow")
                    }
                }
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            PolySpatialRealityKitAccess.tmpOneAndOnlyVolume().view
        }
    }

    @SceneBuilder
    var volumeScene: some Scene {
        WindowGroup {
            PolySpatialRealityKitAccess.tmpOneAndOnlyVolume().view
        }
        .windowStyle(.volumetric)
        .defaultSize(UnityVisionOSSettings.initialSize, in: .meters)
    }

    var body: some Scene {
        realScene
    }

/*
    Once issues are fixed, actually create presized volumetric windows
    var body: some Scene {
        WindowGroup(id: "SplashScreen") {
            // empty, perhaps future splash screen location
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.0, height: 1.0, depth: 1.0)

        WindowGroup(id: "UnityVolume-1x1x1", for: String.self) { volumeId in
            if let id = volumeId.wrappedValue {
                VStack {
                    if let volume = PolySpatialVolume.with(identifier: id) {
                        volume.view
                    } else {
                        Text("Failed to find volume with id: \(volumeId.wrappedValue!)")
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(Color.white)
                    }
                }
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.0, height: 1.0, depth: 1.0, in: .meters)
    }
 */
}

class PolySpatialVolumeCoordinator: ObservableObject, PolySpatialRealityKitDelegate {
    @Published var volumes: [PolySpatialVolume] = []

    var openWindow: OpenWindowAction

    init(_ openWinAction: OpenWindowAction) {
        openWindow = openWinAction

        PolySpatialRealityKitAccess.addDelegate(self)
    }

    func on(volumeAdded: PolySpatialVolume) {
        self.volumes.append(volumeAdded)
        // ask app to open a window for the volume
        // TODO -- actually pick appropriate size window
        //openWindow(id: "UnityVolume-1x1x1", value: volumeAdded.id)
    }

    func reset() {
    }
}
#endif
