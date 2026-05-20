# Whoordan Health Feature Implementation Report

Date: 2026-05-11
Branch: `swift-app`

## Implemented In This Pass

- Added `MovementSummary` to the daily health model.
- Added Apple Health sample mapping for steps, active energy, walking/running distance, sleep duration, workouts, body temperature, wrist temperature, and VO2.
- Added a HealthKit import method that queries authorized samples for the current day after approval and permission request.
- Added source-aware movement aggregation with dedupe and Apple Health source preference.
- Added step goal progress and configurable step goal bounds.
- Added movement contribution to Whoordan strain only when the movement source is valid.
- Added Today dashboard coverage for steps and workout/movement minutes.
- Added a Movement screen with step goal, source/confidence state, active energy, distance, last updated, and source CTAs.
- Added Workouts, Strength, Body Signals, and Trends surfaces under Settings with honest missing/scaffolded states.
- Added tests for HealthKit step/energy/distance mapping, supported read types, movement dedupe/source priority, no fake steps from IMU, movement strain contribution, missing-source strain rejection, and UI surface contracts.
- Added consent-gated Supabase health-sample upload using the publishable key and signed-in bearer token. Upload is blocked unless the user is approved and both Cloud sync and Health-data cloud consent are enabled.

## Files Changed

- `Whoordan/Core/Models/HealthModels.swift`
- `Whoordan/Core/HealthKit/HealthKitService.swift`
- `Whoordan/Core/Scoring/ScoringEngines.swift`
- `Whoordan/App/AppEnvironment.swift`
- `Whoordan/Features/Today/TodayView.swift`
- `Whoordan/Features/Settings/SettingsView.swift`
- `WhoordanTests/HealthKitTests.swift`
- `WhoordanTests/ScoringTests.swift`
- `WhoordanTests/DesignContractTests.swift`
- `WhoordanUITests/WhoordanUITests.swift`
- `docs/WHOORDAN_WEARABLE_FEATURE_PARITY_MATRIX.md`
- `docs/WHOORDAN_SWIFTUI_HEALTH_FEATURE_GAP_MATRIX.md`
- `docs/WHOORDAN_HEALTH_FEATURE_IMPLEMENTATION_REPORT.md`

## Data Source Behavior

- Apple Health samples are imported only after admin approval and HealthKit authorization.
- BLE remains approval-gated and does not create steps from raw accelerometer data.
- Source resolution is now device-first: reliable wearable BLE measurements outrank Apple Health, then manual data, then labeled estimates, then cloud restoration copies.
- Movement aggregation deduplicates identical source records and prefers reliable wearable step samples over Apple Health step samples. Apple Health remains the fallback when no reliable wearable step count exists.
- Cloud copies are backup/restoration data. They are ignored as measurement sources unless explicitly marked as restored user-owned measurement copies.
- Cloud upload eligibility remains separate and still requires approval, cloud consent, and health-data consent.
- Uploaded HealthKit source identifiers and dedupe keys are SHA-256 hashed before they leave the device.

## New In The Device-First Pass

- Added `DataSource.deviceFirstRank`.
- Added `HealthSourceResolver` with source label, confidence, stale/missing status, and safe reason strings.
- Added `DailyHealthAggregator` for local-day aggregation, dedupe, source priority, sleep-minute filtering, and summary confidence.
- Added local benchmark parser/mapper tests with synthetic CSV fixtures.
- Added `Tools/WhoordanBenchmark/WhoordanBenchmark.swift` for local aggregate-only validation against private exports.

## Scoring Behavior

- Recovery remains an original Whoordan 0-100 wellness estimate.
- Strain remains an original Whoordan 0-21 activity-load estimate.
- Steps, active energy, and movement minutes contribute only when source confidence is not unavailable.
- Movement-only strain is low confidence because it lacks direct heart-rate intensity.

## Still Partial

- Full historical HealthKit import and anchored incremental checkpoints.
- Per-type HealthKit authorization status.
- Workout history/detail models and workout HR zones.
- Sleep stages, naps, consistency, planner, and trend logic.
- Strength/muscular load.
- Stress/breathing.
- Menstrual/cycle and pregnancy context with explicit consent.
- Long-term trends.
- Data export/deletion/account deletion workflows.

## Physical Validation Needed

Physical iPhone validation passed for the focused Apple Health path: the app reached authorized status, imported Apple Health samples into local app state, enabled explicit cloud health consent, uploaded through Supabase REST, and the live database showed 175 `health_samples` rows created within the validation window. No private health values were printed.

## Private Export Relationship Analysis Result

The local benchmark harness was rerun against the private CSV export directory
on 2026-05-12. Output was aggregate-only and the raw files remained outside the
repository.

- Files loaded: journal entries, physiological cycles, sleeps, workouts.
- Row counts: journal 180, cycles 63, sleeps 67, workouts 5.
- Date ranges: journal 2025-11-08 to 2025-11-26, cycles 2025-11-05 to
  2026-01-13, sleeps 2025-11-07 to 2026-01-06, workouts 2025-11-15 to
  2025-12-19.
- Mapped columns: journal 6/6, cycles 26/26, sleeps 18/18, workouts 17/17.
- Strongest recovery relationship: HRV versus recovery, Pearson 0.777 and
  Spearman 0.815 across 61 comparable rows.
- Strongest baseline-relative recovery relationship: HRV above rolling baseline,
  Pearson 0.808 and Spearman 0.826 across 54 comparable rows.
- Other useful recovery signals: respiratory rate closer/below baseline and RHR
  below baseline. Sleep duration was supportive but weaker.
- Noisy or counter-directional recovery signals in this export: skin
  temperature, sleep efficiency, sleep debt, and SpO2.
- Strongest sleep relationship: sleep performance versus asleep duration,
  Pearson 0.909 and Spearman 0.807 across 67 rows.
- Sleep stage duration totals were present as source totals, but Whoordan still
  does not fabricate sleep-stage intervals from totals or weak sensor patterns.
- Workout strain relationships were directionally promising but weakly
  validated because only 5 workouts were present.
- Journal categories did not have enough balanced yes/no samples for reliable
  behavior insights; Whoordan must keep minimum sample thresholds and
  association-only language.

Formula decision from the aggregate analysis: Whoordan's original recovery
heuristic was tuned to make HRV the highest-weight contributor, keep RHR and
respiratory deviation as meaningful baseline-relative inputs, reduce sleep to a
supporting contributor, reduce temperature to contextual weight, and avoid
adding SpO2 or previous-day strain as direct score drivers from this single-user
export.

The Recovery screen now surfaces that decision directly with score, category,
confidence, source labels, top positive contributors, top negative contributors,
and a missing-data confidence row. It explains HRV relative to baseline, RHR
relative to baseline, sleep sufficiency, respiratory fit, and temperature
deviation, and it explicitly avoids medical-advice or third-party equivalence claims.

No raw rows, private notes, exact private timestamps, personal identifiers, or
individual health values were copied into tests or docs.

# 2026-05-12 Wearable Capture Research Update

- Added approved-user developer capture mode with scenario-labeled local JSONL
  records for BLE notifications and writes.
- Added packet capture plan for idle, walking, running, workout, full-day,
  pre-sleep, overnight/post-wake, nap, charging, wrist on/off, haptic, alarm,
  and double-tap scenarios.
- Added feature signal research that separates direct device metrics,
  validated derivations, experimental prototypes, Apple Health fallbacks, and
  unavailable metrics.
- Added device-derived feature matrix covering sleep, steps, recovery, strain,
  body signals, device state, haptics, alarms, and platform-blocked notification
  and call behavior.
- No new production health metric was added from ambiguous packets.
- A later physical iPhone capture pass inspected 2,812 local records and 536
  valid reassembled frames. It confirmed standard HR, standard battery,
  R10/R11-like realtime families, historical packet presence, battery event,
  wrist-off event, double-tap event, command responses, metadata, and firmware
  log classification. It did not confirm sleep, naps, stages, explicit steps,
  activity summaries, workouts, calories, true HRV, respiratory rate,
  calibrated SpO2, or production temperature.
# 2026-05-12 Sleep and Movement Update

- Approval/session restore now refreshes expired Supabase sessions and retries
  approval once after `401` or `403`.
- Sleep now includes last sleep, time in bed, awake time when measured,
  efficiency, naps, stage totals when provided, 7-night patterns, sleep need,
  sleep debt, and a conservative bedtime planner.
- Movement now includes steps, goal progress, source/confidence, distance,
  active energy, last updated, 7-day average, best day, trend, and daily rows.
- Wearable remains primary by source priority when reliable samples exist.
- Current wearable captures do not yet prove sleep, naps, stages, or step-count
  packets, so Apple Health remains fallback for those metrics.
- No fake steps from IMU, no fake naps from motion/HR, no fake sleep stages, and
  no BPM-only HRV.

# 2026-05-12 Device-First BLE Discovery Update

- Added HelloHarvard battery/charging/wrist/RTC parsing without exposing raw serial values.
- Added structured event timestamp and payload parsing for battery, charging,
  wrist, temperature-event, double-tap, and haptic-event families.
- Tightened R10 and R21 summaries so full IMU/channel counts are claimed only
  when complete packets are present.
- Removed raw byte-window display from the Device screen and stopped keeping
  first/last raw notification bytes in the notification summary model.
- Wearable sleep/naps/steps remain blocked pending explicit packet captures;
  Apple Health remains fallback and write support remains narrow.
- Validation completed: focused packet/HealthKit/design tests, full simulator
  tests, simulator build, generic iOS build, wireless iPhone signed build and
  install, safety search, and `git diff --check`. Physical launch was blocked
  by the locked phone; physical HealthKit import and wearable capture were not
  re-run in this pass.
