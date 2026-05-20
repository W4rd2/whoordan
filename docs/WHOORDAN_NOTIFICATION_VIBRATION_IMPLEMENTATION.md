# Whoordan Notification Vibration Removal

Date: 2026-05-15

## Decision

Wearable vibration triggered by received phone/app notifications has been removed from the production app.

## Removed Surface

- Notification-specific vibration settings and app-rule models.
- Double-tap notification dismissal action.
- User-facing notification vibration controls and diagnostics.
- Accessory notification-forwarding ExtensionKit targets and entitlements.

## Preserved Surface

- Call vibration for observed incoming cellular call events.
- Wearable alarm vibration.
- Double tap for call-vibration silence and alarm snooze/dismiss.
- Local iOS notifications used for alarm fallback and operational reminders.
- Notification permission handling required by those local notifications.

## Validation Contract

Design contract tests assert the app source tree and Xcode project do not contain the notification-vibration runtime or accessory notification-forwarding stack.
