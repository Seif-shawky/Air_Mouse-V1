import Foundation

public enum TransportConnectionState: Equatable, Sendable {
    case idle
    case searching
    case connecting(String)
    case connected(String)
    case disconnected(String?)
    case failed(String)
}

@MainActor
public protocol Transport: AnyObject {
    var state: TransportConnectionState { get }
    var onStateChange: ((TransportConnectionState) -> Void)? { get set }
    var onMessage: ((ControlMessage) -> Void)? { get set }

    func start()
    func stop()
    func send(_ message: ControlMessage)
}
