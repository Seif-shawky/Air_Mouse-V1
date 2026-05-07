import CoreMotion
import Foundation

final class AirMouseController {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var lastTimestamp: TimeInterval?
    private var activeSource: MotionSource?

    var sensitivity: Double = 1.2
    var onMove: ((Double, Double) -> Void)?

    func start() {
        if queue.name == nil {
            queue.name = "AirMouseMotionQueue"
            queue.qualityOfService = .userInteractive
        }

        lastTimestamp = nil

        if motionManager.isDeviceMotionAvailable {
            activeSource = .deviceMotion
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] motion, _ in
                guard let self, let motion else { return }
                self.handleDeviceMotion(motion)
            }
            return
        }

        if motionManager.isGyroAvailable {
            activeSource = .gyro
            motionManager.gyroUpdateInterval = 1.0 / 60.0
            motionManager.startGyroUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.handleRotationRate(data.rotationRate, timestamp: data.timestamp)
            }
            return
        }

        if motionManager.isAccelerometerAvailable {
            activeSource = .accelerometer
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0
            motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.handleAcceleration(data.acceleration, timestamp: data.timestamp)
            }
            return
        }

    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopAccelerometerUpdates()
        lastTimestamp = nil
        activeSource = nil
    }

    private func handleDeviceMotion(_ motion: CMDeviceMotion) {
        handleRotationRate(motion.rotationRate, timestamp: motion.timestamp)
    }

    private func handleRotationRate(_ rotationRate: CMRotationRate, timestamp: TimeInterval) {
        let dt = updateDeltaTime(timestamp)
        let scale = 520.0 * sensitivity
        let dx = rotationRate.y * dt * scale
        let dy = -rotationRate.x * dt * scale
        emitMove(dx: dx, dy: dy)
    }

    private func handleAcceleration(_ acceleration: CMAcceleration, timestamp: TimeInterval) {
        let dt = updateDeltaTime(timestamp)
        let scale = 420.0 * sensitivity
        let dx = acceleration.x * dt * scale
        let dy = -acceleration.y * dt * scale
        emitMove(dx: dx, dy: dy)
    }

    private func updateDeltaTime(_ timestamp: TimeInterval) -> Double {
        defer { lastTimestamp = timestamp }
        guard let lastTimestamp else { return 0.0 }
        return max(0.0, timestamp - lastTimestamp)
    }

    private func emitMove(dx: Double, dy: Double) {
        guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onMove?(dx, dy)
        }
    }
}

private enum MotionSource {
    case deviceMotion
    case gyro
    case accelerometer
}
