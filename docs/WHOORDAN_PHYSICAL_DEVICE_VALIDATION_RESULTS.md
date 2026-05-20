# Whoordan Physical Device Validation Results

Date: 2026-05-11
Branch: `swift-app`
Project: `Whoordan.xcodeproj`

## Device Used

- Physical iPhone: `Wardan's iPhone`
- iOS reported by Xcode tools: `26.4.1`
- Hardware model reported by `devicectl`: `iPhone 17 (iPhone18,3)`
- Owned wearable target: `WARDAN's wearable`

Device identifiers, tokens, sessions, raw BLE payloads, and health data are intentionally omitted.

## Xcode And Device Availability

The iPhone was available for wireless physical validation after the user unlocked it, trusted the Mac, enabled Developer Mode, and confirmed Xcode Devices showed it ready.

Validated with:

```bash
xcrun xctrace list devices
xcrun devicectl list devices
xcodebuild -showdestinations -project Whoordan.xcodeproj -scheme Whoordan
xcodebuild -showBuildSettings -project Whoordan.xcodeproj -scheme Whoordan
xcodebuild -list -project Whoordan.xcodeproj
```

Observed signing/capability state:

- Bundle identifier: `com.w4rd2.whoordan`
- Automatic Apple Development signing configured.
- HealthKit entitlement present.
- Bluetooth and HealthKit privacy strings present.
- Targeted device family is iPhone.

`devicectl` repeatedly emitted a non-fatal CoreDevice warning: `No provider was found`. Build, install, launch, and physical UI tests still ran.

## Build, Install, And Launch

Passed:

```bash
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'
xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'id=[REDACTED_DEVICE_ID]' -allowProvisioningUpdates
xcrun devicectl device install app --device [REDACTED_DEVICE_ID] [Debug-iphoneos/Whoordan.app]
xcrun devicectl device process launch --device [REDACTED_DEVICE_ID] --terminate-existing com.w4rd2.whoordan
```

The app installed and launched on the physical iPhone.

## Supabase Runtime Config

The user-supplied Supabase project id and publishable key were passed only through process environment for physical launch/test runs. They were not written to source, docs, plist values, xcconfig files, or committed artifacts.

No service-role key was used.

## Approval Gate Physical Result

Passed for the approved-account path. The user signed into an approved account, and physical UI tests reached the approved Today root.

Not fully re-tested in this pass:

- Pending account lock screen.
- Rejected account lock screen.
- Revoked account relock after server-side status change.

The app code still fails closed before approval and stops BLE/haptic work when approval is not approved.

## HealthKit Physical Result

Passed smoke validation after approval:

- Settings exposed the Apple Health permission action only behind the approved app path.
- Physical UI test tapped `Request Permission`.
- The app surfaced a non-private HealthKit request status.

Not validated:

- Real Apple Health sample import contents.
- Denied versus partial versus fully authorized per-type state.
- Any cloud upload path. No upload was performed.

## BLE / Wearable Physical Result

Passed after fixes.

Physical findings and fixes:

- `WARDAN's wearable` was discovered by the app.
- The wearable exposed the protocol service as full UUID `61080001-8D6D-82B8-614A-1C8CB0F8DCC6`, not the short-only form.
- Whoordan was updated to use the full service and characteristic UUID family.
- A real notification crashed the first frame reassembler implementation; the reassembler was fixed to avoid unsafe `Data` indexing on fragmented BLE data.
- The final physical test connected to `WARDAN's wearable` and required `Packet = Seen`; it passed.

Raw BLE payloads were not printed, saved to the repo, or committed. The Device screen now shows a safe diagnostic summary only: characteristic UUID, byte count, first/last small byte windows, frame count, packet type if decoded, and decode status.

## Vibration Physical Result

Passed honest-state UI validation:

- Vibration screen is reachable after approval.
- Built-in preview action reports a real state.
- The test does not claim the wearable physically vibrated.

Not validated:

- Human-observed vibration.
- Haptic fired/terminated events from the wearable.

## UI / Smoothness Result

Physical smoke passed:

- Approved Today root loads.
- Recovery, Sleep, Heart, Settings, Device, Vibration, and Journal navigation paths are reachable.
- Six-tab iOS overflow issue was fixed by moving Device under Settings, keeping the primary tab bar iPhone-native.

Manual smoothness profiling was not performed.

## Accessibility Result

Scoped fixes and checks:

- Vibration pattern buttons now expose explicit accessibility labels.
- Physical UI tests could address Device/Vibration controls through accessibility.

Not fully validated:

- VoiceOver end-to-end manual navigation.
- Large text layout.
- Reduced motion.
- Contrast audit.

## Screenshots

No physical screenshots were captured. Current command-line tooling exposed in this session did not provide a working physical screenshot command.

## Fixes Applied

- Added real CoreBluetooth discovery/connect/subscription foundation.
- Added approval-safe automatic wearable connection after approved session restore and foreground activation.
- Added manual fallback discovery groups:
  - compatible and connected
  - preferred owned device
  - compatible nearby
  - not paired or unknown
- Updated wearable UUID constants to full UUIDs.
- Fixed frame reassembly crash on real BLE notification data.
- Added safe BLE notification diagnostic summary without raw payload logging.
- Tightened physical UI tests so connection/data validation requires `Packet = Seen`, not just a menu entry or realtime label.
- Moved Device out of the sixth tab overflow and into Settings.

## Remaining Blockers

- Full raw BLE payload analysis is intentionally not stored in the repo or chat.
- Historical sync semantics still need deeper device validation.
- R10/R21/event decoding needs more physical verification with safe summaries.
- Haptic physical vibration must be observed manually.
- Revoked/pending/rejected account physical flows need separate test accounts or server-side status changes.
