# Whoordan Private Wearable Export Relationship Analysis

Date: 2026-05-12
Branch: `swift-app`

## Privacy Boundary

This analysis used private local CSV exports only as a benchmark and
relationship-discovery dataset. Raw files remained outside the repository. No
raw rows, private notes, exact private timestamps, personal identifiers, or raw
CSV contents were copied into this document. Findings below are aggregate-only.

Whoordan does not claim third-party formula equivalence and does not copy proprietary
third-party formulas, UI, wording, colors, charts, trade dress, or product behavior.

## Files Inspected

| File | Rows | Date range | Status |
|---|---:|---|---|
| `journal_entries.csv` | 180 | 2025-11-08 to 2025-11-26 | Inspected |
| `physiological_cycles.csv` | 63 | 2025-11-05 to 2026-01-13 | Inspected |
| `sleeps.csv` | 67 | 2025-11-07 to 2026-01-06 | Inspected |
| `workouts.csv` | 5 | 2025-11-15 to 2025-12-19 | Inspected |

No separate recovery/cycles/activity/metrics file beyond the listed cycle,
sleep, workout, and journal exports was present in the provided path.

## Coverage Summary

`physiological_cycles.csv` has high coverage for core recovery inputs:

| Field group | Coverage |
|---|---:|
| Recovery, RHR, HRV, skin temp, SpO2, respiratory, sleep duration, sleep need, sleep debt, sleep efficiency | 61/63 |
| Day strain, energy, max HR, average HR | 62/63 |
| Sleep consistency | 56/63 |

`sleeps.csv` has complete coverage for sleep performance, duration, need, debt,
efficiency, nap flag, and stage-duration totals, with sleep consistency present
in 59/67 rows.

`workouts.csv` has 5/5 coverage for duration, activity strain, energy, max HR,
average HR, HR-zone percentages, and GPS-enabled flag. Because there are only 5
workouts, workout correlations are directional sanity checks, not stable model
validation.

## Recovery Relationships

Recovery score relationships from physiological cycles:

| Input | N | Pearson | Spearman | Interpretation |
|---|---:|---:|---:|---|
| HRV | 61 | 0.777 | 0.815 | Strongest relationship; keep HRV as highest-weight contributor when true HRV source exists. |
| Respiratory rate | 61 | -0.512 | -0.499 | Meaningful negative relationship; higher respiratory rate relative to baseline should reduce recovery support. |
| Sleep performance | 61 | 0.327 | 0.083 | Weak-to-moderate linear relation, noisy monotonic relation. |
| RHR | 61 | -0.307 | -0.322 | Moderate negative relationship; above-baseline RHR should reduce recovery support. |
| Asleep duration | 61 | 0.250 | 0.087 | Positive but weak; useful mainly as sleep-sufficiency context. |
| Previous-day day strain | 61 | 0.218 | 0.263 | Weak in this export; better used to adjust sleep need/context than directly penalize recovery. |
| Day strain | 61 | 0.145 | 0.128 | Weak/noisy. |
| Skin temp | 61 | 0.011 | -0.002 | No relationship in this export. |
| Sleep debt | 61 | -0.041 | -0.016 | No clear direct relationship here. |
| Sleep efficiency | 61 | -0.180 | -0.228 | Noisy and counter-directional; do not overweight. |
| SpO2 | 61 | -0.267 | -0.239 | Counter-directional in this export; use only as low/abnormal measured-source safety context, not a dominant score driver. |

Baseline-relative relationships against recovery:

| Baseline-relative signal | N | Pearson | Spearman | Interpretation |
|---|---:|---:|---:|---|
| HRV above baseline | 54 | 0.808 | 0.826 | Strongest baseline signal. |
| Respiratory rate closer/below baseline | 54 | 0.523 | 0.511 | Meaningful recovery signal. |
| RHR below baseline | 54 | 0.400 | 0.436 | Useful moderate signal. |
| Sleep duration above baseline | 54 | 0.321 | 0.140 | Weak-to-moderate support. |
| Skin temp closer/below baseline | 54 | -0.039 | -0.045 | Not useful in this export. |
| Sleep efficiency above baseline | 54 | -0.182 | -0.254 | Not useful in this export. |
| SpO2 above baseline | 54 | -0.292 | -0.235 | Not useful as a positive trend signal in this export. |

## Sleep Relationships

Sleep performance relationships from sleep rows:

| Input | N | Pearson | Spearman | Interpretation |
|---|---:|---:|---:|---|
| Asleep duration | 67 | 0.909 | 0.807 | Dominant relationship; performance mostly tracks sleep achieved. |
| REM duration | 67 | 0.757 | 0.727 | Strong, but stage totals are source-reported only and should not be fabricated. |
| Deep duration | 67 | 0.727 | 0.525 | Strong, same stage caveat. |
| Sleep consistency | 59 | 0.489 | 0.620 | Useful trend/support signal when enough history exists. |
| Sleep debt | 67 | -0.457 | -0.385 | Higher debt generally relates to lower sleep performance. |
| Sleep need | 67 | -0.328 | -0.297 | Higher need can make performance harder to achieve. |
| Sleep efficiency | 67 | 0.074 | 0.062 | Weak in this export; do not make it a dominant sleep score driver. |

Nap rows were present: 6 true nap rows and 61 non-nap sleep rows. This supports
nap handling as a verified-source feature, but not nap inference from HR/motion.

Night-to-night sleep-debt change versus achieved-minus-need had weak/noisy
relationship in this export: N=66, Pearson -0.239, Spearman -0.066. Whoordan
should keep debt conservative and avoid over-interpreting single nights.

## Workout And Strain Relationships

Workout export has only 5 rows, so results are sanity checks only:

| Input | N | Pearson | Spearman | Interpretation |
|---|---:|---:|---:|---|
| Energy | 5 | 0.908 | 0.900 | Strong directional relation, but small sample. |
| HR zone 4 percent | 5 | 0.900 | 0.447 | Strong linear relation, noisy rank due small N. |
| Average HR | 5 | 0.860 | 0.667 | Strong directional relation. |
| Max HR | 5 | 0.842 | 0.700 | Strong directional relation. |
| Duration | 5 | 0.558 | 0.564 | Moderate relation. |
| HR zone 5 percent | 5 | unavailable | unavailable | No useful variation in this export. |

Candidate Whoordan workout strain using HR-zone load, HR intensity, duration,
and energy had N=5, Pearson 0.851, Spearman 0.900, MAE 2.0 strain points, and
40.0% bucket agreement. The trend is promising but bucket calibration is not
stable with only 5 workouts.

## Journal Associations

Journal analysis used keyword-level categories only and did not copy raw
question text or notes. These are associations, not causal claims.

| Category | Yes N | No N | Aggregate finding |
|---|---:|---:|---|
| Caffeine-like category | 18 | 0 | No yes/no comparison possible. |
| Alcohol-like category | 0 | 1 | No yes/no comparison possible. |
| Late-food-like category | 1 | 17 | Too few yes days; mean difference is not reliable. |
| Screen/device-like category | 0 | 4 | No yes/no comparison possible. |

No journal category had enough balanced yes/no samples to support a reliable
Whoordan insight. The product should require minimum sample sizes and show
association language only.

## Candidate Formula Decisions

Recovery formula tuning:

- Increase HRV weight because both direct and baseline-relative HRV were the
  strongest relationships.
- Keep RHR as a moderate negative contributor.
- Increase respiratory baseline-deviation weight versus the previous formula.
- Reduce sleep sufficiency from a dominant recovery input to a supporting input.
- Reduce temperature deviation to a small contextual contributor until stronger
  individual signal exists.
- Do not add a positive SpO2 trend contributor from this export. Use measured
  SpO2 only as low/abnormal-source context if a validated source exists.
- Do not add previous-day strain as a direct recovery penalty from this export;
  use it to adjust sleep need and contextual confidence.

Strain formula decision:

- Keep the original saturating 0-21 strain estimate.
- Preserve HR-zone load, HR intensity, duration, and source-labeled energy as
  main contributors.
- Treat movement/steps as low-confidence contributor unless source is validated.
- Do not infer strain from unvalidated IMU activity.

Sleep need/debt decision:

- Keep base sleep need conservative.
- Adjust need with prior debt, previous-day strain, and consistency only when
  history is sufficient.
- Naps may reduce debt only when they come from a verified sleep source.
- Avoid overreacting to a single night because debt-change relationships were
  weak/noisy.

Journal decision:

- Require minimum yes/no sample sizes before showing behavior comparisons.
- Use association wording only.
- Do not claim causation.

## Candidate Benchmark Results

Recovery candidate benchmark:

| Candidate | N | Pearson | Spearman | MAE | Bucket agreement |
|---|---:|---:|---:|---:|---:|
| Prior style | 61 | 0.516 | 0.502 | 25.0 | 45.9% |
| SpO2 + previous strain variant | 61 | 0.466 | 0.471 | 26.3 | 44.3% |
| Last-20%-out test variant | 12 | 0.228 | -0.039 | 32.3 | 25.0% |

Interpretation: the export confirms useful directionality for HRV/RHR/respiratory
inputs, but a small single-user dataset does not support tight score matching.
Whoordan should favor explainability, confidence labels, and trend behavior over
attempting exact bucket reproduction.

Workout strain candidate benchmark:

- N=5 workouts.
- Pearson 0.851.
- Spearman 0.900.
- MAE 2.0 strain points.
- Bucket agreement 40.0%.

Interpretation: ranking was directionally reasonable, but bucket calibration is
not stable with only 5 workouts.

## Implementation And Tests

Code changes from this relationship pass:

- Tuned Whoordan's original recovery weighting to HRV 0.35, RHR 0.20, sleep
  sufficiency 0.17, respiratory baseline fit 0.20, and temperature 0.08.
- Updated the Recovery UI to explain the same contributors directly: HRV
  relative to baseline, RHR relative to baseline, sleep sufficiency,
  respiratory fit, temperature deviation, source labels, confidence, top
  positive contributors, top negative contributors, and missing-data confidence.
- Added aggregate-only benchmark helpers for Spearman correlation, rolling
  baselines, candidate recovery scoring, and bucket agreement.
- Added synthetic-only tests for schema parsing, unit-safe benchmark math,
  rolling baseline behavior, candidate recovery directionality, and aggregate
  bucket agreement.

Validation run on 2026-05-12:

- `xcodebuild -list -project Whoordan.xcodeproj`: passed.
- Focused `CSVSchemaTests`: 10 tests passed.
- Simulator build for `iPhone 17, OS 26.4.1`: passed.
- Full simulator test for `iPhone 17, OS 26.4.1`: 123 unit tests passed; UI
  launch test passed; 7 approved-device UI tests were skipped because they
  require an approved physical iPhone session.
- Generic iOS no-codesign build: passed.
- `git diff --check`: passed for tracked changes.
- Scoped privacy scan found no raw export path, raw exact private timestamp
  pattern, or payload-like long private string in the touched benchmark docs,
  tests, or CSV utility code.

## What Could Not Be Inferred

- Exact proprietary recovery, strain, or sleep formulas.
- Valid device-derived sleep, stage, nap, step, HRV, respiratory, SpO2, or
  temperature semantics from CSV exports alone.
- Causal journal effects.
- Stable workout strain bucket calibration from only 5 workouts.
- Population-general weights from one user export.

## Validation Target For Future Runs

- Recovery trend correlation should remain positive when direct HRV/RHR/respiratory
  inputs are present.
- Recovery buckets should be treated as coarse sanity checks only.
- Workout strain ranking should remain positive as workout row count grows.
- Sleep duration and stage totals should match source fields closely when
  imported, but Whoordan should not create stage intervals from totals alone.
