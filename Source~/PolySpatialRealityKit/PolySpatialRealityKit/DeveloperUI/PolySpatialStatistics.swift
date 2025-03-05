//
//  PolySpatialStatistics.swift
//  PolySpatialRealityKit
//
//  Created by Joe Jones on 9/16/22.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PolySpatialStatistics: ObservableObject {
    public static var shared = PolySpatialStatistics()

    var frameCounter = 0
    var lastUpdateFrameCounter = 0
    var lastUpdateTime: Int64
    var updateTime: Int64
    let updateIntervalInMs =  100

    @Published var displayOverlay = false
    @Published var currentFps = 0
    @Published var textureCount = 0
    @Published var materialCount = 0
    @Published var meshCount = 0

    public var estimatedTextureMemory = 0
    public var estimatedMeshMemory = 0

    init() {
        self.updateTime = Date().millisecondsSince1970
        self.lastUpdateTime = self.updateTime
    }

    func updateFrameStatistics( _ timeDelta: Int64) {
        let frameCountDelta = frameCounter - lastUpdateFrameCounter
        if frameCountDelta == 0 {
            currentFps = 0
            return
        }

        let millisPerFrameInInterval =  Double(timeDelta) / Double(frameCountDelta)
        let fps = Int(1000.0 / millisPerFrameInInterval)
        currentFps = (currentFps + fps) / 2
    }

    func updateTextureAssetInformation(_ qrkInstance: PolySpatialRealityKit) {
        textureCount = qrkInstance.textureAssets.count
        for tr in qrkInstance.textureAssets.values {
            var estimatedComponentCount = 0
            if let semantic = tr.texture.resource.semantic {
                switch semantic {

                case .raw:
                    estimatedComponentCount = 1
                case .scalar:
                    estimatedComponentCount = 1
                case .color:
                    estimatedComponentCount = 4
                case .hdrColor:
                    estimatedComponentCount = 4
                case .normal:
                    estimatedComponentCount = 3
                @unknown default:
                    estimatedComponentCount = 0
                }
            }

            estimatedTextureMemory += tr.texture.resource.width * tr.texture.resource.height * estimatedComponentCount * MemoryLayout<Float>.size
        }
    }

    func updateMeshAssetInformation(_ qrkInstance: PolySpatialRealityKit) {
        meshCount = qrkInstance.meshAssets.count
        estimatedMeshMemory = 0
        for m in qrkInstance.meshAssets.values {
            for models in m.mesh.contents.models {
                for part in models.parts {
                    if let tris = part.triangleIndices {
                        estimatedMeshMemory += tris.count * MemoryLayout<UInt32>.size
                    }

                    for buf in part.buffers.values {
                        var byteCount = 0
                        switch buf.elementType {
                        case .uInt8, .int8:
                            byteCount = MemoryLayout<UInt8>.size
                        case .uInt16, .int16:
                            byteCount = MemoryLayout<UInt16>.size
                        case .uInt32, .int32:
                            byteCount = MemoryLayout<UInt32>.size
                        case .float:
                            byteCount = MemoryLayout<Float>.size
                        case .double:
                            byteCount = MemoryLayout<Double>.size
                        case .simd2Float:
                            byteCount = MemoryLayout<SIMD2<Float>>.size
                        case .simd3Float:
                            byteCount = MemoryLayout<SIMD3<Float>>.size
                        case .simd4Float:
                            byteCount = MemoryLayout<SIMD4<Float>>.size
                        default:
                            assertionFailure("Unknown buffer element type: \(buf.elementType)")
                        }

                        estimatedMeshMemory += byteCount * buf.count
                    }
                }
            }
        }
    }

    func updateAssetInformation () {
        estimatedTextureMemory = 0
        let qrkInstance = PolySpatialRealityKit.instance
        updateTextureAssetInformation(qrkInstance)
        updateMeshAssetInformation(qrkInstance)
        materialCount = qrkInstance.materialAssets.count
    }

    func updateStatistics () {
        self.frameCounter += 1
        self.updateTime = Date().millisecondsSince1970

        let timeDelta = (updateTime - lastUpdateTime)

        if timeDelta > updateIntervalInMs {
            updateFrameStatistics(timeDelta)
            updateAssetInformation()
            lastUpdateFrameCounter = frameCounter
            lastUpdateTime = updateTime
        }
    }
}
