import Foundation
import MultipeerConnectivity
import UIKit

@MainActor
final class MultipeerControllerTransport: NSObject, Transport {
    private let serviceType = "mousephone"
    private let pairingCode: String
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private var browser: MCNearbyServiceBrowser?

    private(set) var state: TransportConnectionState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((TransportConnectionState) -> Void)?
    var onMessage: ((ControlMessage) -> Void)?

    init(pairingCode: String) {
        self.pairingCode = pairingCode
        super.init()
        session.delegate = self
    }

    func start() {
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        state = .searching
    }

    func stop() {
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        state = .idle
    }

    func send(_ message: ControlMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? message.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}

extension MultipeerControllerTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
            state = .connecting(peerID.displayName)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            state = .disconnected("Lost \(peerID.displayName)")
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            state = .failed(error.localizedDescription)
        }
    }
}

extension MultipeerControllerTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.state = .connected(peerID.displayName)
                self.send(.pairRequest(.init(code: pairingCode, deviceName: self.peerID.displayName)))
            case .connecting:
                self.state = .connecting(peerID.displayName)
            case .notConnected:
                self.state = .disconnected("Disconnected from \(peerID.displayName)")
            @unknown default:
                self.state = .failed("Unknown connection state")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard let message = try? ControlMessage.decoded(from: data) else { return }
            onMessage?(message)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
