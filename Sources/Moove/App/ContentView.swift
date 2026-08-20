import SwiftUI
import MooveKit

struct ContentView: View {
    @AppStorage(LaunchSequence.onboardingCompletedKey)
    private var hasCompletedOnboarding = false

    @Environment(AppAlarmManager.self)
    private var alarmManager

    @Environment(SubscriptionManager.self)
    private var subscriptionManager

    @State private var activationStamp = 0

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainContent
            } else {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed && !subscriptionManager.isPremium {
                subscriptionManager.shouldShowPaywall = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            activationStamp += 1
        }
    }

    private var mainContent: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.espresso)
        .fullScreenCover(isPresented: .init(
            get: {
                _ = activationStamp
                return alarmManager.activeMission != nil
                    || alarmManager.alarmState == .firing
                    || alarmManager.alarmState == .missionActive
                    || alarmManager.alarmState == .stopped
            },
            set: { if !$0 { alarmManager.cancelMission() } }
        )) {
            AlarmMissionView()
        }
        .fullScreenCover(isPresented: .init(
            get: { subscriptionManager.requiresHardPaywall },
            set: { _ in }
        )) {
            PaywallView(mode: .required)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: .init(
            get: {
                !subscriptionManager.requiresHardPaywall
                    && !subscriptionManager.isPremium
                    && subscriptionManager.shouldShowPaywall
            },
            set: { if !$0 { subscriptionManager.shouldShowPaywall = false } }
        )) {
            PaywallView(mode: .optional)
        }
    }
}

struct AlarmListView: View {
    @Environment(AppAlarmManager.self)
    private var alarmManager

    @Environment(SubscriptionManager.self)
    private var subscriptionManager

    @State private var showingAddSheet = false
    @State private var editingConfig: AlarmConfig?
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if alarmManager.alarms.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .safeAreaInset(edge: .top) {
                if subscriptionManager.shouldShowGraceBanner {
                    TrialGraceBanner(endsAt: subscriptionManager.subscriptionAccess.graceEndsAt)
                }
            }
            .mooveScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.espresso)
                    }
                    .accessibilityIdentifier("alarmList.addButton")
                }
            }
            .sheet(isPresented: $showingAddSheet, onDismiss: clearEditState) {
                AlarmEditView()
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: clearEditState) {
                AlarmEditView(config: editingConfig)
            }
        }
        .overlay(alignment: .topLeading) {
            Image("MooveMonogram")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 48)
                .padding(.leading, 20)
                .padding(.top, 6)
                .accessibilityLabel("Moove")
                .accessibilityIdentifier("alarmList.monogram")
        }
    }

    private func clearEditState() {
        editingConfig = nil
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MooveSpacing.huge)

            Image(systemName: "alarm")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.terracotta.opacity(0.12)))
                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))

            Text("No alarms yet")
                .mooveEyebrow()
                .padding(.top, MooveSpacing.xxxl)

            Text("Wake up.")
                .font(MooveFont.largeTitle())
                .foregroundStyle(Color.espresso)
                .padding(.top, MooveSpacing.lg)

            Text("Set your first alarm — you'll have to walk to stop it.")
                .font(MooveFont.body())
                .foregroundStyle(Color.taupe)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
                .padding(.top, MooveSpacing.xl)

            Button(action: { showingAddSheet = true }) {
                Text("Create Alarm")
            }
            .mooveButton(.primary)
            .padding(.horizontal, MooveSpacing.huge)
            .padding(.top, MooveSpacing.xxxl)
            .accessibilityIdentifier("alarmList.emptyState.createButton")

            Spacer(minLength: MooveSpacing.huge)
        }
        .padding(.horizontal, MooveSpacing.xxl)
    }

    private var listContent: some View {
        List {
            ForEach(alarmManager.alarms) { config in
                AlarmRowView(config: config)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: MooveSpacing.sm,
                        leading: MooveSpacing.xl,
                        bottom: MooveSpacing.sm,
                        trailing: MooveSpacing.xl
                    ))
                    .onTapGesture {
                        editingConfig = config
                        showingEditSheet = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            alarmManager.deleteAlarm(config)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                alarmManager.deleteAlarms(at: indexSet)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tint(.terracotta)
    }
}

struct AlarmRowView: View {
    let config: AlarmConfig

    @Environment(AppAlarmManager.self)
    private var alarmManager

    var body: some View {
        HStack(spacing: MooveSpacing.lg) {
            VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                Text(config.timeString)
                    .font(MooveFont.timePicker(size: 34))
                    .foregroundStyle(config.isEnabled ? Color.espresso : Color.taupe)

                Text(config.label)
                    .font(MooveFont.headline())
                    .foregroundStyle(config.isEnabled ? Color.espresso : Color.taupe)

                HStack(spacing: MooveSpacing.md) {
                    Text(config.weekdaySummary)

                    HStack(spacing: MooveSpacing.xs) {
                        Image(systemName: "figure.walk")
                        Text("\(config.stepGoal)")
                    }
                }
                .font(MooveFont.caption())
                .foregroundStyle(Color.taupe)
            }

            Spacer(minLength: 0)

            Toggle(isOn: toggleBinding) { }
                .labelsHidden()
                .tint(.terracotta)
        }
        .mooveCard(padding: MooveSpacing.lg)
        .opacity(config.isEnabled ? 1 : 0.7)
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { config.isEnabled },
            set: { _ in
                alarmManager.toggleAlarm(config)
            }
        )
    }
}

struct TrialGraceBanner: View {
    let endsAt: Date?

    @Environment(SubscriptionManager.self)
    private var subscriptionManager

    var body: some View {
        Button {
            subscriptionManager.shouldShowPaywall = true
        } label: {
            HStack(alignment: .top, spacing: MooveSpacing.md) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.terracotta)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: MooveSpacing.xs) {
                    Text("Trial ended")
                        .font(MooveFont.headline())
                        .foregroundStyle(Color.espresso)

                    Text(bannerCopy)
                        .font(MooveFont.caption())
                        .foregroundStyle(Color.taupe)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(MooveSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.terracotta.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: MooveCornerRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MooveCornerRadius.md, style: .continuous)
                    .stroke(Color.terracotta.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MooveSpacing.xl)
        .padding(.top, MooveSpacing.sm)
        .accessibilityIdentifier("alarmList.trialGraceBanner")
    }

    private var bannerCopy: String {
        if let endsAt {
            let remaining = max(0, endsAt.timeIntervalSinceNow)
            let hours = max(1, Int(ceil(remaining / 3600)))
            return "Subscribe within \(hours)h to keep your alarms working."
        }
        return "Subscribe within 24 hours to keep your alarms working."
    }
}
