# Whoordan Full App Approval Gate

Last updated: 2026-05-11

## 1. Approval Model

Whoordan now treats admin approval as the outermost app gate. A signed-in Supabase user must have `public.user_access.approval_status = 'approved'` before any app feature unlocks.

Allowed statuses:

- `pending`: signed in, waiting for W4rd2 approval.
- `approved`: app may unlock, subject to the normal Apple Health, BLE, local-only, and cloud-consent settings.
- `rejected`: app remains locked.
- `revoked`: app locks immediately on refresh/foreground and protected work is stopped.
- `missing`, `unknown`, `error`: client-side locked states when the access row cannot be verified.

Approval is not stored in `user_metadata` or `raw_user_meta_data`, because those are not trusted authorization inputs for this app.

## 2. Database Schema

Migration:

- `supabase/migrations/202605110005_whoordan_admin_approval_gate.sql`

Table:

- `public.user_access`
- `user_id uuid primary key references auth.users(id) on delete cascade`
- `email text nullable`
- `approval_status text not null default 'pending'`
- `approved_at timestamptz nullable`
- `approved_by text nullable`
- `rejection_reason text nullable`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

Indexes:

- `user_access_approval_status_idx`
- `user_access_email_lower_idx`

The status check constraint only allows `pending`, `approved`, `rejected`, or `revoked`.

## 3. Trigger / Access Row Creation

The migration creates `public.create_user_access_for_new_auth_user()` as a trigger on `auth.users`.

Behavior:

- Inserts a `pending` access row for every new Supabase Auth user.
- Copies the auth email when available.
- Never auto-approves anyone.
- Uses `security definer` only for the auth trigger path.
- Sets `search_path = ''`.
- Revokes function execution from `public`, `anon`, and `authenticated`.

The Flutter client also has a safe fallback: if a signed-in user has no row, it attempts to insert only its own row with `approval_status = 'pending'`. If that fails, the app remains locked.

## 4. RLS Policy Summary

`public.user_access` has RLS enabled and forced.

Policies:

- Authenticated users can `select` only their own row.
- Authenticated users can `insert` only their own pending row.
- No authenticated `update` policy is present, so users cannot approve themselves or edit approval fields.
- No authenticated `delete` policy is present.

Manual admin approval is done in Supabase Dashboard for now. The mobile app has no admin update RPC and no service-role key.

## 5. Protected Table Policy Pattern

The migration replaces protected user-data table policies so access requires both ownership and approval:

```sql
(select auth.uid()) is not null
and (select auth.uid()) = user_id
and exists (
  select 1
  from public.user_access ua
  where ua.user_id = (select auth.uid())
    and ua.approval_status = 'approved'
)
```

Applied to the current private user-data tables, including profiles, settings, consent records, sync state, health samples, summaries, sleep, workouts, strength data, journal, habits, recovery insights, vibration patterns, alarms, and device diagnostics.

No protected table is intentionally accessible before approval.

## 6. Flutter Approval Gate Behavior

Files:

- `lib/auth/approval_gate.dart`
- `lib/main.dart`
- `lib/auth/auth_controller.dart`

Cold start flow:

1. Restore the secure Supabase session.
2. If no valid session exists, show only sign-in/sign-up/password reset.
3. If a session exists, fetch `user_access`.
4. Show an approval-check loading screen while checking.
5. Unlock `MainShell` only when status is `approved`.
6. Show a locked screen for `pending`, `rejected`, `revoked`, `missing`, `unknown`, or `error`.

The root router no longer renders `MainShell` directly for signed-in users. It routes signed-in users through the approval state first, so cached dashboard data and protected tabs are hidden while approval is uncertain or denied.

## 7. Local Mode Approval Policy

Local-only mode no longer bypasses approval.

Current behavior:

- Signed-out users only see auth screens.
- Signed-in users must be approved before accessing local-only mode.
- Approved users can choose local-only mode from Settings.
- Local-only mode still blocks cloud upload.
- If approval is later revoked, local-only dashboard and cached health views are hidden by the root gate.
- Local health data is not silently deleted on revocation or sign-out.

## 8. Revocation Behavior

On foreground, the lifecycle coordinator refreshes approval before protected work.

If status changes away from `approved`:

- The root gate stops rendering protected screens.
- Cloud sync is canceled.
- Background scheduling is stopped.
- Local BLE capture is stopped.
- BLE disconnect is requested.
- Apple Health import/write paths return without doing protected work.

## 9. Cloud Sync Gating

Cloud sync can run only when all are true:

- Supabase session is valid.
- Admin approval is `approved`.
- Cloud sync mode is enabled.
- Explicit cloud-sync consent is granted.

`LocalCloudModeGuard.canCallCloud()` now requires `adminApproved`. `CloudSyncEngine`, `CloudSyncJobCoordinator`, migration preview/upload, manual Sync Now, and headless background sync all pass approval state before upload.

Admin approval does not enable cloud sync or migrate health data by itself.

## 10. Apple Health / BLE Gating

Apple Health:

- `HealthKitController` blocks refresh, permission request, import, and write paths until approved.
- Apple Health permission remains independent after approval.
- Existing iOS permissions do not unlock imports while approval is revoked.

BLE / wearable:

- `WearableBleService` blocks scan, pairing, reconnect, vibration preview, and catch-up requests until approved.
- `MainShell` is only created after approval.
- Lifecycle foreground/reconnect paths check approval before BLE processing.

## 11. Manual Supabase Approval Steps

1. Open the Supabase Dashboard for the Whoordan project.
2. Open Table Editor.
3. Open `public.user_access`.
4. Find the row by `email` or `user_id`.
5. Set `approval_status` to `approved`.
6. Set `approved_at` to the current timestamp.
7. Optionally set `approved_by` to `W4rd2`.
8. Save the row.
9. Ask the user to tap `Refresh Status` or foreground the app.

## 12. Reject / Revoke

Reject:

- Set `approval_status = 'rejected'`.
- Optionally set `rejection_reason`.

Revoke:

- Set `approval_status = 'revoked'`.
- Optionally set `rejection_reason`.

The next approval refresh locks the app and stops protected work.

## 13. Security Warnings

- Do not put a Supabase service-role key in Flutter, iOS, Android, docs, or local runtime config.
- Do not build mobile admin approval controls without a server-side admin authorization design.
- Do not trust user-editable metadata for approval.
- Do not weaken cloud-sync consent checks after approval.
- Do not use Apple Health for settings, vibration, alarm, notification, or device configuration.

## 14. Tests And Validation Results

Tests added or updated:

- `test/approval_gate_test.dart`
- `test/supabase_schema_test.dart`
- `test/local_mode_test.dart`
- `test/cloud_sync_engine_test.dart`
- `test/cloud_sync_coordinator_test.dart`
- `test/privacy_sync_test.dart`
- `test/healthkit_test.dart`
- `test/ble_processing_test.dart`
- `test/journal_habit_test.dart`

Validation results are recorded in the final response for the implementation run.

Validation performed on 2026-05-11:

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 142 tests.
- `flutter test test/supabase_schema_test.dart test/approval_gate_test.dart`: passed, 19 tests.
- `flutter build ios --no-codesign`: passed.
- `flutter build apk`: not run successfully because no Android SDK was available in the local environment.
- Supabase migrations `202605110005_whoordan_admin_approval_gate.sql` and `202605110006_whoordan_strength_fk_index.sql` were applied to the configured Supabase project.
- Supabase security advisors still report leaked password protection disabled, which must be enabled manually in Supabase Auth settings.
- Supabase performance advisors no longer report the unindexed `strength_workouts` foreign key after the follow-up index migration. Fresh-table unused-index INFO notices remain.

## 15. Known Limitations

- Manual approval currently depends on Supabase Dashboard.
- There is no mobile admin dashboard by design.
- There is no server-side admin API yet.
- Real two-user RLS probes still require testing with two real auth users in the Supabase dev project.
- Physical HealthKit and BLE validation still requires real iPhone/Android/wearable testing.

## 16. Future Optional Admin Dashboard Design

A future admin dashboard should be server-side or web-only, authenticated separately, and authorized through non-user-editable admin claims or a private admin table. It should never expose service-role keys to the mobile app. It should audit who changed approval status, when, and why.
