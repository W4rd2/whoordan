-- Whoordan account-scoped health sample import.
--
-- Use when Codex cannot connect to Supabase directly. Run this in the
-- Supabase SQL editor as the project owner after replacing target_user_id and
-- adding rows to whoordan_import_health_samples.
--
-- This file intentionally does not include credentials, service-role keys,
-- auth tokens, or personal sample rows.

begin;

create extension if not exists pgcrypto;

create temp table whoordan_import_config (
  target_user_id uuid not null,
  expected_email text,
  require_approved_access boolean not null default true,
  require_cloud_health_consent boolean not null default true,
  import_batch_id text not null default encode(gen_random_bytes(8), 'hex')
) on commit drop;

insert into whoordan_import_config (
  target_user_id,
  expected_email,
  require_approved_access,
  require_cloud_health_consent
) values (
  '00000000-0000-0000-0000-000000000000'::uuid,
  null,
  true,
  true
);

create temp table whoordan_import_health_samples (
  sample_type text not null,
  value double precision not null,
  unit text not null,
  sampled_at timestamptz not null,
  ended_at timestamptz,
  source text not null default 'whoordan_estimate',
  source_record_id text,
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text
) on commit drop;

-- Paste rows here. Accepted import source values are:
-- apple_health, wearable_ble, legacy_wearable_device_export, local_manual,
-- whoordan_estimate, cloud_import.
--
-- Raw wearable_imu/wearable_ppg debug frames and synthetic_fixture rows are
-- intentionally not accepted here; convert them into supported production
-- metric samples before importing.
-- Example only:
-- insert into whoordan_import_health_samples (
--   sample_type, value, unit, sampled_at, ended_at, source, source_record_id, metadata
-- ) values
--   ('heartRate', 72, 'bpm', '2026-05-20T01:00:00Z', null, 'wearable_ble', 'ble-hr-1', '{"source_label":"Wearable direct"}'::jsonb),
--   ('sleepAnalysis', 30, 'min', '2026-05-19T22:30:00Z', '2026-05-19T23:00:00Z', 'whoordan_estimate', 'r10-sleep-1', '{"device_only_derivation":"true","metric_policy":"r10_hr_imu_sleep_stage_estimate","sleep_category":"4"}'::jsonb);

do $$
declare
  cfg record;
  matched_email text;
  access_status text;
  consent_ok boolean;
begin
  select * into cfg from whoordan_import_config limit 1;

  if cfg.target_user_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'Replace whoordan_import_config.target_user_id with the auth.users.id for your Whoordan account.';
  end if;

  select email into matched_email
  from auth.users
  where id = cfg.target_user_id;

  if matched_email is null then
    raise exception 'No auth.users row found for target_user_id %.', cfg.target_user_id;
  end if;

  if cfg.expected_email is not null and lower(cfg.expected_email) <> lower(matched_email) then
    raise exception 'target_user_id email mismatch. Expected %, found %.', cfg.expected_email, matched_email;
  end if;

  if cfg.require_approved_access then
    select approval_status into access_status
    from public.user_access
    where user_id = cfg.target_user_id;

    if coalesce(access_status, '') <> 'approved' then
      raise exception 'Target user must be approved before health import. Current status: %.', coalesce(access_status, 'missing');
    end if;
  end if;

  if cfg.require_cloud_health_consent then
    select coalesce((
      select health_cloud_sync_enabled
      from public.user_settings
      where user_id = cfg.target_user_id
    ), false)
    or exists (
      select 1
      from public.consent_records
      where user_id = cfg.target_user_id
        and scope = 'cloud_sync'
        and decision = 'granted'
      order by recorded_at desc
      limit 1
    )
    into consent_ok;

    if consent_ok is not true then
      raise exception 'Target user must explicitly enable cloud health sync before importing health data.';
    end if;
  end if;
end $$;

do $$
declare
  invalid_count integer;
begin
  select count(*) into invalid_count from whoordan_import_health_samples;
  if invalid_count = 0 then
    raise exception 'No rows staged in whoordan_import_health_samples.';
  end if;

  select count(*) into invalid_count
  from whoordan_import_health_samples
  where sample_type not in (
    'heartRate',
    'restingHeartRate',
    'heartRateVariabilitySDNN',
    'heartRateVariabilityRMSSD',
    'respiratoryRate',
    'sleepAnalysis',
    'steps',
    'activeEnergy',
    'distanceWalkingRunning',
    'oxygenSaturation',
    'bodyTemperature',
    'wristTemperature',
    'workout',
    'vo2Max',
    'temperatureEvent'
  )
  or source not in (
    'apple_health',
    'wearable_ble',
    'legacy_wearable_device_export',
    'local_manual',
    'whoordan_estimate',
    'cloud_import'
  )
  or ended_at is not null and ended_at <= sampled_at
  or sample_type = 'heartRate' and value not between 25 and 240
  or sample_type = 'restingHeartRate' and value not between 25 and 160
  or sample_type in ('heartRateVariabilitySDNN', 'heartRateVariabilityRMSSD') and value not between 1 and 300
  or sample_type = 'respiratoryRate' and value not between 4 and 40
  or sample_type = 'sleepAnalysis' and value not between 0 and 1440
  or sample_type = 'steps' and value not between 0 and 200000
  or sample_type = 'activeEnergy' and value not between 0 and 10000
  or sample_type = 'distanceWalkingRunning' and value not between 0 and 200000
  or sample_type = 'oxygenSaturation' and value not between 50 and 100
  or sample_type in ('bodyTemperature', 'wristTemperature', 'temperatureEvent') and value not between 20 and 45
  or sample_type = 'workout' and value not between 0 and 1440
  or sample_type = 'vo2Max' and value not between 10 and 90;

  if invalid_count > 0 then
    raise exception 'Staged import has % invalid row(s). Fix sample types, sources, ranges, and timestamps first.', invalid_count;
  end if;
end $$;

with cfg as (
  select * from whoordan_import_config limit 1
),
normalized as (
  select
    cfg.target_user_id as user_id,
    s.sample_type,
    s.value,
    s.unit,
    s.sampled_at,
    s.ended_at,
    s.source,
    case
      when nullif(s.source_record_id, '') is null then null
      else encode(digest(s.source_record_id, 'sha256'), 'hex')
    end as source_record_id,
    jsonb_strip_nulls(
      s.metadata
      || jsonb_build_object(
        'imported_by', 'whoordan_account_health_import_sql',
        'import_batch_id', cfg.import_batch_id,
        'imported_at', now()
      )
    ) as metadata,
    coalesce(
      nullif(s.dedupe_key, ''),
      encode(
        digest(
          concat_ws(
            '|',
            cfg.target_user_id::text,
            s.sample_type,
            s.source,
            coalesce(s.source_record_id, ''),
            s.sampled_at::text,
            coalesce(s.ended_at::text, ''),
            s.value::text,
            s.unit
          ),
          'sha256'
        ),
        'hex'
      )
    ) as dedupe_key
  from whoordan_import_health_samples s
  cross join cfg
)
insert into public.health_samples (
  user_id,
  sample_type,
  value,
  unit,
  sampled_at,
  ended_at,
  source,
  source_record_id,
  metadata,
  dedupe_key,
  sync_status,
  last_synced_at,
  deleted_at
)
select
  user_id,
  sample_type,
  value,
  unit,
  sampled_at,
  ended_at,
  source,
  source_record_id,
  metadata,
  dedupe_key,
  'synced',
  now(),
  null
from normalized
on conflict (user_id, dedupe_key) do update
set
  sample_type = excluded.sample_type,
  value = excluded.value,
  unit = excluded.unit,
  sampled_at = excluded.sampled_at,
  ended_at = excluded.ended_at,
  source = excluded.source,
  source_record_id = excluded.source_record_id,
  metadata = public.health_samples.metadata || excluded.metadata,
  sync_status = 'synced',
  sync_error = null,
  last_synced_at = now(),
  deleted_at = null,
  updated_at = now();

select
  sample_type,
  count(*) as imported_count,
  min(sampled_at) as first_sampled_at,
  max(sampled_at) as last_sampled_at
from public.health_samples
where user_id = (select target_user_id from whoordan_import_config limit 1)
  and metadata ->> 'import_batch_id' = (select import_batch_id from whoordan_import_config limit 1)
group by sample_type
order by sample_type;

commit;
