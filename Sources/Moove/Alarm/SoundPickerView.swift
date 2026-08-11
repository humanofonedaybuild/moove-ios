import SwiftUI
import MooveKit
import UniformTypeIdentifiers

struct SoundPickerView: View {
    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var playingSoundId: String?
    @State private var showingFilePicker = false

    private let audioManager = AudioManager.shared
    private let audioLibrary = AudioLibrary.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, MooveSpacing.lg)
                    .padding(.vertical, MooveSpacing.md)

                List {
                    if !searchQuery.isEmpty {
                        // Search results
                        let results = audioLibrary.search(searchQuery)
                        if results.isEmpty {
                            Text("No sounds match \"\(searchQuery)\"")
                                .font(MooveFont.subheadline())
                                .foregroundStyle(Color.taupe)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(results) { sound in
                                soundRow(sound)
                            }
                        }
                    } else {
                        // Bundled section
                        Section {
                            ForEach(audioLibrary.builtInSounds) { sound in
                                soundRow(sound)
                            }
                        } header: {
                            Text("Bundled")
                                .mooveEyebrow()
                        }

                        // Imported section
                        let imported = importedSounds
                        if !imported.isEmpty {
                            Section {
                                ForEach(imported) { sound in
                                    soundRow(sound)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                audioLibrary.removeImportedSound(sound)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text("Imported")
                                    .mooveEyebrow()
                            }
                        }

                        // Import button
                        Section {
                            importButton
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .tint(.terracotta)
            }
            .mooveScreenBackground()
            .navigationTitle("Audio Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.taupe)
                }
                if !searchQuery.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Clear") {
                            withAnimation { searchQuery = "" }
                        }
                        .foregroundStyle(Color.espresso)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: MooveSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.taupe)
                .font(MooveFont.subheadline())

            TextField("Search sounds...", text: $searchQuery)
                .font(MooveFont.subheadline())
                .foregroundStyle(Color.espresso)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    withAnimation { searchQuery = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.taupe)
                }
            }
        }
        .padding(.horizontal, MooveSpacing.md)
        .padding(.vertical, MooveSpacing.sm)
        .mooveField()
    }

    private func soundRow(_ sound: AudioLibrary.Sound) -> some View {
        HStack(spacing: MooveSpacing.lg) {
            Image(systemName: sound.icon)
                .font(MooveFont.title3())
                .foregroundStyle(sound.id == selectedSound ? Color.terracotta : Color.taupe)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(sound.displayName)
                    .font(MooveFont.body())
                    .fontWeight(sound.id == selectedSound ? .semibold : .regular)
                    .foregroundStyle(Color.espresso)

                Text(sound.formattedDuration)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }

            Spacer()

            if sound.id == selectedSound {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.terracotta)
                    .font(MooveFont.title3())
            }

            Button {
                togglePlay(sound)
            } label: {
                Group {
                    if playingSoundId == sound.id {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(Color.terracotta)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Color.espresso)
                    }
                }
                .font(MooveFont.title3())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("soundPicker.play.\(sound.id)")
        }
        .padding(.vertical, MooveSpacing.xs)
        .padding(.horizontal, MooveSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: MooveCornerRadius.sm)
                .stroke(sound.id == selectedSound ? Color.terracotta.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSound = sound.id
            dismiss()
        }
        .mooveListRow()
    }

    private var importButton: some View {
        Button {
            showingFilePicker = true
        } label: {
            HStack {
                Spacer()
                VStack(spacing: MooveSpacing.sm) {
                    Image(systemName: "square.and.arrow.down")
                        .font(MooveFont.title2())
                    Text("Import from Files")
                        .font(MooveFont.subheadline())
                        .fontWeight(.medium)
                    Text("Supports .m4a, .wav, .mp3")
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe)
                }
                .padding(.vertical, MooveSpacing.xl)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: MooveCornerRadius.md)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.hairline)
            )
            .foregroundStyle(Color.espresso)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: MooveSpacing.sm, leading: 0, bottom: MooveSpacing.sm, trailing: 0))
    }

    private func togglePlay(_ sound: AudioLibrary.Sound) {
        if playingSoundId == sound.id {
            audioManager.stopAlarmSound()
            playingSoundId = nil
        } else {
            if playingSoundId != nil {
                audioManager.stopAlarmSound()
            }
            audioManager.playAlarmSound(named: sound.id, preview: true)
            playingSoundId = sound.id
        }
    }

    private var importedSounds: [AudioLibrary.Sound] {
        audioLibrary.allSounds.filter { $0.id.hasPrefix("imported_") }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            Task {
                let sound = await audioLibrary.importSound(from: url)
                if sound != nil {
                    selectedSound = sound!.id
                    dismiss()
                }
            }
        case .failure:
            break
        }
    }
}
