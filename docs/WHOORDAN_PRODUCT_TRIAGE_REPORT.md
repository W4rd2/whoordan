# Whoordan Product Triage Report

Updated: 2026-05-12

## Scope

This audit reviewed the native SwiftUI product surface on the `swift-app` branch with a strict release-review lens. The goal was to separate the normal wearable health app experience from developer/protocol diagnostics and stop presenting unvalidated scaffolds as user-facing product value.

## Screen Triage

| Screen | Current classification | Action taken |
| --- | --- | --- |
| Today | Useful shell, too noisy, setup CTAs scattered | Reduced to a flagship day view with one primary setup action, health summary cards, source/sync strip, and measured body signals only when present. |
| Recovery | Useful formula view, too many missing rows when empty | Empty state now shows baseline readiness and required signals. Contributor lists appear only after a score exists. |
| Sleep | Partially useful with Apple Health fallback, noisy when empty | Empty state now shows a calm setup path. Stage and trend sections appear only when measured/imported data exists. |
| Movement / Activity | Useful when Apple Health steps exist, noisy when empty | Promoted to main `Activity` tab. Shows setup action when empty and trend/daily history only when enough data exists. |
| Heart | Useful developer-facing signal detail, not main-tab quality | Removed from main tab bar. Body signal detail now lives under More. |
| Device | Useful but previously debug-heavy | Normal Device now shows connection, live HR, battery, wrist, last sync, and pairing. Packet diagnostics moved to Developer Tools. |
| Vibration | Functional controls, previously settings/debug-heavy | Normal Vibration now focuses on built-in previews, custom recording, saved patterns, and honest playback state. Notification/call limitations moved out of the normal path. |
| Alarms | Useful model and scheduler, too much platform/debug copy | Normal Alarms now focuses on saved alarms, edit controls, snooze/dismiss, pattern selection, and concise delivery status. |
| Settings | Useful but overloaded as a feature launcher | Settings now focuses on privacy, Apple Health, cloud sync, account, and legal. Feature navigation moved to More. |
| Journal | Secondary feature | Kept under More. |
| Workouts / Strength / Trends | Secondary or placeholder | Kept under More; remaining gaps must stay honest until data models are complete. |
| Developer diagnostics | Debug-only | Centralized in More > Developer Tools. |

## Normal Information Architecture

Primary tabs are now:

1. Today
2. Recovery
3. Sleep
4. Activity
5. More

More contains:

- Device
- Vibration
- Alarms
- Body Signals
- Workouts
- Journal
- Trends
- Strength
- Settings
- Developer Tools

## Debug Content Moved To Developer Tools

The following no longer appears on the normal Device screen:

- packet diagnostics
- malformed frame counts
- dropped fragment counts
- IMU/PPG packet counters
- command responses
- batch ACK state
- firmware log summaries
- raw capture controls
- BLE UUID lists
- haptic event diagnostics
- notification/call platform-blocked wall text

## Remaining Product Gaps

- Wearable sleep, naps, reliable steps, workouts, calories, HRV intervals, respiratory rate, SpO2, and temperature trends remain unconfirmed unless future captures prove direct or validated derived sources.
- Custom vibration segment playback remains unsupported until the BLE command format is physically verified.
- Normal cellular call decline remains platform-blocked for a third-party iOS app.
- Wearable alarm delivery while the app is suspended remains unproven; local iOS notification fallback remains the honest baseline.
