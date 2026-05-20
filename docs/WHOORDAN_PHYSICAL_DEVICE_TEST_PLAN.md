# Whoordan Physical Device Test Plan

Updated: 2026-05-11

This is a test plan only. It does not claim that any physical device tests have
been run.

## References

- Apple HealthKit reading data:
  https://developer.apple.com/documentation/healthkit/reading_data_from_healthkit
- Apple Health data privacy model:
  https://support.apple.com/guide/security/protecting-access-to-users-health-data-sec88be9900f/web
- Apple notification authorization:
  https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications
- Apple CallKit:
  https://developer.apple.com/documentation/callkit
- Apple TestFlight overview:
  https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- Android Bluetooth permissions:
  https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
- Android foreground services:
  https://developer.android.com/develop/background-work/services/fgs
- Android foreground service types:
  https://developer.android.com/develop/background-work/services/fgs/service-types
- Android notification listener service:
  https://developer.android.com/reference/android/service/notification/NotificationListenerService

## 1. Required Devices

### iOS

- iPhone running a current public iOS release.
- iPhone running the oldest iOS version Whoordan intends to support, if
  available.
- Apple Watch paired to one iPhone, preferred for real Apple Health heart-rate,
  sleep, HRV, activity, and workout data.
- Optional second iPhone for clean-install and upgrade-migration comparison.

### Android

- Android 11 or older API 30 device to validate legacy BLE location behavior.
- Android 12+ API 31 or newer device to validate Nearby Devices/Bluetooth
  runtime permission behavior.
- Current flagship or current emulator-backed physical test device for
  foreground service, background restriction, and battery optimization behavior.

### Wearable And BLE

- Whoordan-compatible wearable with current test firmware.
- Wearable or firmware test mode capable of producing valid, duplicate,
  malformed, delayed, and out-of-order packets.
- BLE sniffer or firmware logs when available.
- USB cables and host machines for `adb logcat`, Xcode device logs, and crash
  log collection.

## 2. Required Accounts

- Apple Developer account with access to the Whoordan app record.
- TestFlight internal tester account and at least one external tester account.
- Apple ID signed into the iPhone used for Health and TestFlight.
- Supabase dev project user A with email/password.
- Supabase dev project user B with email/password.
- Optional Apple Health test account with Apple Watch historical data.
- No production personal health account should be used for destructive tests.

## 3. Required Supabase Dev Project Setup

- Use a Supabase development project or branch, not production.
- Apply all Whoordan migrations from `supabase/migrations`.
- Confirm every user-data table has RLS enabled and forced.
- Confirm owner-scoped policies use `auth.uid()` or equivalent user ownership
  checks.
- Confirm only a publishable/anon key is configured in the mobile app.
- Do not place service-role keys on any test device, in `.env`, or in client
  code.
- Enable leaked password protection manually in Supabase Auth settings.
- Create two disposable email/password users.
- Run the two-user RLS probe separately before cloud-sync physical testing:

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_PUBLISHABLE_KEY="<public publishable or anon key>"
export RLS_PROBE_USER_A_EMAIL="user-a@example.com"
export RLS_PROBE_USER_A_PASSWORD="<password>"
export RLS_PROBE_USER_B_EMAIL="user-b@example.com"
export RLS_PROBE_USER_B_PASSWORD="<password>"
bash scripts/supabase/two_user_rls_probe.sh
```

Expected: both users can access their own rows; cross-user and unauthenticated
private-row access returns no private rows.

## 4. Required Apple Health Setup

- Open Health app and confirm health data exists for the selected types:
  heart rate, resting heart rate, HRV, respiratory rate, sleep, steps, active
  energy, distance, workouts, wrist/body temperature, SpO2, VO2 max where
  available.
- Add manual Health samples for missing low-risk types when Apple Watch data is
  unavailable.
- For sensitive types, create only synthetic test entries if needed:
  menstrual flow, irregular rhythm events, body composition.
- Confirm Whoordan is not authorized before the first permission test.
- Prepare three permission states:
  denied, partial, and authorized.
- Confirm Apple Health remains independent from cloud sync: granting Health
  permission must not grant cloud upload consent.

## 5. Required Wearable/Firmware Assumptions

- Firmware exposes the current Whoordan BLE service and packet formats expected
  by the app.
- Firmware can send identity, battery, heart-rate, PPG/SpO2, RR/HRV, recovery
  summary, and historical handshake batches where supported.
- Firmware has a documented way to reset pairing and clear bonded state.
- Firmware either supports missing-sample range backfill or clearly reports that
  arbitrary range backfill is unsupported.
- Firmware can send malformed, duplicate, and out-of-order test packets, or the
  test team has a BLE proxy/debug harness that can do so.
- Haptic preview support is available for built-in patterns. Custom interval
  playback must be treated as unsupported unless firmware confirms it.

## 6. Step-By-Step iPhone Tests

### TestFlight Install And First Launch

1. Install the build from TestFlight on a clean iPhone.
2. Confirm app name and icon are Whoordan/W4rd2.
3. Launch the app.
4. Confirm there is no crash, signing error, entitlement error, or immediate
   login flash.
5. Confirm signed-out users see only auth screens.
6. Sign in with an approved Supabase test user.
7. Choose local-only mode from Settings.
8. Force close and relaunch.
9. Confirm local-only state is restored only after approval is verified.

Pass: install succeeds, first launch is stable, and local-only is available only
after sign-in and approval.

### HealthKit Denied State

1. Start in local-only mode.
2. Open Health/Apple Health connection settings in Whoordan.
3. Trigger permission request.
4. Deny all permissions.
5. Return to Whoordan.
6. Confirm UI shows denied or unavailable state honestly.
7. Confirm no fake Health data appears.
8. Confirm cloud sync remains disabled.

Pass: denied state is explicit and no Health data is imported or uploaded.

### HealthKit Partial State

1. Reset Health permissions for Whoordan in iOS Settings or Health app.
2. Request authorization again.
3. Grant only a subset such as steps and workouts.
4. Import latest.
5. Confirm only authorized/importable data appears.
6. Confirm source labels identify Apple Health where useful.
7. Confirm unavailable types show empty/permission states, not zeros that imply
   real measurements.

Pass: partial permission is handled without crashes, fake values, or cloud
   upload.

### HealthKit Authorized Historical Import

1. Grant standard Health read permissions.
2. Import latest.
3. Confirm imported samples include expected types and source metadata.
4. Compare a small sample set against Health app values for date, unit, and
   approximate value.
5. Relaunch app.
6. Confirm cached local data opens quickly before any cloud work.
7. Import latest again.
8. Confirm duplicates are skipped.

Pass: historical import is stable, deduped, locally cached, and source-labeled.

### Sensitive Health Types

1. Without sensitive local consent, verify menstrual, pregnancy-context, body
   composition, and irregular rhythm views hide sensitive imported samples.
2. Grant the relevant in-app local consent.
3. Request/import relevant Health types.
4. Confirm the app uses cautious wellness/display language only.
5. Confirm no diagnosis, pregnancy detection, fertility, contraception, or
   rhythm diagnosis claims appear.

Pass: sensitive data is consent-gated and copy remains non-medical.

### Apple Health And Cloud Independence

1. Authorize Apple Health.
2. Keep Whoordan in local-only mode.
3. Import Health data.
4. Disable network.
5. Confirm dashboard still uses cached local data.
6. Re-enable network.
7. Confirm no cloud sync starts unless account mode and cloud consent are
   explicitly enabled.

Pass: Apple Health permission does not imply cloud upload consent.

## 7. Step-By-Step Android Tests

### Fresh Install And Local-Only

1. Install debug, internal, or release-candidate APK on a clean Android device.
2. Launch Whoordan.
3. Sign in with an approved Supabase test user.
4. Choose local-only mode from Settings.
5. Confirm cloud sync remains disabled and no health data upload starts.
6. Relaunch offline with the cached approved session.
7. Confirm local-only state and cached local data load only after approval is confirmed.

Pass: local-only works online and offline only for approved signed-in users.

### Android BLE Permissions

1. On Android 12+, start wearable scan.
2. Confirm Nearby Devices/Bluetooth permission prompt appears when needed.
3. Deny permission.
4. Confirm the app shows a permission state, not a crash.
5. Grant permission and retry scan.
6. On Android 11/API 30 device, verify legacy location permission behavior is
   scoped to BLE scanning requirements and not requested on newer Android when
   not needed.

Pass: BLE permission handling matches platform version and stays understandable.

### Foreground Service And Background Restrictions

1. Pair a wearable.
2. Start live capture.
3. Background the app.
4. Confirm any foreground service notification does not show live health values.
5. Leave device idle for 15, 30, and 60 minutes.
6. Return to app and confirm UI shows current connection/sync state honestly.
7. Repeat with battery saver enabled.

Pass: no sensitive notification text, no crash, no claim of continuous capture
   if the OS pauses work.

## 8. BLE Tests

### Pairing

1. Reset wearable bond/pairing.
2. Launch Whoordan in local-only mode.
3. Scan for wearable.
4. Pair/connect.
5. Confirm identity, battery, firmware, and device diagnostics populate.
6. Confirm first samples use the wearable device ID, not `unknown`.

Pass: pairing is optional for local-only but works when selected.

### Reconnect

1. Pair wearable and start live capture.
2. Turn wearable off or move it out of range.
3. Confirm disconnected state and diagnostics update.
4. Turn wearable back on or return in range.
5. Confirm saved/known reconnect path runs without requiring full onboarding.
6. Confirm missing-sample request is attempted where supported.
7. If firmware does not support range backfill, confirm the app records the
   unsupported state honestly.

Pass: reconnect is stable and does not pretend unsupported backfill succeeded.

### Malformed Packets

1. Use firmware test mode or BLE proxy to send invalid HR, SpO2, HRV,
   respiratory, timestamp, and summary packets.
2. Confirm invalid packets are rejected.
3. Confirm app remains responsive.
4. Confirm no sensitive raw packet payload is logged.

Pass: malformed packets do not create production metrics or crashes.

### Duplicate Packets

1. Send the same valid packet twice with the same source record ID/packet ID.
2. Confirm only one local health sample is retained.
3. Confirm sync payload preview does not include duplicate samples.

Pass: stable dedupe works locally and before sync.

### Out-Of-Order Packets

1. Send packet A at `t2`, then packet B at older `t1`.
2. Confirm both valid packets are retained if unique.
3. Confirm older packet carries out-of-order diagnostic metadata.
4. Confirm charts/summary ordering remains coherent.

Pass: out-of-order packets are handled without corrupting the timeline.

## 9. Background/Lifecycle Tests

### iOS Lifecycle

1. Sign in to account mode but keep health cloud sync disabled.
2. Background the app for 15 minutes.
3. Relaunch.
4. Confirm no cloud sync occurred without consent.
5. Enable cloud sync with explicit consent.
6. Import or create local records.
7. Background app and allow OS background wake opportunities.
8. Relaunch and inspect sync status.
9. Force quit the app and verify no guaranteed background sync is claimed.

Pass: foreground/lifecycle sync is honest, and iOS limitations are not hidden.

### Android Lifecycle

1. Pair wearable and create local data.
2. Background app.
3. Toggle network off/on.
4. Reopen app.
5. Confirm queued work drains on foreground/network reconnect path where
   implemented.
6. Disable battery optimization only for a comparison run; do not require users
   to disable it for basic local-only use.

Pass: sync state is visible and bounded; no aggressive background polling.

### Offline Launch And Session Restore

1. Sign in as Supabase test user A.
2. Confirm session restore works online.
3. Enable airplane mode.
4. Kill and relaunch app.
5. Confirm cached account opens without login flash where session cache is valid.
6. Confirm cloud writes queue or remain blocked until network/session restore.
7. Sign out online.
8. Relaunch.
9. Confirm secure session is cleared.

Pass: offline launch is usable, and sign-out clears session/sync state.

## 10. Privacy/Security Tests

### Local-Only Privacy

1. Fresh install.
2. Sign in with an approved Supabase test user.
3. Choose local-only mode from Settings.
4. Pair wearable and/or import Health data.
5. Leave cloud sync disabled.
6. Monitor network traffic with a test proxy or OS logs.
7. Confirm no health data leaves the device.
8. Confirm local data export warns that exported data is sensitive.

Pass: local-only never uploads health data.

### Cloud Consent

1. Sign in as user A.
2. Keep cloud sync disabled.
3. Create Health, journal, habit, workout, haptic, and alarm data.
4. Confirm no upload occurs.
5. Enable cloud sync through explicit consent.
6. Run Manual Sync Now.
7. Confirm only consented categories sync.
8. Revoke cloud sync.
9. Create more local data.
10. Confirm no further upload occurs.

Pass: cloud sync is consent-gated and revocable.

### Two-User Data Isolation

1. Sign in as user A and sync a small dataset.
2. Sign out.
3. Sign in as user B on the same device or a second device.
4. Confirm user B cannot see user A's private rows.
5. Repeat on Supabase REST probe script.

Pass: RLS and app cache boundaries prevent cross-user exposure.

### Sensitive Logging

1. Run device logs during HealthKit import, BLE streaming, auth, sync, and
   haptic preview.
2. Search logs for access tokens, refresh tokens, Authorization headers, sample
   values, journal notes, HealthKit raw payloads, and BLE packet dumps.

Pass: sensitive data and secrets are not logged.

## 11. Pass/Fail Checklist

Use `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN`.

| Area | Result | Notes |
|---|---|---|
| TestFlight install succeeds on clean iPhone | NOT RUN | |
| iPhone local-only onboarding works | NOT RUN | |
| iPhone offline relaunch works | NOT RUN | |
| HealthKit denied state is honest | NOT RUN | |
| HealthKit partial state is honest | NOT RUN | |
| HealthKit authorized import maps units/dates/sources | NOT RUN | |
| HealthKit duplicate import is deduped | NOT RUN | |
| Sensitive HealthKit types require local consent | NOT RUN | |
| Apple Health does not imply cloud consent | NOT RUN | |
| Android local-only onboarding works | NOT RUN | |
| Android BLE permission denial is handled | NOT RUN | |
| Android BLE permission grant allows scan/connect | NOT RUN | |
| Wearable pairing succeeds | NOT RUN | |
| Wearable reconnect succeeds or fails honestly | NOT RUN | |
| BLE malformed packets are rejected | NOT RUN | |
| BLE duplicate packets are deduped | NOT RUN | |
| BLE out-of-order packets remain coherent | NOT RUN | |
| Built-in vibration preview works when connected | NOT RUN | |
| Custom vibration safety limits hold | NOT RUN | |
| Alarm vibration settings save/edit/delete | NOT RUN | |
| Native alarm scheduling is not claimed if absent | NOT RUN | |
| Notification/call vibration limitations are honest | NOT RUN | |
| Local-only makes no cloud uploads | NOT RUN | |
| Cloud sync requires explicit consent | NOT RUN | |
| Cloud consent revocation stops upload | NOT RUN | |
| Session restore works online | NOT RUN | |
| Session restore works offline with cached session | NOT RUN | |
| Sign-out clears secure session and stops sync | NOT RUN | |
| Background sync is bounded and platform-honest | NOT RUN | |
| Network reconnect drains queued work where implemented | NOT RUN | |
| Device logs do not expose secrets/health payloads | NOT RUN | |
| No fake production metrics are shown | NOT RUN | |
| No medical diagnosis claims appear | NOT RUN | |

## 12. Known Platform-Blocked Items

- iOS does not provide a general third-party API for intercepting all other
  apps' notifications and calls for custom wearable vibration rules.
- iOS CallKit is for VoIP/native call UI integration and call directory
  extensions; it is not a general phone-call mirroring API for arbitrary calls.
- Android notification-listener behavior requires sensitive user-granted system
  access and policy review. Whoordan must not present it as enabled unless the
  permission surface and review scope are implemented.
- Native alarm scheduling/snooze is not complete unless platform alarm APIs,
  permissions, and exact-alarm behavior are implemented and tested.
- Continuous background sync or BLE capture cannot be guaranteed on iOS or
  Android because the OS may throttle, suspend, or stop background execution.
- Arbitrary BLE historical range backfill is blocked unless the wearable
  firmware/protocol exposes a supported request.
- Full local database-file encryption is not active; app payloads are encrypted,
  but SQLite index metadata remains plaintext until a SQLCipher-class migration
  is validated.

## 13. Bug Report Template

```markdown
## Title

Short action-oriented summary.

## Environment

- Platform:
- Device model:
- OS version:
- Whoordan build/version:
- Install source: TestFlight / debug / internal APK
- Account mode: local-only / account / cloud-sync consented
- Supabase project:
- Wearable model:
- Firmware version:
- Network state: Wi-Fi / cellular / offline / captive / flaky

## Preconditions

- Permissions granted/denied:
- Apple Health data types authorized:
- BLE pairing state:
- Cloud consent state:
- Existing local data:

## Steps To Reproduce

1.
2.
3.

## Expected Result

What should happen, including privacy/security expectations.

## Actual Result

What happened. Do not paste tokens, auth headers, raw health data, or private
journal text.

## Evidence

- Screenshot or screen recording:
- Redacted device logs:
- Redacted Supabase request ID/log line:
- Wearable firmware log:
- Approximate timestamp with timezone:

## Privacy/Security Impact

- Health data exposed? yes/no/unknown
- Token/session exposed? yes/no/unknown
- Cross-user data risk? yes/no/unknown
- Local-only/cloud-consent violated? yes/no/unknown

## Severity

- P0: privacy/security/data loss/crash preventing core use
- P1: core HealthKit/BLE/sync/session failure
- P2: feature failure with workaround
- P3: UI/copy/polish issue

## Regression Info

- Reproduces on previous build? yes/no/unknown
- Reproduces after reinstall? yes/no/unknown
- Reproduces with a second account/device? yes/no/unknown
```
