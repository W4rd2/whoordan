# Whoordan SwiftUI Migration Plan

Date: 2026-05-11

## Branch

Confirmed branch: `swift-app`.

## Remove

Flutter implementation files removed on this branch: `lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, and Flutter devtool/config files.

## Preserve

Preserved: `docs/`, `supabase/migrations/`, `assets/brand/`, repo instructions, Supabase/RLS knowledge, research/calculation docs, scripts, README, and external private CSV files outside the repo.

## Why SwiftUI

Whoordan needs HealthKit, CoreBluetooth, background behavior, Keychain storage, and iPhone-native UI polish. Native SwiftUI reduces bridge complexity and lets the app use Apple platform capabilities directly.

## Conceptual Reuse From Flutter

Reusable ideas: approval gate, local/cloud consent split, HealthKit type list, BLE state-machine concepts, scoring categories, privacy wording, and existing screen taxonomy.

## Not Reused

Flutter widgets, Material navigation, Dart state objects, Android implementation, MethodChannel wiring, generated Flutter iOS Runner files, and legacy prototype UI styling are not reused.

## Architecture

Native layout:

- `Whoordan/App`: app lifecycle, root routing, dependency environment.
- `Whoordan/DesignSystem`: matte dark-first SwiftUI components.
- `Whoordan/Core`: auth, approval, Supabase, storage, HealthKit, BLE, haptics, scoring, privacy, models, CSV schema validation.
- `Whoordan/Features`: Auth, Approval, Today, Recovery, Sleep, Heart, Device, Vibration, Journal, Settings.
- `WhoordanTests` and `WhoordanUITests`: unit and launch coverage.

## Data Model Mapping

Core models include `UserProfile`, `ConsentState`, `HealthSample`, `DailyHealthSummary`, `SleepSession`, `Workout`, `JournalEntry`, `HabitLog`, `VibrationPattern`, `DeviceDiagnostics`, `SyncState`, wearable sample/event models, and `VibrationPreviewResult`.

## Supabase/Auth/Admin Approval

The app uses publishable/anon key configuration only. Auth sessions are stored in Keychain. Approval is read from `public.user_access` for the signed-in user and does not rely on `user_metadata` or `raw_user_meta_data`. Pending, missing, rejected, revoked, and error states remain locked.

## HealthKit

HealthKit starts only after approval. Requested read types include heart rate, resting heart rate, HRV SDNN, respiratory rate, sleep analysis, steps, active energy, oxygen saturation, body/wrist temperature, workouts, and VO2 max. Cloud upload requires approval plus cloud and health-data consent.

## CoreBluetooth/BLE

BLE scan/connect/packet parsing are blocked before approval. The protocol foundation implements UUIDs, frame encoding/decoding, CRCs, init commands, reassembly, metadata ACKs, realtime commands, event scaffolding, and haptic command builders from public public wearable protocol reference protocol references.

## Vibration/Haptics

Built-in pattern preview is implemented through BLE command sinks with approval, connection, unsupported, sending, started, failed, terminated, and unsafe states. Success is not faked; command send success only means the command was sent by the adapter.

## Local Storage

Keychain stores auth session data. The first-pass local store is file-backed JSON for small summaries and state. Large long-term health datasets need a SwiftData/SQLite/encrypted store before production import volume.

## Background Tasks

Background sync is intentionally scaffold-only in this pass and must remain gated by approval and explicit consent.

## Scoring

Whoordan scoring is original, transparent, source-aware, confidence-aware, missing-data safe, and non-medical. Proprietary export score fields are ignored by the scoring engine.

## UI/Design

The design system is dark-first, matte, Apple-native, restrained, and uses SF Symbols and native navigation. It avoids third-party wearable trade dress, glassmorphism, neon overload, Android patterns, fake metrics, and medical claims.

## Testing And Validation

Validation plan: `xcodebuild -list`, simulator build, simulator tests, generic iOS no-codesign build, simulator UI launch, privacy scan, and physical iPhone build/run only when the device is actually available.

## Risks And Blockers

Remaining risks: physical iPhone HealthKit/BLE/haptic testing is not complete, Supabase live auth/RLS testing needs a test project/user, local storage is first-pass, background tasks are scaffolded, and wearable protocol behavior requires owned-device validation.

## Physical Device Requirements

HealthKit authorization, CoreBluetooth scanning, wearable historical sync, realtime packets, vibration preview, and background behavior require a signed physical iPhone and the user's personally owned wearable.
