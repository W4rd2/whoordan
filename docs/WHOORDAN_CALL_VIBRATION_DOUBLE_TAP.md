# Whoordan Call Vibration and Double Tap

Date: 2026-05-12

## Implemented

- `CallVibrationSettings`: enabled state, standard wearable vibration routing, double-tap decline preference, support flag, platform status, timestamp.
- `DoubleTapAction`: none, preview haptic, decline call where supported, snooze alarm where supported, dismiss alarm where supported, debug action.
- `DoubleTapActionRouter`: handles double tap without private APIs or phone-number logging.
- SwiftUI call vibration settings with platform status and standard vibration preview.
- Device diagnostics show call vibration state, platform status, and last double-tap route.
- Incoming cellular call events use the same standard wearable vibration repeatedly while the app receives the call state and stop on call end or wearable double tap.

## Whoordan-Owned Calls

The router can decline a Whoordan-owned VoIP/CallKit call through a `WhoordanCallControlling` adapter if a call service exists. No Whoordan-owned VoIP call service is implemented in this pass, so the production status is scaffolded.

## Normal Cellular Calls

Normal cellular call decline is platform-blocked. The router explicitly silences only the wearable vibration for active normal cellular calls and does not attempt private APIs.

## Tests

Added XCTest coverage for app-owned call decline routing, normal cellular call block behavior, disabled decline behavior through settings, approval gating, and no active supported call handling.

## 2026-05-12 Alarm Priority Update

`DoubleTapActionRouter` now handles active alarms after active supported calls. Priority is:

1. Active supported Whoordan-owned call decline, when enabled and wired.
2. Active alarm snooze or dismiss.
3. Debug action.
4. No-op.

Normal cellular calls remain platform-blocked. Alarm double-tap handling does not attempt call APIs.
