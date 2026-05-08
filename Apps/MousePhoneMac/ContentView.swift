import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: MacReceiverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "iphone.gen2.radiowaves.left.and.right")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("MousePhone")
                        .font(.largeTitle.bold())
                    Text(model.statusText)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(model.accessibilityStatusText, systemImage: model.hasAccessibilityAccess ? "checkmark.shield" : "exclamationmark.triangle")
                    .foregroundStyle(model.hasAccessibilityAccess ? .green : .orange)

                if !model.hasAccessibilityAccess {
                    Button("Open Accessibility Permission Prompt") {
                        model.requestAccessibilityAccess()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Pairing Code")
                    .font(.headline)
                Text(model.pairingCode)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Input")
                    .font(.headline)
                Text(model.lastInputText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Test Cursor Move") {
                    model.testCursorMove()
                }
                .buttonStyle(.bordered)

                Button("Test Click") {
                    model.testClick()
                }
                .buttonStyle(.bordered)

                Button(model.isRunning ? "Stop Receiver" : "Start Receiver") {
                    model.toggleReceiver()
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh Permission") {
                    model.refreshAccessibilityStatus()
                }
            }

            Spacer()
        }
        .padding(28)
        .onAppear {
            model.start()
        }
    }
}

@MainActor
final class MacReceiverModel: ObservableObject {
    @Published private(set) var statusText = "Waiting for iPhone"
    @Published private(set) var pairingCode = String(format: "%06d", Int.random(in: 0...999_999))
    @Published private(set) var hasAccessibilityAccess = AccessibilityController.isTrusted
    @Published private(set) var isRunning = false
    @Published private(set) var lastInputText = "No input received yet"

    private let inputController = MacInputController()
    private lazy var transport: MultipeerReceiverTransport = {
        let transport = MultipeerReceiverTransport(pairingCode: pairingCode)
        transport.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }
        transport.onMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        return transport
    }()

    var accessibilityStatusText: String {
        hasAccessibilityAccess ? "Accessibility access is enabled" : "Accessibility access is reported disabled"
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        transport.start()
        refreshAccessibilityStatus()
    }

    func toggleReceiver() {
        isRunning ? stop() : start()
    }

    func stop() {
        isRunning = false
        transport.stop()
    }

    func requestAccessibilityAccess() {
        AccessibilityController.requestAccess()
        refreshAccessibilityStatus()
    }

    func refreshAccessibilityStatus() {
        hasAccessibilityAccess = AccessibilityController.isTrusted
    }

    func testCursorMove() {
        refreshAccessibilityStatus()
        inputController.movePointer(dx: 120, dy: 0)
        lastInputText = hasAccessibilityAccess ? "Local move test sent" : "Local move test sent despite Accessibility warning"
    }

    func testClick() {
        refreshAccessibilityStatus()
        guard hasAccessibilityAccess else {
            AccessibilityController.requestAccess()
            refreshAccessibilityStatus()
            lastInputText = "Click blocked: enable Accessibility access"
            return
        }

        let clicked = inputController.click(button: .left, phase: .single)
        lastInputText = clicked ? "Local click sent" : "Local click failed"
    }

    private func handleStateChange(_ state: TransportConnectionState) {
        switch state {
        case .idle:
            statusText = "Idle"
        case .searching:
            statusText = "Waiting for iPhone"
        case .connecting(let peer):
            statusText = "Connecting to \(peer)"
        case .connected(let peer):
            statusText = "Connected to \(peer)"
        case .disconnected(let reason):
            statusText = reason ?? "Disconnected"
        case .failed(let message):
            statusText = message
        }
    }

    private func handleMessage(_ message: ControlMessage) {
        refreshAccessibilityStatus()

        switch message {
        case .pointerMove(let dx, let dy):
            lastInputText = "Move dx \(Int(dx)), dy \(Int(dy))"
            inputController.movePointer(dx: dx, dy: dy)
        case .airMouseMove(let dx, let dy):
            lastInputText = "Air mouse dx \(Int(dx)), dy \(Int(dy))"
            inputController.movePointer(dx: dx, dy: dy)
        case .click(let button, let phase):
            guard hasAccessibilityAccess else {
                AccessibilityController.requestAccess()
                refreshAccessibilityStatus()
                lastInputText = "\(button.rawValue.capitalized) click blocked: enable Accessibility access"
                return
            }

            let clicked = inputController.click(button: button, phase: phase)
            lastInputText = clicked ? "\(button.rawValue.capitalized) click \(phase.rawValue)" : "\(button.rawValue.capitalized) click failed"
        case .scroll(let dx, let dy):
            lastInputText = "Scroll dx \(Int(dx)), dy \(Int(dy))"
            inputController.scroll(dx: dx, dy: dy)
        case .volume(let delta):
            lastInputText = "Volume \(delta > 0 ? "up" : "down")"
            inputController.changeVolume(delta: delta)
        case .ping, .pairRequest, .pairAck:
            break
        }
    }
}
