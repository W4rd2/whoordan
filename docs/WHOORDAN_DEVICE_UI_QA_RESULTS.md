# Whoordan Device UI QA Results

Date: 2026-05-11

## 1. Device Used

- Device: Wardan's iPhone
- UDID: `[REDACTED_DEVICE_ID]`
- Model reported by CoreDevice: iPhone 17 / `iPhone18,3`
- iOS: 26.4.1 / build `23E254`
- Connection: wireless first, then wired USB
- Developer Mode: enabled
- Pairing state: paired

## 2. Build And Run Commands

Pre-flight:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --no-codesign
git diff --check
```

Wireless debug attempt:

```bash
flutter run -d [REDACTED_DEVICE_ID] --no-resident \
  --dart-define=SUPABASE_PROJECT_ID=[REDACTED_PROJECT_ID] \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=[REDACTED_PUBLISHABLE_KEY]
```

Result: Xcode built successfully but Flutter debug launch timed out waiting for
`CONFIGURATION_BUILD_DIR` to update.

Wired debug attempt:

```bash
flutter run -d [REDACTED_DEVICE_ID] --no-resident \
  --dart-define=SUPABASE_PROJECT_ID=[REDACTED_PROJECT_ID] \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=[REDACTED_PUBLISHABLE_KEY]
```

Result: same Xcode debug-session timeout after successful build.

Signed release run:

```bash
flutter run --release -d [REDACTED_DEVICE_ID] --no-resident \
  --dart-define=SUPABASE_PROJECT_ID=[REDACTED_PROJECT_ID] \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=[REDACTED_PUBLISHABLE_KEY]
```

Result: installed and launched successfully.

## 3. Screens Checked

Automated physical screenshot capture was not available from this environment:

- `devicectl` in this installed Xcode does not expose a screenshot subcommand.
- `idevicescreenshot` is not installed.
- The device display was confirmed active through
  `xcrun devicectl device info displays`.

Manual screenshot instructions:

1. Open the screen on the iPhone.
2. Press Side Button + Volume Up.
3. Share the screenshots back into the thread for review.

Screens still needing manual screenshots:

- Signed-out auth
- Sign up
- Password reset
- Pending approval locked screen
- Rejected/revoked locked screen if reachable
- Today
- Recovery
- Sleep
- Heart
- More
- Settings
- Apple Health permission/settings
- BLE/device diagnostics
- Vibration settings/editor
- Journal/Habits

## 4. Visual Issues Found

Observed by user during physical launch:

- The app opened with a fully white screen / white flash.

Root cause found in native iOS host files:

- `ios/Runner/Base.lproj/LaunchScreen.storyboard` used a white background.
- `ios/Runner/Base.lproj/Main.storyboard` used a white Flutter host view
  background.
- A debug-mode app launched through `devicectl` also crashed with:
  `Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode.`
  That explains the persistent white screen from the debug `devicectl` fallback.

Fix applied:

- Changed both native storyboard backgrounds to the matte near-black Whoordan
  background color.
- Rebuilt and relaunched a signed release build on the iPhone.

## 5. Jank / Performance Findings

Not physically validated yet. The app was installed and launched, but this
environment could not inspect scrolling frames or capture the physical screen.

Still needs manual/device QA:

- Today vertical scroll
- More screen scroll
- Settings scroll
- Device diagnostics scroll
- Journal/Habits scroll if present
- Vibration editor interactions
- Tab switching

## 6. Approval Gate Results

Automated tests still cover the approval gate. Physical screen-by-screen gate
QA was not completed in this run because direct device screenshots and
interactive observation are manual.

Still needs manual verification:

- Signed-out user sees only auth flow.
- Pending user sees only locked screen.
- Pending user cannot access Today/local mode/settings/HealthKit/BLE/vibration/journal.
- Approved user unlocks app.
- Revoked user locks on foreground refresh.
- Cached health data is hidden before approval and after revocation.

## 7. Vibration Preview Results

Not physically validated. No connected wearable vibration was confirmed in this
run.

Validated by automated tests:

- Playback is blocked before approval.
- Playback is blocked when device is disconnected.
- Built-in pattern sends when approved and connected through the adapter.
- Unsafe patterns are rejected.
- BLE write failure does not report success.
- Custom playback reports unsupported when the adapter does not support it.

Manual device QA still needed:

- Connect supported wearable.
- Approve account.
- Open vibration settings/editor.
- Preview built-in pattern.
- Confirm wearable vibrates.
- Confirm diagnostics record last preview time/status/error.
- Disconnect wearable and confirm disconnected state.
- Confirm custom playback reports unsupported.

## 8. Accessibility Quick Pass

Not physically validated on iPhone in this run. Automated widget/source tests
still cover release-safe copy, shared state widgets, and reduced-motion helper
behavior.

Manual checks still needed:

- Large text
- VoiceOver basics
- Reduced motion
- Tap targets
- Contrast on physical device
- Screen-reader labels for auth, approval, tabs, and vibration preview buttons

## 9. Validation Results

- `flutter pub get`: passed.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 158 tests.
- `flutter build ios --no-codesign`: passed before the native storyboard fix.
- `flutter run --release -d [REDACTED_DEVICE_ID]`: passed after the
  native storyboard fix and launched on the iPhone.
- `git diff --check`: passed before docs update; rerun required after final
  docs.

## 10. Remaining Blockers

- Debug `flutter run` still times out at the Xcode debug-session attach step on
  this machine. For debugging, open `ios/Runner.xcworkspace` and use
  Product > Run, or clear Xcode Automation prompts/settings and retry
  `flutter run`.
- Physical screen screenshots were not captured by tooling.
- Full visual QA is still manual/pending.
- Scroll smoothness is still manual/pending.
- Physical vibration playback is still manual/pending.
- VoiceOver/large text/reduced motion physical QA is still manual/pending.
