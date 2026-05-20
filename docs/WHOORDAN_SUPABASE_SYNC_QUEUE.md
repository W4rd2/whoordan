# Whoordan Supabase Sync Queue

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`

## Status

Implemented as a durable local queue for health sample uploads, with idempotency keys, retry/backoff, repair scan, and consent gates. Live multi-device conflict resolution and live two-user RLS probing remain pending.

## Gate Rules

Whoordan now uses two gates: queue eligibility and upload execution.

Pending queue items can be created when all queue eligibility conditions are true:

- signed in with a known account/user ID
- cloud sync consent enabled
- health-data sync consent enabled for health records
- local-only mode disabled
- record type is cloud-sync eligible
- approval is either fresh `approved` or bounded `offline_approved` from a recent cached approved verification

Pending queue items must not be created without account identity, without required consent, in local-only mode, for local-only record types, or when cached approval is missing, stale, pending, rejected, revoked, or missing.

Upload/drain execution runs only when all upload conditions are true:

- network is online
- session is valid or refreshed
- approval has been freshly verified online as `approved`
- cloud sync consent enabled
- health-data sync consent enabled for health queue items
- local-only mode disabled

`offline_approved` blocks upload/drain but does not block eligible queue creation. Local-only mode never queues or uploads health data.

## Local-First Contract

Health samples are written locally before any upload queue item exists. The queue item references the local health record and its stable dedupe key. If local persistence fails, there is no Supabase upload attempt.

## Queue Fields

Each `SupabaseSyncQueueItem` stores:

- queue ID
- account user ID
- local record ID
- dedupe key
- payload type
- status
- attempt count
- next attempt date
- last error
- created/updated dates
- idempotency key

## Retry And Backoff

Failed uploads remain local and queued. Backoff starts at 60 seconds and doubles per attempt up to one hour. `Repair Sync` scans local unsynced records and adds missing queue items only when a signed-in account identity exists and queue eligibility allows it.

## Upload Shape

The app uploads source-labeled health sample rows through the Supabase REST API using the signed-in user JWT and publishable key configuration. HealthKit source record IDs and dedupe keys are hashed before upload.

## Conflict Handling

Current conflict handling is idempotent upsert by user and dedupe key. Full conflict UI, remote-restore precedence, and multi-device reconciliation remain partial.

## Background Behavior

`BGAppRefreshTask` can drain the queue opportunistically. Foreground catch-up remains the reliable fallback. iOS may defer or skip background refresh based on battery, usage, and system policy.

On launch, foreground refresh, network return, or manual Sync Now, Whoordan refreshes the Supabase session if needed, fetches `public.user_access`, and drains the pending queue only after the approval state becomes fresh online `approved`. If approval becomes revoked, pending, rejected, missing, or auth expired, the app remains locked/fail-closed and the queue stays pending.

## Tests

- upload blocked before approval
- upload blocked without cloud or health-data consent
- queue created only after local write
- queue created during `offline_approved` when account identity and consent allow it
- `offline_approved` blocks queue drain/upload execution
- fresh online approval drains previously queued offline records
- revoked approval after offline mode blocks draining and keeps the queue pending
- stable idempotency key
- retry/backoff after failure
- repair sync queues missing local unsynced records
- local-only mode does not queue or upload

## Remaining Risks

- No live two-user RLS probe was run in this pass.
- Supabase advisor previously reported leaked-password protection disabled.
- Queue persistence currently uses file-backed JSON rather than an indexed encrypted database.
- Settings, alarms, and vibration records have local consent-aware sync status,
  but the generic Supabase uploader for those non-health record types remains
  a future implementation item.
