# Whoordan Sleep Feature Implementation

Date: 2026-05-12

## Status

Implemented for source-labeled local samples with wearable-first priority and
Apple Health fallback.

## User-Visible Sleep Data

- Last sleep duration.
- Bedtime and wake time.
- Time in bed.
- Awake time when the source provides awake segments.
- Sleep efficiency from measured session timing.
- Source and confidence labels.
- Naps from verified sleep-session samples.
- 7-night average.
- Bedtime consistency.
- Wake consistency.
- Conservative sleep need estimate.
- Sleep debt estimate.
- Suggested bedtime based on last measured wake time until a target-wake setting
  exists.

## Stages

Sleep stages are displayed only when HealthKit or a decoded wearable sleep
record provides categories. Supported normalized stages are in bed, asleep,
awake, REM, core, deep, and unclassified. The app does not invent stages.

## Wearable Status

Wearable sleep, naps, and stages are not decoded from current packets. They are
blocked pending additional device packet capture. If decoded wearable sleep
records become available, they will outrank Apple Health by source priority.

Current BLE decoders intentionally do not convert R10 HR, IMU motion, R21
optical presence, or firmware events into sleep, naps, or sleep stages. The
required next evidence is a post-wake historical sync containing explicit
sleep-session/stage records or another validated device sleep packet family.

## HealthKit Fallback

HealthKit sleep analysis is imported through anchored/incremental queries after
approval and user permission. Overnight fallback import starts before the local
day boundary so morning sleep can be visible after app launch.

## Tests

- Wearable sleep preferred over Apple Health.
- Apple Health fallback when wearable sleep is missing.
- Nap classification from verified sleep samples.
- Stage totals and efficiency.
- No nap from motion-only or heart-rate-only samples.
- Sleep need and debt summary.
