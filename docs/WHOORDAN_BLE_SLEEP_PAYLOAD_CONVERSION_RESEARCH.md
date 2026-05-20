# Whoordan BLE Sleep Payload Conversion Research

This note defines the current safe path for converting overnight Whoordan BLE payload exports into sleep data. It intentionally avoids raw payload bytes and remains wellness-only.

## Current Local Capability

- Standard GATT heart-rate packets (`2A37`) can provide heart rate and optional RR intervals.
- Proprietary `61080005` payloads are reassembled into validated frames before decoding.
- Current R10 decoding exposes heart rate, raw contact/wrist temperature, accelerometer arrays, and gyroscope arrays.
- Current R10-derived sleep estimates require complete chunks, HR in a plausible sleep range, and low accelerometer/gyro motion. They emit low-confidence `sleepAnalysis` samples with `metric_policy = r10_hr_imu_sleep_stage_estimate`.
- `SleepAggregator` groups sleep-analysis samples into sessions, requires at least 20 minutes for Whoordan estimates, includes a previous-evening lookback, and can refine stages using session context and nearby HR/HRV.

## Public Research Summary

- Apple Health represents sleep as category samples, including awake, in-bed/asleep, and stage categories such as core, deep, and REM. Whoordan should map derived sleep into these categories only when the app labels the source and confidence clearly. Source: [Apple HealthKit sleep analysis documentation](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis).
- Bluetooth Heart Rate Service packets include flags, heart-rate measurement values, optional energy-expended values, and optional RR-Interval subfields. Whoordan can use `2A37` HR/RR where emitted, but RR intervals are not guaranteed in every notification. Source: [Bluetooth SIG Heart Rate Service 1.0](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/HRS_v1.0/out/en/index-en.html).
- AASM describes actigraphy-based wearables as movement-based sleep estimation, often improved with PPG-derived HRV, respiratory rate, SpO2, temperature, and light. It also emphasizes validation context and limits. Source: [AASM actigraphy technology guidance](https://aasm.org/staying-current-with-actigraphy-devices-for-sleep-wake-monitoring/).
- AASM clinical guidance treats actigraphy as useful for specific sleep/circadian assessments, but it is not the same as full polysomnography and does not make consumer staging medically definitive. Source: [AASM actigraphy clinical practice guideline](https://pmc.ncbi.nlm.nih.gov/articles/PMC6040807/).
- Wearable sleep staging literature commonly uses 30-second or 60-second epochs with accelerometry plus PPG/HR/HRV features. Published models show that sleep/wake can be stronger than detailed stage classification; stage outputs need labeled validation before promotion. Sources: [raw acceleration + PPG sleep staging study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/) and [HR-based wearable sleep staging validation](https://pmc.ncbi.nlm.nih.gov/articles/PMC9584568/).

## Conversion Pipeline

1. Copy overnight export ZIPs from `On My iPhone > Whoordan > whoordan-ble-debug` to a local analysis directory.
2. Extract ZIPs without printing payload contents.
3. Load JSONL records and summarize only counts, file names, timestamps, characteristic UUIDs, directions, and decoded packet labels.
4. Reassemble `61080005` fragments into validated frames using length, CRC8, and CRC32 checks.
5. Decode direct sources:
   - `2A37` HR and optional RR intervals.
   - R10 HR, raw contact/wrist temperature, accelerometer, and gyroscope.
   - Events for wrist/charging context where validated.
6. Convert R10 windows into sleep candidate epochs:
   - reject off-wrist or charging windows when events prove them,
   - reject high-motion/high-gyro windows,
   - reject high-HR windows outside plausible sleep/rest bounds,
   - mark accepted windows as low-confidence Whoordan estimates.
7. Aggregate accepted epochs into sessions:
   - group gaps up to 90 minutes,
   - require at least 20 minutes for an estimated session,
   - assign main sleep versus naps by duration,
   - calculate asleep minutes, in-bed minutes, efficiency, and stage totals.
8. Validate before promotion:
   - compare to Apple Health or exported sleep onset/wake/stage labels,
   - report duration error, onset/wake error, sleep/wake precision/recall, and stage agreement,
   - keep UI wording as estimated until evidence is strong.

## 2026-05-17 Overnight Export Analysis

Two local ZIP exports were analyzed from Ward's Downloads folder without printing raw payload bytes.

| Export | Raw JSONL files | Raw records | UTC coverage | Qatar coverage | R10 records | R10 sleep candidate packets | Candidate minutes |
|---|---:|---:|---|---|---:|---:|---:|
| `whoordan-ble-debug.zip` | 20 | 428,691 | 2026-05-16 21:03:44 to 2026-05-17 03:55:20 | 2026-05-17 00:03:44 to 06:55:20 | 24,246 | 12,484 | 264 |
| `whoordan-ble-debug 2.zip` | 35 | 723,306 | 2026-05-16 21:03:44 to 2026-05-17 08:22:21 | 2026-05-17 00:03:44 to 11:22:21 | 40,493 | 24,299 | 512 |

The second ZIP is the fuller export and includes the earlier overnight window plus later morning records. It contains:

- 681,831 `61080005` protocol notifications.
- 40,216 standard `2A37` heart-rate notifications.
- 115,324 CRC-valid protocol frames.
- 40,493 complete R10 HR/IMU records.
- Heart-rate range of 52-118 bpm across `2A37` and R10-derived streams.
- 40,680 valid RR intervals in standard heart-rate packets.
- 24,299 R10 packets passing the current sleep HR + stillness gates.

The privacy-safe minute bucket output produces one estimated sleep session from the fuller export:

| Session | Qatar start | Qatar end | Candidate minutes | Session span |
|---|---|---|---:|---:|
| Main low-confidence estimate | 2026-05-17 02:18 | 2026-05-17 11:23 | 512 | 545 minutes |

Candidate packet stage labels from the current heuristic were mostly `asleep`, with some `core` and a small number of `deep` packets. These are classifier labels, not verified sleep-stage ground truth.

## Product Boundary

There is still no proven direct proprietary sleep-session or sleep-stage packet semantic in the current evidence. The app may use the R10 HR+IMU pathway as a low-confidence wellness estimate, but it must not present it as medical sleep staging or as exact proprietary-device sleep decoding.

## Next Engineering Step

Add an offline importer/analyzer for local ZIPs that produces privacy-safe summaries plus derived `sleepAnalysis` rows. The app ingestion path can then reuse the existing `HealthIngestionPipeline` and `SleepAggregator` behavior after the derived samples pass validation gates.
