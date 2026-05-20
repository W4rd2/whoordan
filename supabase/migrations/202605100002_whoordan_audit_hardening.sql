alter table public.health_samples
  add column if not exists ended_at timestamptz;

create index if not exists health_samples_user_end_idx
  on public.health_samples(user_id, ended_at desc)
  where ended_at is not null;

drop policy if exists "user_profiles_delete_own" on public.user_profiles;
create policy "user_profiles_delete_own" on public.user_profiles
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "user_settings_delete_own" on public.user_settings;
create policy "user_settings_delete_own" on public.user_settings
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "consent_records_delete_own" on public.consent_records;
create policy "consent_records_delete_own" on public.consent_records
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "sync_states_delete_own" on public.sync_states;
create policy "sync_states_delete_own" on public.sync_states
  for delete to authenticated
  using ((select auth.uid()) = user_id);
