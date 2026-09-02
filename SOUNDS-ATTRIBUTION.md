# Built-in Alarm Sound Library — Sources & Licensing

All 16 built-in alarm sounds are **real, distinct alarm audio** from the
Android Open Source Project (AOSP), licensed under **Apache License 2.0**,
which permits commercial use, modification, and redistribution in App Store
apps. They replace the previous five synthesized placeholder sounds that
sounded identical despite having different names (MOO-175 bug #5).

## Source

- Repository: `platform/frameworks/base` (`aosp-mirror/platform_frameworks_base` on GitHub)
- Path: `data/sounds/alarms/ogg/`
- Commit ref: `oreo-mr1-release`
- License: Apache 2.0 (Android's original alarm sound set — the "Material"
  alarm sounds shipped on billions of devices)
- Format pipeline: `.ogg` (44.1 kHz stereo) → WAV → `.caf` (IMA4 ADPCM) via
  `ffmpeg` + `afconvert`

AOSP contains seven alias duplicates in this set (Fermium = Argon,
Helium = Hassium, Nobelium = Neon, Promethium = Platinum, Plutonium =
Krypton, Neptunium = Carbon, Oxygen = Cesium). Those were identified by
hashing the decoded PCM and dropped, leaving 16 genuinely distinct sounds.

## Bundled sounds

| File | Display name | Duration |
| --- | --- | --- |
| analysis.caf | Analysis | ~2.0 s |
| argon.caf | Argon | ~7.0 s |
| barium.caf | Barium | ~2.0 s |
| carbon.caf | Carbon | ~6.0 s |
| cesium.caf | Cesium | ~2.1 s |
| copernicium.caf | Copernicium | ~8.8 s |
| curium.caf | Curium | ~8.4 s |
| departure.caf | Departure | ~2.1 s |
| firedrill.caf | Fire Drill | ~5.0 s |
| hassium.caf | Hassium | ~8.8 s |
| krypton.caf | Krypton | ~5.0 s |
| neon.caf | Neon | ~20.4 s |
| osmium.caf | Osmium | ~2.4 s |
| platinum.caf | Platinum | ~6.7 s |
| scandium.caf | Scandium | ~3.9 s |
| timing.caf | Timing | ~3.9 s |

All sounds loop during the alarm mission (`AVAudioPlayer` `numberOfLoops = -1`).
The default sound for new alarms is **Barium**.

## Sound selection notes

- `AudioLibrary.defaultBuiltInSounds` maps each file to a display name and
  SF Symbol icon shown in the sound picker.
- Legacy ids from the placeholder library (`default`, `gentle`, `nature`,
  `urgent`, `digital`, `breeze`, `birds`, `waves`) are migrated on load via
  `AudioLibrary.migrateSoundName(_:)` so existing alarms keep a valid sound.
- Files are flattened to the app-bundle root (not a subfolder) so that
  AlarmKit can ring the user's chosen sound on the lock screen via
  `AlertConfiguration.AlertSound.named("<file>.caf")`.
- User-imported sounds (Files app) are stored in the app group container and
  ring only after the mission starts (app-side playback) — system-level
  named sounds must live in the bundle.
