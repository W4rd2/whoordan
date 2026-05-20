# Whoordan Wearable Sleep and Steps Capability

Date: 2026-05-12

## Policy

Whoordan is device-first when the wearable protocol provides reliable,
source-labeled health records. Apple Health is the fallback and assistant source
when wearable records are absent, stale, lower confidence, unsupported, or not
decoded yet. Unsupported metrics are not inferred from adjacent signals.

## Confirmed From Current Captures and Decoders

- Frame structure, length, CRC8, payload, and CRC32.
- Fragment reassembly for large realtime packets.
- Command responses, advertising name, fingerprinted serial-like identity, data
  range candidates, alarm scaffold, and historical-sync scaffold.
- Metadata packets and batch ACK scaffold.
- Realtime/raw realtime packet types `0x28` and `0x2B`.
- R10-like record with plausible direct HR and IMU sample-count summary.
- R11-like raw realtime scaffold, unsupported for production health metrics.
- R21-like optical sample-count summary, not production SpO2.
- Event packets including double tap and scaffolded battery, charging, wrist,
  temperature, haptic fired, and haptic terminated event kinds.
- HelloHarvard battery, charging, RTC, wrist state, and fingerprinted identity.
- Structured event payload parsing for battery percentage and device
  temperature event values when those packets are captured.
- Firmware/debug log summary without raw payload logging.
- Standard GATT Heart Rate Measurement and Battery Level when exposed.

## Not Confirmed Yet

- Wearable sleep-session records.
- Wearable sleep-stage records.
- Wearable nap records.
- Reliable wearable step-count or activity-summary records.
- Calories from wearable packets.
- Respiratory rate from wearable packets.
- True HRV from RR/IBI data.
- Production-grade SpO2 from calibrated optical decoding.
- Skin temperature as a production metric.

## Current Product Behavior

- Wearable heart rate can be emitted when directly decoded and plausible.
- Wearable sleep, naps, and steps remain
  `BLOCKED_PENDING_DEVICE_PACKET_CAPTURE`.
- Apple Health sleep analysis is used as fallback for sleep sessions, stages,
  naps, efficiency, and sleep history.
- Apple Health step count, distance, active energy, and workouts are used as
  fallback movement sources.
- IMU and heart-rate-only rest are not classified as sleep or naps.
- Raw accelerometer/gyroscope samples are not converted to steps.
- Device temperature events are not presented as production body temperature.

## Packet Captures Needed

- Longer historical sync capture with complete batch markers, ACK responses, and
  post-sleep morning records.
- Device step-count or activity-summary packet captured before and after walking.
- Sleep-session and sleep-stage packet captured after a full night.
- Nap record capture after a known nap if the device exposes nap records.
- Battery, charging, wrist, and temperature events captured separately for event
  value validation.
- RR/IBI packet if the wearable exposes true beat-to-beat intervals.
