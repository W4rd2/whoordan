alter table public.user_settings
  add column if not exists baseline_profiles jsonb not null default '{}'::jsonb;

comment on column public.user_settings.baseline_profiles is
  'Cloud-restorable health metric baseline state. Client uploads this only after cloud health sync is enabled.';
