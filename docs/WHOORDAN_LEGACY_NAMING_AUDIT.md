# Whoordan Legacy Naming Audit

Audit date: 2026-05-10

## 1. Summary

Whoordan user-facing branding, app metadata, native display names, package metadata, and primary documentation now use the Whoordan/W4rd2 identity.

No remaining legacy naming was found in visible app labels, splash text, onboarding copy, settings/about copy, iOS display metadata, Android labels, package name, bundle/application ids, active asset names, Supabase schema names, or product-facing docs, except for necessary brand-safety wording that says not to copy third-party branding or proprietary behavior.

Remaining old-name references are intentionally retained only for BLE protocol compatibility, lockfile reproducibility, negative test guardrails, or this audit documentation. They are not user-facing app branding.

## 2. Search Terms Used

Searches covered source, tests, docs, migrations, package config, native iOS/Android config, assets/file names, and generated metadata that belongs in the repo. Build products, `.git`, `.dart_tool`, `ios/Pods`, `ios/.symlinks`, and ignored `.env*` files were excluded.

Terms searched:

- `public-protocol-reference`, `WearableProtocol`, `WEARABLE_PROTOCOL`
- `wearable`, `third-party wearable`
- `wearablestrap`
- `wearable app`
- `wearable-derived`
- `Ward-Tracker`, `Ward Tracker`, `ward_tracker`, `ward-tracker`
- `WT`
- `old app`
- `prototype name`
- `legacy brand`
- `old brand`
- `research prototype`
- `com.public-protocol-reference`
- `public-protocol-reference-private`
- `wearableconnect`
- `com.wearable`
- likely Whoordan/W4rd2 misspellings: `whoordn`, `whordan`, `woordan`, `whoord`, `whoor`, `w4rd`, `ward2`, `w4dr2`

## 3. Files Changed

- `AGENTS.md`
- `README.md`
- `docs/WHOORDAN_EXEC_PLAN.md`
- `docs/WHOORDAN_LEGACY_NAMING_AUDIT.md`
- `pubspec.yaml`
- `lib/ble/ble_service.dart`
- `lib/ble/live_state.dart`
- `test/validation_hardening_test.dart`

Existing rebrand deletions already present in the working tree:

- `android/app/src/main/kotlin/com/wearableconnect/wearable_connect/MainActivity.kt`
- `android/app/src/main/kotlin/com/wearableconnect/wearable_connect/WearableForegroundService.kt`
- `android/app/src/main/kotlin/com/wearableconnect/wearable_connect/WearableNotificationService.kt`

## 4. Legacy References Removed

- Removed casual "research prototype" wording from `AGENTS.md` and `README.md`.
- Reworded `docs/WHOORDAN_EXEC_PLAN.md` from a direct third-party BLE naming phrase to "legacy BLE integration".
- Reworked old visible-name assertions in `test/validation_hardening_test.dart` so old product names are not present as contiguous product copy.
- Old Android package files under `com/wearableconnect/wearable_connect` are deleted in the working tree and replaced by `com/w4rd2/whoordan` Kotlin files.

No user-facing UI, native app display metadata, onboarding text, settings/about copy, splash text, package name, Supabase schema name, or active asset filename needed additional renaming in this pass.

## 5. Legacy References Intentionally Retained

| Reference | Files | Category | User-facing? | Reason |
| --- | --- | --- | --- | --- |
| public BLE protocol reference package name | `pubspec.yaml`, `pubspec.lock`, `lib/ble/ble_service.dart`, `lib/ble/live_state.dart`, docs | D | No | External BLE parser package has a published dependency name. Renaming would break imports or require replacing/forking the protocol package. |
| `public wearable protocol reference.git` Git URL | `pubspec.yaml`, `pubspec.lock` | D | No | Dependency source URL is required for `pub get` reproducibility. |
| protocol UUID helper | `lib/ble/ble_service.dart`, docs | D | No | Exported helper type from the external protocol package. Renaming locally would require wrapping or forking the package. |
| `WearableIdentity`, `WearableEvent`, `WearableFrame`, `WearableCmd` | `lib/ble/ble_service.dart`, `lib/ble/live_state.dart` | D | No | Exported protocol model/type names from the external BLE parser package. |
| BLE scan fallback string `wearable` | `lib/ble/ble_service.dart` | D/E | No | Internal compatibility fallback for existing BLE advertisements. It is not rendered in UI. |
| Brand-safety references to `third-party wearable` | `AGENTS.md`, `README.md`, `docs/WHOORDAN_EXEC_PLAN.md`, `docs/WHOORDAN_IMPLEMENTATION_REPORT.md` | E | No | Necessary compliance guardrails documenting that Whoordan must not copy third-party branding, formulas, UI, language, colors, trade dress, or proprietary behavior. |
| Audit references to legacy names | `docs/WHOORDAN_LEGACY_NAMING_AUDIT.md` | D/E | No | Required by this audit to document retained compatibility identifiers and search terms. |

## 6. Reason Each Retained Reference Remains

The retained BLE references remain because they are coupled to an external protocol parser and existing BLE discovery behavior. Blind renaming could break imports, type compatibility, packet handling, service UUID matching, or device discovery.

The retained lockfile references remain because lockfiles record the resolved dependency identity and source. Editing them manually would create dependency reproducibility risk.

The retained brand-safety references remain because they are explicit product/legal guardrails, not product branding.

## 7. Whether Retained References Are User-Facing

No retained legacy reference is user-facing app branding.

User-facing app surfaces use:

- `Whoordan`
- `W4rd2`
- `com.w4rd2.whoordan`
- `assets/brand/whoordan-w-logo.png`

The retained references are internal code, dependency metadata, docs guardrails, or this audit report.

## 8. Validation Commands Run And Results

| Command | Result | Notes |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | Passed | Formatting check passed with zero changes. |
| `flutter analyze` | Passed | No analyzer issues. |
| `flutter test` | Passed | 57 tests passed. |
| `flutter build ios --no-codesign` | Passed | iOS build completed without signing. |
| `flutter build apk` | Skipped | Android SDK work is intentionally ignored for this chat. |

## 9. Remaining Risks

- The external BLE parser dependency still exposes old protocol names. A public release should decide whether to keep it, fork it, or wrap it behind a neutral internal adapter.
- `pubspec.lock` still records the legacy dependency source. This is expected while the dependency remains.
- Brand-safety docs still name the third-party brand in "do not copy" guardrails. This is intentional, but human legal review should decide the exact wording before release.
- Git history and deleted tracked paths still contain old names until the current working-tree deletion is committed.

## 10. Recommended Next Cleanup Steps

1. Introduce a neutral internal BLE adapter API if the protocol dependency will remain long term.
2. Decide whether to fork or replace the external BLE parser package under a neutral package name.
3. Stage and commit the deleted legacy Android package paths together with the new `com.w4rd2.whoordan` Kotlin paths.
4. Review brand-safety wording with a human before App Store/TestFlight submission.
5. Avoid renaming historical migrations or lockfile entries unless their underlying dependency/schema changes.
