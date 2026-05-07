import Foundation
import MultipeerConnectivity

@MainActor
final class MultipeerReceiverTransport: NSObject, Transport {
    private let serviceType = "mousephone"
    private let pairingCode: String
    private let peerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private var advertiser: MCNearbyServiceAdvertiser?

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
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["pair": pairingCode],
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        state = .searching
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session.disconnect()
        state = .idle
    }

    func send(_ message: ControlMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? message.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension MultipeerReceiverTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            invitationHandler(true, session)
            state = .connecting(peerID.displayName)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            state = .failed(error.localizedDescription)
        }
    }
}

extension MultipeerReceiverTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.state = .connected(peerID.displayName)
                self.send(.pairAck(.init(code: pairingCode, deviceName: self.peerID.displayName)))
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
