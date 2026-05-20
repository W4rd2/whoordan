# Whoordan Private CSV Data Policy

Date: 2026-05-11

## Scope

The private private wearable export CSV files supplied for this migration are user-owned reference data. They are not Whoordan source assets and must not be committed, uploaded, logged, or reproduced.

Files inspected outside the repo:

- `journal_entries.csv`
- `physiological_cycles.csv`
- `sleeps.csv`
- `workouts.csv`

## Allowed Use

- Inspect headers, field names, field categories, timestamp formats, units, missing-value patterns, and aggregate shape.
- Use the schema to create parser validation and sanitized synthetic fixtures.
- Use realistic edge-case categories to make Whoordan models missing-data safe.
- Document field mappings at column level only.

## Disallowed Use

- Do not commit raw CSV exports.
- Do not print private rows, personal notes, device IDs, routes, or timestamps from the exports.
- Do not upload CSV data to any service.
- Do not use CSV values to reverse-engineer third-party formulas.
- Do not claim Whoordan reproduces third-party formulas or scores.
- Do not copy third-party UI, wording, colors, charts, trade dress, or proprietary behavior.

## Handling In This Migration

Only headers, row counts, column counts, and aggregate shape checks were inspected. Raw rows were not printed into docs, tests, logs, or source. The repository contains no CSV fixture copied from the private export. Tests use synthetic headers and values only.

## Fixture Strategy

Synthetic fixtures should be small and invented. They may keep the same column names and broad units, but values must be fabricated and must not include private notes, real route data, real timestamps from the export, or exact proprietary score examples.

## Review Checklist

- `find . -name '*.csv'` returns no private CSVs in the repo.
- Tests reference synthetic data only.
- Docs contain column names and assumptions, not private rows.
- Scoring docs state that Whoordan formulas are original and non-medical.
- Cloud upload requires admin approval and explicit consent.
