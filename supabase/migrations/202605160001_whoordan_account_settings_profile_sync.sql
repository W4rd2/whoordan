alter table public.user_profiles
  add column if not exists birth_date date,
  add column if not exists biological_sex text not null default 'notSet'
    check (biological_sex in ('notSet', 'female', 'male')),
  add column if not exists height_centimeters double precision
    check (height_centimeters is null or (height_centimeters >= 90 and height_centimeters <= 250)),
  add column if not exists weight_kilograms double precision
    check (weight_kilograms is null or (weight_kilograms >= 30 and weight_kilograms <= 250)),
  add column if not exists configured_max_heart_rate double precision
    check (configured_max_heart_rate is null or (configured_max_heart_rate >= 80 and configured_max_heart_rate <= 240));

create index if not exists user_profiles_body_profile_updated_idx
  on public.user_profiles(user_id, updated_at desc);

comment on column public.user_profiles.birth_date is
  'User-provided birth date for account setup sync and wellness-only estimates.';
comment on column public.user_profiles.biological_sex is
  'User-provided biological sex for account setup sync and wellness-only formulas.';
comment on column public.user_profiles.height_centimeters is
  'User-provided height in centimeters for account setup sync and wellness-only estimates.';
comment on column public.user_profiles.weight_kilograms is
  'User-provided weight in kilograms for account setup sync and wellness-only estimates.';
comment on column public.user_profiles.configured_max_heart_rate is
  'Optional user-provided max heart rate for account setup sync and wellness-only zones.';
