# Repository Instructions for Codex

This repository is being directed toward Whoordan, a premium health, recovery, sleep, strain, and fitness tracking app by W4rd2.

## Operating Rules

- Inspect before editing. Read the relevant Swift, Xcode project, script, test, and documentation files before making changes.
- Preserve the existing native SwiftUI architecture where practical. Prefer incremental `AppEnvironment`, `Core`, `DesignSystem`, and feature-screen changes over broad rewrites unless a task explicitly asks for a migration.
- Do not touch secrets, global machine config, git remotes, signing credentials, provisioning profiles, or unrelated files.
- Never add service-role keys, admin API keys, private signing material, or hardcoded user credentials to the app or docs.
- Treat HealthKit, Apple Health, BLE, sleep, heart rate, HRV, SpO2, recovery, strain, and fitness data as sensitive personal data.
- After approval, local-only health-data mode must not call cloud sync, analytics, remote config, or backend health-data APIs except the auth, approval, and session checks required by the access gate.
- Cloud sync must require explicit user consent before any health or fitness data leaves the device.
- Supabase sync must use client-safe publishable/anon keys and row-level security. Never use Supabase service-role keys in mobile code.
- Email/password auth is implemented through Supabase Auth; current auth and approval-gate behavior must be inspected before changing it.
- Do not make medical diagnosis, treatment, prevention, or cure claims. Keep language in the wellness and fitness domain.
- Use original formulas and clearly document their inputs, limitations, and non-medical intent.
- Do not copy third-party branding, formulas, UI, language, colors, trade dress, proprietary behavior, or product claims.
- The Whoordan logo must be an original premium AI-generated image centered around the letter "W"; do not reuse legacy prototype assets as the final logo.
- When installing Whoordan on Ward's physical iPhone, always use `scripts/build-install-ios-supabase.sh`. Do not install to the iPhone through ad hoc `xcodebuild`, Xcode Run, or direct `devicectl` commands unless Ward explicitly authorizes an exception.
- Run validation after changes. At minimum, prefer the narrowest relevant `xcodebuild` test/build command when Swift or project files change.
- Document blocked work honestly, including commands that could not be run and why.

## Current Architecture Notes

- The app is currently a native SwiftUI iOS app in `Whoordan.xcodeproj`. Flutter/Dart/Android paths are not the active app architecture.
- App composition lives under `Whoordan/App/`. `AppRootView` switches between session restore, signed-out auth, approval-locked, and approved routes. The approved shell is a SwiftUI `TabView` with Today, Recovery, Sleep, Activity, and More tabs; feature screens use `NavigationStack` and `NavigationLink`.
- State and dependency wiring currently use a `@MainActor` `ObservableObject` `AppEnvironment`, `@Published` app state, protocol-backed services, async tasks, and Combine where needed for SwiftUI updates.
- Feature surfaces live under `Whoordan/Features/` and should depend on app/core abstractions instead of owning platform, network, or persistence integrations. Shared UI primitives live under `Whoordan/DesignSystem/`.
- Local persistence currently uses `FileProtectedLocalStore` for a file-protected local JSON snapshot, health records, sync queues, HealthKit/BLE checkpoints, journal, alarms, and haptic settings. Supabase auth sessions are stored in Keychain.
- Supabase Auth is available for email/password account mode when client-safe public configuration is supplied. Supported inputs include `WHOORDAN_SUPABASE_URL`, `WHOORDAN_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_PROJECT_ID`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_ANON_KEY`. Use only public anon/publishable keys in mobile code.
- Health-data cloud sync is separate from account sign-in and must remain approval- and consent-gated. Existing local health data must not upload or migrate automatically without explicit cloud health sync consent.
- Apple Health / HealthKit support is native Swift, with entitlements, privacy usage strings, authorization state, anchored import/checkpoint support, app-origin write queues, and local sample storage. Do not upload HealthKit data unless cloud sync is explicitly enabled and consented.
- BLE, wearable haptics, notification/call/alarm routing, recovery, strain, sleep, heart, and movement logic live under `Whoordan/Core/` with unit and contract coverage in `WhoordanTests/`.

## Files and Areas to Avoid Unless Tasked

- Do not edit `.env*`, `config.local.*`, signing files, provisioning files, or Xcode user-specific workspace data unless explicitly tasked.
- Avoid generated or build output: `build/`, DerivedData, `.dart_tool/`, `.pub/`, `.pub-cache/`, generated plugin registrants, and any stale Flutter/Android/iOS generated artifacts unless the task is explicitly migration cleanup.
- Avoid native project metadata churn unless dependency, target, entitlement, or build-setting changes require it.
- Be careful with existing dirty files. If a file has user changes unrelated to the task, work around them or inspect them before editing; never revert them without an explicit request.

## Validation Commands

- `xcodebuild -list -project Whoordan.xcodeproj`
- `xcodebuild test -project Whoordan.xcodeproj -scheme Whoordan -destination 'platform=iOS Simulator,name=iPhone 17'`
- `xcodebuild build -project Whoordan.xcodeproj -scheme Whoordan -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
- `swiftlint lint --config .swiftlint.yml`

Use the narrowest validation that fits the change. For documentation-only changes, no app build is normally required.

## Ward Codex Architecture Compatibility

This project follows Ward's universal Codex settings from `codex-settings`.
Project-local instructions are subordinate to Ward global safety, source-of-truth, no API billing, capability proof, validation, and Obsidian vault rules.
Persistent Codex project planning, memory, sessions, agent artifacts, and runtime preferences belong in:
`${OBSIDIAN_CODEX_VAULT}/10-project-brains/whoordan/`
Do not create durable Codex brain artifacts in this repository.
The project `.env` may remain as a local ignored runtime configuration file, but Codex must not read, print, index, summarize, copy, or commit it.
Allowed project-specific Codex runtime preferences are only:
- `model`
- `reasoning_effort`
and they belong in the vault project brain runtime preferences file, not this repo.

Do not add a .codex-project.toml.

Do not add repo-local Codex planning/memory folders.
