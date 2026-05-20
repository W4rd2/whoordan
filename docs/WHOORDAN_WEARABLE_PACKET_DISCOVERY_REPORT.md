# Whoordan Wearable Packet Discovery Report

Date: 2026-05-12
Branch: `swift-app`

## Scope

This report summarizes the currently decoded wearable BLE packet surface. It uses local code, sanitized tests, existing captured-payload summaries, and public public wearable protocol reference protocol references. It does not include raw private payload bytes.

## Decoded Packet Types

| Packet | Characteristic | Current status | Safe app use |
|---|---|---|---|
| `0x24` command response | `61080003` | Implemented for command echo/status, advertising name, HelloHarvard, data range, alarm, historical sync | Device identity fingerprint, battery/charging/wrist from HelloHarvard, init/sync diagnostics |
| `0x28` realtime data | `61080005` | Implemented common data envelope and record-family classification | Direct HR only when R10 has plausible HR; diagnostics otherwise |
| `0x2B` raw realtime data | `61080005` | Implemented frame reassembly and R10/R11/R21 scaffolds | Direct HR, IMU sample-count diagnostic, optical presence diagnostic |
| `0x2F` historical data | `61080005` | Implemented common data envelope | Classification only until record semantics are captured and validated |
| `0x30` event | `61080004` | Implemented event timestamp/type/payload parser | Battery, charging, wrist, double tap, temperature event, haptic fired/terminated when packets appear |
| `0x31` metadata | `61080003`/data stream | Implemented batch-marker/end-of-sync scaffold | ACK token extraction and sync-state diagnostics |
| `0x32` firmware log | `61080007` | Implemented printable diagnostic summary | Redacted firmware/debug status only |

## Confirmed Wearable-Readable Signals

- Frame structure, fragmentation/reassembly, CRC8, and CRC32.
- Command responses and public init sequence commands.
- Device name and serial-like identity converted to a private fingerprint.
- HelloHarvard battery percentage, charging flag, RTC seconds, and wrist state layout.
- Realtime and raw realtime record-family classification.
- R10 plausible direct heart rate.
- R10 complete-packet IMU sample-count diagnostic.
- R11 unsupported raw realtime scaffold.
- R21 complete-packet optical sample/channel-count diagnostic without SpO2 promotion.
- Event type/kind/timestamp parsing for battery, charging, wrist, double tap, temperature, and haptics.
- Standard GATT heart-rate and battery characteristics when exposed.
- Firmware/debug log summaries without raw payload logging.

## Unconfirmed Health Metrics

- Sleep sessions.
- Sleep stage segments.
- Nap records.
- Reliable step counts.
- Activity summaries, strain/load packets, workout summaries, and calories.
- Respiratory rate.
- True HRV from RR/IBI or validated optical intervals.
- Production SpO2.
- Production skin/body temperature.

## Implementation Decisions

- Wearable wins for every metric once a reliable decoded wearable record exists.
- Apple Health remains fallback for sleep, stages, naps, steps, distance, active energy, workouts, HRV, respiratory rate, SpO2, temperature, and VO2.
- Raw IMU is not converted to steps.
- HR and motion are not converted to sleep or naps.
- R21 optical data is not converted to SpO2 or HRV.
- Device temperature events are recorded only as device events until physical validation proves sensor semantics.

## Tests

The current test suite covers frame validation, reassembly, command responses, HelloHarvard parsing, event payload parsing, R10/R11/R21 scaffolds, no fake HRV/SpO2/steps, no fake sleep/naps through aggregators, source priority, and UI privacy for raw payload bytes.

## 2026-05-12 Large Capture Mode Update

The app now records richer developer-only capture JSONL records when manually
started from the debug Device screen after approval. Records include direction,
scenario, decoded packet type when available, connection state, RSSI, decoded
device time when available, app state, characteristic UUID, byte count, and
base64 payload. Capture output remains local-only and is excluded from Supabase
sync and normal app exports.

New code path:

- `WearableCaptureScenario`
- `WearableCaptureDirection`
- `WearableCaptureDiagnostics`
- `WearableRawPayloadCaptureRecord`
- `WearableBLEService.startRawCapture`
- `WearableBLEService.stopRawCapture`
- `WearableBLEService.updateRawCaptureScenario`

Capture is for research and packet classification only. It does not make sleep,
steps, naps, SpO2, HRV, respiratory rate, calories, or workouts available
without additional confirmed packet semantics or validated algorithms.

## 2026-05-12 Physical Capture Analysis

Physical capture was performed from the approved iPhone with local developer
capture enabled. Raw JSONL files were copied to a temporary local analysis
directory outside the repository. No raw payload bytes were copied into this
document.

Aggregate capture inventory:

| Item | Count |
|---|---:|
| Capture files inspected | 16 |
| Capture records inspected | 2,812 |
| Malformed JSON records | 0 |
| Valid reassembled frames | 536 |
| CRC/content-failed frames | 2 |

Scenario record counts:

| Scenario | Records | Notes |
|---|---:|---|
| `idle` | 2,276 | Included init, historical sync start, realtime stream, standard HR, R10/R11-like frames, and historical packets. |
| `wrist_off` | 148 | Included one confirmed wrist-off event and unknown event candidates. |
| `wrist_on` | 46 | Included command responses and realtime packets, but no confirmed wrist-on event in this capture. |
| `double_tap` | 142 | Included two confirmed double-tap events across the full capture set. |
| `unknown` | 200 | Older debug captures without scenario labels. |

Characteristic counts:

| Characteristic | Records |
|---|---:|
| `61080005` data | 2,610 |
| `2A37` standard HR | 141 |
| `61080003` command response | 24 |
| `61080002` command write | 18 |
| `61080004` events | 7 |
| `2A19` standard battery | 6 |
| `2A29` manufacturer/name | 6 |

Packet families observed after safe reassembly:

| Packet family | Frames |
|---|---:|
| `0x2B` raw realtime data | 292 |
| `0x28` realtime data | 154 |
| `0x2F` historical data | 46 |
| `0x24` command response | 24 |
| `0x23` command write | 8 |
| `0x30` event | 8 |
| `0x31` metadata | 3 |
| `0x32` firmware log | 1 |

Confirmed wearable-readable records from this capture:

- Standard BLE heart-rate notifications were observed.
- Standard BLE battery notifications were observed.
- R10-like IMU/HR records were observed.
- R11-like raw/scaffold records were observed.
- Historical-data frames were observed, but record semantics remain
  unconfirmed.
- A battery event was observed.
- A wrist-off event was observed.
- Double-tap events were observed.
- Firmware log classification was observed.

Unconfirmed after this capture:

- Sleep session records.
- Sleep stage records.
- Nap records.
- Explicit step-count records.
- Activity summary or workout summary records.
- Charging-start/charging-stop events.
- Wrist-on event.
- Haptic fired/terminated events.
- Alarm fired/snoozed/dismissed events.
- True RR/IBI intervals.
- Respiratory rate.
- Calibrated SpO2.
- Calorie or distance records.

Decoder decision: no new production health metric decoder was added from this
capture. Existing decoders for standard HR, standard battery, command responses,
R10/R11 scaffolds, wrist-off, battery event, double-tap, metadata, historical
packet classification, and firmware logs are now physically supported by this
capture set. Unknown events and historical records remain preserved only as
diagnostics until more scenario-specific captures confirm semantics.
