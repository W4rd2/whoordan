# Whoordan Final Implementation Audit

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`

## Honest Status

Whoordan is not feature-complete. It is a native SwiftUI app with meaningful foundations and passing validation. This pass moved the health data path closer to true local-first operation: HealthKit imports and safe wearable-derived samples now persist locally before aggregates or Supabase queueing, HealthKit anchors/checkpoints exist, BLE historical ACK dispatch exists, and a durable Supabase upload queue exists. Many premium wearable-app categories are still partial, scaffolded, missing, blocked by platform, blocked by configuration, or not physically validated.

## 2026-05-11 Local-First Update

- Added `FileProtectedLocalStore`, a durable file-backed local store with iOS file protection. This is an improvement over the prior placeholder store but is not a full encrypted SQLite/SwiftData database.
- Added `HealthIngestionPipeline` so HealthKit and wearable samples are written locally first, then aggregates are recalculated from local records, then eligible Supabase/Apple Health queue work is created.
- Added HealthKit anchored incremental import, local checkpoints, and observer/background delivery registration.
- Added a Supabase health sample queue with idempotency keys, retry/backoff, and repair scan.
- Added BLE historical batch ACK dispatch, end-of-sync checkpoint persistence, realtime disable dispatch, and local persistence callback for plausible wearable HR plus diagnostic IMU summaries.
- Wireless physical iPhone build/install/launch passed with Supabase publishable configuration injected at build time. This proves launch only; it does not prove real HealthKit import, BLE payload receipt, or vibration.

## Counts

| Status | Count |
|---|---:|
| IMPLEMENTED_VALIDATED | 138 |
| IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | 54 |
| PARTIAL | 152 |
| SCAFFOLDED | 40 |
| BLOCKED_PLATFORM | 3 |
| BLOCKED_CONFIG | 1 |
| MISSING | 20 |
| UNSAFE_NEEDS_FIX | 0 |
| TOTAL | 408 |

## Most Important Implemented Areas

- SwiftUI app shell, routing, design system, and primary screens.
- App-wide admin approval gate with protected-service blocking.
- Supabase publishable-key auth/config and RLS-backed approval model.
- Cloud health upload guard requiring approval plus explicit cloud and health-data consent.
- HealthKit read foundation and mapping for common health sample types.
- Device-first source resolver and local-day aggregation.
- Original recovery and strain scoring with confidence and no proprietary formula copying.
- CoreBluetooth/protocol foundation with frame decoding, reassembly, commands, events, R10 safe HR extraction, and diagnostic summaries.
- Vibration preview command architecture with safety checks and honest unsupported/failure states.
- Sanitized private CSV benchmark tooling and policy docs.
- App icon/assets and physical iPhone build/install/launch.

## Most Important Gaps

- Full encrypted indexed health database and production local-only mode hardening.
- Full physical HealthKit import/background validation.
- BLE end-to-end physical validation and more real-packet decoders.
- Physical vibration confirmation.
- Full cloud conflict handling and multi-device repair UX.
- Data export, data deletion, and account deletion.
- Full workouts, strength, stress, breathing, long-term trends, cycle/pregnancy context, and journal insights.
- TestFlight readiness and legal/privacy policy completion.
- Manual visual/accessibility/screenshot QA.

## P0/P1 Findings

No P0/P1 safety issue was found in this audit pass. No service-role key was found in client code, no raw private CSV export was found committed, no production fake metrics were found, no user-metadata authorization dependency was found, and the app-side approval/consent guards remain in place.

Important non-P0 risks:
- Local storage is durable and file-protected, but not production-grade encrypted/indexed storage for large health datasets.
- Session refresh is incomplete.
- HealthKit incremental import/checkpoints are implemented in code but not physically validated.
- Cloud sync now has a local queue/retry/repair path; conflict workflows and live RLS probes remain incomplete.
- BLE physical data flow and vibration were not re-tested in this audit pass.
- Supabase live two-user RLS probe was not run.
- Supabase advisor reports leaked-password protection disabled.

## Detailed Implementation Explanation

### 1. App Architecture
Whoordan uses the SwiftUI app lifecycle in `WhoordanApp`, a root `AppRootView`, `AppRouter`, and a single `AppEnvironment` observable object for app state and dependency wiring. The app modules are separated into `App`, `DesignSystem`, `Core`, `Features`, `Resources`, `WhoordanTests`, and `WhoordanUITests`. Dependencies are protocol-shaped for auth, approval, local storage, HealthKit, BLE, haptics, scoring, and health sync.

### 2. Approval/Auth System
Supabase password auth is implemented with REST calls and publishable-key configuration. Sessions are encoded into Keychain through `KeychainStore`. On launch and sign-in, `AppEnvironment` restores the session, fetches `public.user_access`, and routes only approved users into `MainTabView`. Pending, rejected, revoked, missing, unknown, or error states stay in `ApprovalLockedView`. On sign-out or non-approved refresh, BLE is stopped, haptics are cancelled, cached unlocked summary state is cleared, and protected state is reset. Approval does not rely on `user_metadata` or `raw_user_meta_data`.

### 3. Supabase/Cloud
The app derives Supabase URL from either explicit URL or project ID and accepts only publishable/anon-style public keys in app config. Health sync posts to `health_samples` using the signed-in user JWT and hashed `source_record_id`/`dedupe_key`. Upload is blocked unless the user is signed in, approved, and both cloud sync and health-data consent are enabled. Sync queue, repair sync, conflict UI, account deletion, and export workflows are not complete. MCP inspection found RLS/forced RLS enabled on public tables and no metadata-based RLS policy, but no two-user RLS probe was run.

### 4. Local Storage
Auth secrets use Keychain. `FileProtectedLocalStore` now writes app-owned health records, daily summaries, sleep sessions, workouts, journal entries, vibration patterns, HealthKit checkpoints, BLE checkpoints, Supabase queue items, and Apple Health write queue items to Application Support with iOS file protection. This satisfies the local-first durability requirement for this pass, but it is not a final encrypted indexed database. Large-dataset performance, migrations, account-scoped partitioning, export, deletion, and full local-only retention still need production hardening.

### 5. HealthKit
`HealthKitService` checks availability, requests read authorization, imports supported quantity/category/workout samples, and maps them into `HealthSample` with source labels, units, validation bounds, and confidence. Supported types include HR, RHR, HRV SDNN, respiratory rate, sleep analysis, steps, active energy, walking/running distance, oxygen saturation, body/wrist temperature, workouts, and VO2 max. Anchored incremental import and local checkpoints are now implemented. Background delivery registration uses `HKObserverQuery` and re-runs incremental import. Apple Health write support is intentionally narrow and currently limited to supported user-created workout samples. Device launch/build passed, but real HealthKit import/background/write behavior was not manually re-validated in this pass.

### 6. BLE/Wearable
`WearableBLEService` wraps CoreBluetooth discovery, candidate sorting, auto-connect to connected/preferred devices, service/characteristic discovery, notification subscription, command writes, raw debug capture by explicit flag, and state updates. `WearableProtocol` implements UUID constants, 0xAA frame format, CRC8/CRC32, frame reassembly, command builders, init/realtime/haptic commands, metadata/event/firmware/data decoders, R10 HR extraction, R11 scaffold, R21 optical summary scaffold, safe source metadata, and stable dedupe IDs. Metadata batch markers now dispatch ACKs through the command characteristic, end-of-sync persists a BLE checkpoint, and disconnect/stop attempts realtime disable commands where safe. The app emits only plausible direct HR and diagnostic IMU summaries from wearable packets; it does not emit HRV, SpO2, steps, respiratory rate, calories, or sleep stages from unsupported raw packets. Physical wearable data flow was not re-tested in this pass.

### 7. Vibration/Haptics
`VibrationPattern` enforces repeat/duration/intensity limits. `VibrationPreviewService` requires approval, connected/historical/realtime wearable state, safe built-in patterns, and sends Harvard `0x4F` plus Maverick/Gen4 `0x13` commands with response requested. It reports approval required, not connected, unsupported, unsafe, started, failed, and terminated states. It does not fake actual vibration confirmation; physical haptic validation remains pending.

### 8. Scoring/Health Analytics
`WhoordanScoringService` implements original transparent recovery and strain estimates. Recovery uses available HRV, RHR, sleep, respiratory rate, and temperature inputs against simple baselines, with confidence based on contributor weight. Strain uses HR load where available and source-labeled movement/steps/energy. `HealthSourceResolver` enforces device-first source priority and blocks fake HRV from BPM-only data and uncalibrated SpO2. Rolling baselines, persisted personal normal ranges, full stress, strength load, cycle context, trend analytics, and full sleep planner logic are incomplete.

### 9. UI/UX
The SwiftUI app has a dark matte design system and main screens for Today, Recovery, Sleep, Heart, Device, Vibration, Journal, and Settings, plus settings sub-surfaces for Movement, Workouts, Strength, Body Signals, and Trends. The redesigned signal screens avoid duplicate giant titles and include missing-data CTAs. Visual, dynamic type, VoiceOver, tap target, contrast, and screenshot QA are only partially complete.

### 10. Testing/Validation
Current tests cover approval routing/guards, Supabase config and health sync consent, CSV privacy/sanitized fixtures, HealthKit mapping/source resolution/steps/dedupe, scoring, wearable protocol frames/commands/decoders, haptic command safety, design contracts, and one simulator UI launch. Physical app build/install/launch passed; HealthKit, BLE, wearable data, and physical haptics were not fully re-tested in this audit pass.

## 2026-05-12 Private Wearable Export Relationship Analysis Addendum

- Private third-party wearable CSV exports were used as local benchmark and
  relationship-discovery data only. Raw files stayed outside the repository and
  were not uploaded.
- Files inspected by name only: `journal_entries.csv`,
  `physiological_cycles.csv`, `sleeps.csv`, and `workouts.csv`.
- Aggregate row counts: journal 180, cycles 63, sleeps 67, workouts 5.
- Date ranges were recorded at date precision only: journal 2025-11-08 to
  2025-11-26, cycles 2025-11-05 to 2026-01-13, sleeps 2025-11-07 to
  2026-01-06, workouts 2025-11-15 to 2025-12-19.
- Strongest recovery finding: HRV had the strongest direct and
  baseline-relative relationship with exported recovery. Baseline-relative HRV
  reached Pearson 0.808 and Spearman 0.826 across 54 comparable rows.
- Useful secondary recovery findings: respiratory rate closer/below baseline and
  RHR below baseline. Sleep duration was a weaker supporting signal.
- Weak/noisy findings: skin temperature, sleep efficiency, sleep debt, and SpO2
  were not reliable positive recovery contributors in this export.
- Strongest sleep finding: sleep performance was dominated by asleep duration,
  with Pearson 0.909 and Spearman 0.807 across 67 rows.
- Workout strain findings were directionally useful but not stable because only
  5 workouts were available.
- Journal behavior categories did not have enough balanced yes/no samples for
  reliable habit insight claims.
- Code impact: Whoordan's original recovery heuristic was retuned to HRV 0.35,
  RHR 0.20, sleep sufficiency 0.17, respiratory fit 0.20, and temperature 0.08.
  This remains an original, explainable wellness heuristic and is not a
  proprietary formula copy.
- Tests added: synthetic-only Spearman correlation, rolling baseline,
  candidate recovery directionality, and aggregate bucket-agreement coverage.
- Remaining limitation: this is a single-user export and cannot validate
  population-general weights or exact score equivalence.

## 2026-05-12 Recovery Explanation UI Addendum

- Kept the calibrated original Whoordan recovery weights: HRV 0.35, RHR 0.20,
  sleep sufficiency 0.17, respiratory fit 0.20, and temperature deviation 0.08.
- Did not add SpO2 or previous-day strain as direct recovery drivers.
- Added Recovery-screen explanation rows for score, category, confidence,
  source labels, top positive contributors, top negative contributors, and
  missing-data confidence.
- Contributor rows now explain HRV relative to baseline, RHR relative to
  baseline, sleep sufficiency, respiratory fit, and temperature deviation.
- The screen explicitly says recovery is not medical advice and is not
  third-party score equivalent.
- Sleep, strain, and journal policy remains unchanged: source-reported stages
  only, conservative strain calibration because workout export sample size was
  small, and journal association language only after minimum sample thresholds.

## Validation Results

| Command / check | Result | Notes |
|---|---|---|
| `git branch --show-current` | PASS | Branch was `swift-app`. |
| `git status --short` | PASS WITH DIRTY WORKTREE | SwiftUI migration branch has many expected deletes/adds/modified docs; no destructive revert was performed. |
| Static safety search | PASS | No client service-role key, committed raw private CSV, committed full raw BLE payload, production fake metric string, or user-metadata approval decision found in searched repo files. `.env` and private secret files were not read. |

## 2026-05-12 Device-First Packet Update

- Status: implemented for all currently safe decoded wearable packet families; not complete for unconfirmed device health categories.
- Added/verified decoders: HelloHarvard battery/charging/wrist/RTC, structured event timestamp/payload values, R10 complete-packet IMU summary guard, R21 complete-packet channel summary guard, and device temperature event sample policy.
- Removed user-visible raw BLE byte windows from the Device screen.
- Still blocked pending physical capture: wearable sleep sessions, sleep stages, naps, step/activity summaries, workout summaries, calories, respiratory rate, true RR/IBI HRV, production SpO2, and production temperature semantics.
- Apple Health fallback remains the production path for sleep/stages/naps/steps/distance/active energy/workouts until reliable wearable records are decoded.
- Validation: xcodebuild list, simulator build, full simulator test, generic iOS build, focused packet tests, safety search, and git diff check passed. Wireless iPhone build/install passed; launch was blocked because the device was locked.
| `xcodebuild -list -project Whoordan.xcodeproj` | PASS | Scheme `Whoordan`; targets `Whoordan`, `WhoordanTests`, `WhoordanUITests`. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'` | PASS | Simulator build succeeded. |
| `xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'` | PASS | 71 unit tests passed. UI suite: 1 simulator launch test passed; 7 approved-session physical tests intentionally skipped. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` | PASS | Generic iOS no-codesign build succeeded with one non-blocking HealthKit deprecation warning for direct `HKWorkout` initializer use. |
| `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS,id=<redacted-device-id>'` | PASS | Wireless physical iPhone build succeeded with Apple Development signing, HealthKit entitlement, and Supabase publishable config present in the built plist. |
| `xcrun devicectl device install app --device <redacted-device-id> .../Whoordan.app` | PASS | App installed on the connected physical iPhone. |
| `xcrun devicectl device process launch --device <redacted-device-id> com.w4rd2.whoordan` | PASS | App launched on the connected physical iPhone. |
| Supabase MCP RLS inspection | PASS WITH LIMITATION | All inspected public tables had RLS and forced RLS enabled; policies referenced `auth.uid()` and protected tables referenced `user_access`; no policy referenced user metadata. No live two-user RLS probe was run. |
| Supabase security advisors | WARN | Advisor reported leaked-password protection disabled. |
| Supabase performance advisors | INFO | Advisor reported unused indexes; not a P0/P1 app safety issue. |
| Physical HealthKit manual validation | NOT COMPLETED THIS PASS | App launched on device, but HealthKit permission/import/upload was not manually re-tested during this audit. |
| Physical BLE/wearable validation | NOT COMPLETED THIS PASS | App launched on device, but owned wearable connection/data flow was not manually re-tested during this audit. |
| Physical vibration validation | NOT COMPLETED THIS PASS | Haptic command building is tested; actual vibration was not re-tested during this audit. |

## Top 20 Highest-Priority Next Steps

1. Replace file-backed JSON local storage with encrypted indexed SQLite/SwiftData-style storage and explicit deletion/export behavior.
2. Add a redacted physical HealthKit validation run on an approved account.
3. Add a redacted physical BLE validation run for the owned wearable, including connection state and decoded-safe-signal proof.
4. Complete Apple Health write queue draining for user-created workouts.
5. Add explicit battery/charging/wrist/temperature captures and tests when those real event packets are available.
6. Add full cloud conflict handling and multi-device repair UX.
7. Add live two-user RLS probe using safe test accounts.
8. Move HealthKit workout writes to `HKWorkoutBuilder` to remove the iOS 17 deprecation warning.
9. Add durable account-scoped local store partitioning and migration tests.
10. Add real background-delivery device validation for HealthKit observer callbacks.
11. Enable Supabase leaked-password protection in Dashboard.
12. Add account deletion and local/cloud data deletion workflows.
13. Add data export workflow that redacts secrets and respects health-data privacy.
14. Implement rolling baselines and personal normal ranges.
15. Expand source/confidence labels across all UI surfaces.
16. Finish Workouts history/detail and workout HR zone summaries.
17. Finish Sleep sessions, efficiency, debt/need, and trend persistence without fake stages.
18. Finish Journal/habit persistence and association-only insights with sample-size thresholds.
19. Perform manual accessibility QA for dynamic type, VoiceOver, contrast, and tap targets.
20. Run TestFlight/archive readiness after physical HealthKit/BLE/haptic validation is complete.
# 2026-05-12 Approval, Sleep, and Movement Audit Addendum

## Implemented

- Supabase session restore now refreshes expired/near-expired access tokens.
- Approval fetch now retries once after `401` or `403` by forcing session
  refresh.
- New fail-closed states distinguish checking approval, auth expired, network
  unavailable, approval fetch failed, and unknown error.
- A bounded `offline_approved` mode now lets a signed-in device use local data,
  HealthKit import, BLE, haptics, and alarms while offline if the account was
  verified approved on this device within the last 7 days. Supabase health
  upload and settings sync remain blocked until online approval is verified
  again.
- Sleep summary, stages when measured, naps, efficiency, sleep need/debt,
  patterns, and planner rows are visible in SwiftUI.
- Steps/movement now show goal, progress, 7-day average, best day, direction
  trend, source, confidence, distance, and active energy.
- Local-first and consent-gated sync behavior remains intact.

## Still Limited

- Wearable sleep, nap, stage, and step records are not confirmed from current
  captures.
- File-backed local JSON remains the current store; encrypted indexed storage is
  future work.
- Physical iPhone/HealthKit/wearable validation was not completed in this run.

# 2026-05-12 BLE Protocol Reference Hardening Addendum

## Implemented

- Verified protocol UUID constants for service, command write, command response,
  events, sensor data, and diagnostics/memfault notifications.
- Preserved connection order: scan/connect/discover/subscribe, then init
  commands only after notify subscriptions are active.
- Preserved strict `0xAA` frame validation with length CRC8 and inner CRC32.
- Added dropped orphan-fragment diagnostics and malformed-frame counters.
- Added R10 accelerometer/gyroscope axis summaries from fixed packet offsets.
  These are diagnostic summaries only and do not create steps or sleep.
- Added R21 LED/sample/channel summaries. These remain raw/debug PPG context and
  do not create production SpO2 or true HRV.
- Added realtime HR start/stop and alarm set/fired/disabled event
  classification.
- Updated firmware-log parsing to prefer null-terminated ASCII diagnostics.
- Updated haptic preview command construction for Harvard `0x4F`,
  Maverick/Gen4 `0x13`, and stop `0x7A`.
- Added non-sensitive Device screen diagnostics for sync state, realtime state,
  dropped/malformed counts, last ACK fingerprint, and haptic event status.
- Created `docs/WHOORDAN_BLE_FEATURE_CAPABILITY_MATRIX.md`.

## Still Limited

- No new physical wearable capture was performed in this addendum.
- Wearable sleep sessions, sleep stages, naps, reliable steps, activity/workout
  summaries, calories, respiratory rate, true RR/IBI HRV, and production SpO2
  remain unconfirmed pending targeted captures.
- R10 axis scaling and R21 optical channel calibration remain unknown; only
  safe summaries are persisted.

## Validation

Current run validation on 2026-05-12:

- `xcodebuild -list -project Whoordan.xcodeproj`: passed.
- Simulator build for `iPhone 17, OS 26.4.1`: passed.
- Full simulator test for `iPhone 17, OS 26.4.1`: passed with 88 unit tests and
  8 UI tests; 7 UI tests were intentionally skipped because they require an
  approved real-device session.
- Generic iOS build with `CODE_SIGNING_ALLOWED=NO`: passed.
- Wireless physical iPhone build/install/launch: passed.
- `git diff --check`: passed.

Physical HealthKit import, physical BLE packet receipt, and physical wearable
haptic confirmation were not performed in this addendum.

# 2026-05-12 Notification, Call, and Vibration Audit Addendum

## Implemented

- Received-notification wearable vibration settings have been removed.
- Call vibration settings persist locally first.
- No received-notification vibration router remains in the app.
- Custom vibration patterns now have segment kinds, type, timestamps, repeat
  count, safety status, and finite safety limits.
- The Vibration screen supports recording a tap pattern, saving, duplicating,
  deleting, built-in preview, call pattern preview, and platform limitation
  messaging.
- Live recording sends a supported built-in haptic pulse only when approved and
  connected; disconnected recording remains local only.
- Double-tap routing can decline a Whoordan-owned call only through an explicit
  app-owned call controller. Normal cellular call decline is platform-blocked.
- Device diagnostics now include call vibration status, alarm state,
  double-tap route, and haptic event status.

## Platform Boundaries

- All-app notification capture is not claimed. `UNUserNotificationCenter` and
  notification service extensions are scoped to the app/app extension path, not
  a universal third-party notification feed.
- Normal cellular call control is not claimed. CallKit scaffolding is reserved
  for Whoordan-owned VoIP/CallKit calls if such a service is added.
- No private APIs, phone number logging, notification content storage, or raw
  BLE payload logging were added.

## Validation

- Simulator build passed.
- Full simulator test passed with 99 unit tests and 8 UI tests; 7 UI tests were
  skipped because they require an approved real-device session.
- Physical iPhone build/install passed with Supabase build settings configured
  from the local `.env`; launch was blocked because the device was locked.
- Wearable haptic physical confirmation remains required.

# 2026-05-12 Alarm Vibration Addendum

## Implemented

- Added local-first alarm records with label, enabled state, time, timezone,
  repeat days, selected vibration pattern, snooze limits, trigger timestamps,
  sync status, and delivery status.
- Added Settings > Alarms UI for create, edit, enable/disable, delete, repeat
  days, pattern preview, snooze configuration, and active-alarm snooze/dismiss.
- Added local iOS notification fallback using UserNotifications for the next
  trigger time.
- Added wearable alarm delivery attempt through the existing approval-gated
  haptic preview path when the app can run and the wearable is connected.
- Added central double-tap routing priority: supported app-owned call, active
  alarm, notification action where supported, debug/custom action, no-op.
- Added Device diagnostics for alarm count, active alarm state, and scheduling
  result.

## Platform Boundaries

- Exact wearable alarm delivery while the app is suspended is not claimed.
- Normal cellular call decline and all-app notification capture remain
  platform-blocked.
- No notification content, phone numbers, call metadata, tokens, secrets, or raw
  BLE payload logging were added.

## Validation

- Simulator build passed after the alarm implementation.
- Full simulator test passed with 106 unit tests and 8 UI tests; 7 UI tests were
  skipped because they require an approved real-device session.
- Physical alarm delivery and wearable double-tap snooze/dismiss still require a
  real iPhone plus connected wearable validation run.

# 2026-05-12 Offline Approved Queueing Addendum

## Implemented

- Split sync gating into queue eligibility and upload execution.
- `offline_approved` now allows eligible records to create pending Supabase
  queue items when a signed-in user ID exists, cloud sync consent is enabled,
  health-data sync consent is enabled for health records, local-only mode is
  disabled, and the cached approval is still recent.
- `offline_approved` still blocks Supabase upload/drain execution.
- HealthKit imports and safe wearable samples pass the signed-in user ID into
  the local-first ingestion path so pending queue items are account-scoped.
- Local-only mode now blocks both health upload and health queue creation.
- Pending health queue items drain only after session refresh/restore succeeds
  and approval is freshly verified online as `approved`.
- If approval returns revoked after offline mode, the app locks and pending
  queue items remain undrained.

## Still Limited

- Physical offline/online sync validation was not performed in this addendum.
- Non-health settings, alarm, and vibration records now receive consent-aware
  local sync status, but a generic Supabase uploader for those record families
  remains future work.

## Validation

- `xcodebuild -list -project Whoordan.xcodeproj` passed.
- Simulator build for `iPhone 17, OS 26.4.1` passed.
- Full simulator test passed: 114 unit tests, 0 failures; 8 UI tests, 7 skipped
  because they require an approved real-device session.
- Generic iOS no-codesign build passed.
- `git diff --check` passed.
- Static app/test code search found no service-role key, user-metadata approval
  dependency, or logging calls for sensitive paths.
- Supabase-configured generic iOS build passed with public config injected from
  `.env`; plist key presence was verified without printing values.
- Wireless iPhone install/launch initially found the iPhone offline/unavailable.
  After the phone was unlocked and online, CoreDevice reported it available,
  and a Supabase-configured signed iOS build installed and launched on the
  physical iPhone.
- Physical offline/online sync behavior was not manually exercised after launch.

# 2026-05-12 Wearable Capture And Signal Research Addendum

## Implemented

- Added debug Device-screen controls to start, stop, and relabel wearable packet
  capture scenarios after approval.
- Added local-only JSONL capture records with timestamp, characteristic UUID,
  byte count, direction, base64 payload, decoded packet type, connection state,
  RSSI, decoded device time, app state, and scenario.
- Recorded both notify packets and app write commands so historical sync,
  realtime enable/disable, haptics, and ACK behavior can be analyzed together.
- Kept raw payload bytes out of Device diagnostics and production logs.
- Added tests for capture record encoding and local JSONL capture output.
- Added docs for capture mode, large packet capture plan, feature signal
  research, and device-derived feature matrix.

## Not Implemented

- No direct wearable sleep/session, sleep stage, nap, step-count, workout,
  calories, respiratory-rate, true RR/IBI HRV, or calibrated SpO2 decoder was
  added because no new capture proved those semantics.
- No production sleep/stage/nap/step algorithm was added from raw motion, HR, or
  PPG streams.
- No clinical or medical claims were added.

## Validation

- Focused wearable protocol XCTest passed: 36 tests, 0 failures.
- Full build/test/generic/device validation remains to be rerun after the doc
  update and final safety checks.

## Physical Status

A physical packet capture pass was completed on the approved iPhone with local
developer capture enabled and the wearable connected. The raw JSONL files were
copied to a temporary local directory outside the repo for aggregate analysis
only. The repo docs contain counts and classifications, not raw payloads.

Physical capture aggregate:

- Capture files inspected: 16.
- Capture records inspected: 2,812.
- Valid reassembled protocol frames: 536.
- Content-CRC failed frames: 2.
- Scenario labels represented: `idle`, `wrist_off`, `wrist_on`, `double_tap`,
  and older `unknown` captures.
- Confirmed records/signals: standard HR, standard battery, command responses,
  realtime/raw realtime frames, historical packet presence, metadata, firmware
  log classification, R10/R11-like families, battery event, wrist-off event,
  and double-tap event.
- Still unconfirmed: sleep sessions, sleep stages, naps, explicit step counts,
  activity/workout summaries, calories, true RR/IBI HRV, respiratory rate,
  calibrated SpO2, production temperature, charging events, wrist-on event,
  haptic fired/terminated events, and alarm events.

Decoder decision: no new production metric decoder was added because the newly
captured frames did not safely prove additional health metric semantics beyond
the decoders/scaffolds already present.
