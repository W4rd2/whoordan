alter table public.daily_health_summaries
  add column if not exists metric_payload_version integer not null default 1,
  add column if not exists summary_payload jsonb not null default '{}'::jsonb,
  add column if not exists ready_metric_snapshots jsonb not null default '[]'::jsonb;

create index if not exists daily_summaries_user_metric_restore_idx
  on public.daily_health_summaries(user_id, summary_date desc)
  where deleted_at is null;
