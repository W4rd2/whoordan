# Whoordan UI/UX Implementation Report

Date: 2026-05-11

This report documents the scoped premium UI/UX, motion, accessibility,
performance, copy, and privacy-gate renovation implemented in this pass.

## Executive Summary

Update on 2026-05-11: a focused matte/iPhone correction pass removed the most
obvious glossy/glass treatment, replaced the Material bottom navigation with a
quiet iOS-style tab bar, redesigned Today around one cached insights view, and
removed high-frequency live heart-rate/SpO2/battery/packet projections from the
visible Today scroll content. Wearable vibration preview now uses an explicit
playback service with approval, connection, safety, unsupported, failed, and
started states; custom pattern device playback remains honestly unsupported by
the current BLE adapter.

Device follow-up on 2026-05-11: Wardan's iPhone was detected first wirelessly
and then over USB. Debug `flutter run` built successfully but timed out at the
Xcode debug-session attach step. A signed release run installed and launched on
the iPhone. The user observed a white launch screen/flash; the native
`LaunchScreen.storyboard` and `Main.storyboard` backgrounds were still white.
Both were changed to the matte near-black Whoordan background and a signed
release build was reinstalled/launched successfully. Screen-by-screen visual
QA, scroll profiling, and wearable vibration playback remain manual/pending
because this environment could not capture physical iPhone screenshots.

Whoordan now has a stronger original premium direction, but this is not the
final visual QA pass. The first-run/auth/approval experience, main shell, Today
dashboard, More, Settings, shared cards, chart semantics, reduced-motion policy,
and privacy-safe copy were improved. No screenshots or physical-device UI tests
were captured in this run.

The app still needs manual screenshot review, physical iPhone/Android testing,
VoiceOver/TalkBack review, and a focused pass on Live/device diagnostics,
Journal/Habits, and Vibration recorder polish.

## Subagents Used

Runtime configured role registry was unavailable because `.codex/agents/registry.toml`
was not present. Generic runtime explorer subagents were used with explicit
role packets.

1. Product/UI Design Subagent
   - Inspected theme, widgets, screens, auth, assets, README, and audit docs.
   - Found a coherent but card-heavy generic wearable dashboard.
   - Recommended a private signal lab design language and source/confidence
     primitives.

2. UX Flow Subagent
   - Inspected auth, approval, local/cloud, HealthKit, BLE, haptics, settings,
     and dashboard flows.
   - Confirmed approval is the outermost gate.
   - Found sync indicator ambiguity, scattered setup, and direct pairing
     permission risk.

3. Flutter Performance Subagent
   - Inspected main shell, Today, Live, chart widgets, local repository, BLE, and
     scoring.
   - Found offscreen tab subscriptions, broad live-provider watches, and BLE
     storage batching risk.
   - Recommended active-tab rendering, narrower provider selection, repaint
     boundaries, and future BLE batching.

4. Accessibility Subagent
   - Inspected theme, shared widgets, auth, approval, screens, charts, and
     settings.
   - Found low muted-text contrast, weak custom-card semantics, reduced-motion
     gaps, and chart summary gaps.

5. Motion/Interaction Subagent
   - Inspected root transitions, shell tabs, cards, charts, vibration recorder,
     and breathing screen.
   - Recommended a centralized reduced-motion policy, restrained transitions,
     and non-gamified score motion.

6. Copy/Microcopy Subagent
   - Inspected user-facing strings across auth, screens, privacy, and tests.
   - Found technical copy, medically loaded surface names, and user-facing
     release-placeholder legal text.

7. Privacy/Security Gate Subagent
   - Inspected approval, auth, local mode, cloud, HealthKit, BLE, background,
     screens, and tests.
   - Found manual health action and pairing service-level approval gaps.
   - Ran focused gate validation; 83 tests passed in the subagent run.

8. Test/Validation Subagent
   - Inspected current tests and UI files.
   - Found UI coverage was thinner than service coverage and recommended widget
     and source-guard tests for the renovation.

## Screens Renovated

- Device follow-up: native iOS launch and Flutter host storyboard backgrounds
  now match the matte dark app background to remove the white launch flash.
- Latest pass: Today was restructured into a single smooth scroll view backed
  by cached local insights, a matte recovery hero, compact strain/sleep/signal
  summaries, a data-readiness panel, and a purposeful baseline-building empty
  state.
- Splash/session restore: now uses a premium centered identity/status panel.
- Approval checking: now uses the same polished locked identity panel language.
- Approval locked states: now use a `SignalPanel`, W mark, status pill, and
  clear refresh/sign-out actions.
- Auth/sign-in/sign-up: now uses `BrandLockup`, `PageIntro`, `SignalPanel`,
  safer account-service error copy, and no technical Supabase copy in the UI.
- Main shell: tab title and content transitions are reduced-motion aware; shell
  sync icon now distinguishes local-only/cloud-off/syncing/synced/failed states.
- Today: flagship recovery panel now uses `SignalPanel`, `SignalStack`,
  `SourceConfidenceRow`, confidence/source labels, and caption `TODAY` instead
  of generic readiness framing.
- More: top panel uses an original signal-library intro and safer health surface
  labels.
- Settings: added a page intro and replaced backend/Supabase wording with
  account/cloud-service language.

## Components Created Or Updated

Latest pass:

- `WTheme`: replaced teal-heavy/gloss-prone tokens with near-black graphite
  surfaces, warm white text, cool gray secondary text, restrained mint accent,
  muted signal colors, and softer shadows.
- `GlassCard`: retained as a compatibility component name but now renders a
  matte card with lower border contrast and no glass treatment.
- `SignalPanel`: no longer uses a shiny gradient overlay; it now uses a matte
  panel with a small signal accent rail.
- `_IosBottomNav`: custom iOS-style bottom navigation with subtle active state
  and safe-area support.
- `VibrationPlaybackService`: testable service for wearable pattern playback
  outcomes without fake success.

New reusable primitives in `lib/widgets/cards.dart`:

- `BrandLockup`
- `PageIntro`
- `SignalPanel`
- `SourceBadge`
- `SourceConfidenceRow`
- `ConfidenceMeter`
- `SignalStack`
- `SignalStackItem`

Updated primitives:

- `GlassCard`: reduced-motion-aware animation and stronger semantics for
  tappable cards.
- `SettingsRow`: explicit minimum tap height and semantic button/value/hint
  behavior.
- `LoadingStateCard`, `EmptyStateCard`, `PermissionStateCard`: reused in tests
  with the new premium primitives.
- `ScoreRing` and `ScoreBand`: reduced-motion-aware value animation and richer
  semantic labels.
- `TrendChart`, `Sparkline`, and `SleepTimeline`: repaint boundaries and richer
  semantic summaries.

## Design System Changes

- Latest pass replaced glossy/glass styling with matte graphite surfaces and
  reduced accent saturation. Borders are now lower contrast and status chips use
  softer fills.
- Raised `WTheme.textMuted` contrast for small/supporting text.
- Added `bgTop`, `cream`, `creamSoft`, `slow`, `easeOut`, and `easeInOut` tokens.
- Added `WMotion` helper to respect `MediaQuery.disableAnimations` and
  `accessibleNavigation`.
- Added switch theme styling for more consistent settings controls.

## Performance And Smoothness Changes

- Latest pass removed visible Today subscriptions to live heart-rate, SpO2,
  battery, PPG, and trace values. Today now watches only low-frequency device
  connection state outside cached insights content.
- Latest pass wraps the Today recovery hero in a `RepaintBoundary` and avoids
  multiple independent async sections for the main dashboard content.
- Main tab content now renders the active tab with a reduced-motion-aware
  transition instead of keeping all tabs subscribed in an `IndexedStack`.
- Today health signal panel watches a compact live-provider projection instead
  of the whole live snapshot.
- Chart/score/sleep custom-paint widgets now use `RepaintBoundary`.
- Root auth/approval transitions and shell transitions use centralized motion
  durations and reduced-motion handling.

Skipped intentionally:

- BLE write batching was recommended but not implemented in this UI pass because
  it touches storage cadence and needs careful device/profile validation.
- Full provider splitting for local insights was not implemented because it is
  larger than a UI renovation and could affect scoring/data freshness.

## Accessibility Changes

- Muted text contrast improved.
- Custom cards/rows now expose clearer button/value/hint semantics.
- Score, chart, sparkline, and sleep timeline semantics now include richer data
  summaries.
- Reduced-motion media settings now collapse custom animation durations.
- Shared UI primitive test coverage was expanded.

Remaining accessibility work:

- Manual VoiceOver/TalkBack pass.
- Text-scale screenshot review at small widths.
- Chart legend/point-inspection pass.
- Field-specific form validation/focus polish.

## Copy Changes

- `Whoordan is unlocked.` became `Access is ready.`
- Pending approval copy now says app features are unavailable until approval,
  rather than “the app unlocks.”
- Auth sign-up copy no longer mentions a Supabase project.
- User-facing Supabase/backend copy was replaced with account/cloud-service
  language.
- Legal copy no longer contains release-placeholder text or service-role
  implementation wording.
- `Health Monitor` became `Body Signals`.
- `Stress Monitor` became `Stress Signals`.
- `Long-Term Health` became `Long-Term Trends`.
- `Breathing recommendation` became `Breathing option`.
- Robotic empty/status phrases like `Missing data`, `Future sources`, and
  `No parsed sensor preview` were replaced where found.

## Privacy/Security Regression Checks

Preserved:

- Approval gate remains outermost in `_RootRouter`.
- MainShell still renders only after `approval.isApproved`.
- Local-only remains available only after approval.
- Cloud sync remains approval + explicit consent gated.
- Health-data cloud sync remains approval + explicit consent gated.
- Apple Health and BLE service paths still check approval.

Improved:

- `LocalHealthActionService` now requires admin approval before manual workout,
  strength, breathing, and sensitive consent writes.
- `PairScreen` now checks approval before requesting Bluetooth/location
  permissions, scanning, connecting, or pairing.
- Headless background sync no longer enqueues a pending sync job when no
  approved identity can be verified.

## Tests Added Or Updated

- `test/local_health_insights_test.dart`
  - Added admin-approval requirement for manual health actions and sensitive
    consent writes.
- `test/approval_gate_test.dart`
  - Added a widget test that `PairScreen` does not start device work before
    approval.
- `test/validation_hardening_test.dart`
  - Updated release-safe copy/design guards.
  - Added coverage for new shared UI primitives.
  - Added reduced-motion helper test.
  - Added source guards for local health action, pair screen, and background
    gating.
- `test/ui_live_stability_test.dart`
  - Updated performance guard from indexed hidden tabs to active-tab
    `AnimatedSwitcher`/`KeyedSubtree` rendering.
- `test/privacy_sync_test.dart`
  - Updated legal copy expectations to client-safe account access and local-only
    upload language.

## Validation Results

- `flutter pub get`: passed. `Got dependencies!`; 32 packages have newer
  versions incompatible with current constraints.
- `flutter analyze`: passed. `No issues found! (ran in 2.4s)`.
- Targeted UI/haptics stability tests: passed,
  `flutter test test/vibration_playback_service_test.dart test/ble_processing_test.dart test/main_shell_layout_test.dart test/ui_live_stability_test.dart`.
- `flutter test`: passed, 158 tests.
- `flutter build ios --no-codesign`: passed; built
  `build/ios/iphoneos/Runner.app` at 23.8 MB.
- Physical iPhone release run:
  `flutter run --release -d [REDACTED_DEVICE_ID] --no-resident ...`
  installed and launched successfully after the storyboard fix.
- `git diff --check`: passed.
- `flutter build apk`: intentionally not run in this pass per request to ignore
  Android build for now.

## Remaining UI/UX Risks

- No screenshots were captured.
- No physical device UI validation was performed.
- The latest matte pass was validated by static/tests/build only; actual iPhone
  scroll smoothness still needs Instruments or physical-device observation.
- No VoiceOver/TalkBack pass was performed.
- Live/device diagnostics still feels more technical than premium.
- Vibration recorder still needs pressed/recording/timeline polish.
- Journal/Habits and long feature screens still use many repeated card patterns.
- BLE sample write batching remains a performance follow-up.
- Full golden/screenshot coverage is still missing.

## Recommended Next UI Pass

Run a focused device-backed visual QA pass:

1. Capture screenshots on iPhone small/large and Android small/large.
2. Validate large text and reduced motion.
3. Polish Live/device diagnostics into a premium “Device” surface.
4. Polish Journal/Habits interaction density.
5. Add a visible vibration recorder timeline and delete confirmation.
6. Add screenshot/golden tests for auth, approval, Today, settings, and key
   empty/error states.
