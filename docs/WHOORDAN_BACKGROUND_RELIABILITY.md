# Whoordan Background Reliability

This document describes the current session, lifecycle, background sync, and
wearable catch-up strategy. It is implementation documentation, not a privacy
policy.

## Auth and Session Persistence

- Supabase Auth sessions are stored through `SecureSupabaseLocalStorage`, backed
  by `flutter_secure_storage`.
- Access tokens, refresh tokens, auth headers, and session strings are not
  stored in SharedPreferences and must not be logged.
- `AuthController` restores the secure session on launch before showing the
  sign-in screen.
- Expired sessions are refreshed silently through the Supabase client when a
  refresh token is available.
- Refresh failure caused by revoked, expired, or invalid session state clears
  the local secure session and returns the user to sign-in.
- A non-secret `CloudAccountSnapshot` is stored in local storage so the app can
  open in offline mode when the network is unavailable. It contains only user id,
  email, display name, verification state, and timestamp. It does not contain
  tokens.
- Offline launch with a cached account does not attempt cloud writes until the
  session is refreshed or network-triggered sync succeeds.

## Background Sync Strategy

- Cloud sync is coordinated by `CloudSyncJobCoordinator`.
- Sync work is single-flight: a second sync request returns `alreadyRunning`
  instead of starting a duplicate worker.
- Pending sync work is stored in encrypted indexed local storage under
  `whoordan.local.pending_sync_jobs`.
- Sync checkpoints are stored in `SyncState.lastSuccessAt` and `syncCursors`.
- Checkpoints are updated only after successful upload.
- Initial full sync runs until `initialSyncCompleted` is true.
- Incremental sync uploads records changed since the last successful checkpoint.
- Failed jobs remain queued with exponential backoff and retry limits.
- Manual Sync Now, Repair, Re-upload, foreground, background fetch, network
  reconnect, and device reconnect all route through the same coordinator.
- Background scheduling uses `flutter_background_service` where the platform
  allows it. iOS background fetch is short-lived and should finish quickly.

## BLE Background and Catch-Up

- iOS declares `bluetooth-central` background mode.
- Android declares connected-device foreground-service permissions.
- Continuous BLE delivery is platform-limited and cannot be promised.
- On launch, foreground, and reconnect, Whoordan checks the last BLE packet time
  from `DeviceDiagnostics`.
- `WearableReconnectCoordinator` asks the wearable adapter for missing samples
  since the last packet timestamp.
- The current BLE protocol adapter receives historical batches during handshake
  but does not yet expose an arbitrary range backfill request. Unsupported
  backfill is recorded as diagnostics instead of being treated as fetched data.
- Duplicate and out-of-order packets are still handled by stable dedupe keys and
  BLE sample metadata.

## Offline and Cache Behavior

- Local dashboard data is loaded from the existing local repository immediately.
- Network calls do not block startup UI.
- Cloud writes are queued when sync fails.
- Queued writes drain on foreground, network reconnect, manual sync, and
  platform background wake.
- User-facing sync state includes syncing, failed, queued, and last successful
  sync time.

## Retry and Battery Behavior

- Sync retries use exponential backoff capped at five minutes.
- The queue has a retry limit to avoid endless aggressive background work.
- Sync is event-driven: cold start, foreground, background wake, reconnect, and
  manual action.
- The app does not add foreground-only polling for cloud sync.
- BLE scanning remains explicit/user initiated; reconnect uses saved device
  state rather than scanning forever.

## Known Limitations

- Android APK build was not run in this chat because the Android SDK is not
  configured in the local environment.
- Live background execution still needs real-device verification on iOS and
  Android.
- Network reconnect currently uses a passive adapter; a connectivity plugin can
  be connected later without changing the sync coordinator.
- Arbitrary wearable historical range requests need protocol support before the
  app can guarantee exact catch-up windows.
- The local repository cache now uses encrypted indexed SQLite rows. Full
  database-file encryption is still future work; payloads are encrypted but
  index metadata remains plaintext.

## Tested

- Session persists after app restart.
- Valid stored session avoids sign-in.
- Expired token restore path refreshes silently.
- Failed refresh returns to sign-in and clears the cached account snapshot.
- Offline launch with cached account opens the app.
- Initial and incremental cloud sync continue to use checkpoints.
- Failed sync is queued with backoff and retried later.
- Network reconnect drains queued work.
- Duplicate sync workers are prevented.
- Device reconnect requests missing samples from the last BLE packet timestamp.
- Unsupported wearable backfill is recorded honestly.
