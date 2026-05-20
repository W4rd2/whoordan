# Whoordan Device-First Source Strategy

Date: 2026-05-12
Branch: `swift-app`

## Policy

Whoordan is device-first when a reliable wearable measurement exists. Apple Health is a trusted fallback and assistant source. Manual entries are explicit user context. Whoordan estimates are labeled. Cloud sync is a backup/copy path, not the measurement source of truth, unless restoring a user-owned synced copy after approval.

Protected health processing stays behind the admin approval gate. Cloud upload still requires approval, cloud consent, and health-data consent.

## 2026-05-11 Local-First Implementation Update

Device-first source selection now runs on top of a local-first persistence path. HealthKit and safe wearable samples are normalized into `HealthSample`, written to `FileProtectedLocalStore`, aggregated from local records, and then queued for Supabase only if approval and consent allow it. Wearable HR remains preferred over Apple Health HR when plausible and fresh. Apple Health remains the fallback for steps, sleep, HRV SDNN, respiratory rate, SpO2, temperature, workouts, distance, and active energy when a reliable wearable source is absent.

Wearable IMU summaries are persisted only as diagnostic movement context and are not converted into steps. Raw PPG is not promoted to production SpO2. BPM-only data is not promoted to HRV.

## Source Priority

1. Wearable BLE direct measurement.
2. Apple Health direct import.
3. User-entered/manual data.
4. Whoordan derived estimate.
5. Cloud synced copy.

## Metric Rules

| Metric | Primary | Fallback | Confidence behavior | Must be unavailable when |
|---|---|---|---|---|
| Heart rate | Wearable BLE direct HR when plausible | Apple Health HR | Direct wearable/Health data is medium to high depending on source/contact; stale values are labeled | No plausible measured HR exists |
| Resting heart rate | Wearable-derived resting source when reliably decoded | Apple Health RHR | Direct RHR only; no live HR substitution | Only live BPM exists, or no RHR source exists |
| HRV | True RR/IBI or measured SDNN | Apple Health HRV SDNN | High for authorized SDNN; unavailable from BPM-only data | Only BPM, PPG without validated interval extraction, or estimate exists |
| Respiratory rate | Wearable decoded respiratory source if validated | Apple Health respiratory rate | Direct measured/imported values only | No validated respiratory signal exists |
| SpO2 | Validated measured source | Apple Health oxygen saturation | Production display requires validated source; raw PPG estimates stay debug/unavailable | Only uncalibrated PPG or estimate exists |
| Skin/wrist/body temperature | Wearable temperature event or validated sensor | Apple Health body/wrist temperature | Baseline context only | No baseline/source exists |
| Sleep duration | Wearable decoded sleep packets if validated | Apple Health sleep analysis | Source-labeled measured minutes | No measured/imported sleep session exists |
| Sleep stages | Wearable decoded stages if validated | Apple Health stages | Stages shown only when source supplies stages | Only duration exists |
| Naps | Wearable nap/session records if validated | Apple Health sleep sessions classified by duration/timing | Verified sleep source only | Only motion or low-HR rest exists |
| Sleep efficiency | Source session with asleep/in-bed data | Apple Health sleep categories | Direct/session-derived | In-bed or asleep data is missing |
| Sleep debt/need | Whoordan estimate from measured sleep history | Export benchmark only for comparison | Labeled estimate, confidence rises with history | Insufficient sleep history |
| Sleep planner | Whoordan estimate from measured sleep history and target wake time | Last wake time when no target is set | Conservative wellness planning copy only | Sleep history is insufficient |
| Recovery | Whoordan original baseline-relative estimate | None | Confidence based on available measured contributors | No source-labeled contributors exist |
| Strain | Wearable HR/activity if validated | Apple Health workouts, steps, active energy | HR-based higher confidence; movement-only low confidence | No source-labeled activity exists |
| Heart-rate zones | Wearable or Apple Health HR plus configured max HR | Labeled age-based fallback if implemented | Lower confidence without configured max HR | No max HR/profile fallback exists |
| Steps | Wearable step count if protocol provides reliable steps | Apple Health steps | High for direct step count; no IMU-only steps | Only raw accelerometer exists |
| Movement minutes | Wearable activity summary if decoded | Apple Health workouts and activity samples | Direct summary preferred; workout fallback labeled | Only raw IMU exists |
| Active energy/calories | Apple Health active energy or validated wearable calorie source | Whoordan estimate if implemented and labeled | Imported/calibrated high; estimates lower | Only unsupported raw signals exist |
| Distance | Apple Health walking/running/workout distance or validated wearable distance | Manual workout distance | Direct imported only | No source distance exists |
| Workouts | Apple Health workouts or validated wearable workout packets | Manual workout logging | Source-labeled workout confidence | No workout source/log exists |
| Strength/muscular load | Manual strength log | Whoordan estimate from sets/reps/weight | Estimated and confidence-labeled | No strength log exists |
| Stress signals | Measured HR/HRV baseline signal | Apple Health/body signals | Physiological wellness context only | No measured HR/HRV baseline exists |
| VO2/cardio fitness | Apple Health VO2/cardio fitness | None | Direct platform value | No authorized platform source exists |
| Menstrual/cycle context | Explicit user consent/import | Apple Health cycle data if consented | Context only | No explicit consent |
| Pregnancy context | User-declared context | None | Context only | Not user-declared |
| Irregular rhythm events | Authorized platform import only | None | Imported event label only | No platform event exists |
| Journal/habit insights | User-entered habits | Private CSV benchmark for mapping tests only | Association language with sample-size confidence | Sample size is too small |
| Battery/charging/wrist diagnostics | Wearable standard GATT, HelloHarvard, or event packets | None | Device-state label only | No device-state packet exists |
| Haptics/vibration | Wearable haptic command response or event packet | None | Device-control status only | No haptic command/event evidence exists |
| Firmware/device diagnostics | Wearable firmware log and metadata packets | None | Diagnostic label only, no raw logs | No diagnostic packet exists |

## 2026-05-12 Packet Discovery Addendum

Current code uses all safe metrics proven by the decoded packet families: direct HR from R10/standard GATT, battery from standard GATT/HelloHarvard/event payloads, charging and wrist events, double-tap, haptic event scaffolds, device temperature event parsing, firmware-log summaries, IMU sample-count diagnostics, and R21 optical presence summaries. R10/R21 summaries require complete packet sizes before claiming full sample counts.

Wearable sleep sessions, stages, naps, reliable steps, activity summaries, workout summaries, respiratory rate, true RR/IBI HRV, production SpO2, and production body/skin temperature remain unavailable until captured and validated. Apple Health remains fallback for sleep, stages, naps, steps, distance, active energy, workouts, HRV SDNN, respiratory rate, SpO2, temperature, VO2, and irregular-rhythm events when authorized.

## Implemented Contract

- `DataSource.deviceFirstRank` makes wearable direct data outrank Apple Health, manual, estimate, and cloud copies.
- `HealthSourceResolver` returns source label, confidence, stale/missing status, selected sample ID, and a safe reason string.
- `MovementAggregator` now prefers reliable wearable step samples over Apple Health and does not derive steps from raw IMU packets.
- `DailyHealthAggregator` aggregates local-day samples with source priority, dedupe, sleep-minute filtering, and confidence selection.

## Explicit Non-Goals

- No third-party formulas are copied.
- No private wearable export score is treated as Whoordan truth.
- No HRV is computed from BPM-only data.
- No production SpO2 is produced from uncalibrated PPG.
- No fake steps are produced from raw accelerometer packets.
- No cloud copy is treated as a primary measurement source.
