import Foundation
import AVFAudio
import AVFoundation
import MooveKit

@MainActor
final class AudioLibrary {
    static let shared = AudioLibrary()

    struct Sound: Identifiable {
        let id: String
        let displayName: String
        let filename: String
        let icon: String
        var duration: TimeInterval?

        var formattedDuration: String {
            guard let duration else { return "--:--" }
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private(set) var builtInSounds: [Sound] = []
    private var importedSounds: [Sound] = []
    private let importedSoundsKey = "importedSoundsMetadata"

    private init() {
        builtInSounds = Self.defaultBuiltInSounds
        updateBuiltInDurations()
        loadImportedMetadata()
    }

    func reloadSounds() {
        builtInSounds = Self.defaultBuiltInSounds
        updateBuiltInDurations()
    }

    var allSounds: [Sound] {
        builtInSounds + importedSounds
    }

    func url(for soundName: String) -> URL? {
        if let _ = importedSounds.first(where: { $0.id == soundName }),
           let url = importedFileURL(for: soundName) {
            return url
        }
        if let builtIn = builtInSounds.first(where: { $0.id == soundName }) {
            // Sounds are flattened into the bundle root so AlarmKit can
            // resolve them via `AlertSound.named`; the subdirectory
            // lookup stays as a fallback for older bundle layouts.
            return Bundle.main.url(forResource: builtIn.filename, withExtension: "caf")
                ?? Bundle.main.url(
                    forResource: builtIn.filename,
                    withExtension: "caf",
                    subdirectory: "Sounds"
                )
        }
        return nil
    }

    /// The sound to play when a stored id no longer resolves (e.g. the
    /// legacy placeholder library was removed).
    var fallbackSoundName: String { "barium" }

    func displayName(for soundName: String) -> String {
        builtInSounds.first { $0.id == soundName }?.displayName
            ?? importedSounds.first { $0.id == soundName }?.displayName
            ?? "Default Alarm"
    }

    func icon(for soundName: String) -> String {
        builtInSounds.first { $0.id == soundName }?.icon
            ?? importedSounds.first { $0.id == soundName }?.icon
            ?? "music.note"
    }

    func search(_ query: String) -> [Sound] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return allSounds }
        let q = query.lowercased()
        return allSounds.filter { sound in
            sound.displayName.lowercased().contains(q) || sound.id.lowercased().contains(q)
        }
    }

    private let allowedExtensions: Set<String> = ["m4a", "wav", "mp3", "caf"]

    func importSound(from sourceURL: URL) async -> Sound? {
        let ext = sourceURL.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { return nil }

        let fileManager = FileManager.default
        let soundId = "imported_\(UUID().uuidString.prefix(8))"
        let displayName = sourceURL.deletingPathExtension().lastPathComponent
        let destination = importedSoundsDirectory().appendingPathComponent("\(soundId).\(ext)")

        do {
            try fileManager.createDirectory(at: importedSoundsDirectory(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)

            let asset = AVURLAsset(url: destination)
            let duration = (try? await asset.load(.duration))?.seconds

            let sound = Sound(
                id: soundId,
                displayName: displayName,
                filename: destination.lastPathComponent,
                icon: "waveform",
                duration: duration
            )
            importedSounds.append(sound)
            saveImportedMetadata()
            return sound
        } catch {
            print("AudioLibrary: failed to import sound: \(error.localizedDescription)")
            return nil
        }
    }

    func removeImportedSound(_ sound: Sound) {
        importedSounds.removeAll { $0.id == sound.id }
        if let url = importedFileURL(for: sound.id) {
            try? FileManager.default.removeItem(at: url)
        }
        saveImportedMetadata()
    }

    private func importedFileURL(for soundId: String) -> URL? {
        guard let sound = importedSounds.first(where: { $0.id == soundId }) else { return nil }
        return importedSoundsDirectory().appendingPathComponent(sound.filename)
    }

    private func importedSoundsDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("ImportedSounds", isDirectory: true)
    }

    private struct ImportedSoundMeta: Codable {
        let id: String
        let displayName: String
        let filename: String
    }

    private func saveImportedMetadata() {
        let meta = importedSounds.map { ImportedSoundMeta(id: $0.id, displayName: $0.displayName, filename: $0.filename) }
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults(suiteName: Constants.appGroupIdentifier)?
                .set(data, forKey: importedSoundsKey)
        }
    }

    private func loadImportedMetadata() {
        guard let data = UserDefaults(suiteName: Constants.appGroupIdentifier)?
            .data(forKey: importedSoundsKey),
              let meta = try? JSONDecoder().decode([ImportedSoundMeta].self, from: data)
        else { return }
        importedSounds = meta.compactMap { meta in
            let url = importedSoundsDirectory().appendingPathComponent(meta.filename)
            guard fileExists(at: url) else { return nil }
            return Sound(
                id: meta.id,
                displayName: meta.displayName,
                filename: meta.filename,
                icon: "waveform",
                duration: nil
            )
        }
    }

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func updateBuiltInDurations() {
        builtInSounds = builtInSounds.map { sound in
            var s = sound
            if let url = Bundle.main.url(forResource: s.filename, withExtension: "caf", subdirectory: "Sounds"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                s.duration = player.duration
            }
            return s
        }
    }

    /// File name (without extension) AlarmKit should ring on the lock
    /// screen. The sound is bundled at the app-bundle root so the system
    /// resolves it via `AlertConfiguration.AlertSound.named`.
    nonisolated static func alarmKitSoundName(for soundName: String) -> String {
        let mapping: [String: String] = [
            "analysis": "analysis",
            "argon": "argon",
            "barium": "barium",
            "carbon": "carbon",
            "cesium": "cesium",
            "copernicium": "copernicium",
            "curium": "curium",
            "departure": "departure",
            "firedrill": "firedrill",
            "hassium": "hassium",
            "krypton": "krypton",
            "neon": "neon",
            "osmium": "osmium",
            "platinum": "platinum",
            "scandium": "scandium",
            "timing": "timing",
        ]
        return mapping[soundName] ?? "barium"
    }

    /// Built-in alarm sound library. All 16 sounds are distinct, real
    /// alarm audio from the Android Open Source Project (Apache 2.0) —
    /// see `SOUNDS-ATTRIBUTION.md` for source and license details. The
    /// previous five bundled sounds were synthesized placeholders that
    /// sounded identical (MOO-175 bug #5).
    private static let defaultBuiltInSounds: [Sound] = [
        Sound(id: "barium",       displayName: "Barium",       filename: "barium",       icon: "sunrise.fill"),
        Sound(id: "cesium",       displayName: "Cesium",       filename: "cesium",       icon: "bell.fill"),
        Sound(id: "argon",        displayName: "Argon",        filename: "argon",        icon: "sparkles"),
        Sound(id: "carbon",       displayName: "Carbon",      filename: "carbon",       icon: "dot.radiowaves.left.and.right"),
        Sound(id: "analysis",     displayName: "Analysis",     filename: "analysis",     icon: "waveform"),
        Sound(id: "departure",    displayName: "Departure",    filename: "departure",    icon: "paperplane.fill"),
        Sound(id: "firedrill",    displayName: "Fire Drill",   filename: "firedrill",    icon: "siren.fill"),
        Sound(id: "hassium",      displayName: "Hassium",      filename: "hassium",      icon: "speaker.wave.3.fill"),
        Sound(id: "krypton",      displayName: "Krypton",      filename: "krypton",      icon: "bolt.fill"),
        Sound(id: "neon",         displayName: "Neon",         filename: "neon",         icon: "lightbulb.fill"),
        Sound(id: "osmium",       displayName: "Osmium",       filename: "osmium",       icon: "water.waves"),
        Sound(id: "platinum",     displayName: "Platinum",     filename: "platinum",     icon: "crown.fill"),
        Sound(id: "scandium",     displayName: "Scandium",     filename: "scandium",     icon: "metronome"),
        Sound(id: "timing",       displayName: "Timing",       filename: "timing",       icon: "timer"),
        Sound(id: "copernicium",  displayName: "Copernicium",  filename: "copernicium",  icon: "music.note"),
        Sound(id: "curium",       displayName: "Curium",       filename: "curium",       icon: "music.quarternote.3"),
    ]

    /// Migrates legacy sound ids (the old placeholder library and the
    /// pre-MOO-150 names) to the closest current sound.
    private static let legacySoundMigrationMap: [String: String] = [
        "default": "barium",
        "gentle": "argon",
        "nature": "platinum",
        "urgent": "firedrill",
        "digital": "carbon",
        "breeze": "argon",
        "birds": "platinum",
        "waves": "osmium",
        // Raw filenames should never appear as ids, but tolerate them.
        "default_alarm": "barium",
        "gentle_wake": "argon",
    ]

    static func migrateSoundName(_ name: String) -> String {
        legacySoundMigrationMap[name] ?? name
    }
}
