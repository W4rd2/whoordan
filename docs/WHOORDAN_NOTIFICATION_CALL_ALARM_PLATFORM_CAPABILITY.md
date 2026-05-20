# Whoordan Notification, Call, and Alarm Platform Capability

Date: 2026-05-12

This document classifies vibration, notification, call, double-tap, and alarm behavior for the native SwiftUI app. Public iOS APIs are the boundary: no private APIs, no jailbreak assumptions, no universal notification listener claim, and no normal cellular call control claim.

Apple references used:

- `UNUserNotificationCenter`: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
- `UNNotificationServiceExtension`: https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
- `UNCalendarNotificationTrigger`: https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger
- CallKit: https://developer.apple.com/documentation/callkit
- `CXCallAction`: https://developer.apple.com/documentation/callkit/cxcallaction

## Capability Matrix

| Feature | Status | Whoordan behavior |
| --- | --- | --- |
| App's own notification vibration | REMOVED | Whoordan no longer routes received notifications to wearable vibration. |
| All-app notification vibration | REMOVED / PLATFORM_BLOCKED | A normal iOS app is not a universal listener for every other app's notifications. |
| Selected-app notification vibration | REMOVED / PLATFORM_BLOCKED | App-rule matching and per-app vibration controls have been removed. |
| Per-app pattern selection | REMOVED | No received-notification vibration pattern selection exists in the app. |
| Disable vibration for specific apps | REMOVED | No received-notification vibration app rules exist in the app. |
| Reading notification content | PLATFORM_BLOCKED for other apps | Whoordan does not store notification content. Own notifications can be handled without persisting body text. |
| Reading app identifier/source app | PLATFORM_BLOCKED for other apps | Source matching is limited to public source information when available. |
| iOS notification forwarding | REMOVED | Accessory notification-forwarding targets and entitlements are not part of this build. |
| Call vibration for Whoordan-owned VoIP/CallKit calls | SCAFFOLDED | Settings and router exist. No Whoordan-owned VoIP call service is implemented. |
| Call vibration for normal cellular calls | PLATFORM_BLOCKED | Normal cellular call events/control are not claimed. |
| Decline Whoordan-owned VoIP call by double tap | SCAFFOLDED | Router can call a Whoordan call controller if one is later implemented. |
| Decline normal cellular call by double tap | PLATFORM_BLOCKED | Router returns a platform-blocked status and does not use private APIs. |
| Wearable double-tap event handling | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | BLE event type 14 is decoded and can feed the central action router. |
| Live vibration pattern recording | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Recording stores segments locally and sends a built-in live pulse only when approved and connected. |
| Built-in pattern preview | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Harvard `0x4F` and Maverick/Gen4 `0x13` commands are sent through the approved BLE path. |
| Custom pattern preview | SCAFFOLDED / UNSUPPORTED | Exact segmented custom playback is blocked until the BLE command format is verified. |
| Haptic fired/terminated confirmation | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Event types 60 and 100 update safe diagnostics when observed. |
| Wearable alarm vibration | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Alarm trigger attempts the selected wearable pattern only after approval, while the app can run and the wearable is connected. |
| Local iOS alarm notification fallback | IMPLEMENTED | Schedules a local one-shot notification for the next trigger time using UserNotifications. |
| Alarm snooze | IMPLEMENTED | Snooze reschedules the alarm locally, respects max snoozes, and stops haptics where supported. |
| Alarm dismiss | IMPLEMENTED | Dismiss stops haptics where supported, disables one-time alarms, and schedules the next repeat occurrence. |
| Alarm double-tap snooze/dismiss | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Central router prioritizes active supported calls, then active alarms. |
| Alarm background delivery limits | PHYSICAL_VALIDATION_REQUIRED / PLATFORM_LIMITED | Exact wearable delivery while suspended is not claimed. iOS local notification is the fallback reminder. |

## Privacy Notes

- Notification content, phone numbers, call metadata, tokens, sessions, and raw BLE payloads are not stored by these feature paths.
- BLE haptics and alarms remain approval-gated.
- Call vibration and alarm settings persist locally first.
- Settings/alarm cloud sync may only be queued after approval and cloud-sync consent. Local-only mode blocks upload.
