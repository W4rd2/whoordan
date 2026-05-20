# Whoordan Vibration Pattern Editor

Date: 2026-05-12

## Implemented

- `VibrationPattern` now includes type, segments, duration, repeat count, timestamps, built-in/custom classification, and computed safety status.
- `VibrationSegment` now has explicit `on` and `off` kinds.
- Safety limits enforce finite duration, segment bounds, repeat bounds, and intensity range.
- SwiftUI editor can record taps, save custom patterns, duplicate custom patterns, and delete custom patterns.
- Recording stores local segments first.
- Live wearable feedback sends a supported built-in pulse only when approved, connected, and safe.

## Unsupported

Exact custom interval playback on the wearable remains unsupported until the BLE command format for segmented playback is verified. Saved custom patterns are not falsely reported as physically playable.

## Haptic Playback

Built-in preview uses the already documented BLE command family:

- Harvard `0x4F`
- Maverick/Gen4 `0x13`
- Stop haptics `0x7A` on cancel

Haptic fired and terminated events are decoded when event types 60 and 100 arrive, but physical confirmation remains required for this pass.

## Tests

Added XCTest coverage for unsupported custom playback, live tap sends when connected, disconnected recording without haptic send, unsafe pattern blocking, and local settings persistence.

## Alarm Usage

Alarms can choose any saved safe pattern. Built-in patterns can be previewed on the wearable when approval and connection allow it. Custom patterns remain local/editable, but exact segmented wearable playback stays unsupported until the BLE command format is physically verified.
