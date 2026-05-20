create table if not exists public.user_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  approval_status text not null default 'pending',
  approved_at timestamptz,
  approved_by text,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_access
  drop constraint if exists user_access_approval_status_check;

alter table public.user_access
  add constraint user_access_approval_status_check
  check (approval_status in ('pending', 'approved', 'rejected', 'revoked'));

create index if not exists user_access_approval_status_idx
  on public.user_access(approval_status);

create index if not exists user_access_email_lower_idx
  on public.user_access(lower(email))
  where email is not null;

drop trigger if exists set_user_access_updated_at on public.user_access;
create trigger set_user_access_updated_at
  before update on public.user_access
  for each row execute function public.set_updated_at();

create or replace function public.create_user_access_for_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_access (
    user_id,
    email,
    approval_status
  )
  values (
    new.id,
    new.email,
    'pending'
  )
  on conflict (user_id) do update
    set email = coalesce(excluded.email, public.user_access.email),
        updated_at = now()
    where public.user_access.email is distinct from excluded.email;

  return new;
end;
$$;

revoke all on function public.create_user_access_for_new_auth_user()
  from public;
revoke all on function public.create_user_access_for_new_auth_user()
  from anon;
revoke all on function public.create_user_access_for_new_auth_user()
  from authenticated;

comment on function public.create_user_access_for_new_auth_user() is
  'Creates a pending Whoordan access row for new Supabase Auth users. It never auto-approves users and is executable only as an auth.users trigger.';

drop trigger if exists create_user_access_after_auth_user_insert on auth.users;
create trigger create_user_access_after_auth_user_insert
  after insert on auth.users
  for each row execute function public.create_user_access_for_new_auth_user();

grant select, insert on public.user_access to authenticated;
revoke update, delete on public.user_access from anon;
revoke update, delete on public.user_access from authenticated;

alter table public.user_access enable row level security;
alter table public.user_access force row level security;

drop policy if exists "user_access_select_own" on public.user_access;
create policy "user_access_select_own" on public.user_access
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists "user_access_insert_pending_own" on public.user_access;
create policy "user_access_insert_pending_own" on public.user_access
  for insert to authenticated
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
    and approval_status = 'pending'
    and approved_at is null
    and approved_by is null
    and rejection_reason is null
  );

do $$
declare
  table_name text;
  approved_owner_check text := $policy$
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
    and exists (
      select 1
      from public.user_access ua
      where ua.user_id = (select auth.uid())
        and ua.approval_status = 'approved'
    )
  $policy$;
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

      execute format('drop policy if exists %I on public.%I', table_name || '_select_own', table_name);
      execute format('drop policy if exists %I on public.%I', table_name || '_insert_own', table_name);
      execute format('drop policy if exists %I on public.%I', table_name || '_update_own', table_name);
      execute format('drop policy if exists %I on public.%I', table_name || '_delete_own', table_name);

      execute format(
        'create policy %I on public.%I for select to authenticated using (%s)',
        table_name || '_select_own',
        table_name,
        approved_owner_check
      );
      execute format(
        'create policy %I on public.%I for insert to authenticated with check (%s)',
        table_name || '_insert_own',
        table_name,
        approved_owner_check
      );
      execute format(
        'create policy %I on public.%I for update to authenticated using (%s) with check (%s)',
        table_name || '_update_own',
        table_name,
        approved_owner_check,
        approved_owner_check
      );
      execute format(
        'create policy %I on public.%I for delete to authenticated using (%s)',
        table_name || '_delete_own',
        table_name,
        approved_owner_check
      );
    end if;
  end loop;
end $$;
