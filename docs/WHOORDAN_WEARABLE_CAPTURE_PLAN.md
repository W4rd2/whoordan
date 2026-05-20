# Whoordan Wearable Capture Plan

Date: 2026-05-12
Branch: `swift-app`

## Privacy Rules

- Keep raw captures local and outside the repository.
- Do not paste raw payloads, private rows, notes, timestamps, device identifiers, or health values into chat, docs, tests, or commits.
- Commit only minimized/sanitized fixtures that preserve packet shape.
- Use aggregate-only reports: packet counts, packet families, validation status, and coverage.

## Capture A: Post-Wake Sleep

- Capture immediately after waking.
- Connect Whoordan to the wearable and request historical sync.
- Keep command responses, metadata, historical packets, realtime packets, and ACK flow.
- Look for sleep-session, stage-segment, and recovery-input records.
- Expected result if successful: wearable sleep session and stages can become primary source. If absent, keep Apple Health fallback.

## Capture B: Nap

- Take a known nap.
- Capture immediately after waking and requesting historical sync.
- Look for nap records or short sleep sessions with explicit wearable source semantics.
- Do not infer naps from HR or motion-only packets.

## Capture C: All-Day Activity and Steps

- Wear the device through a normal day.
- Record a before-walk and after-walk sync window.
- Look for step-count, movement-minute, activity-summary, calories, or load packets.
- Do not derive steps from accelerometer/gyro until a validated step algorithm exists.

## Capture D: Workout

- Capture before, during, and after a short workout.
- Look for workout start/end, HR-zone, active-energy, activity-summary, and strain/load packets.
- Compare only aggregate trends against private exports; do not clone proprietary formulas.

## Capture E: Device Events

- Capture battery-level, charging start/stop, wrist on/off, haptic fired/terminated, double tap, and temperature events.
- Validate event payload units and sensor meaning before surfacing as production metrics.

## Capture F: Optical / PPG

- Capture R21 packets during stable optical lock.
- Inspect whether true RR/IBI or validated peak intervals are exposed.
- Do not produce HRV or SpO2 from raw optical channels without validation.

## Acceptance Criteria

- A new decoder is added only after packet family, timestamp, units, source semantics, and dedupe key are understood.
- Normalized data writes locally first.
- Supabase upload remains approval and consent gated.
- HealthKit writes remain limited to supported user-created sample types.
- UI shows source and confidence labels.

## Current Priority Queue

Continue capture sessions in this order:

1. Post-wake historical sync to search for wearable sleep, stage, nap, HRV,
   respiratory, and temperature records.
2. Post-nap historical sync to determine whether naps appear as explicit
   device records or remain Apple Health fallback only.
3. Walking with a known external step count to identify explicit step/activity
   packets without deriving fake steps from IMU.
4. Workout before/during/after capture to search for workout summaries, HR-zone
   load, active energy, and activity records.
5. Haptic, alarm, and double-tap capture to validate haptic fired/terminated,
   alarm, and event routing records.
6. Charging and wrist on/off capture to validate device-state event semantics.

After enough new wearable captures and additional export rows exist, rerun the
relationship analysis and compare recovery trend correlation, recovery bucket
agreement, sleep duration/efficiency agreement, strain trend correlation,
workout ranking, and source-specific confidence.
