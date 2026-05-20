# Whoordan Local-First Sync Architecture

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`

## Summary

Whoordan now routes HealthKit imports and safe wearable-derived samples through a local-first ingestion pipeline. The app writes normalized records to local storage first, recalculates local aggregates from the local store, and only then queues allowed downstream work.

This pass improves the previous placeholder storage, but it is not a final encrypted health database. The current implementation uses a file-backed JSON store in Application Support with iOS file protection. It is durable across app launches and test-covered, but it is not SQLite/SwiftData and does not provide full database encryption, indexing, migrations, or large-dataset performance guarantees.

## Required Data Flow

```text
Wearable BLE / HealthKit / manual input
-> approval and consent checks
-> normalize input
-> stable dedupe key
-> durable local storage
-> update local aggregates
-> recalculate derived metrics
-> queue Supabase upload if allowed
-> queue Apple Health write if supported and authorized
-> UI reads from local store
```

## Current Implementation

- `FileProtectedLocalStore` persists app-owned health records, summaries, sleep sessions, workouts, journal entries, vibration patterns, checkpoints, and sync queues to `Library/Application Support/WhoordanLocalStore/local_store.json`.
- The store applies `.completeUnlessOpen` file protection on iOS when the file is written.
- `HealthIngestionPipeline` is the local-first write path for HealthKit imports, wearable samples, and future manual samples.
- `AppEnvironment.refreshHealthKitSamples()` imports HealthKit incrementally, ingests locally first, and saves HealthKit checkpoints only after local write succeeds or when there were no samples to persist.
- `AppEnvironment.ingestWearableSamples(_:)` persists safe BLE-derived samples locally before they affect aggregates or sync.
- `AppEnvironment.syncHealthDataNow()` repairs and drains the durable Supabase queue only when signed in, approved, cloud sync consent is enabled, and health-data sync consent is enabled.

## Locally Stored Types

- `HealthSample` via `LocalHealthRecord`
- `DailyHealthSummary`
- `SleepSession`
- `WorkoutSession`
- `JournalEntry`
- `VibrationPattern`
- `HealthKitCheckpoint`
- `BLECheckpoint`
- `SupabaseSyncQueueItem`
- `AppleHealthWriteQueueItem`
- `ConsentState`

Planned but still partial or scaffolded:

- `SleepStageSegment`
- `WorkoutHeartRateZoneSummary`
- `StrengthWorkout`
- `StrengthSet`
- `HabitLog`
- `HabitInsight`
- `DeviceDiagnostics` as durable history
- `DerivedMetric` as a queryable persisted model

## Supabase Queue Eligibility

Queue creation and upload execution are intentionally separate gates.

Records can create pending Supabase queue items only after local persistence succeeds and all queue eligibility gates pass:

- signed in with a known local account/user ID
- cloud sync consent enabled
- health-data sync consent enabled for health records
- local-only mode disabled
- record type is cloud-sync eligible
- approval is fresh `approved`, or bounded `offline_approved` from a recent cached approved verification on this device

Records must not create queue items when the account identity is missing, cloud consent is off, health-data sync consent is off for health records, local-only mode is enabled, approval is stale/missing/pending/rejected/revoked, or the record type is local-only.

Queued health sample uploads include the account user ID, stable local IDs, dedupe keys, source labels, units, local-day keys, confidence labels, retry state, and local write timestamps. Upload payloads continue to hash sensitive source identifiers before leaving the device.

## Supabase Upload Execution

Pending queue items may upload only when all upload execution gates pass:

- network is online
- session is valid or refreshed
- current approval is freshly verified online as `approved`
- cloud sync consent is enabled
- health-data sync consent is enabled for health queue items
- local-only mode is disabled

`offline_approved` blocks upload/drain. It does not block creation of eligible pending queue items. When the network returns, Whoordan refreshes the session if needed, verifies approval online, transitions to `approved`, and then drains pending items idempotently. Checkpoints and sync status update only after successful local persistence and successful upload work.

## Apple Health Write Eligibility

Apple Health writes are intentionally narrow. Current supported write candidate:

- manual Whoordan workout samples where HealthKit write sync is enabled and write authorization exists

Do not write:

- recovery score
- strain score
- vibration settings
- device diagnostics
- Supabase sync records
- unsupported wearable-private fields
- HealthKit-imported samples echoed back into HealthKit

Current limitation: the store and `HealthKitService.writeSamples(_:)` support the queue/write model for supported workout samples, but there is not yet a complete user-facing manual workout workflow and queue-drain UI. This remains partial.

## Display-Only Or Derived Data

The following stay local and source-labeled; they are not written to Apple Health:

- recovery/readiness
- strain/activity load
- stress signals
- sleep debt/need/planner values
- wearable IMU diagnostic summaries
- BLE diagnostics
- haptic preview diagnostics
- unsupported optical/PPG estimates

## Approval And Consent Gates

- Auth screens may appear before approval.
- HealthKit import, BLE scanning/processing, haptic preview, dashboard data, local mode, settings tools, background work, and cloud sync remain blocked before approval.
- Revoked or unapproved status hides protected local state and stops BLE/haptics.
- Cloud sync requires approval plus cloud consent plus health-data consent.
- HealthKit write sync requires approval plus Apple Health consent plus write authorization.
- Offline local access is allowed only through the bounded `offline_approved`
  state after a recent approved verification on this device. This state unlocks
  local data and local device services. It also allows consented eligible
  records to create pending sync queue items so offline-created data is not
  dropped. Supabase queue draining/upload execution remains blocked until online
  approval is verified again.

## Background Sync Limits

- HealthKit background delivery is registered with `HKObserverQuery` for supported types after approval and Apple Health consent.
- Observer events trigger incremental import, local persistence, then allowed queue draining.
- `BGAppRefreshTask` is registered for bounded queue/catch-up work.
- iOS does not guarantee continuous execution or real-time background delivery.
- Continuous background BLE is not guaranteed; Whoordan relies on foreground reconnect, CoreBluetooth state restoration where supported, and safe stop/disable behavior.

## Current Gaps

- Replace file-backed JSON with SQLite/SwiftData or another indexed store.
- Add full database encryption or documented SQLCipher-style design if adopted.
- Add migrations and account-scoped local storage partitioning.
- Add full local export/delete/account deletion workflows.
- Complete Apple Health write queue draining for user-created workouts.
- Add conflict UI and live two-user RLS probe for Supabase.
- Physically validate HealthKit import, BLE sample persistence, and vibration on the iPhone/wearable.
- Implement the generic settings/alarm/vibration Supabase uploader. Those
  records now receive consent-aware local sync status, but only health sample
  queue draining is implemented end to end in this pass.
# 2026-05-12 Device-First Sleep and Movement Note

The Swift app keeps the local-first pipeline:

Wearable BLE / HealthKit / manual input -> approval and consent checks ->
normalization -> stable dedupe key -> durable local JSON store -> daily
aggregation -> optional Supabase queue -> optional Apple Health write queue.

The current storage remains file-backed JSON protected with iOS file protection.
That is acceptable for this pass. An encrypted indexed store remains a future
upgrade for larger history and richer query needs.

Sleep and movement now flow through the existing local-first APIs. HealthKit and
wearable samples are stored locally before summaries update. Supabase upload
queueing still requires approval plus cloud sync consent plus health-data cloud
consent. Apple Health write queueing remains narrow and supports only
user-created manual workout samples.
