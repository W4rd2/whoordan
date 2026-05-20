# Whoordan Captured BLE Payload Analysis

Date: 2026-05-12

## Privacy Handling

Raw captures remain outside the repository and must not be committed, pasted into docs, or uploaded. The repo uses minimized synthetic fixtures that preserve packet shape without private payload bytes, private raw identifiers, or personal health values.

## Files Inspected

- Local raw debug JSONL outside the repo, reviewed only as aggregate packet inventory.
- Local warning file beside the private debug capture, confirming that raw capture output is local-only and non-committable.

## Captured Characteristics

- Command response characteristic: `61080003-8D6D-82B8-614A-1C8CB0F8DCC6`
- Sensor/data characteristic: `61080005-8D6D-82B8-614A-1C8CB0F8DCC6`

## Packet Inventory

The capture contained 25 BLE notification records and 11 valid reassembled frames:

- `0x24` command response: 5 frames
- `0x28` realtime data: 1 frame
- `0x2B` raw realtime data: 2 large fragmented frames
- `0x30` event: 1 frame
- `0x31` metadata: 1 frame
- `0x32` firmware log: 1 frame

No malformed captured frames were needed for production parsing. Tests still cover malformed and orphan fragments.

## Fields Decoded

- Frame start byte, length, CRC8, inner payload, CRC32.
- Packet type.
- Packet sequence byte where present.
- Command response command byte, status byte, payload byte count.
- Advertising-name command response string.
- Hello/device response serial-like value as a private input to a stable fingerprint only.
- Data-range response date candidates from plausible little-endian timestamp fields.
- Alarm response configured/not-configured scaffold.
- Historical-sync command response status scaffold.
- Metadata end-of-sync candidate and batch-marker scaffold.
- Realtime/raw realtime record type.
- R10 plausible direct HR byte when present and in range.
- R10 IMU sample-count summary.
- R11 record identification as unsupported raw realtime scaffold.
- R21 sample-count/channel-count scaffold when present.
- Event timestamp, type, kind, and supported numeric event payloads.
- Double-tap event type `14`.
- Battery event type `3` payload parser when present.
- Charging event types `7` and `8`.
- Wrist event types `9` and `10`.
- Temperature event type `17` payload parser when present; this remains a device event, not a clinical body-temperature claim.
- Haptic event scaffolds for types `60` and `100`.
- HelloHarvard battery, charging state, RTC, wrist state, and fingerprinted serial-like identity.
- Firmware log printable text and `Sensors` category.
- Stable dedupe IDs from source metadata without raw private identifiers.

## Attempted But Still Unknown

- Full R10 accelerometer/gyroscope axis scaling.
- R11 payload semantics.
- R20/R7 semantics.
- R21 calibrated optical channel semantics.
- Historical sync checkpoint semantics beyond metadata/end marker and ACK scaffolding.
- Exact alarm payload field layout.
- Exact data-range field names beyond plausible timestamp candidates.
- Firmware log full message continuation when the packet is truncated.

## Usable Signals Now

- Direct wearable HR only when a plausible decoded HR value is present.
- Battery from standard Bluetooth Battery Level, HelloHarvard, or event type `3` when received.
- Charging state from event types `7` and `8`.
- Wrist state from event types `9` and `10`.
- Double tap from event type `14`.
- Haptic fired/terminated scaffolds from event types `60` and `100`.
- Device temperature event parsing from event type `17` when received; not promoted as production body temperature.
- Firmware diagnostic text summary.
- IMU presence/sample-count summary from R10.
- PPG presence/sample-count summary from R21, without medical interpretation.

## Not Safe Yet

- True HRV from BPM-only data.
- Medical-grade or production SpO2 from raw PPG.
- Steps from accelerometer without a validated algorithm or native device step packet.
- Calories from unvalidated wearable packets.
- Sleep stages without HealthKit or decoded device sleep packets.
- Respiratory rate without a validated source.
- Production body/skin temperature until the temperature event is physically validated and mapped to the correct sensor semantics.

## Tests Added

- Base64 JSONL dev fixture parser.
- Command response parsing.
- Advertising name parsing.
- Serial-like fingerprint parsing without exposing raw identifiers.
- Data range response parsing.
- Alarm and historical sync response scaffolds.
- Metadata packet parsing.
- Realtime `0x28` parsing.
- Fragmented raw realtime `0x2B` reassembly.
- R10 HR/IMU summary.
- R11 unsupported scaffold.
- R21 optical scaffold.
- Double-tap event parsing.
- Haptic event scaffold.
- Firmware log parsing.
- Malformed/orphan fragment rejection.
- No HRV/SpO2/steps emitted from unsupported data.
- Stable dedupe ID generation.
- Approval gate blocks BLE processing before approval.

## Next Captures Needed

- Post-wake historical sync covering sleep/session records.
- Nap historical sync after a known nap.
- All-day activity/steps capture before and after walking.
- Workout before/during/after capture.
- Battery event type `3`.
- Charging events `7` and `8`.
- Wrist on/off events `9` and `10`.
- Temperature event `17`.
- Haptic fired/terminated events `60` and `100`.
- R21 optical packet during stable optical sampling.
- True RR/IBI packet if available.
- Device step-count packet if available.
- Longer historical sync session with multiple metadata markers and ACK responses.

## 2026-05-12 Sleep and Steps Update

Current captured payloads still do not confirm sleep sessions, sleep stages, nap
records, or reliable step-count/activity-summary records. Whoordan therefore
keeps wearable sleep, naps, and steps blocked pending additional device packet
capture and uses Apple Health as fallback. Raw IMU and heart-rate-only rest are
not converted into sleep, naps, or steps.

## 2026-05-12 Public Protocol Reference Update

The Swift decoder was checked against the public `public wearable protocol reference` protocol
references and updated where current packet semantics are safe:

- R10 now records summarized accelerometer and gyroscope axis ranges/counts from
  the documented fixed offsets. These summaries remain diagnostic IMU data and
  are not converted into steps, sleep, naps, strain, or activity records.
- R21 now records LED drive level, primary/secondary sample counts, and
  per-channel PPG summaries. These are raw/debug optical summaries only and are
  not promoted to production SpO2 or true HRV.
- Event decoding now classifies realtime HR start/stop, alarm set/fired/disabled,
  haptics fired/terminated, battery, charging, wrist, double tap, and
  temperature events.
- Firmware logs now prefer null-terminated ASCII diagnostic messages and do not
  expose raw binary payload bytes.
- Reassembly diagnostics now count orphan/dropped fragments, and malformed
  frames are counted after CRC/length rejection.

No new physical captures were added in this pass. Sleep sessions, sleep stages,
naps, reliable steps, workouts, calories, respiratory rate, true RR/IBI HRV, and
production SpO2 remain unconfirmed pending targeted captures.

## 2026-05-12 Large Capture Mode Update

The capture path was upgraded from environment-only minimal records to a
manual, scenario-labeled developer mode on the Device screen. The new local JSONL
schema records:

- app capture timestamp
- BLE characteristic UUID
- byte count
- direction (`notify` or `write`)
- base64 payload
- decoded packet type when available
- connection state
- RSSI
- decoded device timestamp when available
- app foreground/background state when known
- scenario label

The capture directory remains private app-sandbox debug data. It is not uploaded
to Supabase, not included in normal exports, and not shown as raw bytes in the
UI. Source-controlled docs must continue to report aggregate counts and
sanitized packet-family summaries only.

## 2026-05-12 Physical Capture Aggregate

The approved iPhone produced local developer capture files with the wearable
connected. Files were copied to a temporary directory outside the repository for
aggregate analysis only. No raw payload strings, raw identifiers, or private
health values were copied into this document.

Aggregate counts:

| Category | Count |
|---|---:|
| JSONL files inspected | 16 |
| Capture records inspected | 2,812 |
| Valid reassembled Wearable-protocol frames | 536 |
| Content-CRC failed frames | 2 |
| Malformed JSON records | 0 |

Scenario counts:

| Scenario | Records | Valid frames |
|---|---:|---:|
| `idle` | 2,276 | 434 |
| `wrist_off` | 148 | 28 |
| `wrist_on` | 46 | 10 |
| `double_tap` | 142 | 25 |
| `unknown` | 200 | 39 |

Characteristic distribution:

| Characteristic | Records | Interpretation |
|---|---:|---|
| `61080005` | 2,610 | Primary data/realtime/historical stream. |
| `2A37` | 141 | Standard BLE heart-rate measurement. |
| `61080003` | 24 | Command response notify. |
| `61080002` | 18 | App command writes captured for correlation. |
| `61080004` | 7 | Wearable event notify. |
| `2A19` | 6 | Standard BLE battery level. |
| `2A29` | 6 | Standard device/manufacturer text characteristic. |

Packet-family distribution from valid frames:

| Packet | Frames |
|---|---:|
| `0x2B` raw realtime | 292 |
| `0x28` realtime | 154 |
| `0x2F` historical | 46 |
| `0x24` command response | 24 |
| `0x23` command | 8 |
| `0x30` event | 8 |
| `0x31` metadata | 3 |
| `0x32` firmware log | 1 |

Record/event observations:

- Standard heart-rate notifications: observed.
- Standard battery notifications: observed.
- R10-like IMU/HR records: observed.
- R11-like companion raw records: observed and kept as scaffold/diagnostic.
- Historical data frames: observed, but the `0x2F` record semantics are not
  confirmed as sleep, steps, activity, or workout data.
- Event `3` battery level: observed.
- Event `10` wrist off: observed.
- Event `14` double tap: observed.
- Unknown event candidates were observed and left unpromoted.
- Haptic fired/terminated, alarm, charging, wrist-on, temperature, RR/IBI,
  respiratory, calibrated SpO2, sleep, nap, step, calorie, and distance records
  were not confirmed by this capture set.

Safe app-use update:

- Existing standard HR, standard battery, R10 diagnostic, R11 scaffold,
  wrist-off, double-tap, command-response, metadata, historical packet
  classification, and firmware-log decoders are supported by this physical
  capture set.
- No new production health metric was added from the historical frames or
  unknown events.
- Apple Health remains fallback for sleep, naps, stages, steps, workouts,
  distance, active energy, HRV, respiratory rate, SpO2, and temperature until
  targeted packet captures or validated algorithms provide stronger evidence.
