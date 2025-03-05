import Foundation
import RealityKit
@_implementationOnly
import FlatBuffers

typealias PolySpatialLogLevel = Unity_PolySpatial_Internals_PolySpatialLogLevel

@MainActor
extension PolySpatialRealityKit {
    static func Log(_ msg: String) {
        instance.Log(msg)
    }

    func Log(_ msg: String) {
        SendLogMessage(.log, msg)
    }

    static func LogWarning(_ msg: String) {
        instance.LogWarning(msg)
    }

    func LogWarning(_ msg: String) {
        SendLogMessage(.warning, msg)
    }

    func LogMaterialWarning(_ id: PolySpatialAssetID, _ msg: String) {
        UpdateMaterialDefinition(UnlitMaterialAsset(id, LogWarningAndGetMaterial(msg)))
    }

    func LogWarningAndGetMaterial(_ msg: String) -> UnlitMaterial {
        if runtimeFlags.contains(.uniqueInvalidMaterialColors) {
            let color = materialErrorColors[materialErrorColorIndex]
            materialErrorColorIndex = (materialErrorColorIndex + 1) % materialErrorColors.count
            
            // Workaround for lack of accessibilityName on older versions of NSColor:
            // https://stackoverflow.com/questions/74228418/how-do-you-access-the-accessibilityname-of-an-nscolor
            LogWarning("\(msg), shown in \(color.value(forKey: "accessibilityName") as! String)")
            return .init(color: color)

        } else {
            LogWarning(msg)
            return GetMaterialForID(PolySpatialAssetID.invalidAssetId) as! UnlitMaterial
        }
    }

    static func LogError(_ msg: String, _ abort: Bool? = nil) {
        instance.LogError(msg, abort)
    }

    func LogError(_ msg: String, _ abort: Bool? = nil) {
        SendLogMessage(.error, msg)
        if abort ?? PolySpatialRealityKit.abortOnError {
            fatalError(msg)
        }
    }
    
    func LogErrorWithMarkup(_ msg: String,
                            _ markupTypes: [Unity_PolySpatial_Internals_LogMarkupType],
                            _ markupValues: [Int64],
                            _ abort: Bool? = nil)
    {
        assert(markupTypes.count >= 1, "If there is no markup use LogError instead.")
        assert(markupTypes.count == markupValues.count, "Markup type and value counts must match.")
                
        var builder = FlatBufferBuilder()
        
        let builderMsg = builder.create(string:msg)
        let vectorTypes = builder.createVector(markupTypes)
        let vectorValues = builder.createVector(markupValues)
        
        let logWithMarkupOffset = PolySpatialLogWithMarkup.startLogWithMarkup(&builder)
        PolySpatialLogWithMarkup.add(log:builderMsg,  &builder)
        PolySpatialLogWithMarkup.add(logLevel:PolySpatialLogLevel.error, &builder)
        PolySpatialLogWithMarkup.addVectorOf(logTypes:vectorTypes, &builder)
        PolySpatialLogWithMarkup.addVectorOf(logValues:vectorValues, &builder)
        let finishedLogWithMarkupOffset = PolySpatialLogWithMarkup.endLogWithMarkup(&builder, start: logWithMarkupOffset)
        builder.finish(offset: finishedLogWithMarkupOffset)
                
        SendHostCommand(PolySpatialHostCommand.logMessageWithMarkup, builder.sizedBuffer)
        
        if abort ?? PolySpatialRealityKit.abortOnError {
            fatalError(msg)
        }
    }

    static func LogException(_ msg: String) {
        instance.LogException(msg)
    }

    func LogException(_ msg: String) {
        SendLogMessage(.exception, msg)
    }

    static func TrackingDisabledOrDestroyedOrInactive(_ trackingFlags: Int32) -> Bool {
        return 0 != ((UInt32)(trackingFlags) & (PolySpatialTrackingFlags.destroyed.rawValue | 
                                                PolySpatialTrackingFlags.disabled.rawValue | PolySpatialTrackingFlags.inactive.rawValue))
    }
    
    static func TrackingDisabledOrDestroyed(_ trackingFlags: Int32) -> Bool {
        return 0 != ((UInt32)(trackingFlags) & (PolySpatialTrackingFlags.destroyed.rawValue | PolySpatialTrackingFlags.disabled.rawValue))
    }

    func SendLogMessage(_ logLevel: PolySpatialLogLevel, _ msg: String) {
        msg.utf8CString.withUnsafeBytes { SendHostCommand(.logMessage, logLevel.rawValue, $0) }
    }

    func SendHostCommand(_ command: PolySpatialHostCommand, _ a1: String) {
        a1.data(using: .utf16LittleEndian)!.withUnsafeBytes {
            var args: [UnsafeRawPointer?] = [$0.baseAddress!]
            var argSizes: [UInt32] = [UInt32($0.count)]
            simHostAPI.SendHostCommand(command.rawValue, 1, &args, &argSizes)
        }
    }

    func SendHostCommand(_ command: PolySpatialHostCommand, _ a1: ByteBuffer) {
        a1.underlyingBytes.withUnsafeBytes {
            var args: [UnsafeRawPointer?] = [$0.baseAddress!]
            var argSizes: [UInt32] = [UInt32(a1.size)]
            simHostAPI.SendHostCommand(command.rawValue, 1, &args, &argSizes)
        }
    }

    func SendHostCommand<T1>(_ command: PolySpatialHostCommand, _ a1: T1) {
        var a1c = a1
        withUnsafeBytes(of: &a1c) {
            var args: [UnsafeRawPointer?] = [$0.baseAddress!]
            var argSizes: [UInt32] = [UInt32($0.count)]
            simHostAPI.SendHostCommand(command.rawValue, 1, &args, &argSizes)
        }
    }

    func SendHostCommand<T1>(_ command: PolySpatialHostCommand, _ a1: T1, _ a2: UnsafeRawBufferPointer) {
        var a1c = a1
        withUnsafeBytes(of: &a1c) {
            var args: [UnsafeRawPointer?] = [$0.baseAddress!, a2.baseAddress!]
            var argSizes: [UInt32] = [UInt32($0.count), UInt32(a2.count)]
            simHostAPI.SendHostCommand(command.rawValue, 2, &args, &argSizes)
        }
    }

    func SendHostCommand<T1, T2>(_ command: PolySpatialHostCommand, _ a1: UnsafePointer<T1>?, _ a2: UnsafePointer<T2>?) {
        var args = [UnsafeRawPointer.init(a1), UnsafeRawPointer.init(a2)]
        var argSizes =  [UInt32(MemoryLayout<T1>.size), UInt32(MemoryLayout<T2>.size)]

        simHostAPI.SendHostCommand(command.rawValue, 2, &args, &argSizes)
    }

    func SendHostCommand<T1, T2, T3>(_ command: PolySpatialHostCommand, _ a1: UnsafePointer<T1>?, _ a2: UnsafePointer<T2>?, _ a3: UnsafePointer<T3>?) {
        var args = [UnsafeRawPointer.init(a1), UnsafeRawPointer.init(a2), UnsafeRawPointer.init(a3)]
        var argSizes =  [UInt32(MemoryLayout<T1>.size), UInt32(MemoryLayout<T2>.size), UInt32(MemoryLayout<T3>.size)]

        simHostAPI.SendHostCommand(command.rawValue, 3, &args, &argSizes)
    }

    func SendHostCommand<T1, T2, T3>(_ command: PolySpatialHostCommand, _ a1: UnsafePointer<T1>?, _ a2: UnsafePointer<T2>?, _ a3: UnsafeBufferPointer<T3>) {
        var args = [UnsafeRawPointer.init(a1), UnsafeRawPointer.init(a2), UnsafeRawPointer.init(a3.baseAddress)]
        var argSizes =  [UInt32(MemoryLayout<T1>.size), UInt32(MemoryLayout<T2>.size), UInt32(a3.count) * UInt32(MemoryLayout<T3>.size)]

        simHostAPI.SendHostCommand(command.rawValue, 3, &args, &argSizes)
    }

    func SendHostCommand<T1, T2, T3, T4>(_ command: PolySpatialHostCommand, _ a1: UnsafePointer<T1>?, _ a2: UnsafePointer<T2>?, _ a3: UnsafePointer<T3>?, _ a4: UnsafePointer<T4>?) {
        var args = [UnsafeRawPointer.init(a1), UnsafeRawPointer.init(a2), UnsafeRawPointer.init(a3), UnsafeRawPointer.init(a4)]
        var argSizes =  [UInt32(MemoryLayout<T1>.size), UInt32(MemoryLayout<T2>.size), UInt32(MemoryLayout<T3>.size), UInt32(MemoryLayout<T4>.size)]

        simHostAPI.SendHostCommand(command.rawValue, 4, &args, &argSizes)
    }

    func ExtractArgs<T>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                        _ a1: inout UnsafeMutablePointer<T>?) {
        assert(argCount == 1)
        assert(argSizes![0] == MemoryLayout<T>.size)

        a1 = args![0]?.bindMemory(to: T.self, capacity: 1)
    }

    func ExtractArgs<T>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                        _ a1: inout UnsafeMutableBufferPointer<T>?) {
        assert(argCount == 1)
        assert(Int(argSizes![0]) % MemoryLayout<T>.size == 0)

        a1 = .init(start: args![0]?.bindMemory(to: T.self, capacity: 1), count: Int(argSizes![0]) / MemoryLayout<T>.size)
    }

    func ExtractArgs(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                     _ a1: inout ByteBuffer?) {
        assert(argCount == 1)

        a1 = .init(assumingMemoryBound: args![0]!, capacity: Int(argSizes![0]))
    }

    func ExtractArgs(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?, _ s: inout String) {
        assert(argCount == 1)
        s = String.init(utf16CodeUnits: args![0]!.assumingMemoryBound(to: unichar.self), count: Int(argSizes![0]) / 2)
    }

    func ExtractArgs<T1, T2>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                             _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?) {
        assert(argCount == 2)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
    }

    func ExtractArgs<T1, T2>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                             _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutableBufferPointer<T2>?) {
        assert(argCount == 2)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(Int(argSizes![1]) % MemoryLayout<T2>.size == 0)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(start: args![1]?.bindMemory(to: T2.self, capacity: 1), count: Int(argSizes![1]) / MemoryLayout<T2>.size)
    }

    func ExtractArgs<T1>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout ByteBuffer?) {
        assert(argCount == 2)
        assert(argSizes![0] == MemoryLayout<T1>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(assumingMemoryBound: args![1]!, capacity: Int(argSizes![1]))
    }

    func ExtractArgs<T1, T2>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout ByteBuffer?, _ a3: inout UnsafeMutablePointer<T2>?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![2] == MemoryLayout<T2>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(assumingMemoryBound: args![1]!, capacity: Int(argSizes![1]))
        a3 = args![2]?.bindMemory(to: T2.self, capacity: 1)
    }
    
    func ExtractArgs<T1, T2>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?, _ a3: inout ByteBuffer?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
        a3 = .init(assumingMemoryBound: args![2]!, capacity: Int(argSizes![2]))
        
    }
    
    func ExtractArgs<T1, T2, T3>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                 _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?,
                                 _ a3: inout UnsafeMutablePointer<T3>?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)
        assert(argSizes![2] == MemoryLayout<T3>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
        a3 = args![2]?.bindMemory(to: T3.self, capacity: 1)
    }

    func ExtractArgs<T1, T2, T3>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                 _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutableBufferPointer<T2>?, _ a3: inout UnsafeMutablePointer<T3>?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(Int(argSizes![1]) % MemoryLayout<T2>.size == 0)
        assert(argSizes![2] == MemoryLayout<T3>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(start: args![1]?.bindMemory(to: T2.self, capacity: 1), count: Int(argSizes![1]) / MemoryLayout<T2>.size)
        a3 = args![2]?.bindMemory(to: T3.self, capacity: 1)
    }

    func ExtractArgs<T1>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout ByteBuffer?,
                         _ a3: inout UnsafeMutableRawBufferPointer?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(assumingMemoryBound: args![1]!, capacity: Int(argSizes![1]))
        a3 = .init(start: args![2], count: Int(argSizes![2]))
    }
    
    func ExtractArgs<T1, T2>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?, _ a3: inout ByteBuffer?,
                         _ a4: inout UnsafeMutableRawBufferPointer?) {
        assert(argCount == 4)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
        a3 = .init(assumingMemoryBound: args![2]!, capacity: Int(argSizes![2]))
        a4 = .init(start: args![3], count: Int(argSizes![3]))
    }

    func ExtractArgs<T1, T2, T3>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                 _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutableBufferPointer<T2>?,
                                 _ a3: inout UnsafeMutableBufferPointer<T3>?) {
        assert(argCount == 3)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(Int(argSizes![1]) % MemoryLayout<T2>.size == 0)
        assert(Int(argSizes![2]) % MemoryLayout<T3>.size == 0)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(start: args![1]?.bindMemory(to: T2.self, capacity: 1), count: Int(argSizes![1]) / MemoryLayout<T2>.size)
        a3 = .init(start: args![2]?.bindMemory(to: T3.self, capacity: 1), count: Int(argSizes![2]) / MemoryLayout<T3>.size)
    }

    func ExtractArgs<T1, T2, T3, T4>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                     _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?,
                                     _ a3: inout UnsafeMutablePointer<T3>?, _ a4: inout UnsafeMutablePointer<T4>?) {
        assert(argCount == 4)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)
        assert(argSizes![2] == MemoryLayout<T3>.size)
        assert(argSizes![3] == MemoryLayout<T4>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
        a3 = args![2]?.bindMemory(to: T3.self, capacity: 1)
        a4 = args![3]?.bindMemory(to: T4.self, capacity: 1)
    }

    func ExtractArgs<T1, T2, T3, T4, T5>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                     _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutablePointer<T2>?,
                                     _ a3: inout UnsafeMutablePointer<T3>?, _ a4: inout UnsafeMutablePointer<T4>?,
                                     _ a5: inout UnsafeMutablePointer<T5>?) {
        assert(argCount == 5)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(argSizes![1] == MemoryLayout<T2>.size)
        assert(argSizes![2] == MemoryLayout<T3>.size)
        assert(argSizes![3] == MemoryLayout<T4>.size)
        assert(argSizes![4] == MemoryLayout<T5>.size)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = args![1]?.bindMemory(to: T2.self, capacity: 1)
        a3 = args![2]?.bindMemory(to: T3.self, capacity: 1)
        a4 = args![3]?.bindMemory(to: T4.self, capacity: 1)
        a5 = args![4]?.bindMemory(to: T5.self, capacity: 1)
    }

    func ExtractArgs<T1, T2, T3, T4, T5>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutableBufferPointer<T2>?,
                                         _ a3: inout UnsafeMutableBufferPointer<T3>?, _ a4: inout UnsafeMutableBufferPointer<T4>?,
                                         _ a5: inout UnsafeMutableBufferPointer<T5>?) {
        assert(argCount == 5)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(Int(argSizes![1]) % MemoryLayout<T2>.size == 0)
        assert(Int(argSizes![2]) % MemoryLayout<T3>.size == 0)
        assert(Int(argSizes![3]) % MemoryLayout<T4>.size == 0)
        assert(Int(argSizes![4]) % MemoryLayout<T5>.size == 0)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(start: args![1]?.bindMemory(to: T2.self, capacity: 1), count: Int(argSizes![1]) / MemoryLayout<T2>.size)
        a3 = .init(start: args![2]?.bindMemory(to: T3.self, capacity: 1), count: Int(argSizes![2]) / MemoryLayout<T3>.size)
        a4 = .init(start: args![3]?.bindMemory(to: T4.self, capacity: 1), count: Int(argSizes![3]) / MemoryLayout<T4>.size)
        a5 = .init(start: args![4]?.bindMemory(to: T5.self, capacity: 1), count: Int(argSizes![4]) / MemoryLayout<T5>.size)
    }

    func ExtractArgs<T1, T2, T3, T4, T5, T6, T7>(_ argCount: Int32, _ args: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, _ argSizes: UnsafeMutablePointer<UInt32>?,
                                         _ a1: inout UnsafeMutablePointer<T1>?, _ a2: inout UnsafeMutableBufferPointer<T2>?,
                                         _ a3: inout UnsafeMutableBufferPointer<T3>?, _ a4: inout UnsafeMutableBufferPointer<T4>?,
                                         _ a5: inout UnsafeMutableBufferPointer<T5>?, _ a6: inout UnsafeMutableBufferPointer<T6>?,
                                         _ a7: inout UnsafeMutableBufferPointer<T7>?) {
        assert(argCount == 7)
        assert(argSizes![0] == MemoryLayout<T1>.size)
        assert(Int(argSizes![1]) % MemoryLayout<T2>.size == 0)
        assert(Int(argSizes![2]) % MemoryLayout<T3>.size == 0)
        assert(Int(argSizes![3]) % MemoryLayout<T4>.size == 0)
        assert(Int(argSizes![4]) % MemoryLayout<T5>.size == 0)
        assert(Int(argSizes![5]) % MemoryLayout<T6>.size == 0)
        assert(Int(argSizes![6]) % MemoryLayout<T7>.size == 0)

        a1 = args![0]?.bindMemory(to: T1.self, capacity: 1)
        a2 = .init(start: args![1]?.bindMemory(to: T2.self, capacity: 1), count: Int(argSizes![1]) / MemoryLayout<T2>.size)
        a3 = .init(start: args![2]?.bindMemory(to: T3.self, capacity: 1), count: Int(argSizes![2]) / MemoryLayout<T3>.size)
        a4 = .init(start: args![3]?.bindMemory(to: T4.self, capacity: 1), count: Int(argSizes![3]) / MemoryLayout<T4>.size)
        a5 = .init(start: args![4]?.bindMemory(to: T5.self, capacity: 1), count: Int(argSizes![4]) / MemoryLayout<T5>.size)
        a6 = .init(start: args![5]?.bindMemory(to: T6.self, capacity: 1), count: Int(argSizes![5]) / MemoryLayout<T6>.size)
        a7 = .init(start: args![6]?.bindMemory(to: T7.self, capacity: 1), count: Int(argSizes![6]) / MemoryLayout<T7>.size)
    }
}

extension ByteBuffer {
    init(for buf: UnsafeMutableBufferPointer<UInt8>?) {
        self = ByteBuffer(assumingMemoryBound: buf!.baseAddress!, capacity: buf!.count)
    }
}
