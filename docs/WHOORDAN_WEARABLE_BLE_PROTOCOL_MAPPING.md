# Whoordan Wearable BLE Protocol Mapping

Date: 2026-05-11

## Public References Inspected

- Public BLE protocol notes and compatible-device behavior references.
- Local sanitized packet summaries and synthetic regression fixtures.

These references were used only for protocol and data-collection behavior.
Whoordan does not claim official manufacturer support and does not copy
third-party UI, formulas, or proprietary analytics.

## UUIDs

Physical validation on `WARDAN's wearable` showed the wearable exposes the protocol UUIDs as full UUIDs with a shared base suffix:

- Primary service: `61080001-8D6D-82B8-614A-1C8CB0F8DCC6`
- Command write: `61080002-8D6D-82B8-614A-1C8CB0F8DCC6`
- Command response notify: `61080003-8D6D-82B8-614A-1C8CB0F8DCC6`
- Events notify: `61080004-8D6D-82B8-614A-1C8CB0F8DCC6`
- Sensor data notify: `61080005-8D6D-82B8-614A-1C8CB0F8DCC6`
- Diagnostics notify: `61080007-8D6D-82B8-614A-1C8CB0F8DCC6`

The short forms remain useful shorthand in protocol notes, but the app uses the full UUIDs for CoreBluetooth matching.

## Frame Format

Implemented:

- byte `0`: `0xAA`
- bytes `1..2`: little-endian frame length equal to inner content length plus 4
- byte `3`: CRC8 over the two length bytes
- inner content
- final 4 bytes: standard CRC32 little-endian over inner content

Packet types implemented/scaffolded: `0x23` command, `0x24` command response, `0x28` realtime data, `0x2B` raw realtime data, `0x2F` historical data, `0x30` event, `0x31` metadata, `0x32` firmware log.

## Commands Implemented

Init sequence builders:

- `GET_HELLO_HARVARD`
- `GET_ADVERTISING_NAME`
- `GET_DATA_RANGE`
- `GET_ALARM_TIME`
- `SEND_HISTORICAL_DATA`

Realtime commands:

- `0x03 [0x01]` enable realtime HR, `0x03 [0x00]` disable
- `0x3F [0x01]` enable R10/R11, `0x3F [0x00]` disable
- `0x9A [0x01]` enable persistent R21, `0x9A [0x00]` disable
- `0x6C [0x01]` enable optical mode, `0x6C [0x00]` disable

Historical sync:

- Metadata batch marker detection is scaffolded.
- Batch ACK builder uses the extracted 8-byte batch token and local batch counter.
- End-of-sync is represented distinctly from batch markers.

Haptics:

- Harvard pattern command `0x4F` with 5-byte payload.
- Maverick/Gen4 pattern command `0x13` with the public 12-byte playback payload.
- Stop/terminate command `0x7A`.

## Decoders

Implemented or scaffolded:

- Strict frame decoder with malformed-frame rejection.
- Fragment reassembler for complete, split, padded, orphan, and multi-frame notifications.
- Command response decoder for hello/device identity, advertising name, data range, alarm, historical sync, and unknown command responses.
- Metadata decoder for batch-marker scaffold and end-of-sync candidates.
- Event decoder for battery, charging, wrist on/off, double tap, temperature, haptics fired, haptics terminated, and unknown events.
- Event decoder also classifies realtime HR start/stop and alarm set/fired/disabled events when those event IDs are observed.
- Firmware log decoder for null-terminated ASCII diagnostic text.
- Standard Bluetooth Heart Rate Measurement (`2A37`) parser.
- Standard Bluetooth Battery Level (`2A19`) parser.
- R10 parser for plausible live HR plus summarized accelerometer/gyroscope axis counts/ranges.
- R21 parser for LED drive, sample counts, and PPG channel summaries. These remain raw/debug optical diagnostics.
- R11 record identification is implemented as an honest unsupported scaffold.
- R20/R7 are preserved as unsupported/scaffolded records until semantics are validated.
- Stable dedupe ID generation and source metadata mapping without raw private identifiers.

## Normalization

Normalized records must carry source `wearable_ble`, device ID, characteristic UUID, packet type, record type, timestamp, received-at time, sequence when available, stable dedupe ID, confidence, metadata summary, and approval/cloud-sync eligibility.

## Physical Payload Sample

A raw debug capture was saved outside the repository with a local no-commit warning file. The exact path is intentionally omitted from source-controlled docs and reports.

That file is private wearable debug data and must not be committed, pasted into docs, or uploaded. It was used to confirm packet categories and decoder shape at a high level: realtime data, raw realtime data, command responses, metadata, event, and firmware log frames were present. The source-controlled app keeps raw capture opt-in only through `WHOORDAN_RAW_BLE_CAPTURE=1` or `--whoordan-raw-ble-capture`.

The captured advertising name and serial-like device value are not committed as raw fixtures. Device identity is mapped to a private stable fingerprint for diagnostics.

## Safe To Implement

Safe first-pass implementation includes discovery, connection state, characteristic subscription, frame validation, command builders, reassembly, event scaffolding, haptic command send, and local-only normalized sample storage after approval.

## Rough Or Unsupported

Full historical record semantics, calibrated SpO2, true HRV from BLE, reliable step counts, calibrated optical metrics, and complete R11/R20/R7 decoding are unsupported until physical validation and better data references exist.

## Intentionally Not Copied

No third-party formulas, UI, colors, wording, score behavior, product claims, or private analytics are copied.

## Physical Validation Required

Completed in first physical pass:

- Owned wearable discovery.
- Service/characteristic UUID correction.
- Initial notification receipt.
- Crash fix for real notification reassembly.
- Packet receipt evidence through `Packet = Seen`.
- Raw payload debug file saved outside the repo with a no-commit warning.
- Safe parser tests added for standard HR, standard battery, R10 HR/IMU summary, R21 optical summary, and event type.
- Focused physical UI validation passed with a real approved session and recognized parsed payload evidence from the owned wearable.

Still required:

- Notification ordering.
- Init response semantics.
- Batch ACK acceptance.
- Historical completion.
- Longer realtime semantic confirmation beyond the focused parsed-payload test.
- Packet decoding accuracy against longer physical sessions.
- Post-wake sleep/session packet capture.
- Device step/activity summary packet capture.
- Haptic fired/terminated events.
- Disconnect recovery.
- Battery/wrist/temperature event semantics.

Raw payloads are not committed or pasted. Analysis should use safe summaries unless explicit local-only debug capture is added outside source control.

## 2026-05-12 Protocol Hardening

Public BLE protocol references were used as protocol references only.
Whoordan now has focused regression tests for R10 axis summaries, R21 optical
summaries, alarm/realtime events, null-terminated firmware logs, dropped orphan
fragments, and the Harvard/Maverick/stop haptic command family. The app still
does not expose unvalidated HRV, SpO2, sleep, naps, steps, workouts, calories,
or respiratory rate from raw BLE records.

## 2026-05-12 Notification, Call, and Haptics Update

- Built-in wearable preview remains approval-gated and uses the Harvard `0x4F`
  and Maverick/Gen4 `0x13` command paths.
- Stop haptics still uses `0x7A` on cancel where supported.
- Custom interval patterns are stored locally and safety-checked, but exact
  custom segmented playback is not sent until the BLE command format is
  physically verified.
- Live custom-pattern recording sends a supported built-in pulse as wearable
  feedback when connected; this is not claimed to be exact interval playback.
- Event type 14 double tap, event type 60 haptics fired, and event type 100
  haptics terminated remain decoded into safe diagnostics.
- Normal cellular call decline and all-app notification capture are platform
  blocked and do not use private APIs.

## 2026-05-12 Alarm Vibration Update

- Wearable alarms now use the same approval-gated haptic command path as
  built-in pattern preview.
- Alarm trigger delivery is attempted only when the app can run and the wearable
  is connected; local iOS notification is the fallback reminder.
- Snooze and dismiss stop haptics with `0x7A` where supported.
- Event type 14 can route to active alarm snooze/dismiss after active supported
  calls. Event type 60/100 confirmations remain diagnostics only until
  physically validated against a real alarm.
- Exact wearable alarm delivery while the app is suspended is not claimed.

## 2026-05-12 Scenario Capture Update

- Developer capture can now be started and stopped from the debug Device screen
  after approval.
- Capture records include notification and write directions so init commands,
  batch ACKs, realtime enable/disable commands, haptic commands, and device
  notifications can be analyzed together.
- Scenario labels allow packet families to be correlated with idle, walking,
  workout, post-wake, nap, charging, wrist, haptic, alarm, and double-tap
  sessions.
- The capture mode does not alter source priority or sync behavior. Raw capture
  files remain local-only private debug data.
