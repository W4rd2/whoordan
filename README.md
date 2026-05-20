# Whoordan

Whoordan is a native SwiftUI iOS app for local-first recovery, sleep, strain,
heart, movement, and wearable diagnostics. It is designed as a production-style
mobile engineering project: typed domain models, privacy-first data flow,
source-ranked health metrics, BLE frame decoding, HealthKit integration,
Supabase account sync, and repeatable validation.

The project is by W4rd2. It is wellness and fitness software, not a medical
device. It does not diagnose, treat, prevent, or cure conditions, and it does
not claim to reproduce another company's proprietary scores, branding, formulas,
or product experience.

## Project Snapshot

| Area | Implementation |
|---|---|
| Platform | Native iOS app built with SwiftUI and Xcode |
| Architecture | `AppEnvironment`, protocol-backed services, feature modules, design-system primitives, and core scoring/ingestion layers |
| Data model | Source-labeled health records with confidence labels, provenance, timestamps, and local persistence |
| Privacy | Manual approval gate, local-only mode, explicit cloud-sync consent, file-protected local store, Keychain-backed account sessions |
| Integrations | Apple Health / HealthKit, standard Bluetooth Heart Rate Service, experimental compatible 4.0 wearable strap BLE support, Supabase Auth and sync |
| Validation | Unit and contract tests, SwiftLint, simulator tests, generic iOS build, MAE summaries, and public-release safety checks |
| Scope | Fitness, recovery, sleep, and wellness insights only; no medical claims and no third-party score equivalence claims |

## Why This Repository Matters

This repository demonstrates end-to-end product engineering rather than an
isolated UI sample. It includes mobile architecture, sensitive-data handling,
BLE protocol parsing, health-data ingestion, scoring formulas, offline storage,
auth/session boundaries, cloud-sync consent gates, and a validation strategy.

For employers, the most relevant parts are:

- Clear separation between app composition, feature UI, core models, scoring,
  BLE, HealthKit, storage, and Supabase integration.
- Privacy-sensitive defaults for health, sleep, fitness, journal, and wearable
  data.
- Original scoring formulas documented with inputs, clamps, confidence labels,
  limitations, and MAE evaluation summaries.
- BLE frame decoding documented at the record-type level without publishing raw
  private captures or device identifiers.
- Public-repo hygiene: no service-role keys, no raw private health exports, no
  signing material, no local `.env` files, and no unsupported affiliation
  claims.

## Table Of Contents

- [Project Snapshot](#project-snapshot)
- [Why This Repository Matters](#why-this-repository-matters)
- [Quick Start](#quick-start)
- [Engineering Highlights](#engineering-highlights)
- [Repository Map](#repository-map)
- [Product And Release Boundaries](#product-and-release-boundaries)
- [Supported Data Sources And Devices](#supported-data-sources-and-devices)
- [Privacy Model](#privacy-model)
- [Architecture](#architecture)
- [Model And Formula Calibration](#model-and-formula-calibration)
- [Validation MAE Summary](#validation-mae-summary)
- [Metric Calculations](#metric-calculations)
- [BLE Compatibility And Frame Decoding](#ble-compatibility-and-frame-decoding)
- [Public Repo Safety Checklist](#public-repo-safety-checklist)
- [Validation](#validation)
- [License](#license)

## Quick Start

Requirements:

- macOS with Xcode installed
- iOS Simulator support for the selected destination
- SwiftLint installed locally if lint validation is required
- Optional public Supabase configuration for account-mode testing

Inspect the project:

```bash
xcodebuild -list -project Whoordan.xcodeproj
```

Run the primary validation commands:

```bash
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
swiftlint lint --config .swiftlint.yml
```

No service-role keys, admin keys, raw private health exports, or signing assets
are required to build or test the public-safe app surface.

## Engineering Highlights

- Native SwiftUI app shell with approved, locked, signed-out, and session-restore
  routes.
- `@MainActor` `AppEnvironment` coordinating protocol-backed services and async
  app state.
- HealthKit foundations for permission-aware import, anchored checkpoints,
  source labeling, app-origin write queues, and local sample storage.
- BLE service layer for discovery, connection state, frame validation, sequence
  tracking, command construction, diagnostics, haptic paths, and sample
  ingestion.
- Standard Bluetooth Heart Rate Service parser for BPM, contact state, RR
  intervals, RMSSD, SDNN, and low-confidence RR-derived respiratory estimates.
- File-protected local JSON persistence for sensitive snapshots, checkpoints,
  sync queues, journal data, alarms, and haptic settings.
- Supabase account mode using public anon/publishable keys only, with approval
  gating and explicit health-data cloud-sync consent.
- Original wellness scoring engines for recovery, strain, sleep, stress, heart
  zones, movement, calories, VO2, respiratory wellness, and confidence labels.

## Repository Map

| Path | Purpose |
|---|---|
| `Whoordan/App/` | App entry, dependency wiring, routing, app state, and shell composition |
| `Whoordan/Core/` | Domain models, scoring, BLE, HealthKit, storage, sync, Supabase, CSV import, and shared services |
| `Whoordan/DesignSystem/` | Shared native UI primitives and visual foundations |
| `Whoordan/Features/` | Feature screens for Today, Recovery, Sleep, Activity, More, and related workflows |
| `WhoordanTests/` | Unit, contract, storage, scoring, protocol, and integration-boundary tests |
| `WhoordanUITests/` | UI launch and interaction coverage |
| `docs/` | Architecture, sync, BLE, validation, privacy, release, and distribution notes |
| `Tools/` | Local benchmark and support utilities |
| `supabase/` | Public-safe database setup/import material; service-role keys are forbidden |

## Product And Release Boundaries

Whoordan is independent software by W4rd2. It is not affiliated with, endorsed
by, sponsored by, or approved by any wearable-device manufacturer. Supported
hardware is described generically by capability and compatibility class. The
app is not made for one specific wearable; compatible 4.0 wearable strap
hardware is one experimental direct-BLE data source alongside Apple Health,
standard Bluetooth Heart Rate Service devices, local manual entries, and
consented cloud backup.

Public visibility is appropriate only when the public branch contains code,
tests, documentation, sanitized aggregate reports, and synthetic fixtures. It
must not contain raw private health data, raw BLE captures, raw CSV exports,
signing files, `.env` files, tokens, private device identifiers, or
service-role/admin keys.

Important legal boundary: no README, disclaimer, code change, or compatibility
note can guarantee that another company will not sue or send a claim. This
project reduces risk by avoiding affiliation claims, copied formulas, copied UI
or trade dress, third-party logos, raw captures, and device-manufacturer product
claims. This is not legal advice. A qualified attorney should review the name,
repository, app copy, App Store listing, and device-compatibility wording before
public release or commercial distribution.

Approved compatibility wording:

- "Experimental direct BLE compatibility with user-owned compatible 4.0 wearable
  strap hardware."
- "Independent software; not affiliated with or endorsed by any wearable-device
  manufacturer."

Blocked wording:

- "Official device-manufacturer support."
- "Replacement for another wearable app."
- "Same recovery/strain/sleep score as another wearable app."
- "Formula compatible with another wearable app."

## Supported Data Sources And Devices

| Source or device | Status | What it can provide | Boundaries |
|---|---|---|---|
| Apple Health / HealthKit | Supported foundation | Source-labeled heart, sleep, activity, respiratory, oxygen, temperature, VO2, and workout samples where permission and platform data exist | Requires iOS permission. Whoordan preserves source labels and does not invent missing data. |
| Standard Bluetooth Heart Rate Service (`180D`) | Supported parser | Heart rate from `2A37`, contact flag, RR intervals, RMSSD, SDNN, RR-derived respiratory estimate, standard battery from `2A19` when exposed | RR-derived respiratory rate is low confidence. BPM-only data is never converted to HRV. |
| Compatible 4.0 wearable strap hardware | Experimental direct BLE compatibility | Discovery, connection, frame validation, packet classification, R10 HR/IMU summaries, R21 optical diagnostics, R24 SpO2 candidate, event diagnostics, haptic command paths | Not official manufacturer support. Not endorsed by any wearable-device manufacturer. Does not claim calibrated medical values or proprietary score equivalence. |
| Supabase cloud sync | Implemented behind gates | Account auth, approval gate, profile/settings sync, consented health-data sync queue | Uses only client-safe publishable/anon keys. Service-role keys are forbidden in mobile code. |
| Local manual or imported backup values | Supported only where source-labeled | Local/manual or restored values can fill visible context when accepted by source policy | Lower confidence than direct measured sources. |

## Privacy Model

Health, recovery, sleep, strain, heart rate, HRV, SpO2, respiratory, movement,
temperature, journal, and fitness data are sensitive personal data.

Whoordan's privacy rules:

1. Users must sign in and be manually approved before protected app features
   unlock.
2. Local-only mode is the default protected mode after approval.
3. Health-data cloud sync requires explicit cloud sync plus explicit
   health-data consent.
4. Local-only mode must not call cloud health-data sync.
5. Raw BLE payload capture is developer-only, opt-in, local-only, ignored by
   git, and never uploaded.
6. Raw private CSV exports and raw BLE payload files must not be committed,
   pasted into docs, uploaded, or used as fixtures.
7. Service-role keys, admin keys, signing credentials, tokens, private keys,
   `.env` files, and provisioning files must never be committed.

## Architecture

Whoordan uses a small native iOS architecture:

- `Whoordan/App/`: app composition, routing, lifecycle, and dependency wiring
- `Whoordan/Core/`: domain models, local storage, HealthKit, BLE, Supabase,
  privacy, scoring, sync, updates, and haptics
- `Whoordan/DesignSystem/`: reusable theme, cards, metrics, charts, and branded
  UI primitives
- `Whoordan/Features/`: SwiftUI feature screens that depend on app/core
  abstractions instead of owning platform, network, or persistence integrations
- `WhoordanTests/`: unit and contract tests for scoring, storage, approval
  gates, HealthKit, BLE protocol, sync, update service, and architecture
  boundaries
- `WhoordanUITests/`: app launch and selected physical-device flows
- `Tools/`: local development and benchmark utilities that must print only
  aggregate results and must not print secrets or raw private health rows
- `docs/`: design, validation, BLE, scoring, privacy, and implementation notes

The app stays local-first: wearable, HealthKit, and manual samples are
normalized and persisted locally before summaries update or cloud upload is
queued. Cloud health sync requires approval plus explicit cloud and health-data
consent.

## Data Source Policy

Metric selection is device-first but conservative. Production metric samples
must pass source, confidence, contact, and type gates before aggregation.

## Model And Formula Calibration

Whoordan's models and formulas are original wellness estimates. They were
calibrated with thousands of source-labeled data points, sanitized aggregate
benchmark rows, synthetic edge-case fixtures, and regression tests. The goal is
stable, explainable, source-aware wellness scoring, not cloning another
company's private analytics.

Training and calibration data must remain privacy-safe:

- Raw private health exports and raw BLE captures stay local and ignored by
  Git.
- Public fixtures must be synthetic or sanitized.
- Benchmark output must be aggregate-only.
- Model notes must describe inputs, weights, limitations, and confidence
  boundaries without exposing private rows.

Current source priority:

1. `wearable_ble`
2. `legacy_wearable_device_export`
3. `apple_health`
4. `cloud_import`
5. `whoordan_estimate`
6. `local_manual`
7. `synthetic_fixture`

Important source rules:

- Raw `wearableIMU` and raw `wearablePPG` are never production metrics by
  themselves.
- `whoordan_estimate` is accepted only for known device-only estimates with
  explicit metadata such as `r10_imu_motion_step_estimate`,
  `r10_hr_imu_sleep_stage_estimate`, `rr_interval_respiratory_rate_estimate`,
  or `r24_candidate_ble_derived_spo2`.
- Contact-sensitive samples reject explicit off-contact metadata such as
  `contact_detected=false`.
- Missing values are skipped, not filled with fake neutral values.
- Implausible values are rejected by type-specific bounds before display or
  scoring.

## Confidence Labels

| Confidence | Meaning |
|---|---|
| `high` | Direct or strongly verified source for this app context. |
| `medium` | Source-labeled or parser-validated, but not final lab-grade validation. |
| `directional` | Useful trend or planning estimate with source caveats. |
| `low` | Minimum-data or beta estimate; visible only with explicit context. |
| `blocked` | Metric is intentionally hidden until required inputs exist. |
| `unavailable` | No usable source exists. |

## Validation MAE Summary

MAE means mean absolute error:

```text
MAE = mean(abs(predicted_value - reference_value))
```

These numbers are local aggregate validation labels used to communicate
accuracy limits. They are not medical validation, population validation, or
proof of proprietary score equivalence. Negative R2 means the formula is rough
and should be treated as directional or low confidence.

| Metric | Current aggregate validation label | Dataset size | Notes |
|---|---:|---:|---|
| Live heart rate | MAE 0.11 bpm, max error 2 bpm, 100% within 3 bpm | 755 controlled rows across 16 files | Targeted R10 validation. All-recorded controlled validation also covered 1,187 rows with 99.9% within 3 bpm. |
| Sleep performance | MAE 11.14 percentage points, R2 0.638 | 1,197 sleep rows | Formula-only sleep/need ratio. Residual-model experiments are not shipped in Swift. |
| Sleep need | MAE 60.08 minutes, R2 -0.944 | 1,197 sleep rows | Low-confidence planning estimate. |
| Sleep debt | MAE 102.22 minutes, R2 -15.919 | 1,197 sleep rows | Today-only beta estimate; carryover debt remains cautious. |
| Sleep consistency | MAE 16.78 points, R2 -0.336 | 990 sleep rows | Rolling 7-day bed/wake timing estimate. |
| Recovery | MAE 21.17 points, R2 0.039 | 1,012 cycle rows | Directional readiness estimate only. Not a proprietary recovery score. |
| Day strain | MAE 5.08 points, R2 -2.160 | 1,080 cycle rows | Directional day-load estimate. |
| Activity strain | MAE 2.44 points, R2 -0.511 | 488 workout rows | Formula-only activity/workout estimate. |
| Candidate workout strain benchmark | MAE 2.0 strain points, Pearson 0.851, Spearman 0.900 | 5 workouts | Very small local benchmark; bucket agreement was only 40.0%. |
| Workout calories | MAE 200.21 kcal, R2 -1.014 | 489 workout rows | Rough estimate only when source energy is absent. |
| Daily calories | MAE 414.39 kcal, R2 -0.119 | 1,080 cycle rows | Rough total energy estimate. |
| Steps from R10 IMU | Not label-rated | Pending labeled step ground truth | Current estimator remains low confidence. |
| R24 SpO2 candidate | Not calibrated | Pending measured oximeter/source validation | Shown only as a low-confidence wellness candidate. |
| Stress | Not proprietary-label rated | Not applicable | Original wellness-load score, not a medical stress score. |
| VO2 max estimate | Not label-rated | Not applicable | Low-confidence Uth-Sorensen style estimate when no measured VO2 max exists. |

## Metric Calculations

The following sections describe what the current Swift implementation computes.
They are intentionally explicit so public readers can see the formula boundary
and understand where confidence is low.

### Heart Rate

Inputs:

- R10 direct BLE heart-rate candidate from compatible wearable frames
- Standard Bluetooth Heart Rate Measurement (`2A37`)
- Source-labeled imported heart-rate samples

Acceptance:

- BPM must be in `25...240`.
- Standard GATT contact flag lowers confidence when contact is false.
- Direct BLE samples carry source metadata, characteristic UUID, packet type,
  record type, timestamp basis, and dedupe fingerprint.

Daily aggregation:

- Uses at least six valid HR samples for daily average and max.
- If samples have end dates, average HR is time-weighted by sample duration.
- If no end dates exist, average HR falls back to arithmetic mean.
- Coverage minutes are estimated from sample durations or gaps, capped at five
  minutes per sample/gap.

Public wording:

- Allowed: "direct/source-labeled heart rate."
- Not allowed: "arrhythmia detection" or "clinical heart monitoring."

### Resting Heart Rate

Inputs:

- Source-labeled resting heart rate when available
- Fallback sleep-window estimate only when a main sleep and enough HR samples
  exist

Fallback formula:

```text
sleep_window_values = valid HR samples inside main sleep
required count >= 12
resting_hr = 20th percentile of sorted sleep_window_values
```

The fallback is marked directional/estimated. Whoordan does not infer resting
heart rate from casual daytime BPM.

### Average Heart Rate

Inputs:

- Valid same-day heart-rate samples

Formula:

```text
if samples have durations:
    average_hr = sum(hr_i * duration_seconds_i) / sum(duration_seconds_i)
else:
    average_hr = arithmetic_mean(hr_i)
max_hr = max(hr_i)
sample_count = count(hr_i)
```

Minimum display requirement:

- At least six valid HR samples.

Confidence:

- Medium when sample count is at least 24.
- Directional for lower but still valid coverage.

### Heart-Rate Zones

Inputs:

- User-configured max HR, or
- Age-estimated max HR

Max HR formula:

```text
if configured_max_hr exists:
    max_hr = configured_max_hr
else:
    max_hr = 208 - (0.7 * age_years)
```

Zones:

| Zone | Range |
|---|---|
| 1 | 50-60% of max HR |
| 2 | 60-70% of max HR |
| 3 | 70-80% of max HR |
| 4 | 80-90% of max HR |
| 5 | 90-100% of max HR |

Age-estimated zones are low confidence. Configured max HR improves confidence.

### HRV

Inputs:

- Standard Bluetooth RR intervals, or
- Source-labeled imported HRV

RR interval acceptance:

- Valid RR interval range: `250...2200 ms`.
- Production BLE HRV emission requires at least 16 RR intervals and contact not
  false.

RMSSD formula:

```text
diffs = successive_rr_ms_i - successive_rr_ms_(i-1)
rmssd = sqrt(mean(diffs^2))
```

SDNN formula:

```text
mean_rr = mean(rr_ms)
variance = sum((rr_ms_i - mean_rr)^2) / (count - 1)
sdnn = sqrt(variance)
```

Boundary:

- BPM-only heart rate is never converted to HRV.
- R21 optical summaries are not converted to true HRV.

### Respiratory Rate

Inputs:

- Measured/source-labeled respiratory rate, or
- Low-confidence RR-interval derived estimate

RR-derived estimator:

```text
valid RR intervals = 250...2200 ms
required count >= 30
required window >= 30 seconds
candidate rates = 6.0...30.0 br/min, step 0.25
for each candidate:
    frequency = candidate / 60
    score = hypot(sum(detrended_rr * sin(2*pi*frequency*time)),
                  sum(detrended_rr * cos(2*pi*frequency*time)))
selected_rate = candidate with max score
```

The estimate is low confidence, wellness-only, and not respiratory monitoring.

### Raw Wrist Temperature

Inputs:

- R10 raw wrist/contact temperature
- Device temperature event

R10 formula:

```text
raw = int16_le(r10_inner_bytes[44:46])
wrist_temperature_c = raw / 512
accepted range = 20...45 C
```

Boundary:

- This is raw wrist/contact temperature.
- It is not body-core temperature.
- It is not a medical fever signal.

### Skin Temperature Delta

Inputs:

- Raw wrist/contact temperature
- Active personal skin-temperature baseline

Baseline profile:

- Requires eligible baseline nights.
- Default required eligible day count is 5.
- Valid active baseline range is `20...45 C`.

Formula:

```text
skin_temp_delta_c = raw_wrist_temperature_c - active_baseline_c
```

Confidence stays limited until personal calibration exists.

### Sleep Duration

Inputs:

- Source-labeled sleep sessions, HealthKit sleep samples, legacy device export
  sessions, or low-confidence BLE-derived sleep estimates

Aggregation:

1. Dedupe samples by source, type, and source record ID.
2. Filter sleep samples to the target day plus a 12-hour lookback window.
3. Group samples into sessions when adjacent samples are no more than 90
   minutes apart.
4. Count asleep categories only:
   - `1`: asleep
   - `3`: core
   - `4`: deep
   - `5`: REM
5. Merge overlapping asleep ranges before summing duration.
6. Main sleep is the longest non-nap session.
7. Naps are sessions under 180 asleep minutes when not selected as main sleep.

Sleep duration formula:

```text
asleep_minutes = sum(merged_asleep_ranges)
in_bed_minutes = max(asleep_minutes, sum(merged_all_sleep_ranges))
efficiency_percent = asleep_minutes / in_bed_minutes * 100
```

Boundary:

- Whoordan does not fabricate a stage timeline from aggregate stage totals.

### Sleep Stages

Source-labeled stage mapping:

| Metadata category | Stage |
|---|---|
| `0` | in bed |
| `1` or missing | asleep |
| `2` | awake |
| `3` | core |
| `4` | deep |
| `5` | REM |
| anything else | unknown |

BLE-derived R10 sleep estimate:

- Requires a complete R10 chunk.
- Requires heart rate in `38...72 bpm`.
- Requires accelerometer vector range divided by gravity at or below `0.12`.
- Requires accelerometer and gyroscope range gates at or below 450.
- Emits one low-confidence minute when accepted.

Initial stage heuristic:

```text
if heart_rate <= 55: deep
else if heart_rate <= 64: core
else: asleep
```

Session contextual refinement:

- Requires at least 20 minutes of estimated sleep coverage.
- Requires enough nearby HR samples.
- Uses session progress, stillness, heart-rate low/high scores, heart-rate
  centrality, local HR instability, REM-cycle prior, and nearby HRV context.
- Produces low-confidence deep/core/REM/awake segments.

Boundary:

- BLE-derived stages are estimates, not medical sleep staging.

### Restorative Sleep

Inputs:

- Available source-labeled or BLE-derived deep and REM stage segments

Formulas:

```text
restorative_minutes = deep_minutes + rem_minutes
restorative_percent = restorative_minutes / total_asleep_minutes * 100
clamped to 0...100
```

If no deep/REM/restorative stage segments exist, the metric is blocked.

### Sleep Performance

Inputs:

- Sleep duration
- Sleep need estimate or source-labeled sleep need

Primary formula:

```text
sleep_performance = clamp((sleep_minutes / sleep_need_minutes) * 100, 0, 100)
```

Optional context:

- Sleep efficiency
- Rolling sleep consistency
- HRV/RHR sleep-stress context

Current Swift behavior keeps optional components as confidence/context. It does
not inflate the primary performance ratio by filling missing optional values.

### Sleep Need

Inputs:

- Stored/source sleep-need value, or
- Source-labeled main sleeps, prior sleep debt, and prior day strain

Formula:

```text
if stored_sleep_need exists:
    sleep_need = stored_sleep_need
else if at least 7 main sleeps:
    personal_base = clamp(median(last_14_main_sleep_minutes) + 30, 420, 540)
else:
    personal_base = 480

prior_debt = clamp(previous_sleep_debt_minutes, 0, 300)
prior_strain = clamp(previous_day_strain, 0, 21)
sleep_need = clamp(personal_base + (0.20 * prior_debt) + (2.0 * prior_strain), 420, 600)
```

This is a planning estimate, not a clinical sleep need determination.

### Sleep Debt

Inputs:

- Stored sleep debt, or
- Sleep need plus measured main sleep plus same-day nap credit

Formula:

```text
nap_credit = min(sum(nap_asleep_minutes), 180)
sleep_debt = max(0, sleep_need_minutes - sleep_minutes - nap_credit)
```

Current implementation is today-only unless a prior stored/local value exists.

### Sleep Consistency

Inputs:

- At least two source-labeled or BLE-derived main sleep sessions in the rolling
  seven-session window

Formula:

```text
start_std_hours = circular_standard_deviation(local_sleep_start_hours)
wake_std_hours = circular_standard_deviation(local_wake_hours)
sleep_consistency = clamp(100 - start_std_hours * 9 - wake_std_hours * 7, 0, 100)
```

Confidence:

- Directional with at least four sessions.
- Low with two or three sessions.

### Recovery

Recovery is an original Whoordan 0-100 wellness estimate. It is not a
third-party wearable score, not a medical readiness score, and not a training
clearance.

Inputs:

- HRV and personal HRV baseline
- Resting heart rate and personal RHR baseline
- Sleep minutes and sleep need
- Respiratory rate and personal respiratory baseline
- Temperature delta
- SpO2 as zero-weight context only

Contributor weights:

| Contributor | Weight |
|---|---:|
| HRV relative to baseline | 0.35 |
| Resting HR relative to baseline | 0.20 |
| Sleep sufficiency | 0.17 |
| Respiratory fit | 0.20 |
| Temperature deviation | 0.08 |
| SpO2 source context | 0.00 |

Component formulas:

```text
hrv_score = 50 + ((hrv / hrv_baseline) - 1) * 80
rhr_score = 50 + (1 - (resting_hr / resting_hr_baseline)) * 90
sleep_score = min(sleep_minutes / sleep_need_minutes, 1.12) * 89
respiratory_score = 100 - min(abs(respiratory_rate - respiratory_baseline) / 2, 1) * 80
temperature_score = 100 - min(abs(temperature_delta_c) / 1.2, 1) * 80
spo2_context_score = 50 when SpO2 >= 95, otherwise clamp(20 + ((SpO2 - 90) / 5 * 30), 20, 50)
```

Score formula:

```text
available = contributors with component scores
core_available = available excluding SpO2
if total_weight == 0 or core_weight == 0:
    recovery is unavailable
recovery = clamp(sum(component_score_i * weight_i) / sum(weight_i), 0, 100)
```

Confidence:

```text
if available_weight >= 0.75: high
else if available_weight >= 0.40: medium
else: low
```

User-facing categories:

| Score | Category |
|---|---|
| `< 40` | Low |
| `40..<70` | Steady |
| `>= 70` | Strong |

Implementation boundary:

- SpO2 alone cannot produce recovery.
- Normal SpO2 is not a positive recovery booster.
- Missing contributors are skipped, not imputed.

### Day Strain

Day strain is an original Whoordan 0-21 wellness/training-load estimate. It is
not a proprietary day strain formula.

Inputs:

- Active minutes
- Average HR
- Max HR
- Configured or estimated max HR
- Resting HR
- HR-zone minutes
- Steps and active energy
- Optional muscular minutes

Heart-rate reserve:

```text
resting_hr = clamp(resting_hr ?? 60, 35, 100)
reserve_span = max(max_hr - resting_hr, 1)
average_reserve = clamp((average_hr - resting_hr) / reserve_span, 0, 1)
peak_reserve = clamp((max_observed_hr - resting_hr) / reserve_span, 0, 1)
```

Zone load:

| Zone | Weight per minute |
|---|---:|
| 1 | 1 |
| 2 | 2 |
| 3 | 3 |
| 4 | 5 |
| 5 | 8 |

Load formula:

```text
active_minutes = min(max(input_active_minutes, sum(zone_minutes)), 1440)
peak_minutes = min(active_minutes, 30)
all_day_cardio_load = active_minutes * pow(average_reserve, 1.8) * 0.055
peak_cardio_load = peak_minutes * pow(peak_reserve, 2)
zone_load = sum(zone_minutes[zone] * zone_weight[zone])
step_load = min(steps / step_goal, 1.6) * 12
energy_load = min(active_energy_kcal / 700, 1.5) * 9
movement_load = step_load + energy_load when movement confidence is available
muscular_load = muscular_minutes * 2.5 when source confidence is available
total_load = all_day_cardio_load + peak_cardio_load + zone_load + movement_load + muscular_load
day_strain = clamp(21 * (1 - exp(-total_load / 180)), 0, 21)
```

Confidence:

- Medium when average HR exists.
- Low when only movement or muscular source exists.
- Unavailable when no load contributor exists.

### Activity Strain

Activity strain is a lower-scope activity/workout estimate.

Formula priority:

1. If movement minutes and HR context exist:

   ```text
   reserve = clamp((average_hr - resting_hr) / (max_hr - resting_hr), 0, 1)
   load = movement_minutes * pow(reserve, 1.6) * 5.0
   activity_strain = clamp(21 * (1 - exp(-load / 120)), 0, 21)
   ```

2. If movement minutes exist without HR context:

   ```text
   activity_strain = clamp(movement_minutes / 6.0, 0, 21)
   ```

3. If active energy exists:

   ```text
   activity_strain = clamp(active_energy_kcal / 33.0, 0, 21)
   ```

4. If steps exist:

   ```text
   activity_strain = clamp((steps / step_goal) * 16, 0, 21)
   ```

### Steps

Preferred input:

- Source-labeled step samples

R10 IMU fallback:

- Low-confidence only
- Requires complete R10 accelerometer/gyroscope chunk
- Requires at least 80 accelerometer samples

Estimator:

```text
vm_i = sqrt(x_i^2 + y_i^2 + z_i^2)
gravity = median(vm)
normalized_i = (vm_i - gravity) / gravity
normalized_range must be >= 0.25
smoothed = moving_average(normalized, radius=1)
baseline = median(smoothed)
noise = median(abs(smoothed_i - baseline))
threshold = max(0.0359, noise * 1.5)
peaks = recurrent local maxima above threshold, minimum distance 12 samples
cadence = (60 * 50Hz) / median_peak_interval
accept only cadence 40...220 steps/min and coefficient_of_variation <= 0.55
steps = peak_count
```

Boundary:

- No direct device step-count packet is currently confirmed.
- R10 steps need labeled step ground truth before higher confidence.

### Movement Summary

Inputs:

- Steps
- Active energy
- Walking/running distance
- Workout minutes

Aggregation:

```text
steps = sum(selected_step_samples)
active_energy = sum(selected_active_energy_samples)
distance = sum(selected_distance_samples)
workout_minutes = sum(selected_workout_samples)
movement_minutes = workout_minutes ?? min(max(active_energy / 7.0, 0), 240)
```

Movement contribution to strain:

```text
load = 0
load += min(steps / goal, 1.6) * 16
load += min(active_energy / 700, 1.5) * 10
load += min(movement_minutes / 90, 1.6) * 8
```

### Workout Calories

Priority:

1. Use source-labeled active energy when present.
2. Use HR/profile estimate when duration, average HR, age, sex, and weight are
   available.
3. Use distance/step estimate when profile and distance can be estimated.
4. Use movement-duration fallback when nothing stronger exists.

Keytel-style HR calorie estimate:

```text
female_kcal_per_min = (-20.4022 + 0.4472 * avg_hr - 0.1263 * weight_kg + 0.074 * age) / 4.184
male_kcal_per_min = (-55.0969 + 0.6309 * avg_hr + 0.1988 * weight_kg + 0.2017 * age) / 4.184
active_kcal = max(0, kcal_per_min) * duration_minutes
```

Distance fallback:

```text
step_length_m = height_m * 0.414
distance_m = steps * step_length_m
active_kcal = 0.53 * weight_kg * distance_km
```

Duration fallback:

```text
active_kcal = movement_minutes * 7
```

All calorie estimates are wellness estimates, not metabolic-lab measurements.

### Daily Calories

Resting energy uses Mifflin-St Jeor:

```text
female_bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age_years - 161
male_bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age_years + 5
```

Total daily calories:

```text
if source_active_energy exists:
    total = bmr + active_energy
else if HR reserve active estimate exists:
    total = bmr + heart_rate_reserve_active_energy
else if distance estimate exists:
    total = bmr + distance_active_energy
```

Heart-rate reserve active-energy fallback:

```text
reserve = clamp((average_hr - resting_hr) / (max_hr - resting_hr), 0, 1)
coverage_scale = clamp(coverage_minutes / 1440, 0.10, 1)
active = 0.020 * weight_kg * 1440 * pow(reserve, 1.25) * coverage_scale
```

### Stress

Stress is an original Whoordan wellness-load estimate on a 0-3 scale. It is not
a medical stress score and not a mental-health assessment.

Inputs:

- HRV vs personal baseline
- Resting HR vs personal baseline
- Sleep sufficiency
- Day strain
- Respiratory deviation
- Temperature deviation

Component weights:

| Component | Weight |
|---|---:|
| HRV load | 0.28 |
| Resting HR load | 0.20 |
| Sleep insufficiency | 0.18 |
| Day strain | 0.14 |
| Respiratory deviation | 0.10 |
| Temperature deviation | 0.10 |

Formula:

```text
hrv_load = 1 - min(hrv / hrv_baseline, 1.25)
rhr_load = ((resting_hr / resting_hr_baseline) - 1) * 2.4
sleep_load = 1 - min(sleep_minutes / sleep_need_minutes, 1.1)
strain_load = min(day_strain / 21, 1)
respiratory_load = abs(respiratory_rate - respiratory_baseline) / 4
temperature_load = abs(temperature_delta_c) / 1.2
stress = clamp((weighted_mean(load_components)) * 3, 0, 3)
```

Confidence is directional only when enough baseline days and at least three
components exist; otherwise it is low.

### SpO2

Inputs:

- Measured/source-labeled oxygen saturation, or
- R24 candidate scalar from compatible BLE frames

R24 candidate formula:

```text
raw = uint16_be(r24_inner_bytes[79:81])
spo2_candidate_percent = raw / 32
accepted range = 50...100
```

Boundary:

- R24 is explicitly marked as a low-confidence BLE-derived wellness candidate.
- R24 is not a calibrated pulse oximeter value.
- R21 raw optical summaries are not promoted to production SpO2.
- SpO2 has zero recovery-score weight in the current recovery formula.

### VO2 Max

Priority:

1. Use source-labeled measured/imported VO2 max.
2. If measured value is absent, allow a low-confidence estimate when max HR and
   resting HR exist.

Estimate:

```text
vo2_max = clamp(15.3 * (max_hr / resting_hr), 10, 80)
```

Boundary:

- No internal workout protocol is implied.
- This is low-confidence trend context only.

## BLE Compatibility And Frame Decoding

Direct BLE support is experimental and should be treated as user-owned hardware
compatibility research. The app decodes only fields that are implemented in
Swift and covered by tests or local aggregate validation. Unknown fields remain
unknown. Raw payload bytes are not published in this repository.

### Service And Characteristic UUIDs

| Purpose | UUID |
|---|---|
| Primary service | `61080001-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Command write | `61080002-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Command response notify | `61080003-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Events notify | `61080004-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Sensor data notify | `61080005-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Diagnostics notify | `61080007-8D6D-82B8-614A-1C8CB0F8DCC6` |
| Standard Heart Rate Service | `180D` |
| Standard Heart Rate Measurement | `2A37` |
| Standard Battery Service | `180F` |
| Standard Battery Level | `2A19` |
| Device Information Service | `180A` |

### Outer Frame Format

Every proprietary protocol frame is decoded with this envelope:

| Field | Bytes | Decode |
|---|---:|---|
| Start byte | `0` | Must be `0xAA` |
| Length | `1..2` | UInt16 little-endian; equals inner content length plus 4 CRC bytes |
| Header CRC | `3` | CRC8 over bytes `1..2` |
| Inner content | `4..innerEnd` | Packet type plus packet payload |
| Content CRC | final 4 bytes | CRC32 little-endian over inner content |

Validation behavior:

- Frames shorter than eight bytes are rejected.
- Start byte must be `0xAA`.
- Length must be at least 4, at most 4096, and match frame length.
- Header CRC8 must match.
- Content CRC32 must match.
- Split notifications are reassembled before decode.
- Null padding is skipped.
- Stale partial frames are dropped when a new plausible frame begins.

### Packet Types

| Packet byte | Name | Current decode behavior |
|---|---|---|
| `0x23` | command | Built and written by the app. |
| `0x24` | command response | Decodes sequence, command byte, request sequence, status, payload count, advertising name, serial-like fingerprint, HelloHarvard, data range, alarm, and historical sync scaffold. |
| `0x28` | realtime data | Decodes record type and supported record families. |
| `0x2B` | raw realtime data | Decodes record type and supported record families. |
| `0x2F` | historical data | Decodes record type and supported record families. |
| `0x30` | event | Decodes event type, timestamp, kind, numeric value for known payloads, and payload count. |
| `0x31` | metadata | Detects batch markers, extracts batch token, distinguishes end-of-sync candidates. |
| `0x32` | firmware log | Extracts null-terminated or printable ASCII diagnostic text. |

### Command Builders

| Command byte | Name | Payload used | Purpose |
|---|---|---|---|
| `0x03` | realtime heart rate | `0x01` enable, `0x00` disable | Start/stop realtime HR. |
| `0x13` | haptic pattern Maverick/Gen4 path | public 12-byte playback payload | Supported haptic preview path where hardware accepts it. |
| `0x16` | send historical data | `0x00` init | Start historical data flow scaffold. |
| `0x1A` | get battery level | command enum exists | Battery request path, not the primary display source. |
| `0x22` | get data range | `0x00` init | Data range candidate response. |
| `0x23` | get HelloHarvard | `0x00` init | Device status, battery candidate, RTC, wrist state candidate, serial fingerprint. |
| `0x43` | get alarm time | `0x01` init | Alarm status response. |
| `0x4C` | get advertising name | `0x00` init | Device display/advertising name response. |
| `0x4F` | haptic pattern Harvard path | 5-byte payload | Supported haptic preview path where hardware accepts it. |
| `0x6C` | optical mode | `0x01` enable, `0x00` disable | Enable/disable optical mode stream candidate. |
| `0x7A` | stop haptics | command payload | Stop/terminate haptic playback where supported. |
| `0x9A` | persistent R21 | `0x01` enable, `0x00` disable | Enable/disable persistent R21 stream candidate. |
| `0x3F` | send R10/R11 realtime | `0x01` enable, `0x00` disable | Enable/disable R10/R11 realtime stream. |

Command frame construction:

```text
inner = [0x23, sequence, command_byte] + payload
pad inner to a 4-byte multiple with 0x00
frame = outer_frame(inner)
```

### Init Sequence

On initialization the app builds these commands:

1. `GET_HELLO_HARVARD`
2. `GET_ADVERTISING_NAME`
3. `GET_DATA_RANGE`
4. `GET_ALARM_TIME`
5. `SEND_HISTORICAL_DATA`

After historical sync/end-of-sync behavior, realtime enable commands can enable
HR, R10/R11, R21, and optical mode streams.

### Command Response Decode

For `0x24` command response frames:

| Field | Decode |
|---|---|
| `inner[1]` | response sequence |
| `inner[2]` | command byte |
| `inner[3]` when present | request sequence |
| `inner[4]` when present | status byte |
| `inner[5...]` | payload |

Payload helpers:

- Advertising-name response extracts printable tokens and chooses the best
  device name.
- HelloHarvard response extracts candidate battery, charging flag, RTC seconds,
  serial fingerprint, and wrist state from known offsets when payload length
  allows.
- Data-range response scans 4-byte Unix seconds and 8-byte millisecond
  timestamp candidates in plausible date ranges.
- Alarm response treats first payload byte as configured/not configured when
  present.
- Historical sync response preserves status and payload count.

Private identifiers are fingerprinted before storage/display.

### Metadata Decode

Metadata packet `0x31`:

- Batch marker detection looks for the known marker frame prefix and extracts an
  8-byte batch token from bytes `17..<25`.
- Batch ACK uses the extracted token:

  ```text
  inner = [0x23, counter, 0x17, 0x01] + 8-byte batch_token
  frame = outer_frame(inner)
  ```

- ACK is deferred until durable local sample storage completes.
- Non-batch metadata is represented as an end-of-sync candidate.

### Event Decode

Event packet `0x30`:

| Field | Decode |
|---|---|
| `inner[1]` | sequence |
| `inner[2..3]` | UInt16 little-endian event type |
| `inner[4..7]` | UInt32 little-endian timestamp seconds when present |
| `inner[12...]` or `inner[4...]` | event payload fallback |

Known event map:

| Event type | Current meaning |
|---:|---|
| 3 | battery level |
| 7 | charging started |
| 8 | charging stopped |
| 9 | wrist on |
| 10 | wrist off |
| 14 | observed in double-tap-related captures but kept as unknown in the decoder because it was not double-tap-only |
| 17 | temperature |
| 33 | realtime heart rate started |
| 34 | realtime heart rate stopped |
| 56 | alarm set |
| 57 | alarm fired |
| 58 | alarm fired |
| 59 | alarm disabled |
| 60 | haptics fired |
| 100 | haptics terminated |
| other | unknown |

Numeric payload decoding:

```text
battery:
    if payload has 4 bytes:
        percent = uint32_le(payload[0:4]) / 10
    else:
        percent = first_byte
    accepted range = 0...100

temperature:
    celsius = int16_le(payload[0:2]) / 10
    accepted range = 20...45 C
```

### Firmware Log Decode

Firmware log packet `0x32`:

- Detects firmware header shape when present.
- Extracts null-terminated ASCII or printable tokens.
- Classifies `Sensors` category when the message contains that word.
- Exposes diagnostic summary only, not raw payload bytes.

### Data Record Families

Data packets `0x28`, `0x2B`, and `0x2F` use `inner[1]` as a record type.

| Record type | Label | Status |
|---:|---|---|
| 7 | R7 raw | Identified only; unsupported. |
| 10 | R10 realtime IMU/HR | Implemented for HR, raw wrist temperature, accelerometer summary, gyroscope summary, low-confidence step/sleep estimates. |
| 11 | R11 realtime raw | Scaffold only; no health metric emitted. |
| 20 | R20 raw | Identified only; unsupported. |
| 21 | R21 optical PPG | Implemented as raw optical diagnostics only. |
| 24 | R24 historical scalar candidate | Implemented for low-confidence SpO2 wellness candidate. |
| other | record N | Classified as unknown record. |

### R10 Decode

R10 is the main realtime IMU/heart-rate record currently used by the app.

Required:

- `inner[1] == 10`
- Complete chunk requires `inner.count >= 1288`
- Accelerometer and gyroscope axis summaries must decode

Fields:

| Field | Offset | Decode | App use |
|---|---:|---|---|
| record type | `inner[1]` | `10` | record family |
| raw timestamp | `inner[7..10]` | UInt32 little-endian seconds | sample timestamp if plausible |
| heart rate | `inner[17]` | UInt8, accepted `1..<240` after complete chunk gate | source-labeled HR sample |
| raw wrist temp | `inner[44..45]` | Int16 little-endian / 512, accepted `20...45 C` | raw wrist/contact temperature |
| accelerometer X | offset `85` | 100 Int16 little-endian samples | IMU summary and beta estimators |
| accelerometer Y | offset `285` | 100 Int16 little-endian samples | IMU summary and beta estimators |
| accelerometer Z | offset `485` | 100 Int16 little-endian samples | IMU summary and beta estimators |
| gyroscope X | offset `688` | 100 Int16 little-endian samples | IMU summary and beta estimators |
| gyroscope Y | offset `888` | 100 Int16 little-endian samples | IMU summary and beta estimators |
| gyroscope Z | offset `1088` | 100 Int16 little-endian samples | IMU summary and beta estimators |

R10 emits:

- Medium-confidence direct HR when plausible.
- Medium-confidence raw wrist/contact temperature when plausible.
- Low-confidence steps when the recurrent peak detector passes.
- Low-confidence one-minute sleep-stage estimate when stillness/HR gates pass.
- Raw IMU batch diagnostics for developer visibility.

R10 does not emit:

- True HRV.
- Calibrated SpO2.
- Medical sleep staging.
- Official device step counts.

### R11 Decode

R11 is recognized but intentionally not converted to health metrics.

Current behavior:

- Preserve payload byte count.
- Preserve raw timestamp candidate.
- Return note: "R11 payload preserved as raw realtime scaffold; no health
  metric emitted."

### R21 Decode

R21 is raw/debug optical PPG diagnostics.

Fields:

| Field | Offset | Decode | App use |
|---|---:|---|---|
| record type | `inner[1]` | `21` | record family |
| LED drive level | `inner[14]` | UInt8 to Int | diagnostic |
| sample count | `inner[16]` | UInt8 | diagnostic |
| secondary sample count | `inner[622]` | UInt8 | diagnostic |
| channel A | offset `20` | 100 UInt16 little-endian samples | min/max/average |
| channel B | offset `220` | 100 UInt16 little-endian samples | min/max/average |
| channel C | offset `420` | 100 UInt16 little-endian samples | min/max/average |
| channel D | offset `632` | 100 UInt16 little-endian samples | min/max/average |
| channel E | offset `832` | 100 UInt16 little-endian samples | min/max/average |
| channel F | offset `1032` | 100 UInt16 little-endian samples | min/max/average |

Boundary:

- R21 is not converted to production SpO2.
- R21 is not converted to HRV.
- R21 is not medical optical analysis.

### R24 Decode

R24 is a historical scalar candidate.

Fields:

| Field | Offset | Decode | App use |
|---|---:|---|---|
| record type | `inner[1]` | `24` | record family |
| raw timestamp | `inner[7..10]` when present | UInt32 little-endian seconds | sample timestamp if plausible |
| SpO2 candidate | `inner[79..80]` | UInt16 big-endian / 32 | low-confidence wellness candidate if `50...100` |

Boundary:

- R24 is explicitly marked `whoordan_estimate`.
- Metadata includes `device_only_derivation=true`.
- It is not a calibrated oximeter reading.

### Standard Bluetooth Heart Rate Decode

Characteristic `2A37`:

| Field | Decode |
|---|---|
| flags bit 0 | heart rate is UInt16 if set, UInt8 otherwise |
| flags bit 3 | energy expended field present, skipped when present |
| flags bit 4 | RR intervals present |
| flags bits 1..2 | contact flag: unknown, false, or true |
| HR value | accepted only in `25...240 bpm` |
| RR intervals | UInt16 little-endian, `raw / 1024 * 1000 ms`, accepted `250...2200 ms` |

Production emissions:

- HR sample for valid BPM.
- RMSSD and SDNN only with at least 16 RR intervals and contact not false.
- Low-confidence respiratory-rate estimate when RR interval window is long
  enough.

### Timestamp And Dedupe Policy

If a decoded packet carries a plausible device timestamp, Whoordan uses it as
the sample time and records `sample_time_basis=device_timestamp`.

If device time is missing or implausible, Whoordan uses `received_at` and
deduplicates estimates by received minute so repeated processing does not
inflate the same minute.

Dedupe IDs are fingerprints built from:

- device ID
- characteristic UUID
- packet type
- record type
- sequence
- raw timestamp
- payload byte count
- optional sample Unix minute

Raw private identifiers are not stored directly in user-facing diagnostics.

## Unsupported Or Intentionally Blocked Claims

Whoordan intentionally does not claim:

- Official wearable-device manufacturer support.
- Compatibility with another company's formulas.
- third-party score reproduction.
- Medical readiness.
- Disease detection.
- Diagnosis, treatment, prevention, or cure.
- Calibrated pulse oximetry from R21/R24.
- True HRV from BPM-only or unvalidated optical packets.
- Medical sleep staging from BLE motion/HR.
- Reliable step counts from R10 before labeled step validation.
- Phone call interception or all-app notification capture on iOS.
- Cloud sync without explicit consent.

## Public Repo Safety Checklist

Before making the GitHub repository public:

1. Review ignored local files and confirm none are tracked:

   ```bash
   git status --short --ignored
   git ls-files .env 'private_wearable_research/*' 'whoordan-ble-payloads-only.md'
   git check-ignore -v .env private_wearable_research/ whoordan-ble-payloads-only.md
   ```

2. Run a tracked-file secret and private-payload scan:

   ```bash
   rg -n "service_role|sb_secret_|BEGIN (RSA|OPENSSH|PRIVATE)|Authorization: Bearer|access_token|refresh_token|payloadBase64" $(git ls-files)
   git ls-files | rg "(\.env|\.p12|\.mobileprovision|\.jsonl|raw-payload|physiological_cycles|journal_entries|workouts\.csv|sleeps\.csv)"
   ```

3. Confirm ignored private local artifacts remain ignored and untracked:

   - `.env`
   - `whoordan-ble-payloads-only.md`
   - `private_wearable_research/`
   - private CSV exports
   - raw BLE JSONL captures
   - signing/provisioning files

4. Review public docs for risky claims:

   ```bash
   rg -n "official .*support|endorsed by|same as|medical|diagnose|treat|cure|prevent" README.md docs Whoordan
   ```

5. Run the narrow validation that fits the change:

   ```bash
   xcodebuild -list -project Whoordan.xcodeproj
   xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17'
   xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
   swiftlint lint --config .swiftlint.yml
   ```

6. Get attorney review before public release or commercial distribution.

## Private Local Mode

Whoordan is private by default. Users must sign in with Supabase Auth and be
manually approved in `public.user_access` before any app feature, including
local-only mode, Apple Health, BLE, dashboard data, journal, haptics, alarms, or
sync controls unlocks. After approval, local-only mode still makes no cloud sync
calls, and health-data cloud sync still requires explicit consent.

```bash
open Whoordan.xcodeproj
```

Supabase account mode uses client-safe public configuration only. Provide values
through the Xcode scheme environment or app configuration:

```bash
WHOORDAN_SUPABASE_URL=https://your-project.supabase.co
WHOORDAN_SUPABASE_PUBLISHABLE_KEY=your-public-publishable-key
```

Do not put Supabase service-role keys in this app.

See `docs/WHOORDAN_SYNC_HAPTICS.md` for the sync, Apple Health, BLE,
source-priority, haptics, privacy-control, and limitation details.

See `docs/WHOORDAN_BACKGROUND_RELIABILITY.md` for auth/session persistence,
background sync, retry/backoff, offline launch, and BLE catch-up behavior.

See `docs/WHOORDAN_FEATURE_RESEARCH_AND_VALIDATION.md` for the current
feature-by-feature research and validation status.

See `docs/WHOORDAN_WEARABLE_BLE_PROTOCOL_MAPPING.md` and
`docs/WHOORDAN_WEARABLE_PACKET_DISCOVERY_REPORT.md` for deeper BLE protocol
notes that avoid raw private payload bytes.

See `docs/WHOORDAN_RESEARCHED_CALCULATIONS.md` and
`docs/WHOORDAN_PRIVATE_WEARABLE_EXPORT_RELATIONSHIP_ANALYSIS.md` for aggregate-only metric
research boundaries and benchmark context.

## iOS Development Install

You need a Mac with Xcode and your Apple Account added in Xcode settings.

In Xcode, configure signing only:

1. Select the `Whoordan` target.
2. Open `Signing & Capabilities`.
3. Set your Team.
4. If Xcode reports the bundle identifier is already used, change it to a
   unique value under your own account.
5. Connect and unlock your iPhone.
6. Enable Developer Mode on the iPhone if iOS asks for it.

After signing is configured, install to Ward's physical iPhone only through the
project script:

```bash
scripts/build-install-ios-supabase.sh
```

For private signed Ad Hoc OTA distribution through `whoordan.w4rd2.tech`, see
`docs/WHOORDAN_PRIVATE_DISTRIBUTION_SETUP.md`.

## Validation

```bash
xcodebuild -list -project Whoordan.xcodeproj
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
swiftlint lint --config .swiftlint.yml
```

Use the narrowest validation that fits the change. If SwiftLint is not installed
locally, install it outside the repository and do not vendor tool binaries. Do
not add secrets or service-role keys to this repository.

## License

The source code and documentation in this repository are licensed under the
Apache License, Version 2.0 unless a file states otherwise. See `LICENSE`.

Apache-2.0 lets people use, study, modify, distribute, and contribute to the
project, including commercially, while requiring preservation of copyright,
license, attribution, and NOTICE information. It also includes an express patent
grant and patent-defense termination clause.

The project includes a `NOTICE` file so forks and redistributed versions carry
clear attribution:

```text
Whoordan
Copyright 2026 W4rd2
```

The Apache License, Version 2.0 does not grant trademark rights. The Whoordan
name, logos, icons, screenshots, visual brand assets, domain names, and related
branding are reserved except for reasonable and customary use in identifying the
origin of the project and reproducing the `NOTICE` file.
