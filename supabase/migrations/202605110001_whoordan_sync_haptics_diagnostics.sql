alter table public.user_settings
  add column if not exists sync_preferences jsonb not null default '{}'::jsonb,
  add column if not exists apple_health_preferences jsonb not null default '{}'::jsonb,
  add column if not exists notification_vibration_preferences jsonb not null default '{}'::jsonb,
  add column if not exists call_vibration_settings jsonb not null default '{}'::jsonb,
  add column if not exists ui_preferences jsonb not null default '{}'::jsonb,
  add column if not exists wearable_device_configuration jsonb not null default '{}'::jsonb;

alter table public.sync_states
  add column if not exists initial_sync_completed boolean not null default false,
  add column if not exists conflict_records integer not null default 0 check (conflict_records >= 0);

create table if not exists public.vibration_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pattern_id text not null,
  name text not null,
  kind text not null default 'custom' check (kind in ('built_in', 'custom')),
  segments jsonb not null default '[]'::jsonb,
  repeat_count integer not null default 1 check (repeat_count >= 1 and repeat_count <= 10),
  allow_infinite_for_alarm boolean not null default false,
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
  unique (user_id, pattern_id),
  unique (user_id, dedupe_key)
);

create table if not exists public.wearable_alarms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  alarm_id text not null,
  label text not null,
  hour integer not null check (hour >= 0 and hour <= 23),
  minute integer not null check (minute >= 0 and minute <= 59),
  enabled boolean not null default true,
  pattern_id text not null,
  snooze_minutes integer not null default 9 check (snooze_minutes >= 1 and snooze_minutes <= 60),
  repeat_weekdays integer[] not null default '{}'::integer[],
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
  unique (user_id, alarm_id),
  unique (user_id, dedupe_key)
);

create table if not exists public.device_diagnostics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  connected_device_name text,
  battery_level double precision,
  firmware_version text,
  rssi integer,
  last_ble_packet_at timestamptz,
  last_sync_at timestamptz,
  parsed_sensor_preview jsonb not null default '{}'::jsonb,
  sync_errors text[] not null default '{}'::text[],
  dedupe_key text not null,
  sync_status text not null default 'pending'
    check (sync_status in ('pending', 'synced', 'failed', 'conflict')),
  sync_version integer not null default 1,
  last_synced_at timestamptz,
  sync_error text,
  conflict_key text,
  conflict_status text not null default 'none'
    check (conflict_status in ('none', 'local_wins', 'remote_wins', 'needs_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id),
  unique (user_id, dedupe_key)
);

create index if not exists vibration_patterns_user_updated_idx
  on public.vibration_patterns(user_id, updated_at desc);
create index if not exists wearable_alarms_user_time_idx
  on public.wearable_alarms(user_id, hour, minute);
create index if not exists device_diagnostics_user_updated_idx
  on public.device_diagnostics(user_id, updated_at desc);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'vibration_patterns',
    'wearable_alarms',
    'device_diagnostics'
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

drop policy if exists "vibration_patterns_select_own" on public.vibration_patterns;
create policy "vibration_patterns_select_own" on public.vibration_patterns
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "vibration_patterns_insert_own" on public.vibration_patterns;
create policy "vibration_patterns_insert_own" on public.vibration_patterns
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "vibration_patterns_update_own" on public.vibration_patterns;
create policy "vibration_patterns_update_own" on public.vibration_patterns
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "vibration_patterns_delete_own" on public.vibration_patterns;
create policy "vibration_patterns_delete_own" on public.vibration_patterns
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "wearable_alarms_select_own" on public.wearable_alarms;
create policy "wearable_alarms_select_own" on public.wearable_alarms
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "wearable_alarms_insert_own" on public.wearable_alarms;
create policy "wearable_alarms_insert_own" on public.wearable_alarms
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "wearable_alarms_update_own" on public.wearable_alarms;
create policy "wearable_alarms_update_own" on public.wearable_alarms
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "wearable_alarms_delete_own" on public.wearable_alarms;
create policy "wearable_alarms_delete_own" on public.wearable_alarms
  for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "device_diagnostics_select_own" on public.device_diagnostics;
create policy "device_diagnostics_select_own" on public.device_diagnostics
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "device_diagnostics_insert_own" on public.device_diagnostics;
create policy "device_diagnostics_insert_own" on public.device_diagnostics
  for insert to authenticated
  with check ((select auth.uid()) is not null and (select auth.uid()) = user_id);
drop policy if exists "device_diagnostics_update_own" on public.device_diagnostics;
create policy "device_diagnostics_update_own" on public.device_diagnostics
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
drop policy if exists "device_diagnostics_delete_own" on public.device_diagnostics;
create policy "device_diagnostics_delete_own" on public.device_diagnostics
  for delete to authenticated
  using ((select auth.uid()) = user_id);
