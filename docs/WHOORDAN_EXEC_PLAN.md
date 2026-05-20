# Whoordan Execution Plan

Inspection date: 2026-05-10
Rebrand pass: 2026-05-10
Design system foundation pass: 2026-05-10
Screen renovation pass: 2026-05-10
Local-only data foundation pass: 2026-05-10
Supabase auth and schema foundation pass: 2026-05-10
HealthKit foundation pass: 2026-05-10
Scoring engine foundation pass: 2026-05-10
Feature wiring pass: 2026-05-10
Journal, habit, insight pass: 2026-05-10
Privacy, consent, migration, export/delete pass: 2026-05-10
Validation hardening pass: 2026-05-10
Final implementation report pass: 2026-05-10

## Detected Stack

- Framework: Flutter mobile app.
- Language: Dart for app code, Kotlin for Android platform code, Swift for iOS platform code.
- Package manager: Dart/Flutter `pub` with `pubspec.yaml` and `pubspec.lock`.
- Native build systems: Android Gradle wrapper and iOS CocoaPods.
- State management: `flutter_riverpod` with `StateNotifier`, `Provider`, `FutureProvider`, and BLE streams.
- UI: Flutter Material 3 with custom Whoordan `WTheme`, reusable card, metric tile, signal chip, state, settings row, score, and chart primitives, plus `fl_chart`.
- Bluetooth: `flutter_blue_plus` plus the git dependency public BLE protocol reference.
- Permissions/storage: `permission_handler`, `shared_preferences`, `flutter_secure_storage`.
- Local data layer: `lib/local/` contains local models, a shared-preferences storage adapter, repository, privacy/mode guard, and local BLE capture worker.
- Scoring layer: `lib/scoring/whoordan_scoring.dart` contains original configurable baseline, recovery, strain, strain target, sleep need/debt, stress, heart-rate zone, cardio fitness, and sample aggregation engines.
- HTTP/backend client: `http` package against a legacy custom REST API.
- Supabase: `supabase_flutter` for email/password auth, initialized lazily only when account mode is used and `WHOORDAN_SUPABASE_URL` plus `WHOORDAN_SUPABASE_ANON_KEY` are configured. The app also accepts `SUPABASE_PROJECT_ID` plus `SUPABASE_PUBLISHABLE_KEY` as safe local aliases. Supabase secret/service-role keys must not be used in the app.
- Platforms present: iOS and Android. No web/desktop target was identified.

## Current Architecture Summary

The app is now branded as Whoordan and remains structured as a Flutter companion app evolved from an earlier BLE wearable research workflow. The app starts in `lib/main.dart`, wraps everything in a Riverpod `ProviderScope`, and uses a private `_RootRouter` to switch between onboarding/auth screens and the main app shell.

Navigation is manual Flutter navigation. Auth state selects `EmailScreen`, `CodeScreen`, or `MainShell`; pairing uses `Navigator.push` with `MaterialPageRoute`; the main app uses a bottom `NavigationBar` with tabs for Today, Recovery, Sleep, Heart, and More. The `go_router` dependency exists but is not currently used.

Live device data flows through the existing BLE service in `lib/ble/ble_service.dart`, then through `LiveController` in `lib/ble/live_state.dart`. The service still uses legacy protocol internals from public BLE protocol reference and exposes streams for heart rate, PPG, RR, recovery summaries, events, battery, and sync state.

Persistence is local-first. The app-owned local repository now stores health samples, summaries, journal, habits, sync state/queue, HealthKit anchors, diagnostics, haptics, alarms, and settings in encrypted indexed SQLite rows. `shared_preferences` remains only for small legacy/compatibility values such as BLE pairing flags and as a migration source. `flutter_secure_storage` stores Supabase sessions, legacy token material, and the local database payload encryption key.

Backend support is now split. Legacy custom REST remains present for old insight endpoints, gated by `WHOORDAN_CLOUD_SYNC=true` and an HTTPS `WHOORDAN_API` value. Supabase Auth is available through `supabase_flutter` when `WHOORDAN_SUPABASE_URL` and `WHOORDAN_SUPABASE_ANON_KEY` are provided, or when `SUPABASE_PROJECT_ID` and `SUPABASE_PUBLISHABLE_KEY` are provided. The app uses the Supabase public anon/publishable key only and stores Supabase sessions through a secure-storage-backed auth storage adapter. The private-app approval gate now requires sign-in and a manually approved `public.user_access` row before local-only mode or any protected feature unlocks.

Health data cloud sync remains separate from account sign-in. Signed-in users start in account mode with health cloud sync disabled. `LocalCloudModeGuard` requires cloud mode plus explicit granted cloud-sync consent before any future health data upload path is allowed. Existing local health data is not migrated automatically.

iOS currently has Bluetooth usage strings, `bluetooth-central` background mode, HealthKit entitlement/capability configuration, and Apple Health privacy usage strings. Android currently declares BLE scan/connect, legacy BLE/location permissions for older Android versions, foreground service, notification, boot, and wakelock permissions. Phone/call-control permissions, notification-listener registration, and unused BLE advertise permission were removed during remediation. Android Health Connect is not configured.

## Product Target

- App name: Whoordan.
- Author / publisher: W4rd2.
- Product type: premium health, recovery, sleep, strain, and fitness tracker.
- Logo: original premium AI-generated image centered around the letter "W".
- Must support Apple Health / HealthKit.
- Must support local-only mode.
- Must support email/password auth.
- Must support Supabase cloud sync only after explicit user consent.
- Must not copy third-party branding, formulas, UI, language, colors, trade dress, or proprietary behavior.
- Must not make medical diagnosis claims.

## Branding and Metadata Status

- `pubspec.yaml` package name is `whoordan`.
- `pubspec.yaml` description identifies Whoordan as a premium local-first recovery, sleep, strain, and fitness tracker by W4rd2.
- `lib/main.dart` uses `WhoordanApp`, title `Whoordan`, and splash text `Whoordan`.
- iOS `CFBundleDisplayName` is `Whoordan`; `CFBundleName` is `whoordan`.
- Android `android:label` is `Whoordan`.
- Android namespace/application id use `com.w4rd2.whoordan`.
- iOS project bundle identifiers use `com.w4rd2.whoordan`.
- README has been replaced with Whoordan product positioning and privacy guardrails.
- User-facing old product identity has been removed from the primary app UI.

Legacy implementation references remain around BLE protocol internals and should be reviewed in a later architecture task.

## Assets and Icons

- iOS app icons are under `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- iOS launch images are under `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
- Android launcher icons are under `android/app/src/main/res/mipmap-*`.
- Android launch backgrounds are under `android/app/src/main/res/drawable*`.
- Flutter assets include the Whoordan W mark from the supplied logo asset pack.
- README references `./banner.png`, but that file was not found during inspection.
- A Whoordan "W" logo master is present at `assets/brand/whoordan-w-logo.png`.
- iOS and Android launcher icon PNGs have been regenerated from the centered dark Whoordan W mark.

## HealthKit / Apple Health Status

HealthKit foundation is implemented for iOS without adding a Flutter plugin dependency:

- iOS has `Runner.entitlements` with the HealthKit entitlement and the project capability flag.
- `Info.plist` has Apple Health read/write privacy purpose strings.
- `ios/Runner/AppDelegate.swift` exposes a native `whoordan.healthkit` MethodChannel for availability, authorization, sample queries, anchored incremental changes, optional background-delivery setup, and sample normalization.
- Dart HealthKit service/controller code lives in `lib/health/healthkit_service.dart`.
- Settings can connect/disconnect Apple Health and import latest samples locally.
- Today shows Apple Health connection status without fake metrics.
- Imported samples are normalized into local `HealthSample` records with source, sample type, value, unit, start/end timestamps, source record id, dedupe key, metadata, and import timestamp.
- Anchors are stored locally and imports deduplicate records before writing.
- Menstrual flow, irregular rhythm events, and body composition types are mapped but not requested by default; they should require explicit product UX before being requested.

Known HealthKit limitation: Apple does not expose read authorization status per data type after the permission sheet. Whoordan stores local authorization intent and reports partial states when native queries return errors, but exact per-type read denial cannot be inspected directly.

## Supabase / Firebase / Appwrite Status

- Supabase dependency is present through `supabase_flutter`.
- Supabase Auth supports email/password sign up, sign in, sign out, password reset, session restore, auth loading states, auth error states, validation, and email verification state when Supabase returns a no-session signup.
- Supabase is configured only through dart defines: `WHOORDAN_SUPABASE_URL` and `WHOORDAN_SUPABASE_ANON_KEY`, or the safe aliases `SUPABASE_PROJECT_ID` and `SUPABASE_PUBLISHABLE_KEY`.
- Supabase migrations are under `supabase/migrations/`.
- No Firebase dependency or configuration was found.
- No Appwrite dependency or configuration was found.

No Supabase service-role key belongs in the mobile app, docs examples, tests, or local config committed to this repo.

## Security and Privacy Risks

- The current app still contains legacy protocol names and the public BLE protocol reference dependency. These should be evaluated before the product becomes a public Whoordan release.
- Health and fitness data upload is guarded by both backend configuration and local consent state. A signed-in user can enable or disable the health cloud sync consent state in Settings, but no automatic local health-data upload or local-to-cloud migration is implemented in this pass.
- Cloud sync is no longer build-time-only from the app layer; it requires account mode, local cloud mode, and a granted cloud consent record.
- Auth is Supabase email/password for the account path. Legacy REST OTP methods are no longer used by the app UI.
- Local health persistence uses encrypted indexed SQLite rows. Full database-file encryption and physical large-history performance validation remain future work.
- HealthKit import is local-only unless future cloud sync code explicitly passes the existing cloud mode and consent guard. No current HealthKit path uploads to Supabase.
- Android still requests sensitive BLE, location for older Android, foreground service, boot completed, notification, and wakelock permissions. Notification listener, phone state, answer calls, call phone, and unused BLE advertise permissions were removed during remediation.
- BLE device identifiers and serial-like identity values are persisted or displayed and should be treated as sensitive.
- Tokens are stored in secure storage, which is good, and the API requires HTTPS, which is also good.
- Recovery/sleep copy and formulas must remain clearly non-medical and original.
- Naming risk note: "Whoordan" should be checked before release for trademark/domain/store availability. This note does not block the requested rename.

## Files That Should Not Be Touched Casually

- Secrets and local config: `.env*`, `config.local.*`, `android/key.properties`, `android/local.properties`.
- Generated/build output: `build/`, `.dart_tool/`, `.pub/`, `.pub-cache/`, `ios/Pods/`, `ios/.symlinks/`, Flutter generated registrants, and generated xcconfig/export files.
- Dependency lockfiles unless dependencies change: `pubspec.lock`, `ios/Podfile.lock`.
- Native signing/provisioning/project settings unless the task is specifically about bundle ids, capabilities, or builds.
- Any currently dirty source file unrelated to the task.

## Validation Commands Discovered

- Install Dart/Flutter packages: `flutter pub get`.
- Static analysis: `flutter analyze`.
- Unit/widget tests: `flutter test`.
- Android build: `flutter build apk`.
- iOS build without signing: `flutter build ios --no-codesign`.
- iOS pods when native dependencies change: `cd ios && pod install`.
- iOS private-device run after signing: `flutter run -d <your-iphone-device-id>`.
- Cloud-mode run, only for trusted backend testing: `flutter run --dart-define=WHOORDAN_CLOUD_SYNC=true --dart-define=WHOORDAN_API=https://your-backend.example`.

## Phased Implementation Plan

### Phase 0 - Baseline and Guardrails

- Keep `AGENTS.md` and this execution plan current.
- Establish the validation baseline with `flutter analyze` and `flutter test`.
- Decide which existing dirty files belong to the user and avoid overwriting them.
- Add privacy/product guardrails before feature work.

### Phase 1 - Product Rebrand to Whoordan

- Completed initial user-facing rename from the earlier prototype branding to Whoordan.
- Completed iOS display name, Android label, bundle/application ids, package namespaces, and metadata update.
- Completed README replacement with Whoordan positioning.
- Completed generated original premium "W" logo and app icon update.
- Remaining: review legacy protocol dependency and implementation naming as a later architecture/product-source decision.

### Phase 2 - Privacy-First Local Data Layer

- Completed the first local-only architecture pass: local user profile, user settings, consent records, sync migration placeholder, daily summary placeholder, health sample placeholder, shared-preferences storage adapter, local repository, privacy/mode guard, and local BLE capture worker.
- Updated onboarding so sign-in/sign-up/password reset are the only pre-approval paths; local-only mode is available only after manual admin approval.
- Completed settings UI for current privacy mode, cloud sync guard state, Apple Health connection/import state, local storage notice, metric-unit setting, and future migration preparation.
- Completed tests for local mode selection, settings persistence, cloud guard behavior, consent requirements, migration placeholder state, and onboarding controller state.
- Remaining: evaluate full database-file encryption and physical large-history validation before broad release.
- Remaining: define richer schemas for sleep sessions, workouts/strain inputs, recovery inputs, and sync queue records.

### Phase 3 - HealthKit / Apple Health

- Completed iOS HealthKit entitlement, capability flag, and Info.plist usage strings.
- Completed native MethodChannel for availability, authorization, direct sample fetches, anchored incremental changes, optional background-delivery registration, and HealthKit sample normalization.
- Completed Dart service/controller, local authorization state, consent records, local anchor storage, deduplicated local imports, settings connection UI, and Today status.
- Default read request covers core wellness/fitness data needed for the app foundation. Menstrual flow, irregular rhythm events, and body composition are mapped but require explicit UX before requesting.
- HealthKit permission remains separate from cloud-sync consent. Local-only mode supports Apple Health and no HealthKit import path uploads data.
- Remaining: move high-volume HealthKit storage to a real local database, design explicit sensitive-type consent UX, test on a physical iPhone, and decide whether background delivery should be enabled in production.

### Phase 4 - Original Metrics and UX

- Completed the first app-wide design system foundation: palette, typography, spacing, radius, elevation, chart styling, score primitives, cards, metric tiles, signal chips, skeletons, empty/permission states, settings rows, modal sheet shell, and Material button/input defaults.
- Completed the first major-screen renovation pass: a flagship Today screen, renovated Recovery, Sleep, Heart Rate, Settings access, and a More feature hub with scaffolded empty/permission states for sleep planning, strain, heart zones, workouts, strength training, stress, breathing, health monitor, long-term health, journal/habits, movement, and recovery insights.
- Current screens intentionally avoid fake production metrics. They use real live/backend values where available and polished missing-data states where local HealthKit or wearable history is insufficient.
- Define original recovery, sleep, strain, and fitness formulas.
- Completed original configurable scoring engines for baselines, recovery, strain, strain targets, sleep need/debt, stress, heart-rate zones, cardio fitness imported-value handling, and local sample aggregation.
- Completed formula documentation in `docs/WHOORDAN_SCORING.md`, including confidence behavior, missing-data handling, limitations, and non-medical intent.
- Build Whoordan-specific UI patterns rather than copying third-party screens, color zones, terminology, or behavior.
- Completed tests for baseline calculations, recovery full/missing data, strain, strain target, sleep debt, stress, heart-rate zones, confidence behavior, imported VO2 handling, and non-medical explanation text.
- Completed feature wiring for Today, Recovery, Sleep, Strain, Heart Rate, Workouts, Strength, Stress, Breathing, Health Monitor, Long-Term Health, Movement, calorie estimates, sensitive contexts, and integrations using real local models where available and polished missing-data states otherwise.
- Completed journal, habit tracking, and recovery insight foundations with local CRUD, configurable habits, minimum sample thresholds, confidence levels, and cautious association language.

### Phase 5 - Auth and Consent-Gated Supabase Sync

- Completed Supabase email/password auth foundation: sign up, sign in, sign out, password reset, session restore, loading/error states, input validation, email verification state, and account settings integration.
- Completed secure client setup using `WHOORDAN_SUPABASE_URL` and `WHOORDAN_SUPABASE_ANON_KEY`; no service-role key is used or expected in mobile code.
- Completed initial Supabase migration for `user_profiles`, `user_settings`, `consent_records`, `sync_states`, `health_samples`, `daily_health_summaries`, `sleep_sessions`, `workouts`, `strength_workouts`, `strength_sets`, `journal_entries`, `habit_logs`, and `recovery_insights`.
- Completed RLS foundation: every user-data table enables and forces RLS, policies are scoped `to authenticated`, and row ownership uses `(select auth.uid()) = user_id`.
- Completed consent UI/state for health cloud sync disabled/enabled. Existing local health data is not migrated automatically.
- Remaining: implement actual Supabase health-data sync queues only after a real local database exists and explicit migration UX is reviewed.
- Remaining: run policy tests against a real Supabase local/dev instance when Supabase CLI or project credentials are available.

### Phase 6 - Hardening and Release Preparation

- Review Android permissions and remove anything not needed for Whoordan.
- Review iOS background modes and HealthKit privacy copy.
- Add crash/error handling that does not leak health data.
- Add release build validation for Android and iOS.
- Add privacy policy and App Store / Play Store metadata aligned with actual behavior.

## Recommended Phase Order

1. Baseline and guardrails.
2. Rebrand and metadata cleanup.
3. Local data layer.
4. Real local database for HealthKit-scale history.
5. Original metrics.
6. Supabase health-data sync implementation with explicit consent.
7. Hardening and release preparation.

## Unknowns

- Whether the current legacy BLE integration should remain, be removed, or be abstracted behind a generic source interface for Whoordan.
- Whether Whoordan will support Android health data sources such as Health Connect.
- Exact Supabase sync conflict resolution behavior.
- Which mapped HealthKit data types should be requested in the first release, especially menstrual cycle, irregular rhythm events, and body composition.
- Final bundle identifiers, app ids, signing teams, and store metadata.
- Whether current dirty files are intentional user edits, generated by a local build, or both.
- Whether the missing README `banner.png` should be restored, removed, or replaced during rebrand.

## Next Codex Task

Recommended next prompt:

```text
Using AGENTS.md, docs/WHOORDAN_EXEC_PLAN.md, docs/WHOORDAN_SCORING.md, and docs/WHOORDAN_IMPLEMENTATION_REPORT.md, perform a human-review readiness pass for TestFlight/App Store preparation. Do not add major features. Verify HealthKit behavior on a physical iPhone, review Apple privacy nutrition labels and sensitive permissions, confirm Supabase RLS against a real development project, decide whether to retain or abstract the legacy BLE protocol dependency, and produce a launch-blocker checklist.
```
