# Whoordan Private Wearable Export Benchmark Policy

Date: 2026-05-11
Branch: `swift-app`

## Allowed Uses

Private third-party wearable CSV/Excel exports may be used only for:

- Schema mapping.
- Edge-case discovery.
- Local-only benchmark validation.
- Sanitized fixture creation.
- Trend comparison.
- Regression testing with synthetic committed fixtures.

## Not Allowed

- Committing raw exports.
- Printing private rows, personal notes, timestamps, or individual values.
- Uploading exports.
- Copying third-party formulas.
- Exact-score cloning.
- Overfitting Whoordan scoring to one person.
- Claiming third-party score equivalence or official wearable-device manufacturer support.

## Benchmark Targets

Recovery:

- Positive trend correlation with exported recovery.
- Reasonable low/medium/high bucket agreement.
- Major low-recovery days should usually be detected.
- Exact score match is not required and is not expected.

Strain:

- Positive trend correlation with exported day/workout strain.
- High-workout days should rank above rest days.
- Exact 0-21 match is not required.

Sleep:

- Duration and efficiency direct mappings should preserve units and map closely.
- Stages are shown only if source stage fields exist.
- Sleep need/debt can differ because Whoordan uses original formulas.

Heart/body signals:

- Direct imported values should match source fields within unit conversion tolerance.
- Derived estimates must be labeled.

Journal:

- Yes/no habit mapping must preserve with/without distinction.
- Insights must use association language, not causation.

## Local Benchmark Harness

The repo includes `Tools/WhoordanBenchmark/WhoordanBenchmark.swift`.

Usage:

```bash
swift Tools/WhoordanBenchmark/WhoordanBenchmark.swift /path/to/private/export/directory
```

The tool reads local CSV files only when a developer explicitly passes a path. It does not hardcode private paths. It prints aggregate-only results:

- File row counts.
- Date ranges.
- Mapped column counts.
- Missing-value counts.
- Recovery/strain trend summaries.
- Sleep direct mapping counts.
- Journal yes/no aggregate counts.

Excel input is documented as pending. CSV exports are required for this benchmark pass.

## Fixture Policy

Committed tests use small synthetic CSV strings with invented values. Raw private rows, private notes, private timestamps, and private health values must never be committed.

## Interpretation

Weak benchmark correlation must not trigger third-party formula cloning. Acceptable explanations include proprietary formulas, missing raw device signals, Apple Health versus wearable source differences, one-person data limits, and missing RR/PPG/IMU semantics. Formula changes must remain transparent, original, source-aware, and non-medical.

## 2026-05-12 Device-First Pass

No new private export rows were inspected or printed in this pass. Existing aggregate-only benchmark rules remain in force. Device packet discovery can use private exports only to check field coverage, broad trends, and unit mappings, not to reproduce proprietary scores.

## 2026-05-12 Packet Capture Benchmark Boundary

Large BLE captures may be compared against private exports only at aggregate
level:

- row counts and date coverage
- broad trend direction
- direct field/unit tolerance where a source field exists
- missing-data coverage
- bucket agreement for original Whoordan score categories

Raw BLE payloads and raw export rows must not be committed, printed, uploaded,
or used to clone proprietary formulas. If a device-derived prototype is compared
against exports, the result must be labeled local benchmark evidence, not
physical or clinical validation.
