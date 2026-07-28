import SwiftUI
import MooveKit
import CoreMotion
import UserNotifications

struct SettingsView: View {
    @Environment(SubscriptionManager.self)
    private var subscriptionManager

    @State private var settings = AppSettings.load()
    @State private var showResetConfirmation = false
    @State private var showingSoundPicker = false
    @Environment(AppAlarmManager.self) private var alarmManager

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                defaultsSection
                snoozeSection
                permissionsSection
                featuresSection
                resetSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .mooveScreenBackground()
            .tint(.terracotta)
            .navigationTitle("Settings")
            .task {
                    refreshNotificationStatus()
                }
            .onChange(of: settings) { _, _ in settings.save() }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView(selectedSound: $settings.defaultSoundName)
            }
            .alert("Reset All Alarms", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) { resetAllAlarms() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your alarms. This action cannot be undone.")
            }
        }
    }

    private var subscriptionSection: some View {
        Section {
            HStack {
                Label("Status", systemImage: "crown.fill")
                    .foregroundStyle(subscriptionManager.isPremium ? Color.terracotta : Color.taupe)
                Spacer()
                Text(subscriptionManager.isPremium ? "Premium" : "Free")
                    .foregroundStyle(subscriptionManager.isPremium ? Color.terracotta : Color.taupe)
                    .fontWeight(.medium)
            }
            .mooveListRow()

            if !subscriptionManager.isPremium {
                Button {
                    subscriptionManager.shouldShowPaywall = true
                } label: {
                    Label("Upgrade to Premium", systemImage: "sparkles")
                        .foregroundStyle(Color.espresso)
                }
                .mooveListRow()
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .foregroundStyle(Color.taupe)
            }
            .mooveListRow()
        } header: {
            Text("Subscription")
                .mooveEyebrow()
        }
    }

    private var defaultsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: MooveSpacing.sm) {
                HStack {
                    Text("\(settings.defaultStepGoal)")
                        .font(MooveFont.timePicker(size: 34))
                        .foregroundStyle(Color.espresso)
                        .contentTransition(.numericText())
                    Text("steps")
                        .font(MooveFont.subheadline())
                        .foregroundStyle(Color.taupe)
                    Spacer()
                    Stepper("Steps", value: $settings.defaultStepGoal, in: stepRange, step: AlarmConfig.stepInterval)
                        .labelsHidden()
                        .tint(.espresso)
                }
                ProgressView(value: Double(settings.defaultStepGoal), total: Double(AlarmConfig.defaultStepRange.upperBound))
                    .tint(.terracotta)
                    .background(Color.hairline)
                    .clipShape(Capsule())
                    .frame(height: 6)
            }
            .mooveListRow()

            Button {
                showingSoundPicker = true
            } label: {
                HStack {
                    Image(systemName: AudioLibrary.shared.icon(for: settings.defaultSoundName))
                        .foregroundStyle(Color.terracotta)
                    VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                        Text("Default Sound")
                            .foregroundStyle(Color.espresso)
                        Text(AudioLibrary.shared.displayName(for: settings.defaultSoundName))
                            .font(MooveFont.caption())
                            .foregroundStyle(Color.taupe)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe)
                }
            }
            .mooveListRow()
        } header: {
            Text("Defaults")
                .mooveEyebrow()
        }
    }

    private var snoozeSection: some View {
        Section {
            Picker(selection: $settings.snoozeLimit) {
                ForEach(Constants.maxSnoozeOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            } label: {
                Label("Max Snooze Limit", systemImage: "moon.zzz.fill")
            }
            .mooveListRow()

            Picker(selection: $settings.snoozeDurationIndex) {
                ForEach(Array(Constants.snoozeOptions.enumerated()), id: \.offset) { index, option in
                    Text(option.label).tag(index)
                }
            } label: {
                Label("Snooze Duration", systemImage: "timer")
            }
            .mooveListRow()

            Toggle(isOn: $settings.gradualVolume) {
                Label("Gradual Volume", systemImage: "speaker.wave.2.fill")
                Text("Slowly increase alarm volume over 30 seconds")
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }
            .tint(.terracotta)
            .mooveListRow()
        } header: {
            Text("Snooze & Sound")
                .mooveEyebrow()
        }
    }

    private var permissionsSection: some View {
        Section {
            PermissionRow(
                icon: "figure.walk.motion",
                title: "Motion & Fitness",
                status: motionAuthorizationStatus
            )
PermissionRow(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    status: notificationStatus
                )
        } header: {
            Text("Permissions")
                .mooveEyebrow()
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $settings.liveActivitiesEnabled) {
                Label("Live Activities", systemImage: "rectangle.inset.filled")
                Text("Show step count on Dynamic Island and Lock Screen")
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }
            .tint(.terracotta)
            .mooveListRow()
        } header: {
            Text("Features")
                .mooveEyebrow()
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset All Alarms", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .mooveListRow()
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .font(MooveFont.body())
                Spacer()
                Text("1.0.0")
                    .font(MooveFont.body())
                    .foregroundStyle(Color.taupe)
            }
            .mooveListRow()
        } header: {
            Text("About")
                .mooveEyebrow()
        }
    }

    private func resetAllAlarms() {
        let allAlarms = alarmManager.alarms
        for alarm in allAlarms {
            alarmManager.deleteAlarm(alarm)
        }
    }

    private var stepRange: ClosedRange<Int> {
        AlarmConfig.defaultStepRange
    }

    private var motionAuthorizationStatus: String {
        if #available(iOS 17.0, *) {
            let status = CMPedometer.authorizationStatus()
            switch status {
            case .authorized: return "Authorized"
            case .denied: return "Denied"
            case .restricted: return "Restricted"
            case .notDetermined: return "Not Determined"
            @unknown default: return "Unknown"
            }
        }
        return CMPedometer.isStepCountingAvailable() ? "Available" : "Unavailable"
    }

    @State private var notificationStatus: String = "Checking..."

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status: String
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: status = "Enabled"
            case .denied: status = "Disabled"
            case .notDetermined: status = "Not Determined"
            @unknown default: status = "Unknown"
            }
            Task { @MainActor in
                self.notificationStatus = status
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let status: String

    @State private var isGranted = true

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.terracotta)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(title)
                    .font(MooveFont.body())
                    .foregroundStyle(Color.espresso)
                Text(status)
                    .font(MooveFont.caption())
                    .foregroundStyle(Color.taupe)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(MooveFont.callout())
            .foregroundStyle(Color.espresso)
        }
        .mooveListRow()
    }
}
