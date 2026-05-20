# Whoordan Notification and Call Platform Capability

Date: 2026-05-12

This document classifies local notifications, call vibration, double tap, and wearable haptic behavior for the native SwiftUI app. It uses Apple public platform behavior as the boundary: no private APIs, no jailbreak assumptions, and no claim that Whoordan can monitor every notification or control normal cellular calls.

Apple references used:

- `UNUserNotificationCenter` manages notification behavior for an app or app extension: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
- `UNNotificationServiceExtension` modifies the content of a remote notification before delivery, for notifications routed to that extension: https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension
- CallKit is the public framework for app calling integration: https://developer.apple.com/documentation/callkit
- `CXEndCallAction` is a CallKit action for ending a CallKit call: https://developer.apple.com/documentation/callkit/cxcallaction

## Capability Matrix

| Feature | Status | Whoordan behavior |
| --- | --- | --- |
| App's own notification vibration | REMOVED | Whoordan no longer routes received notifications to wearable vibration. |
| All-app notification vibration | REMOVED / PLATFORM_BLOCKED | A normal iOS app is not a universal listener for every other app's notifications. |
| Selected-app notification vibration | REMOVED / PLATFORM_BLOCKED | App-rule matching and per-app vibration controls have been removed. |
| Per-app pattern selection | REMOVED | No received-notification vibration pattern selection exists in the app. |
| Disable vibration for specific apps | REMOVED | No received-notification vibration app rules exist in the app. |
| Reading notification content | PLATFORM_BLOCKED for other apps | Whoordan does not store notification content. Own notifications can be handled without persisting body text. |
| Reading app identifier/source app | PLATFORM_BLOCKED for other apps | Source matching is only possible where public APIs provide safe source information. |
| iOS notification forwarding | REMOVED | Accessory notification-forwarding targets and entitlements are not part of this build. |
| Call vibration for Whoordan-owned VoIP/CallKit calls | SCAFFOLDED | Settings and routing model exist. No Whoordan-owned VoIP call service is currently implemented. |
| Call vibration for normal cellular calls | IMPLEMENTED, PLATFORM_LIMITED | `CXCallObserver` can route an incoming cellular call event to repeated standard wearable vibration while the app/runtime receives the event. iOS wake/reliability for suspended states is not claimed. |
| Decline Whoordan-owned VoIP call by double tap | SCAFFOLDED | Router calls a Whoordan call controller if one exists. No active CallKit call service is wired yet. |
| Decline normal cellular call by double tap | PLATFORM_BLOCKED | Double tap explicitly returns a platform-blocked status and does not call private APIs. |
| Wearable double-tap event handling | IMPLEMENTED, not physically revalidated in this pass | BLE event type 14 is decoded and can feed the action router. |
| Standard vibration preview | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Harvard `0x4F` and Maverick/Gen4 `0x13` standard commands are sent through the approved BLE command path. |
| Legacy interval preview | REMOVED | Interval playback is intentionally disabled; legacy pattern input is coerced to standard vibration. |
| Haptic fired/terminated confirmation | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | BLE event types 60 and 100 update diagnostics when observed. |
| Wearable alarm vibration | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Whoordan alarm trigger repeats the same standard wearable vibration after approval, app runtime, and connection checks pass until snooze, dismiss, disable, delete, signout, or protected-service stop. |
| Local iOS alarm notification fallback | IMPLEMENTED | Uses UserNotifications to schedule a local one-shot reminder for the next trigger time. |
| Native Apple Clock alarm detection | PLATFORM_BLOCKED | No public iOS API is used or claimed for detecting alarms from Apple's Clock app or arbitrary third-party alarm apps. |
| Alarm snooze/dismiss | IMPLEMENTED | Snooze reschedules locally; dismiss stops haptics where supported and disables one-time alarms. |
| Alarm double-tap action | IMPLEMENTED, PHYSICAL_VALIDATION_REQUIRED | Double tap routes active supported calls first, then active alarms. |
| Alarm background delivery limits | PHYSICAL_VALIDATION_REQUIRED / PLATFORM_LIMITED | Exact wearable delivery while suspended is not claimed. |

## Privacy Notes

- Notification content, phone numbers, call metadata, tokens, sessions, and raw BLE payloads are not stored by these feature paths.
- BLE haptics remain approval-gated.
- Settings and alarms are stored locally first. Cloud sync for these settings must remain approval and consent gated.
