# Whoordan Private Wearable Export Field Mapping

Date: 2026-05-12

## Files Inspected

Private files inspected outside the repository:

- `journal_entries.csv`
- `physiological_cycles.csv`
- `sleeps.csv`
- `workouts.csv`

Inspection was limited to headers, column counts, row counts, missing-column behavior, and aggregate shape. No private rows or notes were copied into this document.

## Columns Found

`journal_entries.csv` has 6 columns: `Cycle start time`, `Cycle end time`, `Cycle timezone`, `Question text`, `Answered yes`, `Notes`.

`physiological_cycles.csv` has 26 columns including cycle timestamps/timezone, `Recovery score %`, `Resting heart rate (bpm)`, `Heart rate variability (ms)`, `Skin temp (celsius)`, `Blood oxygen %`, `Day Strain`, energy, average/max heart rate, and sleep timing/duration/efficiency/consistency fields.

`sleeps.csv` has 18 columns including sleep start/end/timezone, nap flag, sleep score/performance, respiratory rate, sleep need/debt, sleep efficiency/consistency, total sleep, and sleep-stage durations.

`workouts.csv` has 17 columns including workout start/end/timezone, duration, activity name, activity strain, energy, average/max heart rate, heart-rate-zone percentages, and GPS fields.

## Row Counts And Date Ranges

| File | Rows | Date range |
|---|---:|---|
| `journal_entries.csv` | 180 | 2025-11-08 to 2025-11-26 |
| `physiological_cycles.csv` | 63 | 2025-11-05 to 2026-01-13 |
| `sleeps.csv` | 67 | 2025-11-07 to 2026-01-06 |
| `workouts.csv` | 5 | 2025-11-15 to 2025-12-19 |

## Field Classification

| File | Date/time fields | ID/source fields | Direct measurements | Calculated outputs / benchmark targets |
|---|---|---|---|---|
| `journal_entries.csv` | Cycle start/end time, timezone | Question text; notes ignored/redacted | Answered yes/no | Behavior association counts only |
| `physiological_cycles.csv` | Cycle start/end, sleep onset/wake onset, timezone | Cycle window | RHR, HRV, skin temp, SpO2, energy, max/avg HR, respiratory rate, sleep durations/stage totals | Recovery score, day strain, sleep performance, sleep need, sleep debt, efficiency, consistency |
| `sleeps.csv` | Cycle start/end, sleep onset/wake onset, timezone | Nap flag | Respiratory rate, asleep/in-bed/awake/stage durations, efficiency, consistency | Sleep performance, sleep need, sleep debt |
| `workouts.csv` | Cycle start/end, workout start/end, timezone | Activity name, GPS enabled | Duration, energy, max/avg HR, HR-zone percentages | Activity strain |

## Coverage Notes

- `physiological_cycles.csv`: 61/63 rows contain recovery, RHR, HRV,
  respiratory, SpO2, sleep duration, sleep need, sleep debt, and sleep
  efficiency values; 62/63 contain day strain, energy, max HR, and average HR;
  56/63 contain sleep consistency.
- `sleeps.csv`: 67/67 rows contain sleep performance, duration, need, debt,
  efficiency, and nap flag; 59/67 contain sleep consistency.
- `workouts.csv`: all 5 rows contain duration, activity strain, energy, HR
  summary, zone percentages, and GPS-enabled flag.

## Units And Timestamp Assumptions

- Timestamps are treated as local export timestamps plus an explicit timezone column where present.
- Durations ending in `(min)` are minutes and should be converted to seconds only at the model boundary if needed.
- Heart rate is bpm.
- HRV is milliseconds and should be labeled by source.
- Skin/body temperature columns are Celsius.
- Oxygen saturation is percent.
- Energy columns are calories as exported.
- Zone columns are percentages.

## Missing-Data Behavior

Empty cells map to `nil`/unavailable, not zero. Proprietary score columns may be parsed for import display only if a future user import feature explicitly needs that, but they are ignored by Whoordan scoring. Conflicting sleep/workout/cycle timestamps should be preserved with source labels and excluded from derived scoring until normalized.

## Source Labels

Imported data from these files should use a source label such as `wearable_csv_import` if a future import feature is added. Live Apple Health data uses `apple_health`. Live wearable data uses `wearable_ble`.

## Whoordan Model Mapping

- Journal rows map to `JournalEntry` with question text, yes/no answer, source cycle window, timezone, and sanitized notes handling.
- Cycle rows map to `DailyHealthSummary`, `HealthSample`, and sleep summary fields where direct measured fields exist.
- Sleep rows map to `SleepSession`; sleep stages are stored only when the source provides real stage durations.
- Workout rows map to `Workout` with duration, activity label, energy, heart-rate summary, and zone percentages.
- Recovery, strain, sleep-performance, and sleep-need exports are not copied into Whoordan formulas.

## Benchmark Mapping

The local benchmark harness maps private exports into aggregate-only validation summaries:

- Physiological cycles: direct heart/body/sleep fields are compared against Whoordan model inputs; exported recovery and day strain are benchmark references only.
- Sleeps: duration, in-bed duration, stage-duration, respiratory-rate, efficiency, need, debt, consistency, and nap columns are mapped for coverage and missing-value counts.
- Workouts: duration, activity name, energy, max/average HR, zone percentages, GPS/distance availability, and activity strain reference are mapped for aggregate trend checks.
- Journal: question text and yes/no answer are mapped for habit category coverage; notes are ignored/redacted.

The benchmark may report aggregate row counts, date ranges, missing counts, correlations, and bucket summaries. It must not write private rows or personal values to committed tests or docs.

The aggregate relationship-discovery results for this export are documented in
`docs/WHOORDAN_PRIVATE_WEARABLE_EXPORT_RELATIONSHIP_ANALYSIS.md`.

## Sanitized Fixture Strategy

Unit tests use synthetic headers matching the private export schema and invented values. They validate schema recognition, missing-header errors, ignored proprietary-score columns, and safe mapping assumptions without private rows.

## Intentionally Not Copied

Whoordan does not copy third-party scores, formulas, trend logic, UI, chart language, colors, proprietary behavior, private personal notes, route details, or raw export rows.

## Privacy Handling

The CSV files remain outside the repository. Raw rows were not committed. Tests and docs contain only schema-level information and fabricated values. Any future import UI must require explicit user action and must keep cloud upload gated by admin approval plus cloud and health-data consent.

## Device-First Alignment

CSV exports are benchmark/reference data, not the production measurement source. In the app, reliable wearable BLE samples outrank Apple Health. Apple Health remains the fallback/assistant source. Cloud synced copies are backup/restoration data and are not treated as primary measurements.
