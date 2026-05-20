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

drop policy if exists "consent_records_update_own" on public.consent_records;
create policy "consent_records_update_own" on public.consent_records
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'workouts_user_id_id_key'
      and conrelid = 'public.workouts'::regclass
  ) then
    alter table public.workouts
      add constraint workouts_user_id_id_key unique (user_id, id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'strength_workouts_user_id_id_key'
      and conrelid = 'public.strength_workouts'::regclass
  ) then
    alter table public.strength_workouts
      add constraint strength_workouts_user_id_id_key unique (user_id, id);
  end if;
end $$;

alter table public.strength_workouts
  drop constraint if exists strength_workouts_workout_id_fkey;

alter table public.strength_sets
  drop constraint if exists strength_sets_strength_workout_id_fkey;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'strength_workouts_user_workout_owner_fkey'
      and conrelid = 'public.strength_workouts'::regclass
  ) then
    alter table public.strength_workouts
      add constraint strength_workouts_user_workout_owner_fkey
      foreign key (user_id, workout_id)
      references public.workouts(user_id, id)
      on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'strength_sets_user_strength_workout_owner_fkey'
      and conrelid = 'public.strength_sets'::regclass
  ) then
    alter table public.strength_sets
      add constraint strength_sets_user_strength_workout_owner_fkey
      foreign key (user_id, strength_workout_id)
      references public.strength_workouts(user_id, id)
      on delete cascade;
  end if;
end $$;
