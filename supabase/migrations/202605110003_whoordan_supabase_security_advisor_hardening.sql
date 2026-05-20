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

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public';
    execute 'revoke all on function public.rls_auto_enable() from anon';
    execute 'revoke all on function public.rls_auto_enable() from authenticated';
    execute 'alter function public.rls_auto_enable() set search_path = pg_catalog';
    execute $comment$
      comment on function public.rls_auto_enable() is
        'Whoordan security hardening: helper execution is revoked from public, anon, and authenticated API roles.'
    $comment$;
  end if;
end $$;

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
    'recovery_insights',
    'vibration_patterns',
    'wearable_alarms',
    'device_diagnostics'
  ]
  loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('alter table public.%I enable row level security', table_name);
      execute format('alter table public.%I force row level security', table_name);
    end if;
  end loop;
end $$;

do $$
begin
  if to_regclass('public.sync_states') is not null then
    alter table public.sync_states
      drop constraint if exists sync_states_sync_status_check;

    alter table public.sync_states
      add constraint sync_states_sync_status_check
      check (sync_status in (
        'idle',
        'pending',
        'running',
        'synced',
        'failed',
        'conflict',
        'blocked'
      ));
  end if;
end $$;

do $$
begin
  if to_regclass('public.consent_records') is not null then
    drop policy if exists "consent_records_update_own" on public.consent_records;
    create policy "consent_records_update_own" on public.consent_records
      for update to authenticated
      using ((select auth.uid()) = user_id)
      with check ((select auth.uid()) = user_id);
  end if;
end $$;

do $$
begin
  if to_regclass('public.workouts') is not null then
    if not exists (
      select 1
      from pg_constraint
      where conname = 'workouts_user_id_id_key'
        and conrelid = 'public.workouts'::regclass
    ) then
      alter table public.workouts
        add constraint workouts_user_id_id_key unique (user_id, id);
    end if;
  end if;

  if to_regclass('public.strength_workouts') is not null then
    if not exists (
      select 1
      from pg_constraint
      where conname = 'strength_workouts_user_id_id_key'
        and conrelid = 'public.strength_workouts'::regclass
    ) then
      alter table public.strength_workouts
        add constraint strength_workouts_user_id_id_key unique (user_id, id);
    end if;
  end if;
end $$;

do $$
begin
  if to_regclass('public.strength_workouts') is not null then
    alter table public.strength_workouts
      drop constraint if exists strength_workouts_workout_id_fkey;

    if to_regclass('public.workouts') is not null
      and not exists (
        select 1
        from pg_constraint
        where conname = 'strength_workouts_user_workout_owner_fkey'
          and conrelid = 'public.strength_workouts'::regclass
      )
    then
      alter table public.strength_workouts
        add constraint strength_workouts_user_workout_owner_fkey
        foreign key (user_id, workout_id)
        references public.workouts(user_id, id)
        on delete cascade
        not valid;
    end if;
  end if;

  if to_regclass('public.strength_sets') is not null then
    alter table public.strength_sets
      drop constraint if exists strength_sets_strength_workout_id_fkey;

    if to_regclass('public.strength_workouts') is not null
      and not exists (
        select 1
        from pg_constraint
        where conname = 'strength_sets_user_strength_workout_owner_fkey'
          and conrelid = 'public.strength_sets'::regclass
      )
    then
      alter table public.strength_sets
        add constraint strength_sets_user_strength_workout_owner_fkey
        foreign key (user_id, strength_workout_id)
        references public.strength_workouts(user_id, id)
        on delete cascade
        not valid;
    end if;
  end if;
end $$;
