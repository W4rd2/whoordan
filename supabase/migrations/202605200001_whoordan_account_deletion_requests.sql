create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'canceled')),
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create unique index if not exists account_deletion_requests_active_user_idx
  on public.account_deletion_requests(user_id)
  where status in ('pending', 'processing');

create index if not exists account_deletion_requests_user_requested_idx
  on public.account_deletion_requests(user_id, requested_at desc);

drop trigger if exists set_account_deletion_requests_updated_at on public.account_deletion_requests;
create trigger set_account_deletion_requests_updated_at
  before update on public.account_deletion_requests
  for each row execute function public.set_updated_at();

alter table public.account_deletion_requests enable row level security;
alter table public.account_deletion_requests force row level security;

drop policy if exists "account_deletion_requests_select_own" on public.account_deletion_requests;
create policy "account_deletion_requests_select_own" on public.account_deletion_requests
  for select to authenticated
  using ((select auth.uid()) is not null and (select auth.uid()) = user_id);

drop policy if exists "account_deletion_requests_insert_pending_own" on public.account_deletion_requests;
create policy "account_deletion_requests_insert_pending_own" on public.account_deletion_requests
  for insert to authenticated
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
    and status = 'pending'
    and completed_at is null
  );

drop policy if exists "account_deletion_requests_cancel_own_pending" on public.account_deletion_requests;
create policy "account_deletion_requests_cancel_own_pending" on public.account_deletion_requests
  for update to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
    and status = 'pending'
  )
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = user_id
    and status = 'canceled'
    and completed_at is null
  );

revoke all on public.account_deletion_requests from anon;
grant select, insert, update on public.account_deletion_requests to authenticated;

comment on table public.account_deletion_requests is
  'User-initiated Whoordan account deletion requests. Mobile clients insert only their own pending request through RLS; account/Auth deletion is completed by server-side operations.';
