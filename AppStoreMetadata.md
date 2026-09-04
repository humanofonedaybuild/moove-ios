# Moove App Store Metadata (as submitted — v1.0, build 17)

## App Name
Moove Alarm Clock

## Subtitle
Walk to wake up. Move to stop.

## Primary Category
Lifestyle

## Secondary Category
Health & Fitness

## Age Rating
4+ (all questionnaire answers: NONE — verified via ASC API 2026-09-04)

## Copyright
© 2026 Moove Inc.

## Promotional Text
Get up and move. The alarm that only stops when you do.

## Keywords
alarm,step,walk,wake,morning,sleep,pedometer,fitness,health,motion,activity,shake,mission,wakeup

## Description

Moove is the alarm clock that guarantees you actually get out of bed. Instead of a snooze button, you walk a set number of steps to stop the alarm — starting your day with movement, not frustration.

How it works:
1. Set your alarm and choose a step goal (10–100 steps)
2. When the alarm fires, the only way to stop it is to get up and walk
3. Steps are counted by your iPhone's motion coprocessor (a firm shake works too)
4. Watch your progress on the Lock Screen and Dynamic Island
5. Mission complete — you're up, moving, and ready for the day

Key features:
- AlarmKit-powered: alarms fire reliably through Do Not Disturb, Focus modes, the silent switch, and even if the app was force-closed
- Real-time step tracking: the CoreMotion pedometer counts every step
- Shake detection: a vigorous shake also counts as a step
- Live Activities: your step countdown, live on the Lock Screen and Dynamic Island
- 16 built-in alarm sounds to choose from
- Custom sounds: import your own audio files
- Optional limited snooze — for emergencies only
- Clean, minimal interface — no clutter, no ads

Premium subscription: everything is included free during your 7-day trial. After the trial, a Moove subscription (monthly or yearly) keeps your alarms working. Cancel anytime.

Privacy: steps are processed on your device and never leave it. No analytics, no tracking, no ads.

## URLs (live)
- Support: https://humanofonedaybuild.github.io/moove-ios/support
- Marketing: https://humanofonedaybuild.github.io/moove-ios/
- Privacy policy: https://humanofonedaybuild.github.io/moove-ios/privacy

> NOTE: the previous draft referenced `https://moove.app` — that domain belongs to an
> unrelated third-party fitness app and must not be used in any Moove metadata.
> The GitHub Pages site (this repo's `gh-pages` branch) is the live interim home;
> swap to a company domain when one is acquired.

## Screenshots (1290×2796, APP_IPHONE_67 set, uploaded via ASC API)
alarms.png (alarm list), steps.png (alarm edit), mission.png (walk mission countdown),
nosnooze.png (snooze disabled), trial.png (paywall), sounds.png (settings)

## App Review Information
Contact: Chetan Chopra (account holder) — contact phone must be provided in ASC
portal (App Review Information); Apple does not expose account-holder phone via API.
Notes for review: "Moove is a step-based alarm clock. To review the alarm flow: create
an alarm 1-2 minutes ahead, lock the device, wait for it to fire, then walk with the
device (or give it a firm shake) until the step goal completes and the alarm stops.
Motion & Fitness permission is requested on first launch and required for the wake-up
walk. The optional 7-day free trial and subscription can be tested with a sandbox Apple ID."

## App Privacy (portal-only — exact values to enter in App Store Connect)
- Data collected: Purchases → Purchase History. Purposes: App Functionality.
  Linked to identity: NO. Used for tracking: NO. (RevenueCat processes transaction
  identifiers and subscription status to validate purchases.)
- All other data types: none collected. Steps/motion are processed on-device only.
- No tracking, no analytics SDKs, no ads SDKs.

## Release
Release type: AFTER_APPROVAL (manual release once approved).
Content rights: DOES_NOT_USE_THIRD_PARTY_CONTENT.
Export compliance: ITSAppUsesNonExemptEncryption = false (standard system encryption only).

## License
Proprietary — Moove Inc. All rights reserved. Bundled alarm sounds: AOSP, Apache 2.0 (see SOUNDS-ATTRIBUTION.md).
