# Whoordan Approval Session Restore Fix

Date: 2026-05-12

## Root Cause

The Swift app restored the serialized Supabase session from Keychain and reused
the stored access token for the `public.user_access` approval lookup. After the
app was closed long enough for the access token to expire, approval fetch could
fail and collapse into a generic unavailable approval state. Signing out and
signing in worked because sign-in produced a fresh access token.

## Fix

- Restore now refreshes expired or near-expiry sessions before approval lookup.
- Approval lookup now treats `401` and `403` as token/session problems.
- A `401` or `403` approval response triggers exactly one forced refresh and one
  approval retry.
- A successful refresh persists rotated Supabase tokens back to Keychain and
  rebuilds the authorization header through the token provider.
- Invalid, revoked, or expired refresh tokens produce `auth_expired`.
- Network failures produce `network_unavailable` unless this device has a
  recent cached approved verification that is still inside the offline grace
  window.
- Other approval request failures produce `approval_fetch_failed` or
  `unknown_error`.

## Fail-Closed Behavior

Protected local data, HealthKit import, BLE, vibration, background work, and
cloud sync remain locked unless approval is verified or the device is using the
bounded `offline_approved` local-only state. Cached approval can unlock local
surfaces offline only when all of these are true:

- a signed-in session is still present in Keychain
- the last durable approval status was `approved`
- the last approved verification is no older than 7 days
- the current failure is network/offline, not rejected, revoked, missing, or
  refresh-token invalid

`offline_approved` allows local app data, HealthKit import, BLE, haptics, and
alarms to run from this device while offline. It also allows eligible records to
create pending sync queue items when account identity and explicit consent are
present, so offline-created data is not lost. It does not permit Supabase upload
execution or queue draining; cloud sync resumes only after approval is verified
online again as `approved`.

Queue creation requires a known signed-in user ID, cloud sync consent, health-data
sync consent for health records, local-only mode off, and a cloud-sync eligible
record type. Upload execution requires fresh online `approved`; pending,
rejected, revoked, missing, auth-expired, stale-cache, and fetch-error states do
not drain the queue.

## Retry Behavior

The Refresh Status action reruns session refresh if needed and then approval
fetch. On foreground, the app retries approval verification for signed-in users
and locks immediately if the server now reports pending, rejected, revoked, or
missing.

## Tests

- Expired session refreshes and persists rotated tokens.
- Unexpired session restores without refresh.
- Approval `401` refreshes and retries once.
- Refresh rejection produces `auth_expired`.
- Network failure produces a retryable fail-closed state.
- Expired session restore falls back to the stored local session when token
  refresh cannot reach the network.
- Recent cached approval unlocks local-only offline mode.
- `offline_approved` creates pending health sync queue items when account and
  consent gates allow it.
- `offline_approved` does not upload or drain the pending queue.
- Fresh online approval after offline mode drains pending health samples.
- Revocation after offline mode locks the app and leaves pending queue items
  undrained.
- Stale cached approval remains fail-closed.
- Protected services remain blocked before verified approval.
