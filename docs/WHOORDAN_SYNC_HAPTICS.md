# Whoordan Sync, Health Sources, BLE, And Haptics

## Sync Architecture

Whoordan remains local-first. Cloud sync is allowed only when the user is signed in, `cloudSyncRequested` is enabled, `Save on Cloud` preferences allow the data category, and the latest cloud-sync consent is granted.

`CloudSyncEngine` supports:

- Initial full sync of the full available local repository dataset.
- Incremental sync from the last successful local sync timestamp.
- Manual Sync Now.
- Repair Sync, which rechecks the full local dataset with idempotent upserts.
- Re-upload Data, which replays the full local dataset with duplicate protection.

Rows use stable user-owned dedupe keys. Health samples dedupe by source, sample type, source record ID when available, and timestamp/value/unit fallback. Settings use latest updated timestamp semantics. Custom vibration patterns and alarms keep stable IDs so later conflict handling can preserve both versions when automatic resolution is unsafe.

Known limitation: local health history now uses encrypted indexed SQLite rows, but full database-file encryption is not active yet. Payloads are encrypted; index metadata remains plaintext for local query and sync performance.

## Data Source Priority

Whoordan separates sample origin in each `HealthSample`:

- `wearable_ble`: normalized wearable BLE packets.
- `apple_health`: Apple Health imports.
- `manual_entry`: user-entered local records.
- `wearable_summary`: device summary packets.
- `whoordan`: derived local summaries.

Displayed metrics prefer direct wearable BLE data for wearable-native values, Apple Health as an allowed fallback or external source, manual entries when explicitly entered, and cloud as backup/cross-device storage rather than the primary live source.

## Apple Health

The iOS bridge supports availability, authorization, direct fetches, anchored incremental imports, background delivery requests, and app-origin sample writes. Whoordan never writes Apple Health-origin samples back to Apple Health.

Read permissions are requested for standard fitness and wellness types. Explicitly sensitive types remain opt-in. Write permissions are limited to supported app-origin samples such as mindful sessions, workouts, active energy, and distance where permitted by iOS.

The app handles unavailable HealthKit, denied permission, partial permission, revoked app-side connection, duplicate samples, historical imports, and incremental anchors. Apple Health sync is independent from cloud sync.

## BLE Parsing

`BleMetricNormalizer` converts validated BLE packets into local `HealthSample` rows:

- Heart rate from R10 packets.
- SpO2 from optical packets when present.
- HRV using RMSSD when RR interval data exists.
- Respiratory rate and recovery summaries from device summary packets.
- Battery, firmware, last packet time, RSSI, and parsed previews in diagnostics.

Malformed values are dropped. Out-of-order packets are retained with diagnostic metadata. Duplicate protection is handled through stable source record IDs and repository dedupe keys.

## Metric Calculations

Scoring formulas are original Whoordan heuristics documented in `docs/WHOORDAN_SCORING.md`. Recovery, strain, sleep need, stress, zones, and cardio fitness carry confidence values and missing-data explanations. Estimates are labeled as estimates and are not medical-grade measurements.

HRV uses RMSSD only when raw beat-to-beat intervals are available. Calories distinguish imported active energy from local workout estimates. Distance uses direct source distance when available; step-based distance estimation remains a future user-profile-backed enhancement.

## Vibration Pattern Format

A vibration pattern contains:

- Stable `id`
- `name`
- `kind`: built-in or custom
- Ordered `segments`
- `repeatCount`
- `allowInfiniteForAlarm`
- `createdAt`, `updatedAt`, optional `deletedAt`

Each segment stores `active`, `durationMs`, and `intensity`. Safety limits clamp maximum duration, intensity, minimum spacing, and repeat count. Infinite loops are not allowed except for future alarm-specific protocol support.

## Notification, Call, And Alarm Haptics

Notification settings include:

- `defaultNotificationPatternId`
- `usePerAppNotificationPatterns`
- `perAppNotificationPatterns`
- `disabledNotificationApps`

Calls use separate call settings and do not inherit notification patterns unless the user explicitly selects the same pattern ID. Alarms store their own pattern ID, enabled state, time, snooze minutes, repeat weekdays, and stable alarm ID.

Wearable preview is sent only when the BLE haptic channel is live and the selected built-in pattern can be mapped to the current device protocol. Custom wearable pattern playback is stored and modeled but requires confirmed device protocol support before exact interval playback can be sent.

## Privacy Controls

Cloud category preferences can disable health samples, summaries, activities, settings, vibration patterns, alarms, diagnostics, journal, or habits independently. Apple Health can be enabled or disabled separately from cloud sync. Export and delete flows remain consent-aware and do not print secrets or tokens.

## Tested

- Vibration pattern serialization, safety limits, recorder intervals, notification rules, call/alarm pattern separation.
- BLE normalization, malformed packet rejection, RMSSD calculation, out-of-order packet metadata, diagnostics serialization.
- Initial cloud sync, incremental sync, consent blocking, settings payload with granular preferences.
- HealthKit write filtering so Apple Health-origin samples are not written back.
- Supabase schema inspection for RLS and syncable haptic/alarm/diagnostics tables.

## Not Tested In This Session

- Physical wearable custom haptic interval playback.
- Physical iPhone HealthKit write authorization and sample persistence.
- Live Supabase migration execution and RLS behavior against a configured project.
- Large historical HealthKit import volume still needs physical-device performance validation.
