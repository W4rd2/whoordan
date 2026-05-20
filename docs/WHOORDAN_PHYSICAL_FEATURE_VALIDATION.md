# Whoordan Physical Feature Validation

Updated: 2026-05-12

## Summary

Physical validation was run against Wardan's iPhone with Supabase public configuration present. The first physical UI test launch was blocked because the device reported as locked. After the phone was unlocked, the corrected approved-account physical UI tests installed and launched the app, reached the approved Today root, opened Device, exercised the scan/reconnect path, opened Vibration, and verified that preview reports an honest disconnected state when the wearable is not connected.

No wearable haptic, alarm, double-tap, or packet-capture feature is marked physically passed unless the run produced direct UI/device evidence. In this run, vibration preview did not physically validate wearable vibration because the app reported `Wearable disconnected`.

## Device And Build Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| iPhone discovered | Passed | `xcrun devicectl list devices` showed Wardan's iPhone connected. |
| Supabase public config present | Passed | Local environment check confirmed project id and publishable key variables were present without printing values. |
| Xcode project listed | Passed | `xcodebuild -list -project Whoordan.xcodeproj` listed the `Whoordan` scheme and test targets. |
| Initial physical test launch | Blocked, then retried | Xcode reported: unlock Wardan's iPhone to continue. The run proceeded after the phone was unlocked. |
| Approved Today root | Passed | `testApprovedSessionShowsTodayRoot` passed on the physical iPhone. |
| Device scan path | Passed for UI path | `testApprovedDeviceScanShowsBluetoothState` opened More > Device and tapped Scan or reconnect. It reached a visible connecting state. |
| Vibration preview path | Passed for honest state | `testApprovedVibrationPreviewReportsHonestState` opened More > Vibration and previewed Soft Tap. The UI reported `Wearable disconnected`. |
| Physical wearable vibration | Not validated | The preview did not claim haptic success because the wearable was not connected in the run. |

## Wearable Validation Status

| Feature | Physical status | Notes |
| --- | --- | --- |
| BLE scan UI path | Passed | Physical test tapped Scan or reconnect and observed a visible connection/scanning state. |
| BLE connect | Not validated in this run | The run did not confirm a connected wearable, service discovery, or packet receipt. |
| Service/characteristic discovery | Not validated in this run | Not claimed. |
| Realtime HR | Not validated in this run | UI can display HR when decoded, but this run did not prove live device packets. |
| Historical sync | Not validated in this run | Not claimed. |
| Double tap event | Not validated in this run | Event decoder exists, but no physical event was confirmed. |
| Built-in vibration preview | Honest disconnected state validated | The app did not fake success; it reported `Wearable disconnected`. Physical vibration still needs a connected wearable. |
| Custom live recording feedback | Not validated in this run | No physical haptic pass claimed. |
| Custom segmented playback | Unsupported until command format is verified | App reports unsupported rather than faking success. |
| Alarm local notification | Not validated in this run | Simulator/device validation still needed. |
| Alarm wearable vibration | Not validated in this run | No physical haptic pass claimed. |
| Snooze/dismiss | Not validated in this run | Model/tests cover behavior; physical run still needed. |
| Locked-phone wearable alarm | Not validated in this run | iOS background limits must be tested physically. |
| Notification vibration for other apps | Platform-blocked unless a public API/entitlement exists | Not presented as working. |
| Normal cellular call decline | Platform-blocked | Not attempted. |

## Next Physical Validation Steps

1. Keep the iPhone unlocked and awake.
2. Launch Whoordan with Supabase public config.
3. Confirm approved account reaches Today.
4. Open More > Device and connect the wearable.
5. Confirm Device shows live or syncing state.
6. Open More > Vibration, preview Soft Tap, and confirm physical vibration by observation or haptic event.
7. Record a custom tap pattern and confirm live feedback only if the wearable actually vibrates.
8. Open More > Alarms, create an alarm 1-2 minutes ahead, and test local notification, wearable vibration, snooze, dismiss, and double tap.
9. Open More > Developer Tools only for capture/packet diagnostics.

No raw BLE payloads, tokens, notification content, or private values should be printed or uploaded during validation.
