# Whoordan Scoring Engines

These formulas are original Whoordan heuristics for wellness and fitness feedback. They are not medical guidance, diagnosis, treatment, prevention, or cure claims. Scores should be shown with confidence and missing-data context.

## Baselines

Whoordan builds personal rolling baselines for each signal over 14, 30, and 60 days. The primary window prefers the 30-day baseline when it has enough data, then 14-day, then 60-day, then the best available window.

Each baseline stores count, mean, standard deviation, personal normal range, and confidence. Normal range is the mean plus or minus the larger of observed standard deviation or a signal-specific minimum spread, so flat data does not create brittle scoring.

## Recovery

Recovery is scored from 0 to 100 when at least one weighted contributor is available. The default scoring contributors are HRV, resting heart rate, sleep sufficiency, respiratory baseline fit, and temperature deviation. SpO2 is displayed as measured/source-labeled context only and has zero recovery-score weight.

The engine compares each baseline signal to the user's own history once enough prior baseline days exist. Higher HRV is supportive, lower resting heart rate is supportive, and respiratory rate and temperature use centered deviation. Sleep duration compares against the sleep-need estimate when available.

Missing contributors are skipped rather than imputed. Confidence is the available contributor weight multiplied by contributor baseline confidence.

Categories:
- High: 70-100
- Medium: 45-69.99
- Low: 0-44.99

## Strain

Strain is scored from 0 to 21. It combines heart-rate zone load, workouts, movement, strength load, and physiological stress load. Heart-rate zone load uses configurable max HR and actual HR coverage or movement duration; raw HR sample count is not treated as active minutes.

The load-to-score curve is saturating, so additional load has diminishing effect. Missing contributors lower confidence instead of being filled with fake values.

## Strain Target

The personalized target uses recovery category and recent strain. Low recovery keeps the target conservative and avoids language that encourages overexertion. Recent high strain reduces the upper target.

## Sleep Need And Debt

Sleep need starts from the user's personal sleep-duration baseline once enough source-labeled sleep history exists; otherwise it uses a conservative adult-range baseline with low confidence. Recent prior-day strain and prior sleep debt make bounded adjustments.

## Stress

Stress is a cautious physiological body-signal estimate from heart rate, HRV, respiratory rate, and optional local stress indicators relative to personal baselines. It is not a mental-health assessment.

## Cardio Fitness

Whoordan reads imported VO2 max / cardio fitness values when present. Low-confidence VO2 estimates are labeled as beta estimates and require resting HR plus configured or age-estimated max HR.
