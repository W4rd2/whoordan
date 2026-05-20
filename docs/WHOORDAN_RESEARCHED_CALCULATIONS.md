# Whoordan Researched Calculations And Platform Methods

Audit date: 2026-05-11. This document records the researched basis for Whoordan calculations, source mapping, and platform behavior. Whoordan uses original wellness heuristics only; it is not a medical device and does not diagnose, treat, prevent, or cure disease.

## Source Register

- Apple HealthKit: [HKHealthStore](https://developer.apple.com/documentation/healthkit/hkhealthstore), [Reading data from HealthKit](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit), [Executing observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries), [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy).
- iOS notifications/calls/background: [UserNotifications authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications), [CallKit](https://developer.apple.com/documentation/callkit), HealthKit background delivery docs above.
- Android platform: [Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [Schedule alarms](https://developer.android.com/develop/background-work/services/alarms), [AlarmManager](https://developer.android.com/reference/android/app/AlarmManager).
- Flutter packages: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage), [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus), [flutter_background_service](https://pub.dev/packages/flutter_background_service), [supabase_flutter](https://pub.dev/packages/supabase_flutter).
- Supabase: [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [User sessions](https://supabase.com/docs/guides/auth/sessions), [Securing your API](https://supabase.com/docs/guides/api/securing-your-api).
- Health and exercise references: [CDC sleep](https://www.cdc.gov/sleep/about/index.html), [CDC sleep and heart health](https://www.cdc.gov/heart-disease/about/sleep-and-heart-health.html), [AHA target heart rates](https://www.heart.org/en/healthy-living/fitness/fitness-basics/target-heart-rates), [JACC wearable review](https://pmc.ncbi.nlm.nih.gov/articles/PMC10662962/), [HRV methods review](https://pubmed.ncbi.nlm.nih.gov/30416733/), [MedlinePlus pulse oximetry](https://medlineplus.gov/lab-tests/pulse-oximetry/), [NINDS sleep basics](https://www.ninds.nih.gov/health-information/public-education/brain-basics/brain-basics-understanding-sleep).
- Private user-owned wearable export field reference: `docs/WHOORDAN_PRIVATE_WEARABLE_EXPORT_FIELD_MAPPING.md` and aggregate relationship analysis in `docs/WHOORDAN_PRIVATE_WEARABLE_EXPORT_RELATIONSHIP_ANALYSIS.md`. This export was used only to understand field categories, source relationships, and validation examples. third-party scores, formulas, UI, wording, colors, charts, and proprietary behavior were not copied.
- Additional sleep-stage/efficiency references used in the export-mapping pass: [Apple HKCategoryValueSleepAnalysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis), [NCBI MedGen sleep efficiency definition](https://www.ncbi.nlm.nih.gov/medgen/1669302), and [sleep-efficiency denominator discussion](https://pmc.ncbi.nlm.nih.gov/articles/PMC4751425/).

## 2026-05-11 Private Export Validation Update

The private wearable export confirmed that premium recovery apps commonly organize
data into cycle/day summaries, sleep sessions, workout sessions, and journal
habit answers. Whoordan used those categories to improve source-labeled data
support, not to import proprietary scores.

Applied changes:

- Added source-labeled wearable export mapping for direct physiological signals,
  sleep sessions, workouts, and yes/no journal habit answers.
- Explicitly ignored proprietary export outputs such as recovery score, day
  strain, activity strain, and sleep performance as Whoordan inputs.
- Added sleep efficiency support as a standard metric: asleep duration divided
  by in-bed duration when available, or source-reported efficiency when supplied.
- Added source-reported sleep stage duration totals without fabricating stage
  timelines when exact stage intervals are not available.
- Added workout HR-zone percentage support as a lower-confidence activity-load
  input when continuous HR samples are unavailable.
- Added yes/no habit handling so explicit `no` answers are treated as
  without-habit days in association analysis.

Validation added:

- `test/wearable_export_mapper_test.dart`
- new workout-zone strain test in `test/scoring_engine_test.dart`
- new explicit-no habit insight test in `test/journal_habit_test.dart`

## 1. Recovery Score

- Sources used: HealthKit source semantics, CDC sleep references, HRV reviews, AHA HR zone context.
- Formula or method selected: original 0-100 baseline-relative weighted score
  from HRV, resting HR, respiratory rate, sleep sufficiency, and temperature
  deviation when present. The 2026-05-12 private export relationship pass tuned
  the relative weights to HRV 0.35, RHR 0.20, sleep sufficiency 0.17,
  respiratory baseline fit 0.20, and temperature deviation 0.08.
- Why selected: these are common recovery-adjacent signals, but no proprietary scoring is copied; personal baselines reduce brittle population thresholds.
- Assumptions made: higher-than-baseline HRV and adequate sleep support recovery; higher resting HR, respiratory deviation, temperature deviation, or low SpO2 reduce confidence/support.
- Required inputs: at least one contributor with a value and baseline or direct safe bound.
- Optional inputs: HRV, RHR, respiratory rate, sleep duration, sleep
  efficiency/quality when source-labeled, temperature, SpO2 as low/abnormal
  measured-source context only, and consented cycle context as non-scoring
  context.
- Missing-data behavior: absent contributors are skipped, not imputed.
- Outlier behavior: HealthKit and BLE import reject implausible values where implemented; scoring clamps component scores.
- Stale-data behavior: snapshots are day-based; stale-source UI remains partial and should show last import/sample age before release.
- Source priority: wearable BLE, wearable summary, Apple Health, manual entry, cloud import.
- Confidence-level behavior: confidence is proportional to available contributor weight and baseline confidence.
- User-facing explanation: wellness recovery estimate, not medical readiness or illness detection.
- What should not be claimed: diagnosis, illness prediction, training guarantee, third-party score equivalent score.
- Result type: derived estimate.
- Known limitations: no peer-reviewed validation of the composite score; long historical imports still need physical-device performance validation. The relationship pass was a single-user export and must not be treated as population-general.
- Tests added or updated: Swift `CSVSchemaTests` cover aggregate-only benchmark math, Spearman correlation, rolling baselines, bucket agreement, and candidate recovery directionality. Recovery and source-priority tests cover scoring behavior; proprietary recovery output is not imported as a Whoordan score.
- UI behavior: the Recovery screen now displays score, category, confidence,
  source labels, top positive contributors, top negative contributors, and a
  missing-data confidence row. Contributor explanations are tied to the same
  original weights: HRV 0.35, RHR 0.20, sleep sufficiency 0.17, respiratory fit
  0.20, and temperature deviation 0.08. The UI explicitly says the score is not
  medical advice and is not third-party score equivalent.

### 2026-05-12 Export Relationship Findings

- HRV had the strongest recovery relationship in the export: Pearson 0.777 and
  Spearman 0.815 across 61 comparable cycle rows.
- Baseline-relative HRV was stronger: Pearson 0.808 and Spearman 0.826 across
  54 comparable rows.
- Respiratory rate showed a meaningful negative recovery relationship:
  Pearson -0.512 and Spearman -0.499.
- RHR showed a moderate negative recovery relationship: Pearson -0.307 and
  Spearman -0.322.
- Sleep duration was positive but weaker: Pearson 0.250.
- Skin temperature, sleep debt, sleep efficiency, and SpO2 were noisy or
  counter-directional in this export, so they are not dominant recovery
  contributors.
- Adding SpO2 and previous-day strain directly worsened the candidate recovery
  benchmark, so those are kept as low-confidence context rather than copied into
  the main score.

## 2. Strain/Activity-Load Score

- Sources used: AHA heart-rate zone guidance, HRV/wearable review for cautious interpretation.
- Formula or method selected: original 0-21 saturating score from HR zone load,
  workouts, movement, stress load, and strength load.
- Why selected: bounded score avoids unlimited load inflation and mirrors exercise-load principles without proprietary formulas.
- Assumptions made: more time at higher HR intensity and more activity contribute more load.
- Required inputs: at least one activity/load contributor.
- Optional inputs: HR samples, workout duration, workout HR-zone percentages, steps, strength load, stress estimate.
- Missing-data behavior: missing contributors lower confidence.
- Outlier behavior: HR/HealthKit/BLE bounds reject impossible values; score clamps to 0-21.
- Stale-data behavior: daily only; old samples do not affect the current day except baselines.
- Source priority: direct wearable/Apple Health samples before manual and cloud.
- Confidence-level behavior: confidence rises with direct HR and workout evidence; source-reported workout zone percentages are accepted at lower confidence than continuous HR samples.
- User-facing explanation: training-load estimate.
- What should not be claimed: safe-to-train directive, overtraining diagnosis, exact physiological strain.
- Result type: derived estimate.
- Known limitations: not validated against lab workload. The private workout
  export had only 5 rows, enough for ranking sanity checks but not stable bucket
  calibration.
- Tests added or updated: `strain score combines heart load...`, workout-zone fallback strain test, source-priority aggregation tests, and aggregate-only benchmark bucket tests.

### 2026-05-12 Export Relationship Findings

- Activity strain had strong directional correlations with exported workout
  energy, average HR, max HR, and HR zone 4 percentage, but only 5 workout rows
  were available.
- Candidate Whoordan workout strain had Pearson 0.851, Spearman 0.900, and MAE
  2.0 strain points against activity strain, but bucket agreement was only
  40.0%; more workouts are required before tuning buckets.

## 3. Personalized Strain Target

- Sources used: recovery/strain method above; general training-load caution from AHA exercise context.
- Formula or method selected: original recovery-category plus recent-strain target range.
- Why selected: conservative target prevents low-recovery days from encouraging overexertion.
- Assumptions made: recent high strain and low recovery should lower suggested target.
- Required inputs: current recovery category or recent strain.
- Optional inputs: personal baselines and recent strain history.
- Missing-data behavior: falls back to conservative range and low confidence.
- Outlier behavior: uses clamped recovery/strain inputs.
- Stale-data behavior: recent daily history only.
- Source priority: derived from validated daily snapshots.
- Confidence-level behavior: inherits recovery/strain confidence.
- User-facing explanation: optional wellness planning range.
- What should not be claimed: coach replacement or medical activity clearance.
- Result type: derived estimate.
- Known limitations: no sport-specific periodization model.
- Tests added or updated: strain target conservative-low-recovery test.

## 4. Sleep Duration, Sleep Debt, And Sleep Need

- Sources used: CDC adult sleep guidance, NINDS sleep basics, HealthKit sleep category mapping.
- Formula or method selected: sleep need starts from personal baseline when available, otherwise conservative adult minimum guidance; debt compares recent sleep to need. Previous-day strain may raise sleep-need context when source-labeled. Source-reported sleep need/debt from private exports is not imported as the Whoordan truth.
- Why selected: CDC/NINDS provide population context, while personal baseline improves relevance.
- Assumptions made: adults usually need at least 7 hours, but individual needs vary.
- Required inputs: sleep samples or baseline for personalized calculation.
- Optional inputs: naps, strain, sleep consistency, sleep efficiency, performance mode.
- Missing-data behavior: fallback is estimated and low confidence.
- Outlier behavior: sleep samples over 24 hours/day are rejected or ignored.
- Stale-data behavior: recent days drive debt; old data becomes baseline only.
- Source priority: Apple Health/wearable sleep before manual.
- Confidence-level behavior: measured sleep with multiple days has higher confidence.
- User-facing explanation: estimated sleep need/debt, not clinical sleep assessment.
- What should not be claimed: sleep disorder detection.
- Result type: derived estimate.
- Known limitations: no polysomnography validation. The export relationship
  pass showed sleep performance was dominated by achieved sleep duration and
  source-reported stage totals; Whoordan must not fabricate stages from totals
  or weak sensor patterns.
- Tests added or updated: sleep debt/need test, HealthKit sleep category test, and wearable export sleep efficiency mapping tests.

## 5. Sleep Stages And Sleep Quality

- Sources used: Apple HealthKit sleep analysis category semantics and NINDS sleep basics.
- Formula or method selected: HealthKit sleep category values map to stage metadata; awake/in-bed do not count toward sleep duration. Source-reported stage duration totals can be displayed as totals, but Whoordan does not fabricate stage intervals or a timeline from totals alone.
- Why selected: preserves platform-provided category meaning and avoids overcounting.
- Assumptions made: HealthKit stage samples are imported as source-reported categories.
- Required inputs: sleepAnalysis samples with start/end/category.
- Optional inputs: wearable sleep efficiency, sleep consistency, and stage-duration metadata.
- Missing-data behavior: no stage breakdown if no stage metadata.
- Outlier behavior: missing end time, invalid category, or nonpositive duration is dropped.
- Stale-data behavior: last import age should be shown; UI stale display remains partial.
- Source priority: Apple Health or wearable stage source before manual.
- Confidence-level behavior: direct imported stages higher than estimates.
- User-facing explanation: source-reported sleep stage context; stage totals are shown only as totals when interval ordering is unavailable.
- What should not be claimed: medical sleep-stage accuracy.
- Result type: imported/derived from source categories.
- Known limitations: no overlapping-stage interval reconciliation beyond dedupe.
- Tests added or updated: `native Apple Health sleep maps category metadata...`; wearable export sleep stage total and efficiency tests.

## 6. Heart Rate

- Sources used: HealthKit quantity data, BLE package/platform docs, AHA HR context.
- Formula or method selected: direct HR samples; daily average uses source-priority filtered values.
- Why selected: HR is a direct measurement from wearable/HealthKit sources.
- Assumptions made: valid HR range is 25-240 bpm for import acceptance.
- Required inputs: HR samples.
- Optional inputs: source metadata, RSSI, packet IDs.
- Missing-data behavior: UI shows empty/unknown state.
- Outlier behavior: BLE and HealthKit reject implausible bpm.
- Stale-data behavior: last-sample age should be surfaced before release.
- Source priority: wearable BLE first, then Apple Health.
- Confidence-level behavior: BLE normalized packets high confidence; indirect/imported source depends on source.
- User-facing explanation: measured/imported heart rate.
- What should not be claimed: arrhythmia detection from HR stream.
- Result type: measured/imported.
- Known limitations: physical wearable accuracy unvalidated in this session.
- Tests added or updated: BLE normalizer and source-priority aggregation tests.

## 7. Resting Heart Rate

- Sources used: Apple HealthKit resting heart rate type, wearable review context.
- Formula or method selected: imported RHR when available; no internal resting-HR inference was added.
- Why selected: avoids guessing resting state from sparse samples.
- Assumptions made: source-reported RHR is preferable to app-derived guess.
- Required inputs: imported RHR samples.
- Optional inputs: source labels.
- Missing-data behavior: omitted from score/confidence.
- Outlier behavior: HealthKit import rejects values outside 25-180 bpm.
- Stale-data behavior: stale age UI remains partial.
- Source priority: Apple Health or wearable summary before manual.
- Confidence-level behavior: imported direct RHR higher than absent inference.
- User-facing explanation: source-reported resting heart rate.
- What should not be claimed: cardiac diagnosis.
- Result type: imported/measured.
- Known limitations: no overnight-resting algorithm.
- Tests added or updated: HealthKit normalization and scoring tests.

## 8. Heart-Rate Zones

- Sources used: AHA target HR zones.
- Formula or method selected: configurable max HR; fallback age estimate uses 208 - 0.7 * age and labels it estimated.
- Why selected: user-configured max HR is best; fallback is transparent and estimated.
- Assumptions made: zone ranges are intensity bands, not clinical thresholds.
- Required inputs: HR samples and max HR or age fallback.
- Optional inputs: resting HR/config.
- Missing-data behavior: no zone summary without HR.
- Outlier behavior: HR import bounds.
- Stale-data behavior: same-day samples only.
- Source priority: wearable BLE first.
- Confidence-level behavior: configured max HR higher confidence than age estimate.
- User-facing explanation: workout intensity zones.
- What should not be claimed: exact lactate/threshold zones.
- Result type: derived estimate.
- Known limitations: no lab-tested max HR.
- Tests added or updated: configured and fallback HR-zone tests.

## 9. HRV

- Sources used: JACC wearable review and HRV methods PubMed review.
- Formula or method selected: RMSSD for BLE RR intervals; HealthKit SDNN imports are labeled via source metadata.
- Why selected: RMSSD is common for short-term wearable HRV; HealthKit may expose SDNN, so method metadata matters.
- Assumptions made: RR intervals are valid only when supplied by the adapter.
- Required inputs: RR intervals or imported HRV sample.
- Optional inputs: RR count/method metadata.
- Missing-data behavior: skipped; no fake HRV.
- Outlier behavior: BLE/HealthKit reject <=0 or >500 ms.
- Stale-data behavior: daily snapshot only; stale UI partial.
- Source priority: wearable RR-derived RMSSD before Apple Health imported value for daily aggregation.
- Confidence-level behavior: RR count controls BLE HRV confidence.
- User-facing explanation: HRV method and source should be shown where useful.
- What should not be claimed: diagnosis, autonomic disorder detection.
- Result type: measured/derived depending on source.
- Known limitations: PPG-derived HRV can differ from ECG.
- Tests added or updated: RMSSD and malformed-value tests.

## 10. Respiratory Rate

- Sources used: Apple HealthKit respiratory rate and wearable review context.
- Formula or method selected: imported/direct respiratory rate; no internal respiratory estimate from motion/audio.
- Why selected: avoids guessing sensitive physiology.
- Assumptions made: plausible range 4-60 br/min.
- Required inputs: respiratory samples.
- Optional inputs: source labels.
- Missing-data behavior: skipped in recovery/stress.
- Outlier behavior: BLE/HealthKit reject outside range.
- Stale-data behavior: daily only.
- Source priority: wearable summary/BLE, then Apple Health.
- Confidence-level behavior: source-dependent.
- User-facing explanation: source-reported respiratory rate.
- What should not be claimed: breathing disorder detection.
- Result type: measured/imported.
- Known limitations: no physical accuracy validation.
- Tests added or updated: BLE summary respiratory path and HealthKit sanitization.

## 11. Skin/Body/Wrist Temperature

- Sources used: Apple HealthKit temperature types.
- Formula or method selected: imported body/basal/wrist temperature as context; recovery uses deviation from baseline.
- Why selected: deviations are safer than universal thresholds.
- Assumptions made: plausible Celsius range 20-45.
- Required inputs: temperature samples.
- Optional inputs: source type.
- Missing-data behavior: skipped.
- Outlier behavior: HealthKit rejects outside plausible range.
- Stale-data behavior: stale UI partial.
- Source priority: Apple Health/wearable temperature source.
- Confidence-level behavior: baseline confidence affects recovery component.
- User-facing explanation: wellness temperature trend context.
- What should not be claimed: fever, illness, fertility, or pregnancy inference.
- Result type: imported/measured and derived deviation.
- Known limitations: wrist temperature may be relative/device-specific.
- Tests added or updated: HealthKit outlier sanitization.

## 12. Blood Oxygen

- Sources used: HealthKit SpO2 type and MedlinePlus pulse oximetry accuracy context.
- Formula or method selected: direct SpO2 source values only; live tile is neutral display-only.
- Why selected: SpO2 is medically sensitive and consumer readings can be inaccurate.
- Assumptions made: plausible range 70-100 percent.
- Required inputs: SpO2 samples.
- Optional inputs: source and device metadata.
- Missing-data behavior: no value.
- Outlier behavior: BLE/HealthKit reject outside range.
- Stale-data behavior: latest/sample age should be shown later.
- Source priority: wearable BLE, then Apple Health.
- Confidence-level behavior: direct source but not diagnostic.
- User-facing explanation: display-only, not diagnostic.
- What should not be claimed: hypoxia detection or medical-grade oxygen saturation.
- Result type: measured/imported.
- Known limitations: no device accuracy validation.
- Tests added or updated: BLE SpO2 rejection; live UI static guard.

## 13. Stress Score

- Sources used: HRV wearable literature and general HR/HRV physiology context.
- Formula or method selected: original baseline-relative wellness estimate from HR, HRV, respiratory rate, and optional local stress indicators.
- Why selected: avoids mental-health claims and uses personal deviations.
- Assumptions made: elevated HR and lower HRV relative to baseline may indicate body stress.
- Required inputs: at least one contributor.
- Optional inputs: respiratory rate, journal/local indicators.
- Missing-data behavior: low confidence, skipped contributors.
- Outlier behavior: source-level bounds and score clamps.
- Stale-data behavior: daily snapshots only.
- Source priority: direct sources before manual.
- Confidence-level behavior: contributor availability and baseline quality.
- User-facing explanation: body-signal stress estimate.
- What should not be claimed: mental-health assessment, anxiety diagnosis.
- Result type: derived estimate.
- Known limitations: no validated stress model.
- Tests added or updated: stress score baseline test.

## 14. Steps

- Sources used: HealthKit step count, BLE/platform source mapping.
- Formula or method selected: direct step samples summed from highest-priority source only.
- Why selected: prevents double counting Apple Health plus wearable overlap.
- Assumptions made: day boundary uses device-local day.
- Required inputs: step samples.
- Optional inputs: source labels.
- Missing-data behavior: omitted/empty.
- Outlier behavior: HealthKit rejects >200,000/day sample value.
- Stale-data behavior: daily.
- Source priority: wearable BLE, wearable summary, Apple Health, manual, cloud.
- Confidence-level behavior: direct imported steps higher confidence than manual.
- User-facing explanation: source-reported movement.
- What should not be claimed: exact distance/calorie equivalence.
- Result type: measured/imported.
- Known limitations: no stride calibration.
- Tests added or updated: source-priority aggregation.

## 15. Distance

- Sources used: HealthKit walking/running and cycling distance types.
- Formula or method selected: direct/imported distance only; no step-length estimate added.
- Why selected: avoids unsupported profile-based guesses.
- Assumptions made: unit is source-reported distance.
- Required inputs: distance samples.
- Optional inputs: workout metadata.
- Missing-data behavior: absent.
- Outlier behavior: HealthKit rejects >300,000 m sample.
- Stale-data behavior: daily.
- Source priority: Apple Health/wearable direct distance.
- Confidence-level behavior: direct source higher than any future estimate.
- User-facing explanation: measured/imported distance.
- What should not be claimed: exact GPS distance unless GPS source exists.
- Result type: imported/measured.
- Known limitations: no profile-based estimate.
- Tests added or updated: HealthKit type mapping covered by import tests.

## 16. Calories / Active Energy / Total Energy

- Sources used: HealthKit active energy; general exercise-energy caution.
- Formula or method selected: imported active energy is direct; manual workout local estimate uses duration * 6 kcal/min and is labeled in metadata.
- Why selected: imported active energy is source-provided; local estimate is transparent and low-confidence.
- Assumptions made: manual calorie estimate is rough and not personalized.
- Required inputs: active-energy sample or manual workout duration.
- Optional inputs: HR, distance, user profile (future).
- Missing-data behavior: no calorie display.
- Outlier behavior: imported energy rejects >20,000 kcal sample.
- Stale-data behavior: daily.
- Source priority: Apple Health/wearable active energy before manual estimate.
- Confidence-level behavior: imported direct higher; manual duration estimate low.
- User-facing explanation: active energy or estimated calories.
- What should not be claimed: exact calories or total daily energy unless directly sourced.
- Result type: imported or estimated.
- Known limitations: no BMR/total energy model.
- Tests added or updated: manual workout tests and source-priority aggregation.

## 17. VO2 Max / Cardio Fitness

- Sources used: HealthKit VO2 max/cardio fitness; exercise-science caution from wearable review.
- Formula or method selected: import-only; no internal VO2 estimate.
- Why selected: VO2 estimation needs validated model and user/activity inputs.
- Assumptions made: source value is source-reported.
- Required inputs: imported VO2 max.
- Optional inputs: source/time.
- Missing-data behavior: no estimate generated.
- Outlier behavior: HealthKit rejects outside 5-90 mL/kg/min.
- Stale-data behavior: latest value, stale UI partial.
- Source priority: Apple Health import.
- Confidence-level behavior: source import high; no app estimate.
- User-facing explanation: imported cardio fitness.
- What should not be claimed: lab VO2 max or diagnosis.
- Result type: imported.
- Known limitations: no internal model.
- Tests added or updated: cardio fitness import-only test.

## 18. Workout Load

- Sources used: HealthKit workout type, AHA HR intensity context.
- Formula or method selected: workout minutes plus HR-zone load when HR exists.
- Why selected: direct duration is safe; HR improves intensity estimate.
- Assumptions made: source workout duration is valid.
- Required inputs: workout sample duration.
- Optional inputs: average HR, active energy, distance.
- Missing-data behavior: no workout load if no workout/HR data.
- Outlier behavior: workouts over 24 hours are rejected.
- Stale-data behavior: daily.
- Source priority: direct source before manual.
- Confidence-level behavior: direct HR/workout source higher than manual.
- User-facing explanation: workout/activity load estimate.
- What should not be claimed: training prescription.
- Result type: derived estimate.
- Known limitations: no sport-specific TRIMP model.
- Tests added or updated: strain score tests.

## 19. Strength Training / Muscular Load

- Sources used: general load concept; no authoritative formula adopted.
- Formula or method selected: transparent local volume load = sets * reps * weight.
- Why selected: simple, explainable, user-entered, and not proprietary.
- Assumptions made: weight is entered correctly; bodyweight/explosive work are not fully represented.
- Required inputs: sets, reps, weight.
- Optional inputs: exercise name.
- Missing-data behavior: invalid or missing values are not stored.
- Outlier behavior: negative weight and nonpositive sets/reps rejected.
- Stale-data behavior: daily.
- Source priority: manual entry.
- Confidence-level behavior: low/medium because user-entered.
- User-facing explanation: muscular-load estimate.
- What should not be claimed: strength progression diagnosis or injury risk prediction.
- Result type: user-entered derived estimate.
- Known limitations: no RPE/velocity/bodyweight normalization.
- Tests added or updated: strength local action tests.

## 20. Menstrual Cycle Insights

- Sources used: Apple HealthKit menstrual flow type and HealthKit privacy guidance.
- Formula or method selected: display/import only after explicit local consent and HealthKit authorization; no prediction model.
- Why selected: sensitive data requires explicit opt-in and cautious copy.
- Assumptions made: Apple Health is the source of imported cycle data.
- Required inputs: consent and authorized HealthKit type.
- Optional inputs: source metadata.
- Missing-data behavior: hidden/empty state.
- Outlier behavior: invalid category dropped.
- Stale-data behavior: display-only.
- Source priority: Apple Health.
- Confidence-level behavior: imported context only.
- User-facing explanation: optional wellness context.
- What should not be claimed: contraception, fertility, diagnosis, prediction.
- Result type: imported/user-consented context.
- Known limitations: no cycle prediction.
- Tests added or updated: sensitive HealthKit import-type and consent hiding tests.

## 21. Pregnancy-Related Tracking

- Sources used: HealthKit privacy guidance; no platform pregnancy detection source used.
- Formula or method selected: user-declared context only; no automatic detection/import model.
- Why selected: pregnancy is medically sensitive and should not be inferred.
- Assumptions made: any future value must be explicit user entry.
- Required inputs: explicit consent and user entry.
- Optional inputs: none currently.
- Missing-data behavior: hidden/empty state.
- Outlier behavior: not applicable.
- Stale-data behavior: not applicable.
- Source priority: user-entered only.
- Confidence-level behavior: context only, not measurement.
- User-facing explanation: pregnancy context, not detection.
- What should not be claimed: pregnancy test, fetal health, diagnosis.
- Result type: user-entered/scaffolded.
- Known limitations: no data-entry flow beyond consent/context.
- Tests added or updated: UI copy static guard.

## 22. Irregular Rhythm Events

- Sources used: Apple HealthKit irregular rhythm event type and privacy guidance.
- Formula or method selected: Apple Health import/display only after explicit consent; no app detector.
- Why selected: rhythm detection is medical-sensitive and platform/source-controlled.
- Assumptions made: imported events come from Apple Health.
- Required inputs: consent and HealthKit authorization.
- Optional inputs: source labels.
- Missing-data behavior: hidden/empty state.
- Outlier behavior: invalid category dropped.
- Stale-data behavior: display-only.
- Source priority: Apple Health.
- Confidence-level behavior: source-reported, not app-verified.
- User-facing explanation: Apple Health rhythm events, no custom detector.
- What should not be claimed: AFib detection, diagnosis, emergency warning.
- Result type: imported.
- Known limitations: no physical-device validation.
- Tests added or updated: sensitive import-type and disclaimer tests.

## 23. Journal/Habit Recovery Insights

- Sources used: health privacy/correlation caution; no causal model source.
- Formula or method selected: association-only insight after minimum samples on both sides.
- Why selected: prevents causal overclaiming from sparse data.
- Assumptions made: habit logs may correlate with recovery but do not prove cause.
- Required inputs: habit logs and recovery samples.
- Optional inputs: journal tags/mood.
- Missing-data behavior: no insight until minimum samples exist.
- Outlier behavior: confidence gating.
- Stale-data behavior: recent history.
- Source priority: user-entered journal/habits plus derived recovery.
- Confidence-level behavior: confidence included and capped.
- User-facing explanation: association/correlation wording.
- What should not be claimed: causation, treatment, diagnosis.
- Result type: derived estimate.
- Known limitations: no confounder control.
- Tests added or updated: journal/habit insight cautious-language tests.

## 24. Apple Health Data Mapping

- Sources used: Apple HealthKit docs.
- Formula or method selected: native HealthKit samples map to `HealthSample` with source, source record ID, type, unit, start/end, metadata, and dedupe key.
- Why selected: preserves provenance and deduplication.
- Assumptions made: Apple types are supported only where mapped.
- Required inputs: healthKitType, value, start.
- Optional inputs: end, source name/bundle, metadata.
- Missing-data behavior: invalid type/date/value returns null and is dropped.
- Outlier behavior: per-type plausible bounds.
- Stale-data behavior: anchors and last import timestamps.
- Source priority: Apple Health fallback/direct source depending metric.
- Confidence-level behavior: source imported; not medical validation.
- User-facing explanation: source labels where useful.
- What should not be claimed: Apple Health permission guarantees every type is readable.
- Result type: imported.
- Known limitations: partial authorization is hard to prove per read type without actual imports.
- Tests added or updated: HealthKit normalization, outlier, sleep category, sensitive-type tests.

## 25. BLE/Wearable Data Mapping

- Sources used: Android BLE docs and `flutter_blue_plus` docs.
- Formula or method selected: BLE packets normalize to `HealthSample`; packet ID/source metadata create stable dedupe keys.
- Why selected: keeps UI independent from raw protocol frames.
- Assumptions made: adapter protocol exposes supported packet types only.
- Required inputs: parsed packets.
- Optional inputs: RSSI, battery, firmware, RR intervals.
- Missing-data behavior: absent fields skipped.
- Outlier behavior: malformed values rejected.
- Stale-data behavior: diagnostics store last packet time.
- Source priority: wearable BLE first for wearable-native values.
- Confidence-level behavior: packet quality/RR count/RSSI metadata.
- User-facing explanation: connected wearable source.
- What should not be claimed: arbitrary backfill unless protocol supports it.
- Result type: measured/derived.
- Known limitations: explicit range backfill unsupported by adapter.
- Tests added or updated: BLE normalizer, identity update, out-of-order, diagnostics tests.

## 26. Background Sync Behavior

- Sources used: Apple HealthKit background delivery, Android foreground service docs, `flutter_background_service` docs.
- Formula or method selected: foreground/lifecycle sync plus supported background-service scheduler; local-only and no-consent paths are gated before cloud auth/sync.
- Why selected: respects platform limits and avoids fake timers as guaranteed background sync.
- Assumptions made: OS may throttle/stop background work.
- Required inputs: signed-in cloud account and explicit cloud-sync consent.
- Optional inputs: queued jobs, network reconnect.
- Missing-data behavior: queue remains local.
- Outlier behavior: bounded timeout/retry/backoff.
- Stale-data behavior: sync cursors and last-success timestamps.
- Source priority: local queue first; cloud is backup/cross-device.
- Confidence-level behavior: runtime background availability is not fully validated without devices.
- User-facing explanation: background sync is best-effort and platform-limited.
- What should not be claimed: continuous 24/7 background sync guarantee.
- Result type: platform behavior.
- Known limitations: passive network stream; no physical background test.
- Tests added or updated: local-only lifecycle static guard; cloud sync coordinator tests.

## 27. Cloud Sync Behavior And RLS

- Sources used: Supabase RLS, API keys, sessions, API security docs.
- Formula or method selected: publishable/anon client key, signed-in user JWT, RLS enabled/forced, `auth.uid()` owner policies, stable dedupe upserts, checkpoints after success.
- Why selected: Supabase recommends RLS for client-exposed tables and publishable/anon keys for mobile apps; service-role keys are forbidden in clients.
- Assumptions made: migrations are applied to target Supabase project before production.
- Required inputs: Supabase URL/key, authenticated user, explicit cloud consent.
- Optional inputs: category sync preferences.
- Missing-data behavior: blocked state and safe error messages.
- Outlier behavior: RLS denies cross-user rows; client validates active session ownership.
- Stale-data behavior: incremental cursors.
- Source priority: local source records are source of truth for upload.
- Confidence-level behavior: repo-tested schema available; live project still needs migration/advisor remediation applied.
- User-facing explanation: cloud sync only after consent.
- What should not be claimed: production RLS fully verified until dev/live RLS probes pass.
- Result type: platform/security behavior.
- Known limitations: live project advisor warnings remain for leaked password protection and a non-repo `rls_auto_enable()` function.
- Tests added or updated: Supabase schema hardening tests; cloud sync tests.

## 28. Notification/Call/Alarm/Vibration Platform Limitations

- Sources used: Apple UserNotifications, Apple CallKit, Android alarm/foreground-service docs.
- Formula or method selected: vibration patterns/settings are modeled and syncable; wearable preview only when connected and protocol-supported; notification/call mirroring remains honest scaffold.
- Why selected: iOS does not expose a general API to intercept all other apps' notifications/calls for third-party wearable haptics; Android equivalents require sensitive user-granted roles and policy review.
- Assumptions made: exact wearable custom playback needs confirmed firmware protocol.
- Required inputs: connected wearable for preview; user permission for notifications/alarms when implemented.
- Optional inputs: app identifiers for Android notification rules in future.
- Missing-data behavior: disconnected preview returns false; settings are stored.
- Outlier behavior: vibration safety clamps duration/intensity/repeats.
- Stale-data behavior: settings sync after consent.
- Source priority: user settings/local patterns.
- Confidence-level behavior: model tests high; physical playback unvalidated.
- User-facing explanation: configured settings, platform limits where unsupported.
- What should not be claimed: full per-app notification/call haptics on unsupported platforms.
- Result type: user-entered/settings plus platform-scaffolded behavior.
- Known limitations: local alarm scheduling and notification listener not implemented.
- Tests added or updated: vibration model tests; UI accessibility/static guards.
