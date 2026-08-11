import SwiftUI
import MooveKit

struct AlarmEditView: View {
    @Environment(AppAlarmManager.self) private var alarmManager
    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var alarmDate: Date
    @State private var weekdays: Set<Int>
    @State private var stepGoal: Int
    @State private var soundName: String
    @State private var snoozeEnabled: Bool
    @State private var showingSoundPicker = false

    let editingConfig: AlarmConfig?
    var isEditing: Bool { editingConfig != nil }

    init(config: AlarmConfig? = nil) {
        editingConfig = config
        _label = State(initialValue: config?.label ?? "")
        _alarmDate = State(initialValue: Self.date(from: config))
        _weekdays = State(initialValue: config?.weekdays ?? [])
        let defaults = AppSettings.load()
        _stepGoal = State(initialValue: config?.stepGoal ?? defaults.defaultStepGoal)
        _soundName = State(initialValue: config?.soundName ?? defaults.defaultSoundName)
        _snoozeEnabled = State(initialValue: config?.snoozeEnabled ?? (defaults.snoozeLimit > 0))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MooveSpacing.xxl) {
                    timeSection
                    labelSection
                    repeatSection
                    stepsSection
                    soundSection
                    snoozeSection
                }
                .padding(MooveSpacing.xl)
            }
            .mooveScreenBackground()
            .navigationTitle(isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.taupe)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAlarm() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.espresso)
                }
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(selectedSound: $soundName)
            }
        }
    }

    private var timeSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Time")

            DatePicker(
                "Alarm Time",
                selection: $alarmDate,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxHeight: 200)
            .tint(.espresso)
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private var labelSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Label")

            TextField("Alarm name", text: $label)
                .font(MooveFont.body())
                .foregroundStyle(Color.espresso)
                .padding(.horizontal, MooveSpacing.lg)
                .padding(.vertical, MooveSpacing.md)
                .mooveField()
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private var repeatSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Repeat")

            WeekdayPicker(selection: $weekdays)

            if !weekdays.isEmpty {
                Text(weekdayDescription)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private var stepsSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Steps Required")

            HStack {
                Text("\(stepGoal)")
                    .font(MooveFont.timePicker())
                    .foregroundStyle(Color.espresso)
                    .frame(minWidth: 80)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("alarmEdit.stepGoal")

                VStack(alignment: .leading, spacing: 2) {
                    Text("steps to wake up")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)
                    Text("\(AlarmConfig.defaultStepRange.lowerBound)–\(AlarmConfig.defaultStepRange.upperBound)")
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe.opacity(0.7))
                }

                Spacer()

                Stepper("Steps", value: $stepGoal, in: stepRange, step: AlarmConfig.stepInterval)
                    .labelsHidden()
                    .tint(.espresso)
            }

            ProgressView(
                value: Double(stepGoal),
                total: Double(AlarmConfig.defaultStepRange.upperBound)
            )
            .tint(.terracotta)
            .background(Color.hairline)
            .clipShape(Capsule())
            .frame(height: 6)
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private var soundSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Sound")

            Button {
                showingSoundPicker = true
            } label: {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(Color.terracotta)

                    Text(soundDisplayName)
                        .foregroundStyle(Color.espresso)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe)
                }
                .padding(.horizontal, MooveSpacing.lg)
                .padding(.vertical, MooveSpacing.md)
                .mooveField()
            }
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private var snoozeSection: some View {
        VStack(spacing: MooveSpacing.md) {
            sectionHeader("Snooze")

            Toggle(isOn: $snoozeEnabled) {
                Text("Allow Snooze")
                    .font(MooveFont.body())
                    .foregroundStyle(Color.espresso)
            }
            .tint(.terracotta)
        }
        .mooveCard(padding: MooveSpacing.xl)
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .mooveEyebrow()
            Spacer()
        }
    }

    private var soundDisplayName: String {
        AudioLibrary.shared.displayName(for: soundName)
    }

    private var weekdayDescription: String {
        let ordered = AlarmConfig.weekdayOrder.filter { weekdays.contains($0) }
        let names = ordered.compactMap { AlarmConfig.weekdayFullSymbols[$0] }
        return names.joined(separator: ", ")
    }

    private var stepRange: ClosedRange<Int> {
        AlarmConfig.defaultStepRange
    }

    private func saveAlarm() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmDate)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0

        let config = AlarmConfig(
            id: editingConfig?.id ?? UUID(),
            label: label.isEmpty ? "Alarm" : label,
            hour: hour,
            minute: minute,
            weekdays: weekdays,
            isEnabled: editingConfig?.isEnabled ?? true,
            stepGoal: stepGoal,
            snoozeRemaining: editingConfig?.snoozeRemaining ?? Constants.maximumSnoozeCount,
            snoozeEnabled: snoozeEnabled,
            soundName: soundName
        )

        if isEditing {
            alarmManager.updateAlarm(config)
        } else {
            alarmManager.addAlarm(config)
        }

        dismiss()
    }

    private static func date(from config: AlarmConfig?) -> Date {
        guard let config else { return Date() }
        return Calendar.current.date(from: DateComponents(hour: config.hour, minute: config.minute)) ?? Date()
    }
}
