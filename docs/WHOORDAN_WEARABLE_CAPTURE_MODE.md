# Whoordan Wearable Capture Mode

Date: 2026-05-12
Branch: `swift-app`

## Status

Developer wearable capture mode is implemented for debug builds and remains
local-only. It is exposed from the Device screen after account approval through
the Developer Capture card.

This mode is for packet discovery and wearable protocol research only. It does
not create user-facing metrics by itself.

## Approval And Privacy Gates

- Capture controls are reachable only through approved-app flows.
- `AppEnvironment.startWearableCapture(scenario:)` checks the same protected
  service approval gate used for BLE scanning and connection.
- BLE still does not start before approval.
- Raw captures are written only inside the app sandbox under a local debug
  directory.
- Capture files are not uploaded to Supabase.
- Capture files are not part of normal health export or sync flows.
- Raw payload bytes are not shown in Device diagnostics.
- Device identity is represented in app diagnostics as a fingerprint, not raw
  serial-like values.

## Captured Fields

Each JSONL record includes:

- app capture timestamp
- characteristic UUID
- byte count
- direction: `notify` or `write`
- base64 payload
- decoded packet type when a complete frame is available
- connection state
- RSSI when known
- decoded device time when available
- app state: foreground, inactive, background, or unknown
- scenario label

Scenario labels currently include:

- idle
- walking
- running
- workout
- post-workout
- pre-sleep
- overnight
- post-wake
- nap
- charging
- wrist-off
- wrist-on
- haptic-preview
- alarm
- double-tap
- unknown

## Capture Controls

The Device screen shows:

- recording/stopped status
- active scenario
- record count
- last packet direction
- last decoded packet type
- safe error message
- debug-only Start Capture, Mark Scenario, and Stop controls

Changing the scenario while capture is active changes the scenario for new
records. It does not rewrite prior records.

## Environment Capture

The older developer environment capture still works:

- `WHOORDAN_RAW_BLE_CAPTURE=1`
- `WHOORDAN_RAW_BLE_CAPTURE_MAX=<count>`
- `WHOORDAN_RAW_BLE_CAPTURE_SCENARIO=<scenario>`
- `--whoordan-raw-ble-capture`

The default cap is now suitable for longer sessions, but still bounded. The hard
limit is 50,000 records per capture file.

## What It Does Not Do

- It does not log raw packets to production logs.
- It does not upload captures.
- It does not create fake steps, sleep, naps, HRV, SpO2, respiratory rate, or
  sleep stages.
- It does not claim that captured PPG is clinically validated.
- It does not claim official support for any third-party wearable protocol.

## Files

- `Whoordan/Core/BLE/WearableBLEService.swift`
- `Whoordan/App/AppEnvironment.swift`
- `Whoordan/Features/Device/DeviceView.swift`
- `WhoordanTests/WearableProtocolTests.swift`

## Validation

Focused wearable protocol tests passed on simulator:

- `WearableProtocolTests`: 36 tests, 0 failures.

Physical packet capture was not performed in this run. The iPhone must be used
to start scenario captures from the Device screen with the wearable connected.
