# Whoordan Supabase Security Validation

Updated: 2026-05-11

## Scope

This validation covers the remaining Supabase advisor findings from the Whoordan
audit:

- `public.set_updated_at()` function search-path hardening
- `public.rls_auto_enable()` public executable helper hardening
- user-data table RLS enforcement
- owner-scoped RLS policies
- leaked password protection dashboard setting
- two-user RLS probe instructions

Client-side local-only mode, cloud-consent gating, and mobile Supabase client
configuration were not weakened. No service-role key was added to client code.

## SQL Changes Made

### `202605110003_whoordan_supabase_security_advisor_hardening.sql`

- Recreated `public.set_updated_at()` with an explicit `set search_path = public`.
- If `public.rls_auto_enable()` exists in a live project:
  - revoked function execution from `public`, `anon`, and `authenticated`
  - set the helper function search path to `pg_catalog`
  - added an explanatory comment
- Enabled and forced RLS on all known Whoordan user-data tables when present:
  - `user_profiles`
  - `user_settings`
  - `consent_records`
  - `sync_states`
  - `health_samples`
  - `daily_health_summaries`
  - `sleep_sessions`
  - `workouts`
  - `strength_workouts`
  - `strength_sets`
  - `journal_entries`
  - `habit_logs`
  - `recovery_insights`
  - `vibration_patterns`
  - `wearable_alarms`
  - `device_diagnostics`
- Recreated `consent_records_update_own` with owner-scoped `using` and
  `with check` clauses.
- Kept sync status support for the local blocked state.
- Preserved same-user ownership checks for strength child records through
  composite user/record foreign keys.

### `202605110004_whoordan_function_execute_privileges.sql`

- Revoked `execute` on `public.set_updated_at()` from `public`, `anon`, and
  `authenticated`.
- Revoked `execute` on `public.rls_auto_enable()` from `public`, `anon`, and
  `authenticated` when the helper exists.

## Policies Verified

Live project validation showed all 16 known Whoordan user-data tables have:

- RLS enabled
- RLS forced
- owner-scoped `select`, `insert`, `update`, and `delete` policies
- authenticated-role policies using `auth.uid()` ownership checks

Policy expectations:

- users can access only rows where `user_id` matches their authenticated user id
- inserts and updates require the submitted `user_id` to match the authenticated user id
- unauthenticated requests receive no private rows
- no client path requires or uses a service-role key

## Advisor Findings Addressed

Addressed by SQL migration:

- `public.set_updated_at()` mutable or missing function search path
- executable `public.rls_auto_enable()` helper warnings for API roles
- missing live `consent_records_update_own` policy
- RLS enforcement consistency across Whoordan user-data tables

Still manual:

- leaked password protection is disabled in Supabase Auth settings

After applying the SQL hardening migrations, the live Supabase security advisor
reported only `auth_leaked_password_protection`.

## Manual Supabase Dashboard Steps

Leaked password protection is configured in the Supabase dashboard, not in the
project SQL migrations.

1. Open the Supabase dashboard for the target project.
2. Go to Authentication settings.
3. Open the password security or password protection settings.
4. Enable leaked password protection.
5. Save the setting.
6. Re-run the Supabase security advisor.

Reference:

- Supabase Auth password security documentation:
  https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Two-User RLS Probe

Script:

```bash
scripts/supabase/two_user_rls_probe.sh
```

Required setup:

- Create two normal email/password test users in the target Supabase project.
- Do not use a service-role key for this probe.
- Use the public publishable or anon key.

Environment:

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="<public publishable or anon key>"
export RLS_PROBE_USER_A_EMAIL="user-a@example.com"
export RLS_PROBE_USER_A_PASSWORD="<password>"
export RLS_PROBE_USER_B_EMAIL="user-b@example.com"
export RLS_PROBE_USER_B_PASSWORD="<password>"
```

Run:

```bash
bash scripts/supabase/two_user_rls_probe.sh
```

The probe verifies:

- user A can write and read an owned row
- user B can write and read an owned row
- user A cannot read user B's row
- user A cannot update user B's row
- user A cannot delete user B's row
- user B's row remains accessible to user B after cross-user attempts
- unauthenticated requests cannot read private rows

The probe signs users in through the public Auth endpoint, decodes only the JWT
subject locally, avoids printing tokens, and cleans up rows using each user's
own access token.

## Validation Results

Supabase MCP project URL:

- `https://ellpqzniahggdlvhfefb.supabase.co`

Live migrations applied through the Supabase MCP migration tool:

- `whoordan_supabase_security_advisor_hardening`
- `whoordan_function_execute_privileges`

Live function privilege validation:

- `public.set_updated_at()`
  - `security_definer`: false
  - `search_path`: `public`
  - executable by `public`: false
  - executable by `anon`: false
  - executable by `authenticated`: false
- `public.rls_auto_enable()`
  - `security_definer`: true
  - `search_path`: `pg_catalog`
  - executable by `public`: false
  - executable by `anon`: false
  - executable by `authenticated`: false

Live RLS validation:

- all 16 known Whoordan user-data tables have RLS enabled and forced
- all 16 have owner-scoped CRUD policies

Local static validation added:

- `test/supabase_schema_test.dart` now checks that helper functions are revoked
  from `public`, `anon`, and `authenticated`.

Probe status:

- `scripts/supabase/two_user_rls_probe.sh` was created.
- The probe was not executed in this session because two disposable
  email/password test users were not available in the prompt or environment.

Dev branch status:

- Supabase MCP branch listing was unavailable in this session with:
  `Project reference is missing when validating permissions`.
- The migrations were applied to the Supabase project exposed by the active MCP
  session. For production release, repeat the same migrations against a Supabase
  development branch or disposable dev project first if this MCP project is not
  already the intended development target.

## Notes

- Leaked password protection must be enabled manually in Supabase Auth settings.
- Do not expose helper functions in the public API role surface.
- Keep future user-data policies scoped to `authenticated` and owner checks based
  on `auth.uid()`.
- Keep service-role keys out of mobile code, docs examples used by clients, and
  repository configuration.
