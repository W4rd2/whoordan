# Whoordan Large Packet Capture Plan

Date: 2026-05-12
Branch: `swift-app`

## Goal

Collect enough real wearable BLE traffic to determine which Whoordan features
are directly sent by the device, which packet families can be decoded, which
metrics can be safely derived from raw streams, and which features require Apple
Health fallback or must remain unavailable.

Raw capture files stay local and private. Reports should use aggregate counts,
packet families, sanitized field summaries, and redacted identifiers only.

## Capture Rules

- Start capture only after approval.
- Keep cloud sync consent separate; raw captures are never uploaded.
- Do not paste raw base64 payloads into docs or chat.
- Redact or fingerprint identifiers.
- Label every capture scenario before starting.
- Capture enough packets to observe repeated patterns.
- Stop capture when the scenario ends.
- Delete local raw capture files after analysis if no longer needed.

## Scenarios

### 1. Baseline Idle

- Duration: 5-10 minutes.
- Wearable: on wrist.
- App: foreground, connected, realtime enabled after historical sync.
- Goal: establish packet frequency and low-motion HR/IMU/PPG baseline.

### 2. Walking

- Duration: 10-20 minutes.
- Capture realtime during walking.
- Request/allow historical sync after walking.
- Goal: identify step/activity/movement packet candidates and IMU patterns.

### 3. Running Or Intense Movement

- Duration: 10-20 minutes if feasible.
- Capture realtime plus post-session historical sync.
- Goal: compare packet frequencies and candidate activity/load fields against
  walking and idle.

### 4. Workout

- Capture before, during, and after a short workout.
- If a device or user-started workout mode exists, start and stop it.
- Goal: find workout/activity summary packets and HR-load fields.

### 5. Full-Day Activity

- Wear the device all day.
- Capture a historical sync at end of day.
- Goal: find daily summaries, activity totals, steps, load, calories, or
  workout summaries if exposed.

### 6. Pre-Sleep

- Capture shortly before sleep.
- Goal: compare pre-sleep packets against post-wake packets.

### 7. Overnight Sleep

- Preferred: capture immediately after waking and request historical sync.
- Optional: overnight capture only if battery and privacy constraints are
  acceptable.
- Goal: identify sleep/session/stage/body-signal records.

### 8. Post-Wake

- Start capture immediately after waking.
- Connect wearable and allow historical sync.
- Goal: find sleep-session, sleep-stage, respiratory, temperature, HRV, and
  recovery-input packet families.

### 9. Nap

- Capture before nap and immediately after waking.
- Allow historical sync after nap.
- Goal: determine whether naps are separate records, short sleep sessions, or
  unavailable from current packets.

### 10. Charging

- Capture before placing wearable on charger.
- Capture charge start and charge stop.
- Goal: validate charging events and battery fields.

### 11. Wrist Off / Wrist On

- Capture removal and re-wearing.
- Goal: validate wrist state events and artifact flags.

### 12. Haptic Preview

- Capture before sending built-in haptic.
- Capture command response and event stream.
- Goal: validate haptic fired/terminated events and command ACK behavior.

### 13. Alarm

- Schedule alarm 1-2 minutes ahead.
- Capture trigger, snooze, dismiss, and post-alarm state.
- Goal: validate alarm event types and haptic delivery diagnostics.

### 14. Double Tap

- Double tap wearable several times.
- Goal: validate event type 14 frequency, debouncing, and context routing.

## Analysis Outputs

For each scenario, report only:

- packet count
- characteristic count
- packet type distribution
- frame validity and CRC validity counts
- record-family counts
- timestamp field presence
- command response status counts
- event type counts
- candidate fields and confidence
- safe use or blocked reason

## Next Implementation Criteria

A new decoder can move from research to production only when:

- packet semantics are repeated across scenarios,
- fields correlate with known scenario timing,
- values have plausible units/ranges,
- dedupe keys are stable,
- local persistence works before upload,
- source/confidence labels are clear,
- tests cover the packet family,
- no metric is fabricated from weak evidence.

## Current Run Status

No new real packet captures were performed in this run. The capture tooling and
plan are ready for physical sessions on the approved iPhone with the wearable
connected.

## Next Calibration Run

Prioritize physical captures and benchmark reruns in this order:

1. Post-wake historical sync.
2. Post-nap historical sync.
3. Walking with a known step count.
4. Workout capture.
5. Haptic, alarm, and double-tap capture.
6. Charging and wrist events.

When enough new wearable and export data exists, rerun aggregate-only
relationship analysis for recovery trend correlation, recovery bucket agreement,
sleep duration and efficiency agreement, strain trend correlation, workout
ranking, and source-specific confidence. Do not use the export as a proprietary
formula source.
