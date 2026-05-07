import AppKit
import CoreAudio
import CoreGraphics
import Foundation

final class MacInputController {
    private let volumeStep: Float32 = 0.06

    func movePointer(dx: Double, dy: Double) {
        guard let location = currentPointerLocation else { return }
        let next = clampedPoint(CGPoint(x: location.x + dx, y: location.y + dy))
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        CGWarpMouseCursorPosition(next)
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), next)
        postMouseEvent(type: .mouseMoved, at: next, button: .left)
    }

    func click(button: PointerButton, phase: ClickPhase) {
        guard let location = currentPointerLocation else { return }
        let cgButton: CGMouseButton = button == .left ? .left : .right

        switch phase {
        case .single:
            postClickEvent(type: downType(for: button), at: location, button: cgButton)
            usleep(12_000)
            postClickEvent(type: upType(for: button), at: location, button: cgButton)
        case .down:
            postClickEvent(type: downType(for: button), at: location, button: cgButton)
        case .up:
            postClickEvent(type: upType(for: button), at: location, button: cgButton)
        }
    }

    func scroll(dx: Double, dy: Double) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        )
        event?.post(tap: .cghidEventTap)
    }

    func changeVolume(delta: Int) {
        guard let deviceID = defaultOutputDeviceID() else { return }
        let currentVolume = outputVolume(for: deviceID) ?? 0.5
        let newVolume = min(max(currentVolume + (Float32(delta) * volumeStep), 0), 1)
        setOutputVolume(newVolume, for: deviceID)
    }

    private func postMouseEvent(type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button)?
            .post(tap: .cghidEventTap)
    }

    private func postClickEvent(type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
            return
        }

        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button.rawValue))
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
    }

    private var currentPointerLocation: CGPoint? {
        CGEvent(source: CGEventSource(stateID: .hidSystemState))?.location
    }

    private func clampedPoint(_ point: CGPoint) -> CGPoint {
        let displays = NSScreen.screens.map(\.frame)
        guard let bounds = displays.reduce(nil, { result, frame in result?.union(frame) ?? frame }) else {
            return point
        }

        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX - 1),
            y: min(max(point.y, bounds.minY), bounds.maxY - 1)
        )
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    private func outputVolume(for deviceID: AudioDeviceID) -> Float32? {
        if let masterVolume = volume(for: deviceID, element: kAudioObjectPropertyElementMain) {
            return masterVolume
        }

        let channels = [UInt32(1), UInt32(2)]
        let volumes = channels.compactMap { volume(for: deviceID, element: $0) }
        guard !volumes.isEmpty else { return nil }
        return volumes.reduce(0, +) / Float32(volumes.count)
    }

    private func setOutputVolume(_ volume: Float32, for deviceID: AudioDeviceID) {
        if setVolume(volume, for: deviceID, element: kAudioObjectPropertyElementMain) {
            return
        }

        _ = setVolume(volume, for: deviceID, element: 1)
        _ = setVolume(volume, for: deviceID, element: 2)
    }

    private func volume(for deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Float32? {
        var address = volumeAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var volume = Float32()
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        return status == noErr ? volume : nil
    }

    private func setVolume(_ volume: Float32, for deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var address = volumeAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isSettable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr, isSettable.boolValue else {
            return false
        }

        var newVolume = volume
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &newVolume) == noErr
    }

    private func volumeAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private func downType(for button: PointerButton) -> CGEventType {
        button == .left ? .leftMouseDown : .rightMouseDown
    }

    private func upType(for button: PointerButton) -> CGEventType {
        button == .left ? .leftMouseUp : .rightMouseUp
    }
}
