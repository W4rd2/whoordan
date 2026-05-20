# Whoordan Feature Signal Research

Date: 2026-05-12
Branch: `swift-app`

## Scope

This document maps each Whoordan feature to device packets, possible raw signal
derivations, Apple Health fallback, validation requirements, and safety limits.

Whoordan uses original wellness formulas and must not copy third-party proprietary
formulas, UI, wording, colors, trade dress, or claims.

## Sources Consulted

- Public `public wearable protocol reference` and `public wearable app reference`
  repositories for BLE UUIDs, framing, command flow, packet families, and
  public protocol behavior.
- Apple HealthKit documentation for sleep analysis, quantity samples, workouts,
  and writable HealthKit sample boundaries.
- Peer-reviewed/reputable wearable literature on consumer sleep staging,
  actigraphy, PPG limitations, HRV interval requirements, step counting, and
  respiratory/SpO2 estimation limits.

## Research Summary By Feature

### Sleep Sessions

- Required inputs: decoded device sleep/session record, or validated sleep/wake
  algorithm using motion, HR, HRV/IBI, PPG quality, time-of-day, and inactivity.
- Current source: Apple Health fallback.
- Device candidate: post-wake historical packets, if captured.
- Derivation candidate: experimental sleep/wake detection from inactivity plus
  HR/rest physiology, never production until benchmarked.
- UI rule: label as measured/imported only when source is HealthKit or decoded
  wearable sleep; label research estimates as experimental.
- Implement now: Apple Health fallback and local sleep summary only.

### Sleep Stages

- Required inputs: decoded stage records or validated classifier against
  reference sleep data. HR, HRV, PPG, and motion can inform stages, but wrist
  wearables are not equivalent to PSG.
- Current source: Apple Health stage categories when imported.
- Device candidate: post-wake historical sleep/stage packets.
- UI rule: stages remain unavailable unless measured/imported; no fabricated
  stages from HR/motion.
- Implement now: imported stages only.

### Naps

- Required inputs: decoded nap record, short decoded sleep session, or Apple
  Health sleep analysis.
- Device candidate: post-nap historical sync.
- Derivation risk: resting quietly or low HR is not a nap.
- UI rule: show naps only from verified sleep source.
- Implement now: Apple Health fallback.

### Steps

- Required inputs: decoded device step/activity summary or validated step
  algorithm from IMU.
- Device candidate: all-day activity and walking captures.
- Derivation candidate: wrist IMU step counting, research-only until benchmarked
  against a trusted step source across idle, walking, running, and daily use.
- UI rule: no steps from raw accelerometer/gyro until validation exists.
- Implement now: Apple Health fallback; wearable step packets pending capture.

### Movement / Activity Minutes

- Required inputs: IMU intensity plus HR, or device activity summaries.
- Device candidate: R10 IMU summaries and future activity packets.
- Derivation candidate: experimental movement minutes from IMU variance and HR
  intensity.
- UI rule: estimated movement must be labeled estimate/low confidence.
- Implement now: Apple Health fallback and safe IMU diagnostics only.

### Workouts

- Required inputs: user/manual workout, Apple Health workout, or decoded device
  workout/activity summary.
- Device candidate: workout before/during/after captures.
- Derivation candidate: workout detection from sustained HR plus movement, but
  false positives are likely without user confirmation.
- Implement now: Apple Health/manual fallback.

### Calories / Active Energy

- Required inputs: Apple Health active energy, device direct summary, or
  validated profile-based HR/activity estimate.
- UI rule: estimated energy must be labeled estimate and non-medical.
- Implement now: Apple Health fallback.

### Heart Rate

- Required inputs: standard GATT HR, R10 plausible direct HR byte, or validated
  PPG HR extraction.
- Current source: wearable direct HR and Apple Health fallback.
- Artifact handling: reject implausible values and lower confidence when contact
  is missing.
- Implement now: direct wearable HR when plausible.

### Resting Heart Rate

- Required inputs: stable rest/sleep windows with HR, Apple Health RHR, or
  decoded device RHR.
- Current source: Apple Health fallback.
- Derivation candidate: baseline rest-window median/percentile using wearable HR
  after sleep/rest detection is validated.
- Implement now: fallback/imported only.

### HRV

- Required inputs: true RR/IBI intervals or validated PPG-derived inter-beat
  intervals. BPM alone is insufficient.
- Metrics: SDNN and RMSSD are different measures and must not be mixed.
- Current source: Apple Health HRV fallback.
- Device candidate: R21 or future interval packet if true intervals are
  discovered.
- Implement now: no BLE HRV from BPM.

### Respiratory Rate

- Required inputs: direct device packet, Apple Health respiratory rate, or
  validated sleep-only derivation from PPG/IMU.
- Derivation candidate: research-only until benchmarked.
- UI rule: wellness trend only; no diagnosis.
- Implement now: Apple Health fallback.

### SpO2

- Required inputs: direct calibrated device value or HealthKit oxygen
  saturation. Raw red/IR/optical PPG is not production SpO2.
- Device candidate: explicit calibrated oxygen packet if discovered.
- UI rule: no medical claims; raw PPG remains debug.
- Implement now: Apple Health fallback only.

### Temperature

- Required inputs: direct temperature packet/event and known sensor semantics, or
  Apple Health wrist/body temperature.
- Current BLE status: event scaffold exists, but semantics need physical
  validation.
- UI rule: baseline-relative wellness signal, not illness detection.
- Implement now: device temperature event only as low/medium-confidence event
  until validated.

### Recovery

- Inputs: HRV when true/imported, resting HR, sleep, respiratory rate,
  temperature baseline, SpO2 when direct/imported, recent strain, optional
  cycle context with consent.
- Formula: original Whoordan wellness score, confidence-aware.
- UI rule: "Building confidence" when inputs are missing.
- Implement now: partial, source-aware.

### Strain

- Inputs: HR load/zones, workouts/activity summaries, steps/movement when
  reliable, active energy, manual strength load.
- Formula: original Whoordan activity-load estimate.
- UI rule: no third-party formula copying and no exact equivalence claim.
- Implement now: partial, confidence-aware.

### Stress Signals

- Inputs: HR/HRV baseline deviation and context.
- UI rule: physiological stress language only; no mental-health diagnosis.
- Implement now: not production-ready.

### Body Signals / Health Monitor

- Inputs: trends and baseline deviations for HR, HRV, respiratory rate,
  temperature, SpO2, sleep, strain.
- UI rule: trends only; avoid overinterpreting single days.
- Implement now: partial/missing-data state.

### Cycle / Pregnancy Context

- Inputs: explicit user entry or HealthKit categories with explicit consent.
- UI rule: not contraception, fertility, pregnancy detection, diagnosis, or
  treatment.
- Implement now: not implemented.

### Irregular Rhythm

- Inputs: platform/device imported event only.
- UI rule: no custom AFib detector without clinical validation.
- Implement now: imported-only future work.

### Long-Term Trends

- Inputs: enough local history with source/confidence metadata.
- UI rule: trend wording only.
- Implement now: partial 7-day trends.

## Implementation Position

Direct device metrics currently safe for app use:

- plausible direct HR
- battery/charging/wrist diagnostics when packets arrive
- double tap
- haptic fired/terminated diagnostics
- firmware log summary
- IMU and PPG presence summaries

Metrics needing more captures:

- sleep sessions, stages, naps
- steps and activity summaries
- workouts, calories, strain/load summaries
- true RR/IBI HRV
- respiratory rate
- calibrated SpO2
- validated temperature semantics

Metrics needing algorithm validation before user-facing use:

- sleep/wake derivation
- nap derivation
- step detection from wrist IMU
- movement/activity intensity from IMU plus HR
- respiratory rate from PPG/IMU
- PPG-derived inter-beat intervals

## References

- Apple HealthKit documentation: https://developer.apple.com/documentation/healthkit
- Apple sleep analysis category: https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis
- public wearable protocol reference protocol repository: https://github.com/public wearable protocol reference
- public wearable protocol reference app repository: https://github.com/public wearable app reference
- Consumer sleep technology limitations and validation literature should be
  used before promoting experimental sleep/stage classifiers.
- Raw optical SpO2 derivation requires calibration/validation literature and
  cannot be inferred from debug PPG channels alone.
