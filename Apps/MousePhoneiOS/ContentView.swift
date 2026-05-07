import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: PhoneControllerModel

    var body: some View {
        VStack(spacing: 0) {
            header

            TouchpadView(
                sensitivity: model.sensitivity,
                onMove: model.sendPointerMove(dx:dy:),
                onClick: { model.sendClick(button: .left) },
                onRightClick: { model.sendClick(button: .right) },
                onScroll: model.sendScroll(dx:dy:)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .onAppear {
            model.start()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MousePhone")
                        .font(.title2.bold())
                    Text(model.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.toggleConnection()
                } label: {
                    Image(systemName: model.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel(model.isRunning ? "Stop connection" : "Start connection")
            }

            HStack {
                Image(systemName: "cursorarrow.motionlines")
                Slider(value: $model.sensitivity, in: 0.5...3.0)
                Text(model.sensitivity, format: .number.precision(.fractionLength(1)))
                    .font(.system(.footnote, design: .monospaced))
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding()
        .background(.thinMaterial)
    }
}

struct TouchpadView: View {
    let sensitivity: Double
    let onMove: (Double, Double) -> Void
    let onClick: () -> Void
    let onRightClick: () -> Void
    let onScroll: (Double, Double) -> Void

    var body: some View {
        ZStack {
            TrackpadSurface(
                sensitivity: sensitivity,
                onMove: onMove,
                onClick: onClick,
                onRightClick: onRightClick,
                onScroll: onScroll
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemBackground))

            VStack(spacing: 18) {
                Image(systemName: "hand.point.up.left")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Touchpad")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .ignoresSafeArea(edges: .bottom)
    }
}

struct TrackpadSurface: UIViewRepresentable {
    let sensitivity: Double
    let onMove: (Double, Double) -> Void
    let onClick: () -> Void
    let onRightClick: () -> Void
    let onScroll: (Double, Double) -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = onMove
        view.onClick = onClick
        view.onRightClick = onRightClick
        view.onScroll = onScroll
        view.sensitivity = sensitivity
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.onMove = onMove
        uiView.onClick = onClick
        uiView.onRightClick = onRightClick
        uiView.onScroll = onScroll
        uiView.sensitivity = sensitivity
    }
}

final class TrackpadUIView: UIView {
    var sensitivity = 1.2
    var onMove: ((Double, Double) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onScroll: ((Double, Double) -> Void)?

    private var lastCentroid: CGPoint?
    private var touchStartDate: Date?
    private var longPressWorkItem: DispatchWorkItem?
    private var didMove = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let allTouches = event?.allTouches else { return }
        lastCentroid = centroid(for: allTouches)
        touchStartDate = Date()
        didMove = false

        longPressWorkItem?.cancel()
        if allTouches.count == 1 {
            let item = DispatchWorkItem { [weak self] in
                self?.onRightClick?()
            }
            longPressWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let allTouches = event?.allTouches, let previous = lastCentroid else { return }
        let current = centroid(for: allTouches)
        let dx = current.x - previous.x
        let dy = current.y - previous.y

        if abs(dx) > 1 || abs(dy) > 1 {
            didMove = true
            longPressWorkItem?.cancel()
        }

        if allTouches.count >= 2 {
            onScroll?(Double(dx), Double(dy))
        } else {
            onMove?(Double(dx) * sensitivity, Double(dy) * sensitivity)
        }

        lastCentroid = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { resetGestureState() }
        guard !didMove, let touchStartDate else { return }
        if Date().timeIntervalSince(touchStartDate) < 0.35 {
            onClick?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetGestureState()
    }

    private func resetGestureState() {
        lastCentroid = nil
        touchStartDate = nil
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        didMove = false
    }

    private func centroid(for touches: Set<UITouch>) -> CGPoint {
        let points = touches.map { $0.location(in: self) }
        let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }
}

@MainActor
final class PhoneControllerModel: ObservableObject {
    @Published var sensitivity = 1.2
    @Published private(set) var statusText = "Searching for Mac"
    @Published private(set) var isRunning = false

    private let pairingCode = "000000"
    private lazy var transport: MultipeerControllerTransport = {
        let transport = MultipeerControllerTransport(pairingCode: pairingCode)
        transport.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }
        return transport
    }()
    private lazy var volumeObserver = VolumeButtonObserver { [weak self] delta in
        self?.transport.send(.volume(delta: delta))
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        transport.start()
        volumeObserver.start()
    }

    func toggleConnection() {
        isRunning ? stop() : start()
    }

    func stop() {
        isRunning = false
        transport.stop()
        volumeObserver.stop()
    }

    func sendPointerMove(dx: Double, dy: Double) {
        transport.send(.pointerMove(dx: dx, dy: dy))
    }

    func sendClick(button: PointerButton) {
        transport.send(.click(button: button, phase: .single))
    }

    func sendScroll(dx: Double, dy: Double) {
        transport.send(.scroll(dx: dx, dy: dy))
    }

    private func handleStateChange(_ state: TransportConnectionState) {
        switch state {
        case .idle:
            statusText = "Idle"
        case .searching:
            statusText = "Searching for Mac"
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
}
