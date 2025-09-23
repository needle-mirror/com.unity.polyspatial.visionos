import Foundation
import RealityKit
import AVFoundation
@_implementationOnly
import FlatBuffers
import UIKit

typealias PolySpatialVideoPlayerData = Unity_PolySpatial_Internals_PolySpatialVideoPlayerData
typealias PolySpatialVideoPlayerState = Unity_PolySpatial_Internals_PolySpatialVideoPlayerState

extension PolySpatialRealityKit {

    func getVideoURL(_ source: PolySpatialSourceType, _ urlString: String) -> URL? {
        if (source == .videoClip) {
            return URL(filePath: urlString)
        }

        guard let url = URL(string: urlString) else {
            return nil
        }

        // If the user just passed in the name of the video asset and its extension, then this isn't an absolute path and we'll search the mainBundle for it.
        if (url.scheme == nil) {
            let videoExtension = url.pathExtension
            let videoName = url.deletingPathExtension().lastPathComponent
            if let bundleUrl = Bundle.main.url(forResource: videoName, withExtension: videoExtension) {
                return bundleUrl
            } else {
                return nil
            }
        }

        return url
    }

    // Sets video component first time, optionally inverts mesh uvs.
    func setVideoComponent(_ id: PolySpatialInstanceID,
                           _ info: PolySpatialVideoPlayerData,
                           _ rendererEntity: PolySpatialEntity,
                           _ videoUrl: URL) {
        if !rendererEntity.components.has(ModelComponent.self) || !rendererEntity.components.has(PolySpatialComponents.RenderInfo.self) {
            PolySpatialRealityKit.instance.LogWarning("No model or render component found for mesh entity \(info.meshRendererEntityId!) when setting the video player on it, video player component will not be initialized.")
            return
        }

        let videoComp = PolySpatialComponents.UnityVideoPlayer(id, videoUrl, info.preroll)

        rendererEntity.components.set(videoComp)
        rendererEntity.updateVideoPlayerMesh()

        videoComp.state = info.playState
        return
    }

    func updateVideoComponent(_ info: PolySpatialVideoPlayerData,
                              _ rendererEntity: PolySpatialEntity,
                              _ firstTimeSetup: Bool,
                              _ videoUrl: URL) {
        guard let videoComp = rendererEntity.components[PolySpatialComponents.UnityVideoPlayer.self] as PolySpatialComponents.UnityVideoPlayer? else {
            PolySpatialRealityKit.instance.LogWarning("Renderer entity \(rendererEntity) does not have a video component.")
            return
        }

        // Url was changed.
        if videoComp.videoUrl != videoUrl {
            videoComp.shouldPreroll = info.preroll
            videoComp.changeUrl(videoUrl)

            rendererEntity.updateVideoPlayerMesh()
        }

        // Set up play on awake.
        if firstTimeSetup {
            // Handle first time loop setup.
            videoComp.setLooping(info.isLooping)
            if info.playOnAwake {
                videoComp.player.play()
            } else {
                videoComp.player.pause()
            }
            return
        }

        // Set direct volume and mute.
        videoComp.player.isMuted = info.isMuted
        videoComp.player.volume = info.volume

        // Set up play state if just updating.
        videoComp.setState(info.playState, info.isLooping)
    }

    // Removes video component, optionally restores previous mesh and materials.
    func cleanUpVideoPlayer(_ id: PolySpatialInstanceID) {
        // Video player was deleted or disabled, do some cleanup here.
        guard let oldRenderId = videoPlayerEntityMap[id] else {
            return
        }

        videoPlayerEntityMap[id] = nil

        guard let oldRenderEntity = TryGetEntity(oldRenderId) else {
            return
        }

        if let videoPlayer = oldRenderEntity.components[PolySpatialComponents.UnityVideoPlayer.self] as PolySpatialComponents.UnityVideoPlayer? {
            videoPlayer.player.pause()
            videoPlayer.player.removeAllItems()
        }

        oldRenderEntity.components.remove(PolySpatialComponents.UnityVideoPlayer.self)

        if oldRenderEntity.components.has(PolySpatialComponents.RenderInfo.self) {
            oldRenderEntity.updateModelComponent()
        }
    }

    // Resets all video players in the identified volume, recreating their assets and video materials/model components.
    func resetVideoPlayers(_ volumeId: PolySpatialInstanceID) {
        for entityId in videoPlayerEntityMap.values {
            guard entityId.hostId == volumeId.hostId, entityId.viewSubgraphIndex == volumeId.viewSubgraphIndex else {
                continue
            }
            let entity = GetEntity(entityId)
            let videoComp = entity.components[PolySpatialComponents.UnityVideoPlayer.self]!
            let previousState = videoComp.state
            let wasLooping = (videoComp.avPlayerLooper != nil)

            videoComp.changeUrl(videoComp.videoUrl)

            entity.updateVideoPlayerMesh()

            videoComp.setState(previousState, wasLooping)
        }
    }
}
