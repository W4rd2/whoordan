# Whoordan BLE Feature Capability Matrix

Date: 2026-05-12

## Scope

Public `public wearable app reference` and `public wearable protocol reference`
references were used only as protocol references. Whoordan does not claim
official wearable-device manufacturer support and does not copy third-party UI, wording, colors, formulas,
trade dress, or proprietary analytics.

Raw private BLE captures stay local-only and are not committed or pasted into
docs. This matrix classifies app-visible capability from current Swift decoders,
sanitized tests, and prior aggregate capture inventory.

## Status Legend

- `CONFIRMED_USABLE`: can be used by app logic when received and plausible.
- `IMPLEMENTED`: implemented in code and unit-tested with synthetic/minimized
  fixtures.
- `IMPLEMENTED_NOT_PHYSICALLY_VALIDATED`: code exists but needs a fresh
  physical wearable run.
- `UNCONFIRMED_PENDING_CAPTURE`: protocol/capture evidence is not enough yet.
- `UNSAFE_TO_EXPOSE`: raw signal exists but user-facing production metric would
  be misleading or unvalidated.
- `BLOCKED_PLATFORM_OR_CONFIG`: blocked by approval, Bluetooth permission,
  HealthKit permission, signing, or unavailable hardware/config.

## Matrix

| Feature | Status | Whoordan behavior |
|---|---|---|
| BLE service/characteristics | IMPLEMENTED | Uses service `61080001`, command write `61080002`, command response `61080003`, events `61080004`, data `61080005`, diagnostics `61080007`. |
| Connection flow | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Scan, connect, discover services/characteristics, subscribe to notify/indicate characteristics, then send init after subscriptions are active. Disconnect resets local state. |
| Frame decoder | CONFIRMED_USABLE | Validates `0xAA`, little-endian length, CRC8 over length, inner payload, CRC32 over inner content; malformed frames are rejected and counted. |
| Fragment reassembly | IMPLEMENTED | Reassembles split/tail frames, skips null padding, rejects orphan fragments, tracks dropped fragments. |
| Command responses | CONFIRMED_USABLE | Decodes command byte, status, payload count, device name, HelloHarvard fields, data-range candidates, alarm status, and historical-sync response scaffold. |
| Historical sync ACK | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Detects `AA 1C 00 AB 31` metadata batch markers, extracts the 8-byte batch token, sends ACK, and checkpoints only through local pipeline callbacks. |
| End-of-sync / realtime enable | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Non-batch metadata marks end-of-sync and enables HR, R10/R11, R21, and optical streams. |
| Heart rate | CONFIRMED_USABLE | Emits plausible R10 HR and standard Bluetooth HR as wearable-source HR samples. |
| Resting heart rate | UNCONFIRMED_PENDING_CAPTURE | No wearable RHR summary packet is confirmed; use HealthKit fallback or derived non-wearable summaries only when explicitly implemented. |
| HRV | UNSAFE_TO_EXPOSE | No true RR/IBI or validated PPG interval decoder exists. BPM-only HR is never converted to HRV. |
| Respiratory rate | UNCONFIRMED_PENDING_CAPTURE | No validated respiratory packet or formula exists. |
| SpO2 | UNSAFE_TO_EXPOSE | R21 raw/debug PPG is summarized only; no calibrated production SpO2 is shown. |
| Temperature | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Event type `17` is parsed as a device temperature event and labeled as non-clinical sensor context. |
| Sleep sessions | UNCONFIRMED_PENDING_CAPTURE | No decoded wearable sleep/session packet exists. Apple Health remains fallback. |
| Sleep stages | UNCONFIRMED_PENDING_CAPTURE | No decoded wearable stage packet exists; stages are shown only when imported/measured. |
| Naps | UNCONFIRMED_PENDING_CAPTURE | No decoded wearable nap/session packet exists; no HR/motion-only nap inference. |
| Steps | UNCONFIRMED_PENDING_CAPTURE | No reliable device step packet is decoded; raw IMU is not converted into steps. |
| Movement | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | R10 accelerometer/gyroscope axes are summarized as diagnostic IMU batches, not user-facing steps. |
| Workouts/activity summaries | UNCONFIRMED_PENDING_CAPTURE | No workout/activity summary record has been confirmed from current captures. |
| Calories/energy | UNCONFIRMED_PENDING_CAPTURE | No validated wearable calories packet is decoded; HealthKit active energy remains fallback. |
| Battery | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Parsed from standard Battery Level, HelloHarvard, or event type `3` when present. |
| Charging | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Event types `7` and `8` and HelloHarvard charging state update diagnostics. |
| Wrist status | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Event types `9` and `10` and HelloHarvard wrist state update diagnostics. |
| Haptics | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Builds Harvard `0x4F`, Maverick/Gen4 `0x13`, and stop `0x7A`; fired/terminated confirmation updates only when events arrive. |
| Double tap | IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | Event type `14` is classified as double tap. |
| Firmware logs | IMPLEMENTED | Null-terminated ASCII diagnostic summaries are parsed; raw payloads are not user-exposed. |
| Raw PPG/R21 | UNSAFE_TO_EXPOSE | LED drive, sample counts, and channel summaries are stored as raw/debug diagnostics only. |
| R11/R20/R7 | UNCONFIRMED_PENDING_CAPTURE | Identified as packet families but not converted to user-facing metrics until semantics are validated. |

## Gate Requirements

- BLE scanning/connection is blocked unless admin approval is confirmed.
- Health samples are written locally first through the ingestion pipeline.
- Supabase upload still requires approval plus explicit cloud and health-data
  consent.
- Raw debug capture requires explicit local opt-in and is not production logging.

## Next Captures

1. Post-wake historical sync for sleep/session/stage packets.
2. Nap historical sync after a known nap.
3. All-day activity capture before and after known step counts.
4. Workout before/during/after capture.
5. Battery, charging, wrist on/off, temperature, haptic fired/terminated, and
   alarm event captures.
6. R21 optical capture during stable sampling to determine whether RR/IBI-like
   intervals are available without claiming HRV or SpO2 prematurely.
