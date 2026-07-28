import Foundation
import AVFAudio
import MooveKit

@MainActor
final class AudioManager: NSObject {
    static let shared = AudioManager()

    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var wasInterrupted = false

    private override init() {
        super.init()
        observeInterruptions()
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            wasInterrupted = audioPlayer?.isPlaying == true
            audioPlayer?.pause()
        case .ended:
            guard wasInterrupted else { return }
            wasInterrupted = false
            try? audioSession.setActive(true)
            audioPlayer?.play()
        @unknown default:
            break
        }
    }

    func configureAudioSession() {
        try? audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try? audioSession.setActive(true)
    }

    func playAlarmSound(named soundName: String, preview: Bool = false) {
        guard let url = AudioLibrary.shared.url(for: soundName) else { return }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        try? audioSession.setActive(true)
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = preview ? 0 : -1
        audioPlayer?.delegate = self

        let gradual = !preview && AppSettings.load().gradualVolume
        audioPlayer?.volume = gradual ? 0.0 : 1.0
        audioPlayer?.play()
        if gradual {
            // "Slowly increase alarm volume over 30 seconds" (Settings).
            audioPlayer?.setVolume(1.0, fadeDuration: Constants.gradualVolumeRampDuration)
        }
    }

    func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        wasInterrupted = false
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print("AudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
