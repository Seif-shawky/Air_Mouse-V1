import Foundation

public enum PointerButton: String, Codable, Sendable {
    case left
    case right
}

public enum ClickPhase: String, Codable, Sendable {
    case down
    case up
    case single
}

public struct PairingPayload: Codable, Equatable, Sendable {
    public let code: String
    public let deviceName: String

    public init(code: String, deviceName: String) {
        self.code = code
        self.deviceName = deviceName
    }
}

public enum ControlMessage: Codable, Equatable, Sendable {
    case pointerMove(dx: Double, dy: Double)
    case airMouseMove(dx: Double, dy: Double)
    case click(button: PointerButton, phase: ClickPhase)
    case scroll(dx: Double, dy: Double)
    case volume(delta: Int)
    case ping(timestamp: TimeInterval)
    case pairRequest(PairingPayload)
    case pairAck(PairingPayload)
}

public extension ControlMessage {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder = JSONDecoder()

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> ControlMessage {
        try Self.decoder.decode(ControlMessage.self, from: data)
    }
}
