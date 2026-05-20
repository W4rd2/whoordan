# Whoordan UI/UX Renovation Plan

Date: 2026-05-11

This plan covers the premium Flutter UI/UX renovation pass for Whoordan by
W4rd2. It is scoped to product design, motion, accessibility, copy,
performance, and privacy-gate safety. It does not change formulas, HealthKit
behavior, BLE protocol behavior, Supabase RLS, or consent rules.

## Research And Reference Guardrails

Sources used for implementation direction:

- Apple HealthKit HIG:
  <https://developer.apple.com/design/human-interface-guidelines/healthkit/>
- Apple HealthKit privacy:
  <https://developer.apple.com/documentation/healthkit/protecting-user-privacy>
- Apple reduced-motion accessibility criteria:
  <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-accessibility-evaluation-criteria>
- Apple UserNotifications and CallKit docs for platform limitations:
  <https://developer.apple.com/documentation/usernotifications>,
  <https://developer.apple.com/documentation/callkit>

Public wearable app references were treated only as broad category context. No
third-party UI, formula, color system, chart treatment, wording, trade dress, or
proprietary behavior was copied.

## UI/UX Inventory

Current design system:

- `lib/theme.dart` defines the dark-first Whoordan token set, typography,
  spacing, radii, shadows, button/input/nav styling, and chart style.
- `lib/widgets/cards.dart` contains shared cards, status pills, stat tiles,
  settings rows, empty/loading/permission states, and modal sheets.
- Chart/visual primitives live in `score_ring.dart`, `sparkline.dart`,
  `trend_chart.dart`, and `sleep_timeline.dart`.

Current high-value screens:

- Auth/sign-up/reset request: `lib/auth/auth_screens.dart`
- Approval checking and locked states: `lib/main.dart`
- Main navigation shell: `lib/screens/main_shell.dart`
- Today flagship dashboard: `lib/screens/today_screen.dart`
- Recovery, Sleep, Heart, More, Settings, feature screens, vibration settings,
  history, privacy/legal, and pairing screens under `lib/screens/` and
  `lib/pairing/`.

Main inconsistencies and risks found:

- The app was consistent but card-heavy, making many screens feel similar.
- Auth and approval were secure but visually utilitarian.
- The shell sync icon could imply cloud success while cloud sync was disabled.
- Muted text contrast was too low for small supporting text on some surfaces.
- Custom cards/rows needed stronger semantic button behavior and tap targets.
- Motion existed but had no centralized reduced-motion policy.
- Main tab swaps were abrupt and all indexed tabs stayed mounted/subscribed.
- Some copy used technical words like Supabase/backend in user-facing contexts.
- Manual local health actions and pairing needed lower-level approval checks in
  addition to route-level gating.

## Design Direction

Whoordan design language: private signal lab.

The interface should feel:

- private
- precise
- calm
- strong
- modern
- athletic
- health-tech
- minimal but not empty

Visual rules:

- Dark graphite base with cream identity accents and restrained teal for live or
  interactive signal.
- Source, confidence, local-only, and cloud-off states should be visible but not
  alarmist.
- Health charts and score visuals should be calm; no gamified or pulsing health
  states.
- Data cards must clearly separate measured/imported values from estimates.
- Unsupported notification/call/alarm capabilities stay scaffolded honestly.

Avoid:

- default Flutter look
- repeated generic icon/value cards as the only visual system
- random glassmorphism
- copied wearable-app layouts or wording
- fake metrics
- medical/diagnostic claims
- protected-data rendering before approval

## Renovation Priorities

P0 privacy/security gates:

- Preserve admin approval as the outermost gate.
- Ensure no local-only, HealthKit, BLE, cloud, haptics, journal, dashboard, or
  cached health UI is reachable before approval.
- Add service-level approval checks where UI-only gating was not enough.

P1 reusable design system:

- Strengthen theme contrast and motion tokens.
- Add reusable premium primitives: brand lockup, page intro, signal panel,
  source/confidence row, confidence meter, signal stack.
- Improve shared card and settings row semantics/tap targets.

P1 flagship screens:

- Auth: premium private-access first impression with safe error copy.
- Approval locked/checking: polished identity/status panels with no private data.
- Shell: smoother reduced-motion-aware transitions and privacy-aware sync icon.
- Today: original signal-stack recovery panel with source/confidence labels.
- More/Settings: stronger hierarchy and safer copy.

P2 accessibility and smoothness:

- Reduced-motion-aware transitions and score animations.
- Repaint boundaries around charts/score/sleep visuals.
- More semantic chart summaries.
- Avoid offscreen tab subscriptions by rendering the active tab.

P3 future design pass:

- Full screenshot/golden coverage.
- Physical VoiceOver/TalkBack review.
- Dedicated redesign of Live/device diagnostics, Journal, Vibration recorder,
  and long-form Settings grouping.

## Subagent Findings Incorporated

Product/UI Design:

- Found card-heavy, generic dark dashboard patterns.
- Recommended a distinctive Whoordan design direction and source/confidence
  primitives.
- Incorporated with `SignalPanel`, `PageIntro`, `BrandLockup`,
  `SourceConfidenceRow`, `ConfidenceMeter`, and `SignalStack`.

UX Flow:

- Confirmed approval is outermost gate.
- Found sync indicator confusion, scattered setup, and direct permission risks.
- Incorporated with privacy-aware shell indicators and pairing pre-approval
  blocking.

Flutter Performance:

- Found offscreen tabs stayed subscribed and broad live watches caused rebuilds.
- Incorporated with active-tab rendering, reduced live watch scope on Today,
  and repaint boundaries.
- BLE write batching remains a future performance task.

Accessibility:

- Found low muted-text contrast, weak custom card/row semantics, and missing
  reduced-motion handling.
- Incorporated with higher `textMuted`, semantic cards/rows, motion helper,
  chart summaries, and tests.

Motion/Interaction:

- Recommended centralized reduced-motion policy and tasteful transitions.
- Incorporated with `WMotion`, reduced-motion-aware root/tab transitions, and
  animated score ring/band changes.

Copy/Microcopy:

- Found technical user-facing copy and medically loaded labels.
- Incorporated by replacing user-facing Supabase/backend wording, removing
  release-placeholder legal copy, renaming Body Signals/Stress Signals/Long-Term
  Trends, and adding safe auth error copy.

Privacy/Security Gate:

- Found service-level manual health action and pairing gaps.
- Incorporated with approval checks in `LocalHealthActionService`,
  `PairScreen`, and headless background sync queue behavior.

Test/Validation:

- Recommended widget/source guard coverage for UI state, motion, and gates.
- Incorporated with tests for reduced motion, shared UI primitives, pairing
  pre-approval block, manual health action approval, and updated stability
  guards.

## Remaining Manual Checks

- Capture screenshots for auth, approval pending/revoked, Today, Recovery,
  Sleep, Heart, More, Settings, Pairing, Vibration settings, and legal screens.
- Review at small phone width and large text.
- Run VoiceOver/TalkBack manually.
- Validate physical iPhone HealthKit, Android BLE/wearable, haptic preview,
  alarm behavior, and TestFlight install.
- Consider a second focused pass for Live/device diagnostics, Journal/Habits,
  and Vibration recorder interaction.
