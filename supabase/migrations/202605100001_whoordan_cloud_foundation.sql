create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  email text,
  display_name text,
  email_verified boolean not null default false,
  publisher text not null default 'W4rd2',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  metric_units boolean not null default true,
  apple_health_enabled boolean not null default false,
  health_cloud_sync_enabled boolean not null default false,
  local_to_cloud_migration_state text not null default 'not_started'
    check (local_to_cloud_migration_state in ('not_started', 'prepared', 'running', 'completed', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('cloud_sync', 'apple_health')),
  decision text not null check (decision in ('granted', 'denied', 'revoked')),
  policy_version text not null default 'cloud-v1',
  recorded_at timestamptz not null default now(),
  note text,
  dedupe_key text not null,
  sync_status text not null default 'synced'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create table if not exists public.sync_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  health_cloud_sync_enabled boolean not null default false,
  migration_prepared boolean not null default false,
  upload_allowed boolean not null default false,
  pending_records integer not null default 0 check (pending_records >= 0),
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  sync_cursor jsonb not null default '{}'::jsonb,
  sync_status text not null default 'idle'
    check (sync_status in ('idle', 'pending', 'running', 'synced', 'failed', 'conflict', 'blocked')),
  sync_version integer not null default 1,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.health_samples (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sample_type text not null,
  value double precision not null,
  unit text not null,
  sampled_at timestamptz not null,
  source text not null,
  source_record_id text,
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create table if not exists public.daily_health_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  summary_date date not null,
  recovery_score double precision,
  sleep_seconds integer,
  strain double precision,
  confidence double precision not null default 0 check (confidence >= 0 and confidence <= 1),
  source text not null default 'whoordan',
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, summary_date),
  unique (user_id, dedupe_key)
);

create table if not exists public.sleep_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  total_seconds integer,
  deep_seconds integer,
  rem_seconds integer,
  light_seconds integer,
  awake_seconds integer,
  efficiency double precision,
  source text not null,
  stages jsonb not null default '[]'::jsonb,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  activity_type text not null,
  duration_seconds integer,
  energy_kcal double precision,
  avg_heart_rate double precision,
  source text not null,
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id),
  unique (user_id, dedupe_key)
);

create table if not exists public.strength_workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid,
  started_at timestamptz not null,
  ended_at timestamptz,
  title text,
  source text not null default 'whoordan',
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (user_id, workout_id)
    references public.workouts(user_id, id) on delete cascade,
  unique (user_id, id),
  unique (user_id, dedupe_key)
);

create table if not exists public.strength_sets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  strength_workout_id uuid not null,
  exercise_name text not null,
  set_index integer not null default 1,
  reps integer,
  weight_kg double precision,
  effort_rating double precision,
  source text not null default 'whoordan',
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (user_id, strength_workout_id)
    references public.strength_workouts(user_id, id) on delete cascade,
  unique (user_id, dedupe_key)
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  title text,
  body text,
  tags text[] not null default '{}'::text[],
  mood_label text,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_key text not null,
  logged_on date not null,
  value text not null default 'done',
  note text,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, habit_key, logged_on),
  unique (user_id, dedupe_key)
);

create table if not exists public.recovery_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  insight_date date not null,
  insight_type text not null,
  title text not null,
  body text not null,
  confidence double precision not null default 0 check (confidence >= 0 and confidence <= 1),
  source text not null default 'whoordan',
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create index if not exists user_profiles_user_id_idx on public.user_profiles(user_id);
create index if not exists user_settings_user_id_idx on public.user_settings(user_id);
create index if not exists consent_records_user_scope_idx on public.consent_records(user_id, scope, recorded_at desc);
create index if not exists sync_states_user_id_idx on public.sync_states(user_id);
create index if not exists health_samples_user_time_idx on public.health_samples(user_id, sample_type, sampled_at desc);
create index if not exists health_samples_user_sync_idx on public.health_samples(user_id, sync_status);
create index if not exists daily_summaries_user_date_idx on public.daily_health_summaries(user_id, summary_date desc);
create index if not exists sleep_sessions_user_start_idx on public.sleep_sessions(user_id, started_at desc);
create index if not exists workouts_user_start_idx on public.workouts(user_id, started_at desc);
create index if not exists strength_workouts_user_start_idx on public.strength_workouts(user_id, started_at desc);
create index if not exists strength_sets_user_workout_idx on public.strength_sets(user_id, strength_workout_id);
create index if not exists journal_entries_user_date_idx on public.journal_entries(user_id, entry_date desc);
create index if not exists habit_logs_user_date_idx on public.habit_logs(user_id, logged_on desc);
create index if not exists recovery_insights_user_date_idx on public.recovery_insights(user_id, insight_date desc);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'user_profiles',
    'user_settings',
    'consent_records',
    'sync_states',
    'health_samples',
    'daily_health_summaries',
    'sleep_sessions',
    'workouts',
    'strength_workouts',
    'strength_sets',
    'journal_entries',
    'habit_logs',
    'recovery_insights'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format(
      'drop trigger if exists %I on public.%I',
      'set_' || table_name || '_updated_at',
      table_name
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'set_' || table_name || '_updated_at',
      table_name
    );
  end loop;
end $$;

create policy "user_profiles_select_own" on public.user_profiles
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "user_profiles_insert_own" on public.user_profiles
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "user_profiles_update_own" on public.user_profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "user_settings_select_own" on public.user_settings
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "user_settings_insert_own" on public.user_settings
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "user_settings_update_own" on public.user_settings
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "consent_records_select_own" on public.consent_records
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "consent_records_insert_own" on public.consent_records
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "consent_records_update_own" on public.consent_records
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "sync_states_select_own" on public.sync_states
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "sync_states_insert_own" on public.sync_states
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "sync_states_update_own" on public.sync_states
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "health_samples_select_own" on public.health_samples
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "health_samples_insert_own" on public.health_samples
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "health_samples_update_own" on public.health_samples
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "health_samples_delete_own" on public.health_samples
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "daily_health_summaries_select_own" on public.daily_health_summaries
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "daily_health_summaries_insert_own" on public.daily_health_summaries
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "daily_health_summaries_update_own" on public.daily_health_summaries
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "daily_health_summaries_delete_own" on public.daily_health_summaries
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "sleep_sessions_select_own" on public.sleep_sessions
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "sleep_sessions_insert_own" on public.sleep_sessions
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "sleep_sessions_update_own" on public.sleep_sessions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "sleep_sessions_delete_own" on public.sleep_sessions
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "workouts_select_own" on public.workouts
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "workouts_insert_own" on public.workouts
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "workouts_update_own" on public.workouts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "workouts_delete_own" on public.workouts
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "strength_workouts_select_own" on public.strength_workouts
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "strength_workouts_insert_own" on public.strength_workouts
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "strength_workouts_update_own" on public.strength_workouts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "strength_workouts_delete_own" on public.strength_workouts
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "strength_sets_select_own" on public.strength_sets
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "strength_sets_insert_own" on public.strength_sets
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "strength_sets_update_own" on public.strength_sets
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "strength_sets_delete_own" on public.strength_sets
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "journal_entries_select_own" on public.journal_entries
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "journal_entries_insert_own" on public.journal_entries
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "journal_entries_update_own" on public.journal_entries
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "journal_entries_delete_own" on public.journal_entries
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "habit_logs_select_own" on public.habit_logs
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "habit_logs_insert_own" on public.habit_logs
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "habit_logs_update_own" on public.habit_logs
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "habit_logs_delete_own" on public.habit_logs
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "recovery_insights_select_own" on public.recovery_insights
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "recovery_insights_insert_own" on public.recovery_insights
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
create policy "recovery_insights_update_own" on public.recovery_insights
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "recovery_insights_delete_own" on public.recovery_insights
  for delete to authenticated
  using ((select auth.uid()) = user_id);
