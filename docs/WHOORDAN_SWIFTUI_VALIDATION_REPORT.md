# Whoordan SwiftUI Validation Report

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`
Project: `Whoordan.xcodeproj`

## Validation Results

| Command / check | Result | Notes |
|---|---|---|
| `git branch --show-current` | PASS | Branch was `swift-app`. |
| `git status --short` | PASS WITH DIRTY WORKTREE | SwiftUI migration branch has many expected deletes/adds/modified docs; no destructive revert was performed. |
| Static safety search | PASS | No client service-role key, committed raw private CSV, committed full raw BLE payload, production fake metric string, or user-metadata approval decision found in searched repo files. `.env` and private secret files were not read. |

## 2026-05-12 Device-First BLE Update

- Focused XCTest validation passed for WearableProtocol, HealthKit, and design contracts after adding structured event/HelloHarvard parsing and raw-payload UI hardening.
- `xcodebuild -list -project Whoordan.xcodeproj` passed.
- Simulator build for `iPhone 17, OS 26.4.1` passed.
- Full simulator test passed: 86 unit tests and 8 UI tests, with 7 approved-account physical UI tests skipped by design.
- Generic iOS build with `CODE_SIGNING_ALLOWED=NO` passed.
- Wireless physical iPhone signed build and install passed.
- Wireless launch was attempted three times and was blocked by iOS because the device was locked.
- `git diff --check` passed.
- Physical wearable sleep, nap, step, activity, workout, RR/IBI, and SpO2 validation remains not performed in this pass.
| `xcodebuild -list -project Whoordan.xcodeproj` | PASS | Scheme `Whoordan`; targets `Whoordan`, `WhoordanTests`, `WhoordanUITests`. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'` | PASS | Simulator build succeeded. |
| `xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'` | PASS | 71 unit tests passed. UI suite: 1 simulator launch test passed; 7 approved-session physical tests intentionally skipped. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` | PASS | Generic iOS no-codesign build succeeded with one non-blocking HealthKit deprecation warning for direct `HKWorkout` initializer use. |
| `xcrun xctrace list devices` | PASS | Showed the configured physical iPhone on iOS 26.4.1. |
| `xcrun devicectl list devices` | PASS WITH TOOL WARNING | Listed the iPhone as connected. `devicectl` also printed a CoreDevice provider warning, but install/launch still succeeded. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS,id=<redacted-device-id>'` | PASS | Wireless physical iPhone build succeeded with Apple Development signing, HealthKit entitlement, and Supabase publishable config present in the built plist. |
| `xcrun devicectl device install app --device <redacted-device-id> .../Whoordan.app` | PASS | App installed on the connected physical iPhone. |
| `xcrun devicectl device process launch --device <redacted-device-id> com.w4rd2.whoordan` | PASS | App launched on the connected physical iPhone. |
| Built app Supabase config check | PASS | Built plist had a project ID and publishable key present; values were not printed. URL was not explicitly configured because the app derives URL from project ID. |
| Supabase MCP RLS inspection | PASS WITH LIMITATION | All inspected public tables had RLS and forced RLS enabled; policies referenced `auth.uid()` and protected tables referenced `user_access`; no policy referenced user metadata. No live two-user RLS probe was run. |
| Supabase security advisors | WARN | Advisor reported leaked-password protection disabled. |
| Supabase performance advisors | INFO | Advisor reported unused indexes; not a P0/P1 app safety issue. |
| Physical HealthKit manual validation | NOT COMPLETED THIS PASS | App launched on device, but HealthKit permission/import/upload was not manually re-tested during this audit. |
| Physical BLE/wearable validation | NOT COMPLETED THIS PASS | App launched on device, but owned wearable connection/data flow was not manually re-tested during this audit. |
| Physical vibration validation | NOT COMPLETED THIS PASS | Haptic command building is tested; actual vibration was not re-tested during this audit. |

## Device Availability

- `xcrun xctrace list devices` showed `the configured physical iPhone (26.4.1)` with UDID `<redacted-device-id>`.
- Physical iPhone build succeeded.
- `devicectl` install succeeded.
- `devicectl` launch succeeded.
- This proves build/install/launch only. It does not prove approved account flow, HealthKit import, BLE data receipt, or vibration success.

## Test Coverage Summary

- Unit tests: 71 passed.
- UI tests: 8 total in suite; 1 simulator launch test passed; 7 physical/approved-session tests were intentionally skipped on simulator.
- Covered: approval guard, cloud consent guard, hashed health sync rows, CSV privacy/synthetic parser, HealthKit mapping/source resolver/dedupe/steps, scoring, wearable protocol frame/decoder/haptic scaffolds, design contracts, simulator launch.
- Not covered enough: encrypted/indexed local DB, complete Apple Health write drain, two-user RLS, real HealthKit import/background callback, real BLE end-to-end, real vibration, export/deletion/account deletion, full accessibility manual QA, TestFlight/archive.

## Supabase Validation

- MCP table inspection found RLS and forced RLS enabled on inspected public tables.
- MCP policy aggregate found protected table policies reference `user_access` and `auth.uid()` and do not reference `user_metadata`/`raw_user_meta_data`.
- Security advisor warning: leaked-password protection disabled.
- Performance advisor info: unused indexes reported.
- No two-user live RLS probe was run.

## Physical Validation Boundary

Do not treat this report as proof that HealthKit, BLE/wearable data, or vibration works on hardware. The physical proof from this pass is limited to build, install, and launch on the iPhone.
# 2026-05-12 Validation Addendum

Focused validation passed:

```text
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -only-testing:WhoordanTests/ApprovalGateTests -only-testing:WhoordanTests/HealthKitTests
```

Result: 31 selected tests, 0 failures.

Covered in this focused run:

- Expired and unexpired session restore behavior.
- Approval `401` refresh and retry.
- Refresh rejection -> `auth_expired`.
- Network approval failure -> retryable fail-closed state.
- Network approval failure with recent cached approval -> local-only
  `offline_approved` unlock.
- Network approval failure with stale cached approval -> fail-closed
  `network_unavailable`.
- Cloud upload remains blocked during `offline_approved`.
- Wearable-first sleep and movement priority.
- Apple Health fallback sleep and steps.
- Stage totals, efficiency, naps, and sleep debt.
- No nap from motion-only or heart-rate-only data.
- No fake steps from IMU.

Physical iPhone, HealthKit data, and wearable validation were not performed in
this addendum and must not be claimed as passed for this run.

## 2026-05-12 Offline Approved Queueing Validation

Focused simulator validation passed:

```text
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -only-testing:WhoordanTests/HealthIngestionPipelineTests -only-testing:WhoordanTests/ApprovalGateTests -only-testing:WhoordanTests/LocalStoreTests -only-testing:WhoordanTests/VibrationTests
```

Result: 51 selected tests, 0 failures.

Covered in this focused run:

- `offline_approved` health sample creates a pending Supabase queue item when
  account ID, cloud sync consent, and health-data sync consent are present.
- `offline_approved` does not queue without health-data consent, in local-only
  mode, or without account ID.
- Duplicate offline imports do not duplicate queue items.
- `offline_approved` does not drain/upload the queue.
- Fresh online `approved` after offline mode drains pending health samples.
- Revoked approval after offline mode locks the app and leaves the queue
  pending.
- Settings/alarm/vibration sync status treats `offline_approved` as
  queue-eligible only when account ID and cloud consent exist.

Physical offline/online sync validation was not performed in this addendum.

Full validation later in the same run:

```text
xcodebuild -list -project Whoordan.xcodeproj
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

Results:

- Project list passed and showed scheme `Whoordan`.
- Simulator build passed.
- Full simulator test passed: 114 unit tests, 0 failures; 8 UI tests, 7 skipped
  because they require an approved real-device session.
- Generic iOS no-codesign build passed.
- `git diff --check` passed.
- Static app/test code search found no service-role key, user-metadata approval
  dependency, or logging calls for sensitive paths.
- Supabase-configured generic iOS build passed using public config from `.env`;
  built plist keys were verified without printing values.
- Wireless iPhone install/launch initially found the iPhone offline/unavailable.
  After the phone was unlocked and online, CoreDevice reported it available,
  and a Supabase-configured signed iOS build installed and launched on the
  physical iPhone. Physical offline/online sync behavior was still not manually
  exercised.
