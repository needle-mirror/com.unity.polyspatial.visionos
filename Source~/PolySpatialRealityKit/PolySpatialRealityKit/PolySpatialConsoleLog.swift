import Foundation
import Combine

public enum PolySpatialConsoleLogType: Int32 {
    case exception = 0
    case assert = 1
    case error = 2
    case warning = 3
    case log = 4
}

public struct PolySpatialConsoleLogItem: Identifiable, Hashable {
    public var id = UUID()
    public let messageType: PolySpatialConsoleLogType
    public let message: String
    public let stackTrace: String
    
    init(messageType: PolySpatialConsoleLogType, message: String, stackTrace: String) {
        self.id = UUID()
        self.message = message
        self.stackTrace = stackTrace
        self.messageType = messageType
    }
}

public final class PolySpatialConsoleLog: ObservableObject {
    public private(set) static var instance: PolySpatialConsoleLog = .init()
    
    @Published public var messages: [PolySpatialConsoleLogItem]
    
    init () {
        messages = .init()
    }
}
