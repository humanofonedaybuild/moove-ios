# Moove Alarm Clock

A step-triggered alarm clock for iOS and watchOS that enforces a physical wake-up routine. Alarms are delivered through iOS AlarmKit, guaranteed through Focus modes, Do Not Disturb, and the silent switch.

## Requirements

- iOS 26.0+
- watchOS 11.0+
- Xcode 16.0+
- Swift 6.0

## Architecture

```
Moove/
├── Sources/
│   ├── Moove/            # iOS app
│   │   ├── Alarm/        # AlarmKit scheduling & mission UI
│   │   ├── App/          # Entry point, content view, delegate
│   │   ├── Audio/        # Alarm sound playback & library
│   │   ├── Intents/      # App Intent for lock-screen action
│   │   ├── LiveActivity/ # Dynamic Island / Lock Screen
│   │   ├── StepTracking/ # CMPedometer + shake detection
│   │   ├── Subscription/ # StoreKit 2 paywall & entitlements
│   │   └── WatchConnectivity/ # iPhone ↔ Watch messaging
│   ├── MooveKit/         # Shared models, utilities, constants
│   └── MooveWatch/       # watchOS companion app
├── Resources/            # App icons, entitlements
└── Tests/                # Unit tests
```

## Setup

### Prerequisites

1. **Xcode 16** — download from [developer.apple.com](https://developer.apple.com/download/)
2. **XcodeGen** — `brew install xcodegen`
3. **Apple Developer account** with AlarmKit entitlement
4. **App Group** `group.com.moove.alarmclock` and matching entitlements

### Generate Xcode Project

```bash
xcodegen generate
open Moove.xcodeproj
```

### Configure Signing

1. Open the project in Xcode
2. Select the **Moove** target → Signing & Capabilities
3. Select your team
4. Repeat for **MooveWatch** and **MooveKit** targets

### AlarmKit Entitlement

Apple's AlarmKit requires a special entitlement. The `Moove.entitlements` file is pre-configured, but your Apple Developer account must have the entitlement granted. Contact your Apple Developer representative or add it through the Developer Portal.

## Building

```bash
# Generate project
xcodegen generate

# Build iOS
xcodebuild build -project Moove.xcodeproj -scheme Moove -sdk iphonesimulator

# Build watchOS
xcodebuild build -project Moove.xcodeproj -scheme MooveWatch -sdk watchsimulator

# Run tests
xcodebuild test -project Moove.xcodeproj -scheme Moove -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Key Technical Decisions

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Alarm scheduling | iOS AlarmKit | System-level alarm guarantees through any device state |
| Step tracking | CMPedometer + CMMotionManager | Hardware-backed step counting with shake fallback |
| Lock screen action | App Intents (`StartWalkingIntent`) | Replaces native "Stop" button with "Start Walking" |
| Background runtime (watch) | HKWorkoutSession | Keeps watch app alive during alarm mission |
| Live updates | ActivityKit Live Activities | Dynamic Island + Lock Screen step countdown |
| Audio | AVAudioSession (.playback) | Reliable audio through silent switch, DND, background |
| Purchase | StoreKit 2 | 7-day free trial, receipt validation, no server needed |
| Watch connectivity | WCSession | Bidirectional step sync with fallback |

## Alarm Sounds

5 built-in sounds are bundled as CAF files in `Sources/Moove/Resources/Sounds/`:

| ID | Name | Style |
|----|------|-------|
| `default_alarm` | Default Alarm | Classic alternating tones |
| `gentle_wake` | Gentle Wake | Soft ascending chime |
| `urgent` | Urgent | Fast rapid beeps |
| `nature` | Nature | Bird chirps with ambient drone |
| `digital` | Digital | Electronic retro beeps |

Users can also import custom sounds from Files.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

- **ci.yml** — Build, test, lint on every push and PR

## App Store Connect

### TestFlight

1. Archive in Xcode (`Product → Archive`)
2. Distribute via TestFlight
3. Set up the subscription product (`com.moove.alarmclock.premium`) in App Store Connect

### Important: Sandbox Testing

- Use a sandbox Apple ID for purchase testing
- The 7-day trial is configurable in App Store Connect subscription pricing
- Test alarm firing on a physical device (simulator cannot test AlarmKit fully)

## License

Proprietary — Moove Inc.
