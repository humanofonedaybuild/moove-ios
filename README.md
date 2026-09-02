# Moove Alarm Clock

A step-triggered alarm clock for iOS that enforces a physical wake-up routine. Alarms are delivered through iOS AlarmKit, guaranteed through Focus modes, Do Not Disturb, and the silent switch.

> watchOS is out of scope for v1 (deferred to v2). The v1 product is the iOS app only.

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 6.0

## Architecture

```
Moove/
├── Sources/
│   ├── Moove/            # iOS app
│   │   ├── Alarm/        # AlarmKit scheduling & mission UI
│   │   ├── App/          # Entry point, content view, delegate
│   │   ├── Audio/        # Alarm sound playback & library
│   │   ├── Intents/     # App Intents for lock-screen actions
│   │   ├── LiveActivity/ # Dynamic Island / Lock Screen
│   │   ├── StepTracking/ # CMPedometer + shake detection
│   │   ├── DesignSystem/ # Moove design tokens & components
│   │   └── Subscription/ # RevenueCat / StoreKit 2 paywall & entitlements
│   └── MooveKit/         # Shared models, utilities, constants
├── Resources/            # App icons, entitlements, sounds, fonts
└── Tests/                # Unit + UI tests
```

## Setup

### Prerequisites

1. **Xcode 26** — download from [developer.apple.com](https://developer.apple.com/download/)
2. **XcodeGen** — `brew install xcodegen`
3. **Apple Developer account** with AlarmKit entitlement
4. **App Group** `group.com.moove.alarmclock` and matching entitlements

### Generate Xcode Project

```bash
xcodegen generate
python3 scripts/patch-scheme-storekit.py
open Moove.xcodeproj
```

### Configure Signing

1. Open the project in Xcode
2. Select the **Moove** target → Signing & Capabilities
3. Select your team
4. Repeat for the **MooveKit** target

### AlarmKit Entitlement

Apple's AlarmKit requires a special entitlement. The `Moove.entitlements` file is pre-configured, but your Apple Developer account must have the entitlement granted. Contact your Apple Developer representative or add it through the Developer Portal.

## Building

```bash
# Generate project
xcodegen generate
python3 scripts/patch-scheme-storekit.py

# Build iOS
xcodebuild build -project Moove.xcodeproj -scheme Moove -sdk iphonesimulator

# Run tests
xcodebuild test -project Moove.xcodeproj -scheme Moove -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Key Technical Decisions

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Alarm scheduling | iOS AlarmKit | System-level alarm guarantees through any device state |
| Step tracking | CMPedometer + CMMotionManager | Hardware-backed step counting with shake/swing fallback |
| Lock screen action | App Intents (`StartWalkingIntent`) | Replaces native "Stop" button with "Start Walking" |
| Live updates | ActivityKit Live Activities | Dynamic Island + Lock Screen step countdown |
| Audio | AVAudioSession (.playback) | Reliable audio through silent switch, DND, background |
| Purchase | RevenueCat (StoreKit 2) | 7-day free trial, receipt validation, no server needed |

## Alarm Sounds

16 distinct built-in sounds are bundled as CAF files in `Resources/Sounds/`,
sourced from the Android Open Source Project under Apache 2.0 — see
`SOUNDS-ATTRIBUTION.md` for the full list, sources, and license. Users can
also import custom sounds from the Files app.

## Subscriptions

- Backend: **RevenueCat** (SDK wired; set the public `appl_` SDK key in
  `Sources/MooveKit/Utilities/RevenueCatConstants.swift`). While the key is
  a placeholder, the manager falls back to direct StoreKit 2 against the
  local `Resources/Moove.storekit` configuration for simulator development.
- Products: `moove.monthly`, `moove.yearly` · Entitlement: `premium`
- 7-day intro trial with 24h post-trial grace window, then hard paywall.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

- **ci.yml** — Build, test, lint on every push and PR
- **testflight.yml** — Archive and upload to TestFlight on version tags

## License

Proprietary — Moove Inc. Bundled alarm sounds are Apache 2.0 (AOSP); see
`SOUNDS-ATTRIBUTION.md`.
