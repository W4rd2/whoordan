# Whoordan Feature Research And Validation

Audit date: 2026-05-11

This document validates implemented Whoordan features against repo evidence,
automated tests, and current public/official sources. It does not claim physical
device validation unless that validation was actually performed. Whoordan uses
original wellness heuristics only. It must not diagnose, treat, prevent, or cure
any condition, and it must not copy third-party formulas, UI, colors, trade dress, or
proprietary behavior.

## Source Register

Official technical sources:

- Apple HealthKit authorization, privacy, reading data, observer queries, and
  background delivery:
  <https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data>,
  <https://developer.apple.com/documentation/healthkit/protecting-user-privacy>,
  <https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit>,
  <https://developer.apple.com/documentation/healthkit/executing-observer-queries>.
- Apple HealthKit HIG:
  <https://developer.apple.com/design/human-interface-guidelines/healthkit/>.
- Apple UserNotifications and CallKit:
  <https://developer.apple.com/documentation/usernotifications>,
  <https://developer.apple.com/documentation/callkit>.
- Android BLE, foreground services, and alarms:
  <https://developer.android.com/develop/connectivity/bluetooth/bt-permissions>,
  <https://developer.android.com/develop/connectivity/bluetooth/ble/background>,
  <https://developer.android.com/develop/background-work/services/fgs/service-types>,
  <https://developer.android.com/develop/background-work/services/alarms/schedule>.
- Flutter/local storage packages:
  <https://docs.flutter.dev/cookbook/persistence/sqlite>,
  <https://pub.dev/packages/sqflite>,
  <https://pub.dev/packages/flutter_secure_storage>,
  <https://pub.dev/packages/flutter_blue_plus>,
  <https://pub.dev/packages/flutter_background_service>.
- Supabase Auth, API keys, sessions, and RLS:
  <https://supabase.com/docs/guides/getting-started/api-keys>,
  <https://supabase.com/docs/guides/auth/sessions>,
  <https://supabase.com/docs/guides/database/postgres/row-level-security>,
  <https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection>.

Health/exercise-science sources:

- CDC sleep guidance:
  <https://www.cdc.gov/sleep/about/index.html>,
  <https://www.cdc.gov/sleep/data-research/facts-stats/adults-sleep-facts-and-stats.html>.
- American Heart Association target heart rates:
  <https://www.heart.org/en/healthy-living/fitness/fitness-basics/target-heart-rates>.
- MedlinePlus pulse oximetry:
  <https://medlineplus.gov/lab-tests/pulse-oximetry/>.
- Sleep stage and sleep-efficiency references:
  <https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis>,
  <https://www.ncbi.nlm.nih.gov/medgen/1669302>,
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC4751425/>.
- HRV/wearable context:
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC10662962/>,
  <https://pubmed.ncbi.nlm.nih.gov/30416733/>.
- Private user-owned wearable export field mapping:
  `docs/WHOORDAN_PRIVATE_WEARABLE_EXPORT_FIELD_MAPPING.md`.

Public UX references used only for broad category awareness:

- Apple HealthKit HIG and Apple Health presentation guidance listed above.
- General wellness-app category review without copying another product's UI,
  formulas, terminology, or product claims.

## Validation Summary

Automated validation in this run:

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 152 tests.
- `flutter build ios --no-codesign`: passed.
- `git diff --check`: passed.

Not completed in this run:

- Android build, because the local Android SDK is unavailable.
- Two-user live Supabase RLS probes.
- Physical iPhone HealthKit permission/import/write validation.
- Physical Android BLE/wearable reconnect/background validation.
- TestFlight install/review validation.

## Feature Validation Matrix

Status values:

- `IMPLEMENTED_VALIDATED`: implementation exists and automated validation covers
  the core behavior.
- `IMPLEMENTED_NOT_PHYSICALLY_VALIDATED`: implementation and automated tests
  exist, but real device/backend validation is still required.
- `PARTIAL`: useful implementation exists but feature scope is incomplete.
- `SCAFFOLDED`: honest model/copy/UI exists without claiming full behavior.
- `BLOCKED_PLATFORM`: platform or firmware capability is not available.
- `UNTESTED`: not validated in this run.

| # | Feature | Status | Sources used | Selected method and data display | Required/optional inputs | Missing/stale/outlier/confidence behavior | Tests and validation | Remaining limitations |
|---:|---|---|---|---|---|---|---|---|
| 1 | Admin approval gate | IMPLEMENTED_VALIDATED | Supabase API keys/RLS/sessions docs | `public.user_access` is the outermost gate; only `approved` unlocks app. Locked screens show no private data. | Signed-in Supabase user, `user_access` row. Optional email for lookup. | Missing/error rows lock. Revoked status stops protected work. Confidence is binary access state. | `approval_gate_test.dart`, `supabase_schema_test.dart`, full tests pass. | Two-user live RLS probe still needed. |
| 2 | Auth/session | IMPLEMENTED_VALIDATED | Supabase sessions, Flutter secure storage | Supabase email/password with secure-storage-backed session restore and refresh. | Supabase URL/key, email/password. | Offline cached identity can launch only through approval check; no token logging found. | `auth_session_persistence_test.dart`, static secret search, full tests pass. | Real expired-session edge cases should be device-tested. |
| 3 | Local-only mode | IMPLEMENTED_VALIDATED | Supabase/API key docs, Apple HealthKit privacy | Local-only is available only after approval and never permits cloud upload. | Approved signed-in user. Optional Apple Health/BLE permissions. | Revocation hides cached local health UI without silently deleting local data. | `local_mode_test.dart`, approval tests pass. | Physical local-only HealthKit/BLE not run. |
| 4 | Cloud sync | IMPLEMENTED_VALIDATED | Supabase RLS/API keys/sessions | Sync requires signed-in, approved, cloud consent, and health-sync consent where applicable. Initial, incremental, repair, retry/backoff, queue, and dedupe are implemented. | User id, local repository, consent records, configured Supabase. | Blocked sync writes safe local status. Failures use user-safe messages. | `cloud_sync_engine_test.dart`, `cloud_sync_coordinator_test.dart`, `privacy_sync_test.dart`. | Live backend sync with real data not run. |
| 5 | Supabase/RLS | IMPLEMENTED_VALIDATED | Supabase RLS/API key docs | Protected tables require owner check plus approved access row. Publishable key only. No metadata authorization. | Auth JWT and `user_id`. | Unauthenticated access fails because `auth.uid()` is null. No self-approval update policy. | `supabase_schema_test.dart`; live advisors checked. | Leaked password protection remains manual Dashboard setting; two-user probes not run. |
| 6 | Apple Health | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Apple HealthKit authorization/privacy/HIG/observer docs | Native MethodChannel availability, fine-grained request, anchored imports, deletes, source labels, limited writes. Approval gate blocks pre-approval access. | iOS device, HealthKit entitlement, user permission. | Denied/unavailable/partial states are modeled. Implausible values are dropped. Source labels preserved. | `healthkit_test.dart`, iOS build passed. | Real permission sheet, historical import, background delivery, and write paths need device validation. |
| 7 | BLE/wearable | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Android BLE permissions/background docs, `flutter_blue_plus` docs | Scan/connect/reconnect plus parser normalization for HR, SpO2, HRV, respiratory, diagnostics. Approval gate blocks pre-approval. | Compatible wearable and protocol packets. | Malformed values dropped; duplicates deduped; out-of-order packets marked. | `ble_processing_test.dart`, `ble_reconnect_coordinator_test.dart`. | Real wearable behavior, long reconnect, firmware catch-up not validated. |
| 8 | Background/lifecycle | PARTIAL | Apple HealthKit observer docs, Android background/FGS docs, `flutter_background_service` docs | Cold start/foreground/background/network hooks are approval-gated and bounded. | Approved user, signed-in cloud account for cloud work. | Revocation/sign-out stop protected jobs. Background work is best-effort. | Lifecycle/static tests and sync tests pass. | Passive network reachability only; real OS scheduling not proven. |
| 9 | Steps | IMPLEMENTED_VALIDATED | HealthKit data docs, broad wearable UX references | Direct/imported steps; deterministic source priority prefers wearable then Apple Health. | Step samples. | Missing shows empty state. Outliers capped at import. Confidence follows source/coverage. | Source-priority scoring tests. | No step-derived distance yet. |
| 10 | Calories | IMPLEMENTED_VALIDATED | HealthKit active energy docs, HealthKit HIG | Active energy import is direct; manual workout calories are local estimates and labeled. | Active energy samples or manual workout. | Missing shows no imported active energy. Estimates are not exact. | `local_health_insights_test.dart`, UI copy search. | Total/resting energy model not implemented. |
| 11 | Distance | PARTIAL | HealthKit distance types | Imported workout/distance is preferred. Manual workout distance is user-entered. No stride estimate is presented as exact. | Distance sample or manual entry. | Missing distance omitted. Outliers capped. | HealthKit mapper tests and local action tests. | Profile/stride-based estimate intentionally not implemented. |
| 12 | Heart rate | IMPLEMENTED_VALIDATED | HealthKit HR docs, AHA context, BLE docs | Direct HR samples, daily summaries, live and workout contexts. | HR samples. | 25-240 bpm bounds; stale age display can improve. | BLE and HealthKit tests. | Physical sensor accuracy not validated. |
| 13 | Resting heart rate | IMPLEMENTED_VALIDATED | HealthKit RHR docs | Import-only RHR, compared to personal baseline for recovery. | RHR samples. | Missing RHR lowers recovery confidence; no guessed RHR. | Scoring and HealthKit tests. | No app-derived overnight RHR algorithm. |
| 14 | HRV | IMPLEMENTED_VALIDATED | HRV PubMed review, wearable review, HealthKit HRV | BLE uses RMSSD only from RR intervals; Apple Health HRV is imported separately and should carry method/source metadata. | RR intervals or imported HRV. | Missing skipped. Invalid or >500 ms dropped. Confidence depends on RR count/baseline. | BLE RMSSD/scoring tests. | UI can make SDNN/RMSSD method differences more explicit. |
| 15 | Respiratory rate | IMPLEMENTED_VALIDATED | HealthKit respiratory rate, wearable review | Direct/imported respiratory rate only. | Respiratory samples. | 4-60 br/min bounds; missing skipped. | BLE/HealthKit tests. | No physical accuracy validation. |
| 16 | Blood oxygen / SpO2 | IMPLEMENTED_VALIDATED | HealthKit SpO2, MedlinePlus pulse oximetry | Direct/imported display and trends only, cautious copy. | SpO2 samples. | 70-100 percent bounds; no emergency interpretation. | BLE/HealthKit/static copy tests. | Consumer device accuracy not validated. |
| 17 | Skin/body/wrist temperature | IMPLEMENTED_VALIDATED | HealthKit temperature types | Imported values; recovery uses baseline-relative deviation. | Temperature samples. | 20-45 C bounds; no fever/illness/fertility claim. | HealthKit outlier/scoring tests. | Environmental/device effects remain user-facing limitation. |
| 18 | Sleep tracking | IMPLEMENTED_VALIDATED | HealthKit sleep analysis, CDC/NINDS sleep references, sleep-efficiency references, private export field mapping | Imported sleep only; stage metadata preserved; in-bed/awake excluded from sleep duration. Source-reported stage totals can be displayed as totals without fabricating timelines. | Sleep start/end/category samples, optional efficiency/consistency/stage-total metadata. | Missing shows empty state. Invalid intervals dropped. Confidence depends on repeated samples. | HealthKit sleep mapping, scoring, and wearable export mapper tests. | No polysomnography validation or overlap reconciliation. |
| 19 | Sleep debt / need / planner | IMPLEMENTED_VALIDATED | CDC sleep guidance, NINDS sleep basics, sleep-efficiency references, private export field mapping | Original conservative heuristic from personal baseline, recent sleep, naps, strain, consistency, and source-labeled efficiency where available. Source-reported proprietary sleep need/debt values are not imported as Whoordan truth. | Sleep history, optional efficiency/consistency/nap metadata. | Fallback is estimated and low confidence. Need is clamped 6-11 hours. | `scoring_engine_test.dart`, `wearable_export_mapper_test.dart`. | Not clinical sleep advice. |
| 20 | Recovery score | IMPLEMENTED_VALIDATED | CDC sleep, HRV literature, HealthKit docs | Original 0-100 baseline-relative weighted estimate. | At least one recovery contributor plus baseline/direct bound. | Missing contributors skipped. Confidence is coverage weighted. | Recovery tests pass. | Not clinically validated. |
| 21 | Strain/activity-load score | IMPLEMENTED_VALIDATED | AHA HR zones, general training-load principles, private export field mapping | Original 0-21 saturating estimate from HR zones, workouts, movement, strength, stress. Source-reported workout zone percentages can feed the original formula at lower confidence when continuous HR samples are missing. Proprietary day/activity strain values are not imported. | At least one load contributor. | Missing lowers confidence; score clamps 0-21. | Strain tests pass, including workout-zone fallback. | Not lab-validated. |
| 22 | Personalized strain target | IMPLEMENTED_VALIDATED | AHA exercise caution plus internal recovery method | Conservative target range from recovery and recent strain. | Recovery result, recent strain history. | Incomplete recovery gives conservative low-confidence target. | Strain target tests. | Not coaching/medical clearance. |
| 23 | Heart-rate zones | IMPLEMENTED_VALIDATED | AHA target heart rates | Configurable max HR preferred; fallback 208 - 0.7 * age is labeled estimated. | HR samples and max HR or age/fallback. | Missing HR no zone summary. Configured max HR has higher confidence. | HR zone tests pass. | No lab threshold model. |
| 24 | Stress monitor | IMPLEMENTED_VALIDATED | HRV wearable literature | Physiological body-signal estimate from HR, HRV, respiratory rate, and optional stress input. | Baseline signals. | Missing lowers confidence; no mental-health diagnosis. | Stress/scoring and copy tests. | Not a mental health assessment. |
| 25 | Breathing/relaxation | IMPLEMENTED_VALIDATED | HealthKit mindful session support | Local guided session logging with optional pre/post HR values. | Duration, optional HR before/after. | Missing HR still logs mindful minutes. | Local health action tests. | No clinical stress-reduction claim. |
| 26 | Workout tracking | IMPLEMENTED_VALIDATED | HealthKit workouts/energy/distance docs, private export field mapping | Imports workouts and supports manual workout logs with duration, HR, distance, estimated calories, source labels, GPS availability metadata, max/average HR, and HR-zone percentage display when available. | Workout sample or manual entry. | Estimated calories labeled. Missing fields omitted. | Local action, sync, and wearable export mapper tests. | No GPS route recorder. |
| 27 | Strength training / muscular load | IMPLEMENTED_VALIDATED | General load principles, original heuristic | Sets/reps/weight produce transparent local muscular load that can contribute to strain. | Exercise, sets, reps, optional weight. | Missing strength load simply omitted. | Local health/scoring/schema tests. | Simple estimate, not biomechanics. |
| 28 | VO2/cardio fitness | IMPLEMENTED_VALIDATED | HealthKit VO2 max/cardio fitness | Import-only; no internal estimate. | VO2 max samples. | Missing omitted; trends only. | Scoring cardio import tests. | No estimate model. |
| 29 | Long-term health metrics | PARTIAL | HealthKit HIG, Apple privacy guidance | Trends use local encrypted indexed history and baseline bands. | Repeated samples. | Avoids single-day alarm; confidence/stale display can improve. | Scoring/local storage tests. | Long historical import performance not physically tested. |
| 30 | Menstrual cycle insights | PARTIAL | HealthKit sensitive type docs, Apple privacy guidance | Explicit consent gates cycle import/display. Context only. | Consent plus cycle samples. | Hidden until consent; no prediction. | Sensitive consent/import tests. | No cycle prediction, contraception, or fertility feature. |
| 31 | Pregnancy-related tracking | SCAFFOLDED | Apple privacy/HIG caution | User-declared context copy only; no detection. | Consent/user declaration later. | Hidden/disabled until user enables context. | Static copy tests. | No data entry beyond scaffold. |
| 32 | Irregular rhythm events | PARTIAL | HealthKit irregular rhythm type, Apple privacy | Import/display Apple Health events after consent only. No custom detector. | Consent plus Apple Health event. | Missing hidden. No diagnosis or heart-attack claim. | Sensitive HealthKit/static copy tests. | Physical Apple Health event import not tested. |
| 33 | Journal/habits | IMPLEMENTED_VALIDATED | Apple privacy/HIG for health data handling, private export field mapping | Local journal/habit entries with privacy-preserving sync gate. Export-style yes/no questions can map to custom habit definitions/logs without importing private notes into tests. | Entries, habits, optional mood/soreness/stress. | Local-only stays local; cloud requires consent. Explicit `no` values are without-habit days. | `journal_habit_test.dart`, `wearable_export_mapper_test.dart`. | UX can be refined. |
| 34 | Recovery insights/habit correlations | IMPLEMENTED_VALIDATED | Cautious correlation principles, private export field mapping | Minimum sample groups and confidence; uses association wording. Explicit no answers are treated as without-habit days. | Habit logs and recovery scores. | Insufficient samples produce no claim. | Journal insight tests. | No causation claim. |
| 35 | Haptics/vibration patterns | IMPLEMENTED_VALIDATED | Android/iOS notification and wearable limits, internal model | Built-ins, custom recorder/editor, serialization, duration/repeat/intensity limits. | Pattern segments. | Unsafe patterns normalized; disconnected wearable handled by no-preview behavior. | `vibration_models_test.dart`. | Exact custom wearable interval playback needs firmware validation. |
| 36 | Alarm vibration | SCAFFOLDED | Android alarm docs | Alarm settings model with pattern/snooze/edit/delete fields. | Alarm time and pattern. | Bounds hour/minute/snooze. | Alarm model tests. | Native scheduling/snooze dispatch not implemented. |
| 37 | Notification vibration | BLOCKED_PLATFORM | Apple UserNotifications, Android notification listener docs | Default/per-app preference model exists; no unsupported iOS third-party notification mirroring claim. | App identifier when platform supplies one. | Unsupported paths documented. | Static permission tests and resolver tests. | Real notification listener/mirroring not implemented. |
| 38 | Call vibration | BLOCKED_PLATFORM | Apple CallKit docs | Separate call pattern model exists; no generic phone-call interception claim. | Platform-supported call event later. | Unsupported paths documented. | Resolver tests. | Generic call mirroring blocked/not implemented. |
| 39 | Device diagnostics | IMPLEMENTED_VALIDATED | BLE docs and privacy logging rules | Device id/name, firmware, battery, RSSI, last packet, last sync, safe preview. | BLE identity/packet/battery streams. | No sensitive token/session logs. | BLE diagnostics tests. | Real device diagnostics not physically verified. |
| 40 | UI/product display | PARTIAL | Apple HealthKit HIG, public wearable category references | Original Whoordan dark premium UI with source/confidence/estimate/empty states. Auth header adjusted for iPhone safe display. | Local insights and UI state data. | Empty/loading/error states used; color not the only status in key places. | Widget/static tests and device screenshot remediation. | Full accessibility/contrast/small-screen visual QA still needed. |
| 41 | TestFlight readiness | PARTIAL | Apple HealthKit HIG/App Store privacy expectations | iOS bundle/display name, HealthKit strings, entitlements, no-codesign build pass. | Signing, icons, metadata, privacy copy. | Manual legal/review items documented. | iOS build passed. | TestFlight upload, final metadata, physical tests, Android SDK/build remain open. |

## Security And Safety Search Results

Searched repo text for service-role keys, private-key indicators, token/logging
patterns, user-metadata authorization, fake/demo metric phrases, third-party/legacy
visible branding, and unsafe medical language. Findings:

- No client service-role key or secret key was found.
- No `print`, `debugPrint`, or `console.log` token/health logging was found in
  `lib/`.
- `raw_user_meta_data` and `user_metadata` appear only in docs/tests warning not
  to use them for authorization.
- public BLE protocol reference and protocol UUID helper remain internal BLE compatibility
  names only, documented in the legacy naming audit.
- Medical terms appear in disclaimers, safety tests, or blocked-feature copy,
  not as production claims.

## Fixes Applied In This Run

- Adjusted the auth screen top padding and header title scaling so the Whoordan
  title does not clip on the tested iPhone layout with larger text.
- Added a static guard in `test/validation_hardening_test.dart` for the auth
  header spacing/scaling pattern.
- Updated repo documentation to reflect encrypted indexed storage, approval-gated
  local-only mode, current validation counts, and the remaining unvalidated items.

## Open Must-Test Items

1. Run two-user Supabase RLS probes with disposable users:
   user A own rows allowed, user B own rows allowed, cross-user read/update/delete
   denied, unauthenticated private access denied, unapproved private access
   denied.
2. Enable Supabase leaked password protection in Dashboard Auth settings.
3. Run physical iPhone HealthKit tests for permission states, anchored import,
   sensitive consent types, background delivery, and write whitelist.
4. Run Android BLE/wearable tests for scan, pair, reconnect, malformed/duplicate/
   out-of-order packets, diagnostics, low battery, and background constraints.
5. Validate haptic preview and custom pattern behavior on the actual wearable.
6. Configure Android SDK locally and run `flutter build apk`.
7. Run TestFlight install and review the launch screen, icon, Info.plist copy,
   privacy policy, and small-screen accessibility.
