# Whoordan SwiftUI Implementation Report

Date: 2026-05-11

## Branch

Confirmed branch: `swift-app`.

## Project

Created native iOS SwiftUI project at `Whoordan.xcodeproj` with app source under `Whoordan/`, unit tests under `WhoordanTests/`, and UI tests under `WhoordanUITests/`.

## Removed

Removed Flutter source, tests, Android host project, Flutter iOS Runner project, Flutter dependency manifests, and Flutter analysis/devtool config on this Swift migration branch.

## Preserved

Preserved docs, Supabase migrations, brand logo assets, repo instructions, scripts, research/calculation material, and private CSV exports outside the repo.

## Screens Built

- Auth: sign in, sign up, password reset scaffold, session restore loading.
- Approval locked: pending, rejected, revoked, missing, and error states.
- Today: single-header dashboard, status strip, vertical baseline/recovery hero, clear Apple Health/wearable/baseline CTAs, compact summary grid, and useful-only body signal list.
- Recovery: single-header recovery instrument, contributor readiness list, missing-signal CTAs, and small info-sheet safety copy.
- Sleep: single-header last-sleep state, sleep need/debt/efficiency/source rows, source CTAs, and no fake sleep stages.
- Heart: single-header source state, RHR/HRV/SpO2/zones rows, Apple Health/wearable/max-HR CTAs, and small info-sheet safety copy.
- Device: BLE status, diagnostics, sync state, live parsed HR, battery, discovered attributes, packet/record processing summary, and developer protocol summary.
- Vibration: built-in patterns, preview states, safety failures.
- Journal: simple local habit/notes scaffold with no causal claims.
- Settings: account, approval, local/cloud consent, Apple Health, device, privacy, legal/disclaimer.

## UI Redesign Pass

Replaced the generic repeated-title `SignalScreen` usage on Recovery, Sleep, and Heart with screen-specific SwiftUI layouts. Added reusable layout primitives: screen header, status strip, hero module, CTA rows, compact metric tiles, signal rows, signal lists, and footnotes. Reduced card border weight and moved long safety copy into info sheets where practical.

## App Icon

Installed the provided iOS icon pack into `Whoordan/Resources/Assets.xcassets`.

- App icon source: `AppIcon`
- App Store/TestFlight master icon: `Whoordan-AppIcon-1024.png`
- In-app W mark: `Whoordan-W-Mark-Transparent.png`
- Launch/branding image set: `WhoordanLaunchIcon`

iOS will apply icon masking. No rounded-corner processing was added.

## Security And Approval

Approval is the outermost app gate. Protected services and data are blocked before approval through `PrivacyAccessGuard` and `AppRouter`. Sign-out clears protected state. The app uses publishable/anon Supabase configuration and Keychain session storage, not service-role keys.

Supabase config supports either an explicit `WHOORDAN_SUPABASE_URL` or a safe derived URL from `SUPABASE_PROJECT_ID`, plus `WHOORDAN_SUPABASE_PUBLISHABLE_KEY`/`SUPABASE_PUBLISHABLE_KEY`. This keeps physical builds configurable without committing keys.

## HealthKit

HealthKit availability, supported type registry, permission request, and unit mapping foundation are implemented. Requests and imports are approval-gated.

The Priority A health pass added current-day HealthKit import scaffolding and mappings for steps, active energy, walking/running distance, workouts, sleep duration, heart rate, resting heart rate, HRV SDNN, respiratory rate, SpO2, body temperature, wrist temperature, and VO2. Movement aggregation now deduplicates source records, prefers Apple Health over wearable data for step counts, exposes source/confidence labels, and never derives fake steps from raw IMU packets.

Per-type read success, real sample import, and HealthKit permission UI still require physical iPhone validation.

## BLE

CoreBluetooth service scaffolding, state machine, UUID constants, frame builder/decoder, CRC8/CRC32, reassembler, init command sequence, batch ACK builder, realtime command builders, event scaffolding, and conservative normalization models are implemented.

The app now discovers all services exposed after connection, reads readable characteristics, subscribes to notify/indicate characteristics, parses standard Bluetooth Heart Rate Measurement (`2A37`) and Battery Level (`2A19`), and processes recognized protocol frames into safe app state. Recognized payload processing includes live HR from R10/standard HR, event type, R10 IMU sample count, R21 optical sample count, packet type, and record type. Unsupported records are counted and preserved as unsupported rather than converted into fake metrics.

## Vibration

Built-in wearable preview architecture is implemented with approval, connection, unsafe, unsupported, sending, started, failed, and terminated states. It sends haptic command payloads through a BLE command sink and does not fake unsupported custom patterns.

## Scoring

Original Whoordan recovery and strain foundations are implemented with confidence, source labels, missing-input behavior, and non-medical explanations. Exported proprietary score columns are intentionally ignored.

Strain now accepts source-labeled movement inputs from steps, active energy, and movement minutes. Movement-only strain is deliberately low confidence because it lacks direct heart-rate intensity.

## Health Feature Surfaces

The Today dashboard now includes steps and workout/movement coverage. Settings now exposes Movement, Workouts, Strength, Body Signals, and Trends surfaces. Movement is functional for source-labeled imported data and step-goal configuration; the other new surfaces are honest partial/scaffolded views with CTAs or missing-state copy, not fake metrics.

## Local/Cloud

Local-only mode is available only after approval. Cloud sync eligibility requires approval, cloud consent, and health-data consent.

The SwiftUI app now includes a focused Supabase health-sample upload path for imported Apple Health samples. It uses the publishable key plus the signed-in user bearer token, relies on `public.health_samples` RLS, hashes source record identifiers/dedupe keys before upload, and caps a single upload batch to 500 samples. A physical iPhone test verified that imported Apple Health samples were uploaded after explicit Cloud Health Sync consent.

Full encrypted local health database, durable sync queue, background sync, conflict repair, export, and deletion remain future production work.

## SwiftUI Versus Flutter

For this app, native SwiftUI is now a better fit than the removed Flutter scaffold because the core product depends on HealthKit, CoreBluetooth, Keychain, iOS permissions, and Apple-native interaction patterns.
