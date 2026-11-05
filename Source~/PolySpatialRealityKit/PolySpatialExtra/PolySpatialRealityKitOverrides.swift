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
        api.SendClientCommand = {(a, b, c, d) in
            guard let header = PolySpatialCommandHeader.load(validating: a) else { return }
            PolySpatialRealityKit.instance.OnSendClientCommandOverrides(header, b, c, d) }
    }

    internal func OnSendClientCommandOverrides(
        _ header: PolySpatialCommandHeader,
        _ argCount: Int32,
        _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?,
        _ argSizes: UnsafeMutablePointer<UInt32>?) {

        switch header.command {

            // entity APIs


            case .endAppFrame:
                var frameDataPtr: UnsafeMutablePointer<PolySpatialFrameData>?
                ExtractArgs(argCount, args, argSizes, &frameDataPtr)

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
                PolySpatialRealityKit.instance.OnSendClientCommand(header, argCount, args, argSizes)
                break
        }
    }
}
