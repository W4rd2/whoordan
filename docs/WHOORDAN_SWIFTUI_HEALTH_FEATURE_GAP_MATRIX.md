# Whoordan SwiftUI Health Feature Gap Matrix

Date: 2026-05-11
Branch: `swift-app`

## Scope

This gap matrix summarizes the native SwiftUI app after the Priority A wearable-feature pass. The full 209-item audit lives in `docs/WHOORDAN_WEARABLE_FEATURE_PARITY_MATRIX.md`.

## Priority A Status

| Area | Current status | Implemented now | Remaining gap |
|---|---|---|---|
| Steps / daily movement | `IMPLEMENTED_NOT_PHYSICALLY_VALIDATED` | Apple Health step mapping, daily aggregation, source preference, dedupe, goal progress, Today tile, Movement screen, tests. | Physical Apple Health import and longer-term trends. |
| Active energy | `IMPLEMENTED_NOT_PHYSICALLY_VALIDATED` | Apple Health kcal mapping, aggregation, Movement/Workouts display, strain contribution when source-labeled. | Physical import and per-workout attribution. |
| Distance | `IMPLEMENTED_NOT_PHYSICALLY_VALIDATED` | Apple Health walking/running distance mapping and Movement display. | Physical import and route/GPS availability. |
| Workouts | `PARTIAL` | HealthKit workout duration mapping, summary surface, active energy/distance metadata. | Workout history/detail models, HR zones per workout, wearable workout detection. |
| Recovery | `IMPLEMENTED_VALIDATED` for base score | Original score uses HRV, RHR, sleep, respiratory rate, temperature delta when available. | Trends, category bands, recent-strain/cycle/SpO2 contributors. |
| Strain | `IMPLEMENTED_VALIDATED` for base score | Original 0-21 score uses HR load, zone minutes, active minutes, and valid movement source. | Personalized target, strength/muscular load, recent balance. |
| Sleep | `PARTIAL` | HealthKit sleep category duration mapping and existing Sleep screen missing-state behavior. | Stages, naps, efficiency, planner, consistency, full session model. |
| Heart/body signals | `PARTIAL` | HealthKit mapping for HR, RHR, HRV SDNN, respiratory rate, SpO2, body/wrist temperature, VO2. | Physical per-type import, trends, baseline comparisons. |
| Source labels | `IMPLEMENTED_VALIDATED` | Apple Health/wearable/manual/calculated labels are in models and UI. | More detailed source provenance per chart. |
| Confidence labels | `IMPLEMENTED_VALIDATED` | Movement, scoring, and signal UI expose confidence. | Confidence should be refined with stale-data and conflict handling. |
| Missing-data CTAs | `IMPLEMENTED_VALIDATED` | Today, Movement, Heart, Sleep, Recovery use Apple Health/wearable/baseline CTAs. | CTA routing should deepen into setup flows. |

## Non-Fake Metric Rules Preserved

- No steps are derived from raw wearable accelerometer/IMU packets.
- Movement contributes to strain only when the movement source has usable confidence.
- HRV is not computed from BPM-only data.
- SpO2 from Apple Health is supported as imported data; uncalibrated wearable PPG remains non-production.
- Sleep stages are not shown unless imported or decoded from a reliable measured source.
- Medical diagnosis and treatment claims remain out of app copy.

## Physical Validation Required

- Apple Health permission screen and per-type authorization on iPhone.
- Real HealthKit import for steps, active energy, distance, workouts, sleep, HR, RHR, HRV, respiratory rate, SpO2, temperature, and VO2 where available.
- Today dashboard update from real imported values.
- No cloud upload without approval, cloud consent, and health-data consent.
- BLE/wearable step support remains unproven; no wearable steps are emitted until a reliable step packet or algorithm is validated.
