import AVFoundation
import MediaPlayer
import SwiftUI

@MainActor
final class VolumeButtonObserver: NSObject {
    private let onChange: (Int) -> Void
    private let audioSession = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var previousVolume: Float = 0
    private let volumeView = MPVolumeView(frame: .zero)

    init(onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        super.init()
    }

    func start() {
        try? audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? audioSession.setActive(true)
        previousVolume = audioSession.outputVolume
        installHiddenVolumeView()

        observation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            Task { @MainActor in
                guard let self, let newValue = change.newValue else { return }
                let delta = newValue > self.previousVolume ? 1 : -1
                self.previousVolume = newValue
                self.onChange(delta)
            }
        }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        volumeView.removeFromSuperview()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func installHiddenVolumeView() {
        guard volumeView.superview == nil else { return }
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        volumeView.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first?
            .addSubview(volumeView)
    }
}
