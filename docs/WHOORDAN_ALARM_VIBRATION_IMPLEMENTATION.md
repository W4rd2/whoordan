# Whoordan Alarm Vibration Implementation

Date: 2026-05-12

## Implemented

- `Alarm` model with label, enabled state, time, timezone, repeat days, selected vibration pattern, snooze settings, last/next trigger, sync status, and delivery status.
- Local-first alarm persistence in `FileProtectedLocalStore`.
- Alarm creation, edit, enable/disable, delete, preview, repeat-day selection, snooze configuration, and active-alarm controls in SwiftUI Settings > Alarms.
- Local iOS notification fallback through `UNUserNotificationCenter` and a one-shot `UNCalendarNotificationTrigger` for the next trigger.
- Wearable vibration attempt at alarm time when approval is verified, the app can run, the wearable is connected, and the selected pattern is safe.
- Snooze stops haptics where supported, reschedules by `snoozeMinutes`, and respects `maxSnoozes`.
- Dismiss stops haptics where supported, disables one-time alarms, and schedules the next repeated occurrence.
- Central double-tap routing priority: active supported call, active alarm, notification action where supported, debug/custom action, no-op.
- Device diagnostics expose alarm count, active alarm status, last scheduling result, and last double-tap route.

## Platform Limits

- Exact wearable delivery while the app is suspended is not claimed. iOS local notification is the fallback reminder.
- Wearable alarm vibration is not marked physically validated until a connected wearable confirms haptic delivery at a real alarm time.
- Normal cellular call decline remains platform-blocked and is not part of alarm routing.
- No private APIs are used.

## Sync and Privacy

- Alarm records are stored locally first.
- Alarm sync status is `pending` only when approval is approved, cloud sync is enabled, and local-only mode is off.
- No notification content, phone numbers, call metadata, tokens, secrets, or raw BLE payloads are stored in alarm records.

## Tests

Added XCTest coverage for next-trigger scheduling, repeat-day scheduling, snooze max behavior, settings sync gating, local alarm persistence, double-tap alarm snooze/dismiss, active-call priority over alarm, approval gating, and no-op behavior without an active alarm.

## Physical Validation

Not performed in this pass. Required real-device checks:

- Build/install/launch on approved iPhone.
- Connect wearable.
- Create alarm one to two minutes in the future.
- Confirm local notification fires.
- Confirm selected wearable pattern vibrates while connected.
- Confirm snooze, dismiss, and double-tap snooze/dismiss.
- Confirm disconnected-wearable status is recorded honestly.
