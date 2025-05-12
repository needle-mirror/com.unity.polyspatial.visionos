import Foundation
import RealityKit
import UIKit

@_implementationOnly
import FlatBuffers
@_implementationOnly
import PolySpatialRealityKitC

@MainActor
extension PolySpatialRealityKit {
    public static func overrideApi(_: Int, _ api: inout PolySpatialNativeAPI) {
        // convenient place to init
        api.SendClientCommand = {(a, b, c, d) in PolySpatialRealityKit.instance.OnSendClientCommandOverrides(PolySpatialCommand.init(rawValue: a)!, b, c, d) }
    }

    internal func OnSendClientCommandOverrides(
        _ cmd: PolySpatialCommand,
        _ argCount: Int32,
        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
        _ argSizes: UnsafeMutablePointer<UInt32>?) {

        switch cmd {

            // entity APIs


            case .endAppFrame:
                var instanceIdPtr: UnsafeMutablePointer<PolySpatialInstanceID>?
                var frameDataPtr: UnsafeMutablePointer<PolySpatialFrameData>?
                ExtractArgs(argCount, args, argSizes, &instanceIdPtr, &frameDataPtr)

                PolySpatialWindowManager.shared.matchVolumesAndWindows()
                StaticBatchManager.instance.updateStaticBatches()
                particleManager.updateSubEmitters()
                NotifyTextureObservers()
                NotifyCollisionObservers()
                ShaderManager.instance.ApplyRemainingShaderGlobalPropertyValues()

                // Delay expensive mesh blending until all batched frames have been received.
                if !frameDataPtr!.pointee.morePendingFramesBatched {
                    skinnedMeshManager.updateBlendedMeshInstances()
                }
                break

            case .setShaderGlobalPropertyMap:
                var data: ByteBuffer?
                ExtractArgs(argCount, args, argSizes, &data)
                let shaderGlobalPropertyMap: PolySpatialShaderGlobalPropertyMap = getRoot(byteBuffer: &data!)
                ShaderManager.instance.SetShaderGlobalPropertyMap(shaderGlobalPropertyMap)
                break
            case .setShaderGlobalPropertyValues:
                var data: ByteBuffer?
                ExtractArgs(argCount, args, argSizes, &data)
                let shaderGlobalPropertyValues: PolySpatialShaderGlobalPropertyValues = getRoot(byteBuffer: &data!)
                ShaderManager.instance.SetShaderGlobalPropertyValues(shaderGlobalPropertyValues)
                break
            default:
                PolySpatialRealityKit.instance.OnSendClientCommand(cmd, argCount, args, argSizes)
                break
        }
    }
}
