# Moove Architecture & Engineering Standards

## Core Architecture

### Alarm Lifecycle

```
User creates alarm → AlarmConfig → AlarmStore.schedule()
                                        ↓
iOS AlarmKit daemon (persists across app termination)
                                        ↓
Alarm fires → StartWalkingIntent (secondaryIntent → lock screen button)
                                        ↓
AlarmManager .startMission() → StepCounter.beginCounting() + AudioManager.playAlarmSound()
                                        ↓
User walks X steps → StepCounter.registerSteps() → currentStepCount >= targetStepCount
                                        ↓
completeMission() → stop audio + end Live Activity + Show "Good Morning!" (2s) → idle
```

### State Machine

```
idle → scheduled (after save)
scheduled → firing (AlarmKit triggers intent)
firing → missionActive (step counting begins)
missionActive → stopped (steps completed)
missionActive → snoozed (user taps snooze)
snoozed → firing (after 5 min)
stopped → idle (2s completion display)
```

## Key Engineering Decisions

### AlarmKit Integration (iOS 26+)

- `AlarmConfiguration` schedules via system daemon, survives force-quit and reboot
- `secondaryIntent` replaces native lock-screen "Stop" with "Start Walking"
- `AlarmSoundConfiguration` handles audio routing through silent switch
- The `StartWalkingIntent` receives the alarm's UUID to look up full configuration including step goal, sound name, and label

### Step Tracking

- `CMPedometer.startUpdates(from:)` provides cumulative step count from mission start
- `CMMotionManager` accelerometer at 0.5s interval for shake detection
- Shake threshold: 2.5g vector magnitude, 300ms minimum interval
- Steps from pedometer AND shakes both feed `StepCounter.registerSteps()`
- Watch steps sent via WCSession; iPhone forward to Watch too

### WatchOS Companion

- `HKWorkoutSession` (walking, indoor) starts when mission begins
- Keeps app alive in background for wrist-based step tracking
- `WatchStepCounter.startMission()` → `WorkoutSessionManager.startWorkout()` → step updates → iPhone sync
- Session is ended when mission completes

### Subscription

- StoreKit 2 `Transaction.currentEntitlements` for entitlement checks
- `Transaction.updates` observer for real-time subscription changes
- `revocationDate` check prevents reinstalled-app bypass
- 7-day trial configured in App Store Connect

## Engineering Standards

### Code Style

- Swift 6.0 with complete strict concurrency
- `@Observable` for state management (no Combine, no ObservableObject)
- `@MainActor` on all stateful classes
- `Sendable` on model types
- Dependency injection via SwiftUI `@Environment`
- Singletons for shared services (AlarmManager, StepCounter, AudioManager, etc.)

### Testing

- Swift Testing framework (no XCTest)
- Test files in `Tests/` mirror source structure
- Focus on: AlarmConfig clamping, step counter logic, subscription edge cases
- Manual verification required for: AlarmKit firing, CMPedometer, StoreKit sandbox

### PR Requirements

- **Alarm changes:** Manual test log showing alarm fires through all device states
- **Step tracking:** Test showing CMPedometer events decrement counter; shake equivalence
- **WatchOS:** Log proving HKWorkoutSession stays alive during test alarm
- **Subscription:** Sandbox test log showing trial → expiry → renewal → paywall
- **UI:** Screenshots from simulator + real device

### Dependencies

- Zero third-party dependencies — all Apple frameworks:
  - AlarmKit, AppIntents, ActivityKit, CoreMotion, StoreKit, HealthKit, WatchConnectivity, AVFAudio

## Audio Assets

5 built-in CAF sounds in `Sources/Moove/Resources/Sounds/`:

| File | Type | Duration |
|------|------|----------|
| `default_alarm.caf` | PCM/aac | ~8s loop |
| `gentle_wake.caf` | PCM/aac | ~8s loop |
| `urgent.caf` | PCM/aac | ~8s loop |
| `nature.caf` | PCM/aac | ~8s loop |
| `digital.caf` | PCM/aac | ~8s loop |

Sounds are processed through `AVAudioPlayer` with infinite looping (`numberOfLoops = -1`), `.playback` category, and `.duckOthers` option.

## Build System

Two parallel build configurations:

1. **XcodeGen** (`project.yml`) — primary for development, generates `Moove.xcodeproj`
2. **SwiftPM** (`Package.swift`) — CI and command-line builds

Run `xcodegen generate` after pulling changes that modify `project.yml`.

## CI/CD Pipeline

GitHub Actions workflow `.github/workflows/ci.yml`:

1. **test-ios** — Build + test iOS on simulator
2. **test-watch** — Build watchOS on simulator
3. **lint** — SwiftLint with `--strict`
4. **spm-build** — SPM build with strict concurrency

## App Store Submission Checklist

- [ ] AlarmKit entitlement confirmed in Developer Portal
- [ ] App Group `group.com.moove.alarmclock` created
- [ ] StoreKit product `com.moove.alarmclock.premium` configured
- [ ] Subscription pricing and 7-day trial set up
- [ ] HealthKit and CoreMotion usage descriptions correct
- [ ] TestFlight build submitted and smoke-tested on real device
- [ ] Sandbox purchase test: trial → subscribe → restore
- [ ] Alarm test: foreground, background, force-quit, DND, focus, silent switch, locked
- [ ] Watch build paired and mission sync verified
