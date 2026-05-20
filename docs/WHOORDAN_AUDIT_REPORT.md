# Whoordan Audit Report

Audit date: 2026-05-10

## 1. Executive Summary

Whoordan is a Flutter/Riverpod mobile app with local-first storage, Supabase email/password auth foundation, consent-gated cloud sync foundations, iOS HealthKit foundations, original scoring engines, and renovated app screens.

No blocking stop condition was found in the inspected app code: no committed Supabase service-role key was found, `.env` is ignored and untracked, local-only mode is guarded from cloud calls, HealthKit import paths write locally, and user-data Supabase tables enable/force RLS with owner policies.

The audit fixed several safety and correctness gaps:

- Supabase cloud data operations now require the requested user id to match the active Supabase session.
- Migration payload ownership is validated before upload.
- Cloud export now includes the workout/sleep/strength tables that deletion already covered.
- Health sample cloud schema now has an explicit `ended_at` column.
- Delete policies were added for profile/settings/consent/sync tables so the mobile cloud deletion path can delete all user-owned app rows.
- Daily health aggregation and journal/habit date keys now use the device local calendar day instead of UTC day boundaries.

## Remediation Status Update - 2026-05-10

- Fixed: the main app shell no longer forces wearable pairing before local-only or Apple Health-oriented use. Pairing remains available from Settings.
- Fixed: Android phone/call-control permissions, notification-listener permission/service registration, and unused BLE advertise permission were removed from the current release manifest.
- Fixed: Android foreground-service notification copy no longer exposes live heart-rate values in system notification text.
- Fixed: local wearable summary capture now uses the device local calendar day key consistently with the rest of local storage.
- Added regression coverage for forced pairing, Android sensitive permission scope, foreground notification privacy, and local summary day boundaries.
- Still blocked: live Supabase RLS execution, physical HealthKit validation, Android build validation, and qualified legal/App Store privacy review.

## 2. Stack Detected

- Framework: Flutter mobile app.
- Languages: Dart, Swift, Kotlin.
- Platforms: iOS and Android. No web target is present.
- State management: Riverpod providers, `StateNotifier`, streams, and async providers.
- Navigation: manual `MaterialApp`, auth root switcher, `Navigator.push`, and bottom `NavigationBar`.
- Storage: `shared_preferences` for local app data and `flutter_secure_storage` for auth/session material.
- Backend/auth: Supabase Auth via `supabase_flutter`; legacy custom REST remains behind dart defines and consent guards.
- Health: iOS HealthKit through Swift `MethodChannel`; Android Health Connect is not configured.
- UI: custom Whoordan dark Material 3 design system with reusable cards, score, chart, and state primitives.
- Package manager: Flutter/Dart `pub`.

## 3. Validation Commands Run And Results

| Command | Result | Notes |
| --- | --- | --- |
| `dart format lib/privacy/privacy_sync_service.dart lib/local/local_models.dart lib/local/local_repository.dart lib/scoring/whoordan_scoring.dart test/supabase_schema_test.dart test/privacy_sync_test.dart test/scoring_engine_test.dart` | Passed | Formatted touched files. |
| `flutter test test/privacy_sync_test.dart test/supabase_schema_test.dart test/scoring_engine_test.dart` | Passed | 28 focused tests. |
| `flutter analyze` | Passed | No issues found. |
| `flutter test` | Passed | 61 tests passed. |
| `dart format --output=none --set-exit-if-changed lib test` | Passed | 50 files checked, 0 changed. |
| `plutil -lint ios/Runner/Info.plist` | Passed | iOS plist is valid. |
| `flutter build ios --no-codesign` | Passed | Built `build/ios/iphoneos/Runner.app` at 22.7 MB. |
| `command -v supabase` | Failed as expected | Supabase CLI is not installed, so live RLS/policy tests were not run. |
| `flutter build apk` | Skipped | Android SDK work is intentionally ignored for this chat. |
| `flutter build web` | Skipped | No `web/` directory/target exists. |

## 4. Branding Audit

- User-facing product identity is Whoordan.
- Publisher attribution W4rd2 appears in product copy and metadata where appropriate.
- iOS `CFBundleDisplayName` is Whoordan.
- Android label is Whoordan.
- Bundle/application ids use `com.w4rd2.whoordan`.
- The installed logo asset is `assets/brand/whoordan-w-logo.png`, and native launcher icons were generated from the W mark.
- Remaining old naming is intentionally retained only in internal BLE protocol dependency names and documented in `docs/WHOORDAN_LEGACY_NAMING_AUDIT.md`.
- Necessary brand-safety references to third-party wearable remain only as compliance guardrails.

## 5. UI/Product Audit

- The app has a cohesive custom Whoordan design system in `lib/theme.dart` and `lib/widgets/`.
- Major screens use polished loading, empty, error, and permission states instead of fake production metrics.
- The Today screen is the flagship app surface with brand presence, recovery/strain/sleep/status panels, and missing-data handling.
- Screens avoid explicit medical diagnosis positioning and use wellness language.
- Remaining product risk: several feature areas are production-shaped foundations rather than complete end-to-end workflows.
- Remediated UX risk: the app no longer prompts pairing automatically after entering the main shell. Users can open wearable pairing from Settings when needed.

## 6. Accessibility Audit

- Reusable cards and status components include semantic labels where most useful.
- Buttons generally meet large tap target expectations through theme-level minimum sizing.
- Empty and permission states use icons plus text, not color alone.
- Forms use labeled inputs or clear hints; auth errors are visible.
- Remaining risk: no full device-matrix visual/a11y audit was run with screen readers, dynamic type extremes, or small physical devices.

## 7. Local-Only Audit

- Local-only mode now requires sign-in and manual admin approval before it unlocks.
- Local-only mode stores profile/settings/consents/health samples/journal/habits locally.
- Local-only mode can connect Apple Health after approval.
- `LocalCloudModeGuard` blocks cloud calls unless backend is available, mode is cloud sync, sync was requested, and latest cloud-sync consent is granted.
- Tests cover local-only selection, persistence, cloud blocking, and migration blocking.
- No local-only HealthKit upload path was found.

## 8. Auth Audit

- Supabase email/password sign up, sign in, sign out, password reset, session restore, input validation, loading/error state, and email verification state are implemented.
- Supabase initializes lazily only when configured and needed.
- Session storage uses `flutter_secure_storage`.
- No plaintext password storage or token logging was found.
- Official Supabase password docs confirm password reset uses `resetPasswordForEmail`; current implementation uses that method.

## 9. Supabase Schema/RLS Audit

- Migrations create `user_profiles`, `user_settings`, `consent_records`, `sync_states`, `health_samples`, `daily_health_summaries`, `sleep_sessions`, `workouts`, `strength_workouts`, `strength_sets`, `journal_entries`, `habit_logs`, and `recovery_insights`.
- Every user-data table is in the RLS loop and has `enable row level security` plus `force row level security`.
- Policies are scoped `to authenticated` and use `(select auth.uid()) = user_id`.
- The audit added delete policies for `user_profiles`, `user_settings`, `consent_records`, and `sync_states`.
- The audit added `health_samples.ended_at` for first-class end timestamps.
- No unrestricted `to anon`, `using (true)`, or public health-data policy was found.
- Live Supabase verification remains blocked because the Supabase CLI is not installed.

Official-doc alignment:

- Supabase says publishable keys are public-client appropriate, but data protection depends on RLS.
- Supabase says secret/service-role keys are elevated, bypass RLS, and must not be exposed in mobile apps.
- Supabase RLS docs recommend policies scoped to `authenticated` and ownership checks with `auth.uid()`.

## 10. Cloud Sync/Migration Audit

- Cloud sync requires account mode plus explicit cloud-sync consent.
- Existing local data does not migrate automatically.
- Migration requires sign-in, preview, explicit confirmation, dedupe, and retry-safe local retention on failure.
- The audit added current-session user-id validation and migration payload ownership validation.
- Cloud export now includes profile, settings, sync state, consents, health samples, summaries, sleep, workouts, strength workouts, strength sets, journal entries, habit logs, and insights.
- Cloud delete now has matching owner-scoped delete policies for all app tables it attempts to delete.

## 11. Apple Health/HealthKit Audit

- iOS HealthKit entitlement is present.
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` are present.
- The native bridge checks `HKHealthStore.isHealthDataAvailable()`.
- Authorization requests use read types and an empty write/share set.
- Standard read types cover core wellness/fitness signals.
- Sensitive types such as menstrual flow, irregular rhythm events, and body composition are mapped but not requested by default.
- Samples normalize source, type, value, unit, start/end timestamps, source record id, metadata, and import timestamp.
- Anchored incremental imports and local anchors are implemented.
- Imported samples write to local storage and deduplicate by stable keys.
- HealthKit permission is separate from cloud-sync consent.

Official-doc alignment:

- Apple HealthKit requires fine-grained user authorization per data type.
- Apple requires HealthKit usage descriptions before requesting authorization.
- Apple documents that apps cannot reliably know when users deny read permission for a type; Whoordan still needs physical-device validation for denied and partial read behavior.

## 12. Data Model/Deduplication Audit

- Local `HealthSample` includes id, type, value, unit, timestamp, end timestamp, imported timestamp, source, source record id, dedupe key, and metadata.
- Supabase `health_samples` now includes `sampled_at` and `ended_at`.
- Local imports dedupe with `appendHealthSamplesDeduped`.
- HealthKit deleted objects remove matching local dedupe keys.
- Date aggregation now uses the device local calendar day.
- Remaining risk: local storage now uses encrypted indexed SQLite rows, but full database-file encryption and physical large-history performance validation are still outstanding.

## 13. Scoring Engine Audit

- Baselines use rolling 14/30/60-day personal history.
- Recovery score is original, baseline-relative, 0-100, confidence-aware, and handles missing inputs.
- Strain score is original, 0-21, contributor-based, and confidence-aware.
- Strain target is conservative when recovery is low.
- Sleep need/debt uses recent sleep, strain, naps, consistency, and performance mode.
- Stress score uses physiological/body-signal language and avoids mental-health diagnosis.
- Heart-rate zones support configured max HR and label fallback estimates.
- VO2/cardio fitness uses imported values only and does not estimate by default.
- Tests cover scoring, confidence, missing data, non-medical text, and local-day aggregation.

## 14. Feature Status Table

| # | Feature | Status | Audit Notes |
| --- | --- | --- | --- |
| 1 | Daily Recovery Score | Implemented foundation | Original scoring; depends on real local inputs. |
| 2 | Sleep Tracking | Partially implemented | Reads local samples; richer stage/session modeling needs real data validation. |
| 3 | Sleep Planner | Implemented foundation | Uses local sleep need/debt model. |
| 4 | Strain Score | Implemented foundation | Uses HR zones, movement, workouts, stress, strength where available. |
| 5 | Personalized Strain Target | Implemented foundation | Conservative low-recovery language present. |
| 6 | Heart Rate Tracking | Implemented foundation | Local samples and live BLE where available. |
| 7 | Heart Rate Zones | Implemented foundation | Configurable/fallback max HR. |
| 8 | Workout Tracking | Partially implemented | Apple Health imports and manual logs; route/location not implemented. |
| 9 | Strength Training and Muscular Load | Partially implemented | Local manual set logging and load calculation. |
| 10 | Stress Monitor | Implemented foundation | Physiological/body-signal wording only. |
| 11 | Breathing and Relaxation Tools | Partially implemented | Guided timer and local session logging. |
| 12 | Health Monitor | Implemented foundation | Displays local wellness signals and baseline context. |
| 13 | Resting Heart Rate | Implemented foundation | Imported/local signal. |
| 14 | Heart Rate Variability | Implemented foundation | Imported/local HRV signal. |
| 15 | Respiratory Rate | Implemented foundation | Imported/local signal. |
| 16 | Skin Temperature | Implemented foundation | Temperature signals mapped; device validation needed. |
| 17 | Blood Oxygen | Implemented foundation | SpO2 signal mapped/displayed when authorized. |
| 18 | Long-Term Health Metrics | Partially implemented | Trend views exist; needs larger local DB. |
| 19 | Fitness and VO2 Max Estimate | Partially implemented | Apple Health import supported; internal estimates intentionally not generated. |
| 20/21 | Numbering gap | Preserved | No feature assigned. |
| 22 | Irregular Rhythm Notifications | Scaffolded/display-only | Imports/displays only authorized Apple Health events; no detector. |
| 23 | Menstrual Cycle Insights | Scaffolded/consent-gated | Explicit consent required; not fertility/contraception/medical tool. |
| 24 | Pregnancy-Related Tracking | Scaffolded | User-declared context only; no detection. |
| 25 | Journal and Habit Tracking | Implemented foundation | Local CRUD and custom habits. |
| 26 | Recovery Insights | Implemented foundation | Minimum sample thresholds and cautious association language. |
| 27 | Steps and Daily Movement | Implemented foundation | Uses local step samples when available. |
| 28 | Calorie Estimates | Partially implemented | Imported active energy and labeled manual estimates. |
| 29 | App Integrations | Scaffolded | Apple Health first; no fake unsupported integrations. |

## 15. Journal/Habits/Insights Audit

- Daily journal entry supports notes, mood, stress, and soreness.
- Habit library includes requested default habit types and supports custom habits.
- Logs can be added/edited/deleted locally.
- Insight generation requires minimum samples in both with/without groups.
- Insight language uses “associated with” and explicitly avoids cause-and-effect claims.
- Tests cover CRUD, local-only cloud blocking, minimum thresholds, and cautious language.

## 16. Privacy/Legal/Consent Audit

- Cloud sync consent flow explains local-only behavior and upload categories.
- Consent records are stored locally and can be revoked.
- Apple Health disconnect explains iOS manages Health permissions.
- Export flow provides in-app JSON preview and copy action with sensitivity warning.
- Delete flow requires confirmation and can delete local data plus cloud app rows for a signed-in user.
- Account deletion is documented as requiring a secure server-side flow.
- Privacy, terms, wellness disclaimer, irregular rhythm, menstrual cycle, pregnancy, and calorie estimate documents are present.
- Release legal text still needs human legal/privacy review.

## 17. Security/Secrets Audit

- `.env` exists locally but is ignored by `.gitignore` and is not tracked.
- No committed service-role key, secret key, private key, or hardcoded real secret was found in scanned app/test/docs/schema text.
- Supabase client config uses anon/publishable keys only.
- Supabase bootstrap has `debug: false`.
- No health sample logging, auth session logging, `debugPrint`, `print`, or `developer.log` calls were found in app code.
- Legacy custom REST token storage remains in secure storage and is gated by cloud consent before use.

## 18. Tests Added Or Fixed

- Added Supabase schema test coverage for owner delete policies on every user-data table.
- Added Supabase schema test coverage for explicit `health_samples.ended_at`.
- Added migration payload test for HealthKit sample end timestamps.
- Added static hardening test that the Supabase cloud data client checks the active session user.
- Added scoring aggregation test for device local calendar day grouping.

## 19. Bugs Fixed During Audit

- Cloud data operations could rely only on RLS for user-id mismatch protection; now the client also rejects mismatched session/user ids.
- Migration payload rows were not explicitly checked for ownership before upload.
- Cloud export omitted sleep/workout/strength tables.
- Cloud delete attempted to delete profile/settings/consent/sync rows without matching delete policies.
- Health sample end timestamps were stored only in metadata for cloud rows.
- Health and journal date boundaries used UTC calendar days instead of the device local calendar day.

## 20. Remaining Issues

- HealthKit denied-read behavior cannot be fully detected by design and needs real-device UX validation.
- Shared preferences are not suitable for high-volume HealthKit history or robust offline sync queues.
- Supabase policies have not been executed against a live local/dev Supabase instance.
- Android phone/call-control permissions, notification-listener permission/service registration, and unused BLE advertise permission were removed. Remaining Android BLE, older-version location, foreground-service, boot, notification, and wakelock permissions still require Play Store release review.
- Some screens are foundations, not complete production workflows.
- Pairing-first app shell was remediated; pairing is now user-initiated from Settings.
- Legal text is placeholder/release-oriented and needs qualified human review.

## 21. Blocked Items

- Live Supabase RLS tests are blocked because Supabase CLI is not installed.
- Physical HealthKit authorization/import validation is blocked without a real iPhone and Apple Health data.
- Android build was skipped because this chat is intentionally ignoring Android SDK installation/work.
- App Store/TestFlight signing and provisioning were not validated.

## 22. Recommended Next Steps

1. Run Supabase migrations in a disposable dev project and verify RLS with two test users.
2. Validate HealthKit authorization, denied states, anchored imports, sample deletion, and unit normalization on a physical iPhone.
3. Replace shared-preferences health sample storage with a local database before expanding HealthKit import volume.
4. Review remaining Android BLE, older-version location, foreground-service, boot, notification, and wakelock permissions against the final Play Store release scope.
5. Add a server-side account deletion function if account deletion is required in-app.
6. Run a human privacy/legal/App Store review before TestFlight.

## 23. App Store/Privacy/Human Review Checklist

- Confirm HealthKit purpose strings match final requested data types.
- Confirm sensitive categories: heart rate, HRV, sleep, respiratory rate, SpO2, temperature, cycle context, pregnancy context, irregular rhythm events, body composition, workouts, and distance.
- Confirm no HealthKit data is used for advertising or sold/shared beyond explicit user permission.
- Prepare a complete privacy policy, terms, and App Store privacy nutrition labels.
- Review cloud sync consent copy and local-to-cloud migration copy.
- Review local-only uninstall/backup messaging.
- Review medical-device positioning risk and keep claims wellness/fitness-only.
- Review trademark/domain/store-listing risk for Whoordan and the W mark.
- Confirm Supabase project uses only publishable/anon client keys in mobile builds.
- Confirm RLS and grants in the actual Supabase project before any public beta.

## Official Documentation Checked

- Apple HealthKit authorization: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- Apple HealthKit privacy: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Apple `HKHealthStore.requestAuthorization`: https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization%28toshare%3Aread%3Acompletion%3A%29
- Apple HealthKit entitlement: https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.healthkit
- Supabase API keys: https://supabase.com/docs/guides/getting-started/api-keys
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase API security: https://supabase.com/docs/guides/api/securing-your-api
- Supabase password auth: https://supabase.com/docs/guides/auth/passwords
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
