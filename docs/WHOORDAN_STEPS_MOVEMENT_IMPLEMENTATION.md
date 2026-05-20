# Whoordan Steps and Movement Implementation

Date: 2026-05-12

## Status

Implemented for source-labeled local samples with wearable-first priority and
Apple Health fallback.

## Today

The Today dashboard shows steps, goal progress, source, confidence, and sync
status independently of recovery confidence. If sleep exists but recovery is
still building, sleep and steps remain visible.

## Movement Screen

The Movement screen shows:

- Today's step count.
- Current step goal.
- Goal progress.
- Active energy when available.
- Walking/running distance when available.
- Last updated time and source.
- 7-day average.
- Best day.
- Simple direction trend.
- Daily step list.
- Missing-data CTAs for Apple Health and wearable pairing.

## Step Goal

Step goal is locally configurable from 1,000 to 40,000 steps in 500-step
increments. The default remains the existing app goal unless changed locally.

## Wearable Status

Reliable wearable step-count packets are not confirmed from current captures.
Whoordan does not derive fake steps from IMU samples. Wearable steps remain
blocked pending device step-count or activity-summary packet capture.

R10 accelerometer/gyroscope packets are retained only as diagnostic movement
context. They can support future algorithm research, but they are not used for
user-facing steps, goal progress, strain, or activity summaries unless a
validated step/activity algorithm is implemented and tested.

## HealthKit Fallback

Apple Health imports step count, active energy, walking/running distance, and
workouts after approval and permission. These records write locally first and
only queue cloud upload when approval and explicit health-data consent allow it.

## Tests

- Wearable steps preferred when reliable step samples exist.
- Apple Health fallback when wearable steps are missing.
- No fake steps from IMU samples.
- Daily aggregation and goal progress.
- Movement trend backed by locally stored summaries.
