# Whoordan Wearable BLE Device Test Plan

Date: 2026-05-11

## Current Validation Status

Status: partially passed on physical hardware.

Passed:

- Physical iPhone install and launch.
- Approved-account gated access to Device.
- Discovery of owned wearable `WARDAN's wearable`.
- Connection path using full protocol UUID family.
- Notification/frame path no longer crashes.
- Packet receipt evidence through `Packet = Seen`.

Still pending:

- Historical sync correctness.
- Realtime stream semantics.
- R10/R21/event decoding verification.
- Human-observed haptic vibration.
- Long-running reconnect behavior.

## Required Hardware

- A signed physical iPhone with Developer Mode enabled.
- The user's personally owned compatible wearable.
- Xcode with the `com.w4rd2.whoordan` bundle identifier signed for the device.

## Preconditions

- User is signed in and approved through `public.user_access`.
- BLE, HealthKit, local mode, and cloud sync are unavailable before approval.
- Cloud and health-data upload consent are off unless explicitly enabled by the user.
- Raw BLE payload logging is disabled by default.

## Discovery And Connection Checklist

1. Launch Whoordan on the physical iPhone.
2. Confirm the account is approved.
3. Confirm auto-connect starts after approved session restore or app foreground activation.
4. Open `Settings > Device`.
5. Confirm the UI separates:
   - compatible and connected
   - preferred owned device
   - compatible nearby
   - not paired or unknown
6. Confirm `WARDAN's wearable` is discovered.
7. Confirm service `61080001-8D6D-82B8-614A-1C8CB0F8DCC6`.
8. Confirm characteristics:
   - command write `61080002-8D6D-82B8-614A-1C8CB0F8DCC6`
   - command response notify `61080003-8D6D-82B8-614A-1C8CB0F8DCC6`
   - events notify `61080004-8D6D-82B8-614A-1C8CB0F8DCC6`
   - sensor data notify `61080005-8D6D-82B8-614A-1C8CB0F8DCC6`
   - diagnostics notify `61080007-8D6D-82B8-614A-1C8CB0F8DCC6`
9. Confirm `Packet = Seen` before claiming data receipt.

## Safe BLE Diagnostic Sample

The app may show a safe notification summary:

- characteristic UUID
- byte count
- first 12 bytes
- last 12 bytes
- frame count
- decoded packet type when available
- decode status

Do not paste or commit full raw payloads. Full raw payload capture, if ever required, must be explicit, local-only, ignored, and outside source control.

## Historical Sync Checklist

- Subscribe before commands are sent.
- Send init packets one at a time.
- Receive command responses.
- Detect metadata batch marker.
- Send batch ACK with extracted token.
- Store local checkpoint only after local write succeeds.
- Detect end-of-sync before starting realtime.
- Verify no cloud upload without consent.

## Realtime Checklist

- Send realtime enable commands after historical sync/end marker.
- Confirm data or responses before displaying realtime active.
- Decode battery, wrist, charging, temperature, and haptic events if emitted.
- Decode R10/R11/R21 records conservatively.
- Confirm R10 direct HR is plausible before showing it.
- Confirm R11 remains an unsupported scaffold until semantics are known.
- Confirm R21 optical samples are not displayed as medical SpO2.
- Confirm HRV, steps, respiratory rate, and sleep stages remain unavailable unless a validated source is captured.
- Reject outliers and label low-confidence estimates.

## Haptic Preview Checklist

- Preview remains disabled before approval.
- Preview remains disabled when disconnected.
- Unsafe custom pattern is blocked.
- Built-in pattern sends supported command(s).
- UI waits for command response or haptic event before claiming fired.
- Terminated event updates status.

## Failure Modes

- Bluetooth off or denied.
- Device unavailable, out of range, or connected to another host.
- Missing expected service or characteristics.
- CRC/frame validation failure.
- Historical sync never completes.
- Realtime commands acknowledged but no data.
- Haptic unsupported or rejected.
- Approval revoked during active connection.

## Pass/Fail Rule

Discovery/menu visibility is not connection success.

Connection success requires progression into service discovery, subscription, initialization, historical sync, or realtime.

Data receipt success requires `Packet = Seen` or an equivalent accepted decoded-notification state.

Metric success requires a recognized safe signal, such as plausible direct HR, battery, wrist/charging event, double tap, firmware diagnostic text, R10 IMU summary, or R21 optical presence summary. Raw packet receipt alone is not enough to claim a health metric is available.
