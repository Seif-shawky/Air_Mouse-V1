import SwiftUI
import UIKit
import CoreMotion

enum ControllerInputMode: String, CaseIterable, Identifiable {
    case touchpad
    case airMouse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .touchpad:
            "Touchpad"
        case .airMouse:
            "Air Mouse"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: PhoneControllerModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch model.inputMode {
                case .touchpad:
                    TouchpadView(
                        sensitivity: model.sensitivity,
                        onMove: model.sendPointerMove(dx:dy:),
                        onClick: { model.sendClick(button: .left) },
                        onRightClick: { model.sendClick(button: .right) },
                        onScroll: model.sendScroll(dx:dy:)
                    )
                case .airMouse:
                    AirMouseView(
                        statusText: model.airMouseStatusText,
                        onCalibrate: model.calibrateAirMouse,
                        onLeftClick: { model.sendClick(button: .left) },
                        onRightClick: { model.sendClick(button: .right) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground))
        .onAppear {
            model.start()
            model.updateMotionCapture()
        }
        .onDisappear {
            model.stopMotionCapture()
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

            Picker("Input mode", selection: $model.inputMode) {
                ForEach(ControllerInputMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: model.inputMode == .airMouse ? "gyroscope" : "cursorarrow.motionlines")
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

struct AirMouseView: View {
    let statusText: String
    let onCalibrate: () -> Void
    let onLeftClick: () -> Void
    let onRightClick: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "gyroscope")
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Air Mouse")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: onCalibrate) {
                Label("Calibrate", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            HStack(spacing: 14) {
                Button(action: onLeftClick) {
                    Label("Left Click", systemImage: "cursorarrow.click")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onRightClick) {
                    Label("Right Click", systemImage: "contextualmenu.and.cursorarrow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .ignoresSafeArea(edges: .bottom)
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
    @Published var inputMode: ControllerInputMode = .touchpad {
        didSet {
            updateMotionCapture()
        }
    }
    @Published private(set) var statusText = "Searching for Mac"
    @Published private(set) var airMouseStatusText = "Point your iPhone like a remote"
    @Published private(set) var isRunning = false

    private let pairingCode = "000000"
    private let motionManager = CMMotionManager()
    private let airMouseDeadzone = 0.008
    private let airMouseSendInterval = 1.0 / 20.0
    private let maxAirMouseStep = 420.0
    private let airMouseGain = 18_000.0
    private let airMouseSmoothing = 0.45
    private var latestAttitude: CMAttitude?
    private var referenceAttitude: CMAttitude?
    private var airMouseSendTimer: Timer?
    private var smoothedAirMouseDX = 0.0
    private var smoothedAirMouseDY = 0.0
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
        updateMotionCapture()
    }

    func toggleConnection() {
        isRunning ? stop() : start()
    }

    func stop() {
        isRunning = false
        transport.stop()
        volumeObserver.stop()
        stopMotionCapture()
    }

    func sendPointerMove(dx: Double, dy: Double) {
        transport.send(.pointerMove(dx: dx, dy: dy))
    }

    func sendAirMouseMove(dx: Double, dy: Double) {
        transport.send(.airMouseMove(dx: dx, dy: dy))
    }

    func sendClick(button: PointerButton) {
        transport.sendReliably(.click(button: button, phase: .single))
    }

    func sendScroll(dx: Double, dy: Double) {
        transport.send(.scroll(dx: dx, dy: dy))
    }

    func calibrateAirMouse() {
        guard let latestAttitude else {
            airMouseStatusText = "Hold still for a moment"
            return
        }

        referenceAttitude = latestAttitude.copy() as? CMAttitude
        airMouseStatusText = "Calibrated"
    }

    func updateMotionCapture() {
        guard isRunning, inputMode == .airMouse else {
            stopMotionCapture()
            return
        }

        guard motionManager.isDeviceMotionAvailable else {
            airMouseStatusText = "Motion sensors are unavailable"
            return
        }

        startAirMouseSendTimer()

        if !motionManager.isDeviceMotionActive {
            airMouseStatusText = "Move the iPhone through the air"
            motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                self.handleMotionUpdate(motion)
            }
        }
    }

    func stopMotionCapture() {
        airMouseSendTimer?.invalidate()
        airMouseSendTimer = nil

        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }

        latestAttitude = nil
        referenceAttitude = nil
        smoothedAirMouseDX = 0
        smoothedAirMouseDY = 0
        airMouseStatusText = "Point your iPhone like a remote"
    }

    private func handleMotionUpdate(_ motion: CMDeviceMotion) {
        latestAttitude = motion.attitude.copy() as? CMAttitude
        guard let latestAttitude else { return }

        if referenceAttitude == nil {
            referenceAttitude = latestAttitude.copy() as? CMAttitude
            airMouseStatusText = "Calibrated"
        }

        guard let referenceAttitude else { return }

        let relative = latestAttitude.copy() as? CMAttitude
        relative?.multiply(byInverseOf: referenceAttitude)

        guard let relative else { return }
        let rawDX = -relative.yaw
        let rawDY = -relative.pitch

        guard abs(rawDX) > airMouseDeadzone || abs(rawDY) > airMouseDeadzone else {
            smoothedAirMouseDX *= 0.55
            smoothedAirMouseDY *= 0.55
            return
        }

        let gain = airMouseGain * sensitivity * airMouseSendInterval
        let targetDX = rawDX.removingDeadzone(airMouseDeadzone) * gain
        let targetDY = rawDY.removingDeadzone(airMouseDeadzone) * gain
        smoothedAirMouseDX += (targetDX - smoothedAirMouseDX) * airMouseSmoothing
        smoothedAirMouseDY += (targetDY - smoothedAirMouseDY) * airMouseSmoothing
    }

    private func startAirMouseSendTimer() {
        guard airMouseSendTimer == nil else { return }

        airMouseSendTimer = Timer.scheduledTimer(withTimeInterval: airMouseSendInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushAirMouseMove()
            }
        }
        RunLoop.main.add(airMouseSendTimer!, forMode: .common)
    }

    private func flushAirMouseMove() {
        let dx = smoothedAirMouseDX.clamped(to: -maxAirMouseStep...maxAirMouseStep)
        let dy = smoothedAirMouseDY.clamped(to: -maxAirMouseStep...maxAirMouseStep)
        guard abs(dx) >= 0.5 || abs(dy) >= 0.5 else { return }
        sendAirMouseMove(dx: dx, dy: dy)
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func removingDeadzone(_ deadzone: Double) -> Double {
        guard abs(self) > deadzone else { return 0 }
        return self > 0 ? self - deadzone : self + deadzone
    }
}
