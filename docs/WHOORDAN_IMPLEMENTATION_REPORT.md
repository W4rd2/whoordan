# Whoordan Implementation Report

Report date: 2026-05-10

## 1. Stack Detected

- App framework: Flutter mobile app.
- Languages: Dart, Swift, Kotlin.
- Platforms present: iOS and Android. No web or desktop target is present.
- State management: Riverpod with `StateNotifier`, providers, streams, and async providers.
- Navigation: manual Flutter navigation with `MaterialApp`, auth root switching, `Navigator.push`, and a bottom `NavigationBar`. `go_router` is installed but not active.
- Storage: `shared_preferences` for current local app data and settings; `flutter_secure_storage` for auth/session secrets.
- Charts/UI: Material 3, custom Whoordan `WTheme`, reusable components, and `fl_chart`.
- Backend/auth: Supabase Auth via `supabase_flutter`, plus legacy custom REST hooks behind dart defines.
- Native health integration: iOS HealthKit through a Swift MethodChannel. Android Health Connect is not configured.
- Package manager: Flutter/Dart `pub`.

## 2. Summary Of What Changed

The app has been redirected from an earlier wearable prototype into Whoordan, a premium local-first recovery, sleep, strain, and fitness tracker by W4rd2. The work completed so far includes the rebrand, original logo assets, a custom design system, renovated core screens, local-only mode, local repositories and models, Supabase email/password auth foundation, consent-gated cloud-sync foundations, iOS HealthKit foundation, original scoring engines, journal/habit/insight features, privacy/legal flows, and validation hardening.

The app intentionally avoids fake production health metrics. Where real local data is unavailable, screens show missing-data, loading, error, or permission states. Health language remains wellness-oriented and non-diagnostic.

## 3. Files Modified By Category

- Repo guidance and docs: `AGENTS.md`, `README.md`, `docs/WHOORDAN_EXEC_PLAN.md`, `docs/WHOORDAN_SCORING.md`, `docs/WHOORDAN_IMPLEMENTATION_REPORT.md`.
- App metadata and config: `pubspec.yaml`, `pubspec.lock`, `lib/config.dart`, `.gitignore`.
- Branding/assets: `assets/brand/whoordan-w-logo.png`, iOS app icons, Android launcher icons, splash/launch metadata.
- App shell/auth: `lib/main.dart`, `lib/auth/auth_controller.dart`, `lib/auth/auth_screens.dart`.
- Theme/components: `lib/theme.dart`, `lib/widgets/cards.dart`, `lib/widgets/score_ring.dart`, `lib/widgets/sparkline.dart`, `lib/widgets/trend_chart.dart`, `lib/widgets/sleep_timeline.dart`.
- Screens: `lib/screens/today_screen.dart`, `recovery_screen.dart`, `sleep_screen.dart`, `heart_rate_screen.dart`, `feature_screens.dart`, `more_screen.dart`, `settings_screen.dart`, `privacy_legal_screen.dart`, plus existing live/history/pairing screens.
- Local architecture: `lib/local/local_models.dart`, `local_repository.dart`, `local_storage.dart`, `mode_guard.dart`, `local_capture_worker.dart`.
- Health/scoring/journal/privacy: `lib/health/`, `lib/scoring/`, `lib/journal/`, `lib/privacy/`.
- Cloud/auth/sync: `lib/cloud/cloud_auth_service.dart`, `supabase_bootstrap.dart`, `supabase_secure_storage.dart`, `sync_worker.dart`, `api.dart`.
- Native iOS/Android: `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, iOS project metadata, Android manifest/build files, Kotlin package paths.
- Supabase: `supabase/migrations/202605100001_whoordan_cloud_foundation.sql`.
- Tests: `test/config_privacy_test.dart`, `healthkit_test.dart`, `journal_habit_test.dart`, `local_health_insights_test.dart`, `local_mode_test.dart`, `privacy_sync_test.dart`, `scoring_engine_test.dart`, `supabase_schema_test.dart`, `validation_hardening_test.dart`, `widget_test.dart`.

## 4. Branding Updates

- App name: Whoordan.
- Author/publisher: W4rd2.
- Dart package name: `whoordan`.
- iOS display name: `Whoordan`.
- Android label: `Whoordan`.
- Bundle/application id: `com.w4rd2.whoordan`.
- User-facing old identity has been removed from primary screens and docs.
- Intentionally retained legacy references: public BLE protocol reference and protocol UUID helper remain in BLE internals because they are part of the current protocol dependency, not user-facing brand copy. Review before public release.
- Guardrail remains documented: do not copy third-party branding, formulas, UI, colors, trade dress, or product claims.

## 5. Logo Implementation Status

- The supplied centered dark Whoordan W mark is installed at `assets/brand/whoordan-w-logo.png`.
- Flutter registers the logo asset in `pubspec.yaml`.
- The W mark is used in app splash/header surfaces.
- iOS and Android launcher icon PNGs have been regenerated from the same centered dark W mark with alpha flattened for native app-icon compatibility.
- Human review still needed for final icon legibility at small sizes, App Store guidelines, and trademark/domain risk.

## 6. Design System Summary

Whoordan now uses a custom dark premium health-tech system centered on `WTheme`. The foundation includes color tokens, type scale, spacing, radius, elevation, chart colors, score bands, score rings, reusable cards, metric tiles, signal chips, skeleton/loading cards, empty states, permission states, settings rows, modal sheet shell, and Material button/input defaults.

Accessibility work includes readable contrast, large tap targets where practical, semantics on key cards and logo surfaces, missing-data states that do not rely on color alone, and restrained motion.

## 7. Screens Renovated

- Splash / launch.
- Onboarding and auth shell.
- Today / Home flagship screen.
- Recovery.
- Sleep.
- Heart Rate.
- More feature hub.
- Settings.
- Privacy/legal screens.
- Feature screens for Sleep Planner, Strain, Heart Rate Zones, Workouts, Strength Training, Stress Monitor, Breathing/Relaxation, Health Monitor, Long-Term Health, Journal/Habits, Recovery Insights, Steps/Movement, Calorie Estimates, menstrual context, pregnancy context, irregular rhythm events, and integrations.

Some feature screens are intentionally scaffolded around real local data models and polished empty states rather than fake metrics.

## 8. Architecture Overview

The app starts in `lib/main.dart`, initializes Flutter, and wraps the app in Riverpod. Auth state selects the signed-out/auth flow or the main shell. The main shell uses a bottom navigation bar for Today, Recovery, Sleep, Heart, and More.

Local data is mediated through `LocalRepository`, `LocalStorageAdapter`, and model classes in `lib/local/`. Privacy and sync routing are mediated by `LocalCloudModeGuard`. HealthKit imports and local insight aggregation feed scoring engines and UI screens. Supabase Auth is initialized lazily through `SupabaseBootstrap` only when configured and needed.

Current local persistence is suitable for the foundation pass but not for high-volume HealthKit history. A durable local database remains the next major architecture upgrade.

## 9. Apple Health Integration Summary

- iOS HealthKit entitlement and project capability are present.
- `Info.plist` includes HealthKit read/write purpose strings.
- Native Swift MethodChannel supports availability checks, authorization, direct sample fetches, anchored incremental changes, sample normalization, and optional background-delivery calls.
- Dart service/controller live in `lib/health/healthkit_service.dart`.
- Apple Health permission is separate from cloud-sync consent.
- Imported samples are normalized into local `HealthSample` records with type, value, unit, source, source record id, timestamps, metadata, dedupe key, and import timestamp.
- Anchors are persisted locally and imported samples are deduplicated.

Mapped standard read types include heart rate, resting heart rate, HRV SDNN, respiratory rate, sleep analysis, steps, active energy, body/basal/wrist temperature, oxygen saturation, workouts, VO2 max, mindful sessions, walking/running distance, and cycling distance.

Mapped explicit/sensitive types include menstrual flow, irregular rhythm events, body mass, body fat percentage, and lean body mass. These should require explicit UX before being requested.

## 10. Local-Only Behavior

- Whoordan is private by default. Users must sign in and be manually approved before local-only mode or any protected app feature unlocks.
- Approved users can choose local-only mode after approval.
- Local-only settings, local profile, consent records, HealthKit anchors, health samples, summaries, journal entries, habits, and sync state are stored locally.
- Local-only mode does not call Supabase/cloud sync.
- Apple Health can be connected in local-only mode.
- The app explains that uninstalling may delete local-only data unless platform backup preserves it.

## 11. Supabase/Auth/Cloud Sync Summary

- Supabase email/password auth foundation supports sign up, sign in, sign out, password reset, session restore, validation, loading/error states, and email verification state.
- Client-side config uses public anon/publishable keys only:
  - `WHOORDAN_SUPABASE_URL`
  - `WHOORDAN_SUPABASE_ANON_KEY`
  - Safe aliases: `SUPABASE_PROJECT_ID`, `SUPABASE_PUBLISHABLE_KEY`
- Signed-in account mode does not automatically enable health-data cloud sync.
- Health cloud sync requires explicit granted consent and cloud-sync mode.
- Local-to-cloud migration requires sign-in, explicit confirmation, preview, dedupe, and guarded upload behavior.
- Export and delete flows exist for local data and supported cloud paths.
- Service-role keys are not used in mobile code.

## 12. Supabase Schema/RLS Summary

The migration creates these tables:

- `user_profiles`
- `user_settings`
- `consent_records`
- `sync_states`
- `health_samples`
- `daily_health_summaries`
- `sleep_sessions`
- `workouts`
- `strength_workouts`
- `strength_sets`
- `journal_entries`
- `habit_logs`
- `recovery_insights`

Every user-data table enables and forces RLS. Policies are scoped to `authenticated` users and use `(select auth.uid()) = user_id`. Syncable tables include dedupe keys, sync status/version fields, last sync/error fields, conflict fields, timestamps, and indexes.

## 13. Feature Status Table

| Area | Status | Notes |
| --- | --- | --- |
| Rebrand to Whoordan | Implemented | User-facing identity, metadata, docs, app icons, and W mark are in place. |
| Design system | Implemented | Custom dark mobile UI foundation with reusable primitives. |
| Splash/onboarding/auth UI | Implemented | Pre-approval path is sign-in/sign-up/password reset only. |
| Local-only mode | Implemented | Requires signed-in admin-approved user and blocks cloud calls. |
| Local persistence | Implemented foundation | Uses encrypted indexed SQLite rows for repository payloads; full DB-file encryption remains future work. |
| Supabase Auth | Implemented foundation | Requires public project config. |
| Supabase health-data sync | Scaffolded | Guarded by consent; automatic upload is not enabled. |
| Supabase RLS migration | Implemented foundation | Needs verification against real Supabase project/CLI. |
| HealthKit | Implemented foundation | Needs physical iPhone validation. |
| HealthKit background delivery | Scaffolded | Native method exists; production policy still needs review. |
| Scoring engines | Implemented | Original baseline, recovery, strain, target, sleep, stress, zones, cardio handling. |
| Today/Recovery/Sleep/Heart screens | Implemented foundation | Real local data where available; empty states otherwise. |
| Workouts/Strength/Stress/Breathing/etc. | Scaffolded/partial | UI and local models exist; some workflows need deeper production data capture. |
| Journal/habits/insights | Implemented foundation | Local CRUD and cautious association insights. |
| Privacy/legal/export/delete | Implemented foundation | Release legal text still needs human review. |
| Android Health Connect | Blocked/not started | Not part of current implementation. |
| App Store/TestFlight readiness | Needs human review | Signing, privacy labels, real-device HealthKit, and permissions rationale remain. |

## 14. Tests Added

- Local-only onboarding, settings persistence, cloud guard, account mode, consent, and migration placeholder tests.
- HealthKit unavailable, denied, partial permission, normalization, dedupe, local write, and cloud-blocking tests.
- Scoring tests for baselines, recovery full/missing data, strain, strain target, sleep debt, stress, heart-rate zones, confidence, VO2 handling, and non-medical copy.
- Supabase schema/RLS tests for tables, policies, dedupe/sync/conflict fields, and no service-role usage.
- Privacy/sync tests for migration consent, dedupe, retry-safe failure, conflict counts, export, delete, and disclaimers.
- Journal/habit tests for CRUD, local-only persistence, cloud blocking, minimum sample thresholds, insight confidence, and cautious language.
- Validation hardening tests for branding, native metadata, env tracking, committed secret patterns, disclaimers, and shared UI states.

## 15. Validation Commands Run And Results

| Command | Result | Notes |
| --- | --- | --- |
| `flutter pub get` | Passed | Required escalation once because Flutter needed to write its tool cache. |
| `dart format --output=none --set-exit-if-changed lib test` | Passed | Formatting clean after final pass. |
| `flutter analyze` | Passed | No issues found. |
| `flutter test` | Passed | 57 tests passed. |
| `plutil -lint ios/Runner/Info.plist` | Passed | iOS plist is valid. |
| `flutter build ios --no-codesign` | Passed | Built `build/ios/iphoneos/Runner.app`. |
| `flutter build apk` | Skipped | Android SDK work is intentionally ignored for this chat. |
| `flutter build web` | Skipped | No `web/` target exists. |

## 16. Security/Privacy Checks

- `.env` is ignored and not tracked.
- No Supabase secret/service-role key belongs in app code or docs.
- Secret-pattern scan excludes ignored env files and covers tracked plus pending repo text files.
- No app health-data logging calls were found in `lib`/`test`.
- Local-only mode blocks cloud calls.
- HealthKit permission is separate from cloud-sync consent.
- Cloud sync requires sign-in, cloud mode, and explicit consent.
- HealthKit imports write locally and do not upload by default.
- Disclaimers are present for wellness-only use, irregular rhythm events, menstrual cycle context, pregnancy context, and calorie estimates.

## 17. Known Limitations

- Shared preferences are not suitable for large HealthKit histories, long-term analytics, or robust offline sync queues.
- HealthKit behavior still needs validation on a physical iPhone with real Apple Health permissions.
- Supabase RLS has test coverage from SQL inspection but has not been verified against a live local/dev Supabase instance in this repo.
- Android Health Connect is not implemented.
- Some feature screens are production-shaped foundations, not complete end-to-end workflows.
- Legacy BLE/protocol names remain in internal dependency paths.
- Legal text is release-oriented but still needs human legal review.
- App signing, provisioning, store metadata, screenshots, and privacy labels are not completed.

## 18. Recommended Next Steps

1. Verify HealthKit authorization, anchored imports, and sample normalization on a physical iPhone.
2. Replace shared-preferences health sample storage with a durable local database before expanding import volume or sync.
3. Verify Supabase migrations and RLS policies with Supabase CLI or a disposable development project.
4. Decide whether the legacy BLE protocol dependency remains, is rewrapped behind a neutral source abstraction, or is removed.
5. Review Android permissions and remove anything not required by Whoordan's release scope.
6. Run a human copy/legal/privacy pass before TestFlight.
7. Prepare App Store privacy labels, HealthKit permission explanations, and screenshots from real app states.

## 19. App Store/Privacy Risks To Review With A Human

- HealthKit purpose strings and actual requested data types.
- Sensitive data categories: heart rate, HRV, sleep, respiratory rate, oxygen saturation, cycle context, pregnancy context, irregular rhythm events, body composition, workouts, and location-adjacent distance data.
- Cloud-sync consent copy and data-upload explanations.
- Local-only data deletion and uninstall/backup behavior.
- Account deletion limitations from the mobile client.
- Remaining Android sensitive permissions, especially legacy BLE/location, foreground service, boot completed, notifications, and wakelock. Notification listener, phone/call permissions, and unused BLE advertise permission were removed during remediation.
- Medical-device positioning risk: keep all claims in wellness/fitness language.
- Trademark/domain/store-listing risk for the Whoordan name and W mark.

## 20. Docs That Still Need Official Verification

- Apple HealthKit capability, read/write permission behavior, and background-delivery guidance against current Apple documentation.
- App Store Review Guidelines and privacy nutrition label requirements.
- Supabase Auth/session storage and RLS policy behavior against current Supabase official docs and a live dev project.
- Android Play Store data safety and sensitive permission policy if Android release remains in scope.
- Final privacy policy and terms with a qualified legal reviewer.
