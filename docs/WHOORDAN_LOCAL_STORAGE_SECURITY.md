# Whoordan Local Storage Security

Updated: 2026-05-11

## Storage Architecture Chosen

Whoordan now uses an indexed encrypted local storage adapter for the app-owned
local repository:

- implementation: `IndexedEncryptedLocalStorageAdapter`
- database engine: SQLite through `sqflite`
- production provider: `localStorageAdapterProvider`
- legacy migration source: `SharedPreferencesStorageAdapter`
- key storage: `flutter_secure_storage`

The repository API remains stable, but the production adapter no longer stores
large health collections as SharedPreferences string blobs. Collection writes are
split into per-record SQLite rows.

Indexed encrypted collections:

- consent records
- health samples from Apple Health, BLE, manual workouts, and local actions
- daily health summaries
- journal entries
- habit definitions
- habit logs
- vibration patterns
- wearable alarms
- sync history
- pending sync jobs

Encrypted key-value records:

- local profile
- cached non-token cloud account snapshot
- user settings and haptic/settings preferences
- sync state/checkpoints
- HealthKit anchors
- device diagnostics

`SharedPreferencesStorageAdapter` remains available for legacy migration and
unit tests. It is no longer the default production repository adapter.

## Encryption Approach

The current implementation uses row-level application encryption:

- AES-GCM with 256-bit keys from the `cryptography` package
- one encrypted payload per key-value row or collection record
- encryption key generated on first use
- encryption key stored only in `flutter_secure_storage`
- no health sample values, notes, journal payloads, haptic patterns, or sync job
  payloads are stored as plaintext database payloads

The adapter intentionally keeps a small set of index metadata outside the
encrypted payload so the app can query and sync efficiently:

- storage key
- record type
- source
- device ID
- local date key
- timestamp
- imported-at timestamp
- updated-at timestamp
- sync status
- stable sample ID hash

Stable sample IDs and dedupe keys are indexed as deterministic SHA-256 hashes,
not stored as raw plaintext index values.

## Full Database Encryption Limitation

Full SQLite file encryption was not added in this pass. The safer current choice
for this Flutter stack is app-level payload encryption on top of the standard
`sqflite` driver, because replacing the SQLite driver with a SQLCipher-specific
package would add native build and device-validation risk.

Known limitation: SQLite index metadata is still visible to someone with direct
access to the database file. The sensitive payload values are encrypted, but
metadata such as source, type, device ID, date, and sync status remains
plaintext to support indexed local queries. A future SQLCipher migration can
encrypt the full file after iOS and Android build/device validation.

## Indexes

The local database creates indexes for:

- date: `storage_key, date_key`
- type: `storage_key, record_type`
- source: `storage_key, source`
- device ID: `storage_key, device_id`
- sync status: `storage_key, sync_status`
- timestamp: `storage_key, timestamp_ms`
- imported-at: `storage_key, imported_at_ms`
- updated-at: `storage_key, updated_at_ms`
- stable sample ID hash: unique `storage_key, stable_id_hash`

These indexes support local dashboard reads, incremental sync, HealthKit import
queries, BLE sample lookup, and deduplication without storing large datasets in
SharedPreferences.

## Migration Behavior

On first open, `IndexedEncryptedLocalStorageAdapter` migrates all known
Whoordan local repository keys from legacy SharedPreferences into SQLite:

1. creates the encrypted SQLite schema
2. reads each known legacy local repository key
3. writes collections as encrypted per-record rows
4. writes single records as encrypted key-value rows
5. removes migrated legacy keys from SharedPreferences
6. writes a migration marker so the migration is not repeated

The migration is local only. It does not call Supabase, does not upload data,
does not change cloud consent, and does not enable Apple Health sync.

## Local-Only And Cloud Consent

Local-only mode remains independent of cloud sync, but it no longer bypasses
the private-app approval gate:

- users must be signed in and manually approved before local-only mode unlocks
- approved local-only users can keep using BLE, Apple Health imports, journal,
  habits, haptics, and local dashboards without cloud upload
- cloud sync still requires signed-in account state and explicit cloud-sync
  consent
- preparing local-to-cloud migration still sets `uploadAllowed` to false
- background/headless sync reads the same encrypted local repository and returns
  before cloud work when consent is not granted

## Sensitive Logging

The local storage adapter does not log health payloads, encryption keys, session
tokens, auth headers, or decrypted records. Tests also assert that encrypted
payload storage does not contain plaintext sample source/type/device metadata in
the encrypted payload field.

## Remaining Limitations

- Full database-file encryption is not active yet; payloads are encrypted but
  index metadata remains plaintext.
- Existing small BLE pairing flags and saved device identifiers outside the
  local repository still use SharedPreferences. They are not large health
  datasets, but moving them into the encrypted repository would further reduce
  metadata exposure.
- Existing repository methods still rewrite whole collections on some updates.
  The data now lands in indexed rows, but future work can add repository methods
  that update individual rows directly.
- Physical iOS and Android device validation is still required for encrypted
  database behavior in background isolates and app upgrades.

## Tests

Added `test/encrypted_local_storage_test.dart` covering:

- encrypted indexed record storage for health samples
- plaintext payload avoidance for encrypted record bodies
- indexed metadata for type, source, device ID, timestamp, and stable IDs
- repository dedupe preservation
- migration from legacy SharedPreferences keys
- removal of migrated legacy sensitive keys

Relevant validation commands:

- `flutter test test/encrypted_local_storage_test.dart`
- `flutter test test/local_mode_test.dart test/cloud_sync_engine_test.dart test/healthkit_test.dart test/encrypted_local_storage_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build ios --no-codesign`

Current validation result:

- `flutter pub get`: passed
- `flutter analyze`: passed
- `flutter test`: passed, 126 tests
- `flutter build ios --no-codesign`: passed
- `flutter build apk`: blocked because no Android SDK is configured in this
  environment

## References

- Flutter SQLite cookbook: https://docs.flutter.dev/cookbook/persistence/sqlite
- `sqflite`: https://pub.dev/packages/sqflite
- `cryptography`: https://pub.dev/packages/cryptography
- `flutter_secure_storage`: https://pub.dev/packages/flutter_secure_storage
