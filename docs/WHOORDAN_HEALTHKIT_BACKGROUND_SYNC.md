# Whoordan HealthKit Background Sync

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`

## Status

Implemented in code and simulator/unit validated where practical, but not physically validated with real HealthKit samples in this pass.

## Implemented

- HealthKit stays blocked before admin approval.
- `HealthKitService.importIncremental(checkpoints:fallbackStart:fallbackEnd:)` runs anchored queries for supported HealthKit types.
- Anchors are serialized into `HealthKitCheckpoint` records and saved locally only after local persistence succeeds.
- Duplicate HealthKit samples are deduped by stable source IDs and local dedupe keys.
- `HealthKitService.registerBackgroundDelivery(_:)` registers `HKObserverQuery` observers and enables background delivery for supported sample types.
- `AppEnvironment` registers observers after approval and Apple Health consent, and reruns catch-up work on launch/foreground/background refresh.

## Supported Read Types

- heart rate
- resting heart rate
- HRV SDNN
- respiratory rate
- sleep analysis
- steps
- active energy
- walking/running distance
- oxygen saturation
- body/wrist temperature where available
- workouts
- VO2/cardio fitness where available

## Checkpoint Rule

HealthKit checkpoints must advance only after local persistence succeeds. If local persistence fails, anchors are not saved and the next incremental run can retry.

## Background Limitations

- iOS controls when HealthKit observer callbacks are delivered.
- Background delivery is not real-time.
- The app must register observers again on launch.
- Background work still checks approval and consent before processing.
- Cloud upload is never triggered from background work unless approval, cloud consent, and health-data consent all pass.

## Apple Health Writes

Current write support is intentionally narrow:

- supported: user-created/manual workouts where HealthKit write authorization exists
- unsupported: recovery, strain, diagnostics, vibration settings, private wearable fields, and imported HealthKit samples echoed back to HealthKit

Current limitation: queueing and service write support exist, but full user-facing workout creation plus queue drain flow remains partial.

## Tests

- Local-first ingestion tests cover local write-before-queue behavior.
- Store tests cover HealthKit checkpoint persistence.
- Existing HealthKit mapping tests cover units/source labels/dedupe behavior.
- Physical HealthKit permission/import/background callback validation remains pending.
