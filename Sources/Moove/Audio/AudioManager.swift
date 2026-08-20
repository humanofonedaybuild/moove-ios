import Foundation
import AVFAudio
import MooveKit

@MainActor
final class AudioManager: NSObject {
    static let shared = AudioManager()

    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var wasInterrupted = false
    private var currentSoundName: String?

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
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("AudioManager: failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func playAlarmSound(named soundName: String, preview: Bool = false) {
        currentSoundName = soundName
        guard let url = AudioLibrary.shared.url(for: soundName) else {
            if let fallbackUrl = AudioLibrary.shared.url(for: "default") {
                playSoundFromURL(fallbackUrl, preview: preview)
            }
            return
        }
        playSoundFromURL(url, preview: preview)
    }

    private func playSoundFromURL(_ url: URL, preview: Bool) {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        configureAudioSession()
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            print("AudioManager: failed to create player for \(url.lastPathComponent): \(error.localizedDescription)")
            if let fallbackUrl = AudioLibrary.shared.url(for: "default"),
               fallbackUrl != url {
                audioPlayer = try? AVAudioPlayer(contentsOf: fallbackUrl)
            }
            if audioPlayer == nil { return }
        }
        audioPlayer?.numberOfLoops = preview ? 0 : -1
        audioPlayer?.delegate = self

        let gradual = !preview && AppSettings.load().gradualVolume
        audioPlayer?.volume = gradual ? 0.0 : 1.0
        audioPlayer?.play()
        if gradual {
            audioPlayer?.setVolume(1.0, fadeDuration: Constants.gradualVolumeRampDuration)
        }
    }

    func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentSoundName = nil
        wasInterrupted = false
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print("AudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
    }
}