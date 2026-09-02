import XCTest
@testable import MooveKit
@testable import Moove

/// Item 5 (import path) of the MOO-87 QA matrix: local file import into the
/// audio library. The UI-level file picker is system-owned; the import logic
/// itself is verified here end-to-end (copy → catalog → resolve → delete).
@MainActor
final class AudioLibraryImportTests: XCTestCase {

    private var importedSoundID: String?

    override func tearDown() async throws {
        if let id = importedSoundID,
           let sound = AudioLibrary.shared.allSounds.first(where: { $0.id == id }) {
            AudioLibrary.shared.removeImportedSound(sound)
        }
        importedSoundID = nil
        try await super.tearDown()
    }

    func testImportSoundFromLocalFile() async throws {
        // Stage a fake "user file": copy a bundled CAF to a temp location with
        // a custom name, as if picked from the Files app. Sounds are flattened
        // to the bundle root (AlarmKit named-sound requirement).
        guard let bundled = Bundle.main.url(
            forResource: "argon", withExtension: "caf"
        ) else {
            XCTFail("Bundled test sound missing")
            return
        }
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent("My Custom Alarm.m4a")
        try? FileManager.default.removeItem(at: staged)
        try FileManager.default.copyItem(at: bundled, to: staged)

        let sound = await AudioLibrary.shared.importSound(from: staged)
        let imported = try XCTUnwrap(sound, "Import of a supported audio file must succeed")
        importedSoundID = imported.id

        XCTAssertTrue(imported.id.hasPrefix("imported_"))
        XCTAssertEqual(imported.displayName, "My Custom Alarm")
        XCTAssertTrue(
            AudioLibrary.shared.allSounds.contains(where: { $0.id == imported.id }),
            "Imported sound must appear in the library"
        )

        // The imported sound must resolve to a playable URL.
        let url = AudioLibrary.shared.url(for: imported.id)
        XCTAssertNotNil(url, "Imported sound must resolve to a file URL")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(url).path))

        // Unsupported extensions are rejected.
        let textFile = FileManager.default.temporaryDirectory.appendingPathComponent("notes.txt")
        try "not audio".write(to: textFile, atomically: true, encoding: .utf8)
        let rejected = await AudioLibrary.shared.importSound(from: textFile)
        XCTAssertNil(rejected, "Unsupported file types must be rejected")
    }
}
