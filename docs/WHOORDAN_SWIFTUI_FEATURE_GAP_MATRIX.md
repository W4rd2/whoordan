# Whoordan SwiftUI Feature Gap Matrix

Generated: 2026-05-11 22:05 Asia/Qatar
Branch: `swift-app`

This gap matrix is derived from `WHOORDAN_FULL_FEATURE_IMPLEMENTATION_AUDIT.md`. It is strict: screens-only work is not counted as complete, simulator tests are not physical validation, and HealthKit/BLE/haptic features are not complete without real data flow and manual/hardware evidence.

## Counts

| Status | Count |
|---|---:|
| IMPLEMENTED_VALIDATED | 138 |
| IMPLEMENTED_NOT_PHYSICALLY_VALIDATED | 54 |
| PARTIAL | 152 |
| SCAFFOLDED | 40 |
| BLOCKED_PLATFORM | 3 |
| BLOCKED_CONFIG | 1 |
| MISSING | 20 |
| UNSAFE_NEEDS_FIX | 0 |
| TOTAL | 408 |

Status-count delta from the 21:30 audit: this pass reclassified the directly changed local-first rows for durable local storage, local-first ingestion, HealthKit anchors/background registration, BLE ACK/local persistence, and Supabase queue/retry/repair. Untouched feature rows retain their previous strict status.

## Gaps By Status

### IMPLEMENTED_VALIDATED

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 1 | App launch/session restore | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 7 | Admin approval gate | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 15 | Local-only mode blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 16 | App features blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 19 | HealthKit blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 20 | BLE blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 21 | Cloud sync blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 22 | Cloud sync consent | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 23 | Health-data cloud sync consent | A. APP ACCESS / AUTH / APPROVAL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 26 | Supabase config | B. SUPABASE / CLOUD / SYNC | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 27 | Publishable/anon key handling | B. SUPABASE / CLOUD / SYNC | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 28 | No service-role key | B. SUPABASE / CLOUD / SYNC | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 38 | Deduplication before upload | B. SUPABASE / CLOUD / SYNC | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 46 | Supabase advisor status | B. SUPABASE / CLOUD / SYNC | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 56 | Private CSV handling | C. LOCAL STORAGE / PRIVACY | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 60 | Medical disclaimer copy | C. LOCAL STORAGE / PRIVACY | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 61 | HealthKit capability/entitlement status | D. HEALTHKIT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 62 | Info.plist usage descriptions | D. HEALTHKIT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 70 | Unit conversion | D. HEALTHKIT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 71 | Source labels | D. HEALTHKIT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 72 | Deduplication | D. HEALTHKIT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 99 | Device identity/name decoding | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 100 | Serial/fingerprint decoding | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 102 | Frame decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 103 | CRC8 validation | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 104 | CRC32 validation | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 105 | Frame reassembler | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 106 | Fragment handling | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 107 | Padding handling | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 108 | Malformed packet handling | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 109 | Packet type decoding | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 110 | Command response decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 111 | Init handshake commands | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 112 | Data range decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 113 | Alarm response decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 115 | Metadata decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 116 | Batch marker decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 117 | Batch ACK builder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 121 | Realtime 0x28 decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 122 | Raw realtime 0x2B decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 123 | R10 decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 126 | Event 0x30 decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 127 | Double-tap event decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 132 | Haptic fired/terminated event decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 133 | Firmware log 0x32 decoder | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 139 | BLE source metadata | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 140 | BLE dedupe IDs | E. BLE / WEARABLE PROTOCOL | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 142 | Vibration pattern model | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 143 | Built-in vibration patterns | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 144 | Custom vibration pattern model | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 146 | Pattern safety limits | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 148 | Vibration preview service | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 149 | Harvard haptic command 0x4F | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 150 | Maverick/Gen4 haptic command 0x13 | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 151 | Stop haptics command | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 154 | Disconnected state | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 155 | Unsupported state | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 156 | Failed state | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 166 | HealthSample model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 167 | DailyHealthSummary model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 168 | SleepSession model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 174 | JournalEntry model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 184 | ConfidenceLevel model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 185 | Source resolver | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 186 | Source priority: wearable > Apple Health > manual > estimate > cloud copy | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 187 | Dedupe logic | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 188 | Local-day aggregation | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 189 | Timezone handling | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 191 | Missing-data handling | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 192 | Confidence scoring | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 193 | Measured/imported/calculated/estimated labeling | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 194 | Daily step count | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 195 | Step source priority | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 197 | Apple Health step fallback | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 198 | Step deduplication | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 199 | Step goal | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 201 | Steps on Today | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 203 | Movement minutes | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 204 | Movement contribution to strain | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 205 | Missing steps CTA | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 206 | Active energy | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 209 | Distance | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 217 | HRV method/source labeling | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 218 | No BPM-only fake HRV | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 219 | Heart-rate zones | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 223 | Respiratory rate | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 224 | SpO2 | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 225 | SpO2 estimate/debug labeling | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 226 | Temperature | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 229 | Out-of-baseline cautious copy | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 231 | No custom AFib detector | I. HEART / BODY SIGNALS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 235 | Recovery score 0-100 | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 237 | Recovery contributors | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 238 | Recovery confidence | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 239 | Recovery missing-data behavior | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 240 | HRV recovery contribution | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 241 | RHR recovery contribution | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 242 | Respiratory recovery contribution | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 243 | Sleep recovery contribution | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 244 | Temperature recovery contribution | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 249 | Strain score 0-21 | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 256 | Step/movement load | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 257 | Active energy load | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 261 | Physiological stress only | J. RECOVERY / STRAIN / STRESS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 266 | Sleep tracking/import | K. SLEEP | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 268 | Sleep duration | K. SLEEP | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 283 | Sleep source labels | K. SLEEP | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 284 | Sleep confidence | K. SLEEP | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 286 | No fake sleep stages | K. SLEEP | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 287 | Workout import | L. WORKOUTS / STRENGTH | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 290 | Workout type | L. WORKOUTS / STRENGTH | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 291 | Workout duration | L. WORKOUTS / STRENGTH | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 294 | Workout active energy | L. WORKOUTS / STRENGTH | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 296 | Workout distance/GPS | L. WORKOUTS / STRENGTH | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 335 | Association language only | M. JOURNAL / HABITS / INSIGHTS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 336 | No causation claims | M. JOURNAL / HABITS / INSIGHTS | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 354 | Not contraception | N. LONG-TERM / SPECIAL CONTEXT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 355 | Not fertility tool | N. LONG-TERM / SPECIAL CONTEXT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 358 | No pregnancy detection | N. LONG-TERM / SPECIAL CONTEXT | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 360 | SwiftUI app shell | O. UI / UX / ACCESSIBILITY | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 373 | Missing-data CTAs | O. UI / UX / ACCESSIBILITY | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 386 | No repeated awkward titles | O. UI / UX / ACCESSIBILITY | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 390 | Unit tests | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 392 | Simulator build | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 393 | Simulator test | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 394 | Physical iPhone build/run | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 399 | App icon/assets | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 401 | Bundle ID | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 402 | Signing/capabilities | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 405 | No raw private CSV committed | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 406 | No secrets committed | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 407 | No fake metrics | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |
| 408 | No unsafe medical claims | P. RELEASE / TESTING | Validated by current xcodebuild/test/static/MCP evidence where applicable. | Keep regression coverage; add physical/manual evidence where relevant. |

### IMPLEMENTED_NOT_PHYSICALLY_VALIDATED

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 8 | Pending approval screen | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 9 | Rejected screen | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 10 | Revoked screen | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 11 | Missing/error approval screen | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 12 | Approval refresh | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 13 | Revocation lockout | A. APP ACCESS / AUTH / APPROVAL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 29 | Supabase Auth integration | B. SUPABASE / CLOUD / SYNC | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 30 | Session restore/refresh | B. SUPABASE / CLOUD / SYNC | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 63 | HealthKit availability check | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 64 | HealthKit permission request | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 74 | Heart rate import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 75 | Resting heart rate import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 76 | HRV SDNN import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 77 | Respiratory rate import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 78 | Sleep analysis import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 79 | Steps import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 80 | Active energy import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 81 | Distance import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 82 | Workouts import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 83 | Oxygen saturation import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 84 | Temperature import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 85 | VO2/cardio fitness import | D. HEALTHKIT | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 89 | CoreBluetooth manager | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 90 | BLE permission flow | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 91 | BLE scan | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 92 | BLE connect | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 94 | BLE disconnect cleanup | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 95 | Service discovery | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 96 | Characteristic discovery | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 97 | Notify subscription | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 98 | Command write | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 101 | Connection state machine | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 119 | Realtime enable commands | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 134 | Device diagnostics | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 135 | RSSI | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 138 | Last packet display | E. BLE / WEARABLE PROTOCOL | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 147 | Vibration preview UI | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 152 | Haptic command ACK handling | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 157 | Device diagnostics for haptics | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 212 | Live heart rate | I. HEART / BODY SIGNALS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 215 | Resting heart rate | I. HEART / BODY SIGNALS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 216 | HRV | I. HEART / BODY SIGNALS | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 362 | Today dashboard | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 363 | Recovery screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 364 | Sleep screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 365 | Heart screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 366 | Movement/Steps screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 369 | Device screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 370 | Vibration screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 372 | Settings screen | O. UI / UX / ACCESSIBILITY | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |
| 391 | UI tests | P. RELEASE / TESTING | Code built and unit/simulator tests passed; physical/manual flow not completed in this audit. | Run scripted/manual validation on real iPhone or owned wearable and record redacted results. |

### PARTIAL

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 2 | Sign in | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 3 | Sign up | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 4 | Password reset | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 5 | Sign out | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 6 | Keychain session storage | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 17 | Cached health data hidden before approval/revocation | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 24 | Manual Supabase approval workflow | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 25 | Supabase RLS assumptions/live validation status | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 31 | Cloud sync architecture | B. SUPABASE / CLOUD / SYNC | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 32 | Initial sync | B. SUPABASE / CLOUD / SYNC | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 37 | Conflict handling | B. SUPABASE / CLOUD / SYNC | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 39 | Manual Sync Now | B. SUPABASE / CLOUD / SYNC | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 41 | Self-hosted Supabase mode, if present | B. SUPABASE / CLOUD / SYNC | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 47 | Local storage architecture | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 48 | Keychain usage | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 50 | Local storage encryption status | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 51 | Large health dataset handling | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 52 | Local-only mode after approval | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 53 | Local-only never uploads health data | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 57 | Raw payload/log handling | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 58 | Audit/logging privacy | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 59 | Legal/privacy copy | C. LOCAL STORAGE / PRIVACY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 65 | Denied state | D. HEALTHKIT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 66 | Partial permission state | D. HEALTHKIT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 67 | Historical import | D. HEALTHKIT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 73 | HealthKit write support | D. HEALTHKIT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 88 | HealthKit physical iPhone validation status | D. HEALTHKIT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 93 | BLE reconnect | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 114 | Historical sync request | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 118 | End-of-sync detection | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 120 | Realtime disable commands | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 124 | R11 decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 125 | R21 decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 128 | Battery event decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 129 | Charging event decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 130 | Wrist on/off event decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 131 | Temperature event decoder | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 136 | Battery display | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 137 | Firmware display | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 141 | Wearable physical validation status | E. BLE / WEARABLE PROTOCOL | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 153 | Haptic fired/terminated event handling | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 158 | Physical vibration test status | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 165 | Platform-blocked notification/call limitations | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 170 | WorkoutSession model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 177 | RecoveryScoreResult model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 178 | StrainScoreResult model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 183 | SourceMetadata model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 190 | Stale-data handling | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 196 | Wearable step source status | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 200 | Step trend | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 202 | Steps detail section/screen | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 207 | Total calories | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 208 | Calorie estimate labeling | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 210 | GPS/workout distance | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 211 | Step/stride distance estimate status | H. STEPS / MOVEMENT / CALORIES / DISTANCE | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 213 | Daily heart rate summary | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 214 | Workout heart rate | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 220 | Configurable max HR | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 221 | Fallback max HR estimate | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 222 | Zone minutes | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 227 | Baseline comparison | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 228 | Body signal trends | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 230 | Irregular rhythm events | I. HEART / BODY SIGNALS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 232 | Baseline engine | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 234 | Personal normal ranges | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 236 | Recovery category | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 245 | SpO2 recovery contribution | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 246 | Recent strain recovery contribution | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 248 | Recovery trend | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 250 | Daily strain | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 251 | Workout strain | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 253 | Strain contributors | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 254 | HR load | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 255 | Zone load | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 259 | Recent strain balance | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 260 | Stress signals | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 262 | Stress trend | J. RECOVERY / STRAIN / STRESS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 267 | Last sleep session | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 269 | Time in bed | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 270 | Awake duration | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 271 | Sleep stages | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 272 | REM sleep | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 273 | Deep sleep | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 274 | Light/core sleep | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 275 | Naps | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 276 | Sleep efficiency | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 277 | Sleep consistency | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 278 | Sleep debt | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 279 | Sleep need | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 280 | Sleep planner | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 281 | Bedtime recommendation | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 282 | Wake-time recommendation | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 285 | Sleep trend | K. SLEEP | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 292 | Workout heart rate | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 293 | Workout HR zones | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 295 | Workout calories estimate label | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 297 | Workout strain contribution | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 298 | Workout recovery impact | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 299 | Workout history | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 300 | Workout detail screen | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 306 | Muscular load heuristic | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 307 | Strength contribution to strain | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 309 | Strength confidence | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 310 | Strength estimate disclaimer | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 311 | Daily journal | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 312 | Habit logging | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 313 | Custom habits | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 331 | Habit recovery insights | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 332 | With-vs-without comparison | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 333 | Minimum sample size | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 334 | Confidence/sample size display | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 337 | Long-term recovery trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 338 | Long-term sleep trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 339 | Long-term strain trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 340 | Long-term steps trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 341 | Long-term active energy trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 342 | Long-term RHR trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 343 | Long-term HRV trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 344 | Long-term respiratory trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 345 | Long-term SpO2 trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 346 | Long-term temperature trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 347 | Long-term workout trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 348 | Long-term strength trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 349 | VO2/cardio fitness trend | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 350 | Healthspan/wellness summary | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 356 | Pregnancy-related tracking | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 357 | User-declared pregnancy only | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 359 | Pregnancy trend context only | N. LONG-TERM / SPECIAL CONTEXT | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 361 | Premium iPhone-native visual quality | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 367 | Workouts screen | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 368 | Strength screen | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 371 | Journal screen | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 374 | Source labels in UI | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 375 | Confidence labels in UI | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 376 | Estimated labels in UI | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 377 | Empty states | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 378 | Loading states | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 379 | Error states | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 380 | Permission states | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 381 | Reduced motion | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 382 | Dynamic type | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 383 | VoiceOver labels | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 384 | Tap targets | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 385 | Contrast | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 387 | No Android-ish UI patterns | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 388 | No glossy/glass cheap UI | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 389 | Screenshot/manual visual QA status | O. UI / UX / ACCESSIBILITY | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 395 | Physical HealthKit validation | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 396 | Physical BLE/wearable validation | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 397 | Physical vibration validation | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 400 | Launch screen | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 403 | Privacy policy/terms | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |
| 404 | Final legal copy | P. RELEASE / TESTING | Partially validated by build/static/unit checks; incomplete scope remains. | Finish missing data flow, persistence, UI labels, tests, and validation for this feature. |

### SCAFFOLDED

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 14 | Deep-link/protected-route protection | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 18 | Background jobs blocked before approval | A. APP ACCESS / AUTH / APPROVAL | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 145 | Custom vibration recorder/editor | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 159 | Alarm vibration | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 160 | Alarm scheduling | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 161 | Snooze | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 169 | SleepStageSegment model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 171 | WorkoutHeartRateZoneSummary model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 172 | StrengthWorkout model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 173 | StrengthSet model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 175 | HabitLog model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 176 | HabitInsight model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 179 | SleepNeedResult model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 180 | StressSignalResult model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 181 | BodySignalSummary model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 182 | LongTermTrend model | G. HEALTH DATA MODELS / SOURCE RESOLUTION | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 289 | Manual workout logging | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 301 | Strength workout logging | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 302 | Exercises | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 303 | Sets | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 304 | Reps | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 305 | Weight | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 308 | Strength history | L. WORKOUTS / STRENGTH | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 314 | Caffeine | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 315 | Alcohol | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 316 | Hydration | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 317 | Supplements | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 318 | Screen time | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 319 | Late meals | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 320 | Illness | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 321 | Mood | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 322 | Stress | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 323 | Travel | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 324 | Meditation | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 325 | Exercise type | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 326 | Soreness | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 327 | Medication | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 328 | Time outdoors | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 329 | Diet habits | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |
| 330 | Notes | M. JOURNAL / HABITS / INSIGHTS | Partially validated by build/static/unit checks; incomplete scope remains. | Define production contract, implement workflow, then add tests. |

### BLOCKED_PLATFORM

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 162 | Notification vibration | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Reviewed as platform-limited; not implemented as production behavior. | Document limitation or replace with a platform-supported alternative. |
| 163 | Per-app notification vibration | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Reviewed as platform-limited; not implemented as production behavior. | Document limitation or replace with a platform-supported alternative. |
| 164 | Call vibration | F. HAPTICS / VIBRATION / ALARMS / NOTIFICATIONS | Reviewed as platform-limited; not implemented as production behavior. | Document limitation or replace with a platform-supported alternative. |

### BLOCKED_CONFIG

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 45 | Live two-user RLS probe status | B. SUPABASE / CLOUD / SYNC | Configuration or live test account matrix missing for proof. | Provision the required safe test setup and rerun validation. |

### MISSING

| # | Feature | Category | Evidence | Required next step |
|---:|---|---|---|---|
| 33 | Incremental sync | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 34 | Sync queue | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 35 | Retry/backoff | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 36 | Sync checkpoints | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 40 | Repair Sync | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 42 | Data export | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 43 | Data deletion | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 44 | Account deletion | B. SUPABASE / CLOUD / SYNC | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 49 | Local health database | C. LOCAL STORAGE / PRIVACY | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 54 | Data deletion local | C. LOCAL STORAGE / PRIVACY | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 55 | Data export local | C. LOCAL STORAGE / PRIVACY | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 68 | Incremental import | D. HEALTHKIT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 69 | Checkpoints/anchors | D. HEALTHKIT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 86 | Menstrual/cycle data import | D. HEALTHKIT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 87 | Irregular rhythm event import | D. HEALTHKIT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 233 | Rolling baselines | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 247 | Cycle context recovery contribution | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 252 | Personalized strain target | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 258 | Strength/muscular load contribution | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 263 | Breathing/relaxation sessions | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 264 | Breathing timer | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 265 | Before/after HR/HRV support | J. RECOVERY / STRAIN / STRESS | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 288 | Workout detection | L. WORKOUTS / STRENGTH | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 351 | Menstrual cycle insights | N. LONG-TERM / SPECIAL CONTEXT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 352 | Cycle phase/context | N. LONG-TERM / SPECIAL CONTEXT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 353 | Cycle impact on sleep/recovery/temp | N. LONG-TERM / SPECIAL CONTEXT | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |
| 398 | TestFlight readiness | P. RELEASE / TESTING | No validation beyond absence/static inspection. | Prioritize, design, implement, and test only if still in product scope. |

### UNSAFE_NEEDS_FIX

None.
# 2026-05-12 Targeted Gap Update

| Area | Status | Notes |
| --- | --- | --- |
| Approval/session restore | Implemented in Swift pass | Keychain restore refreshes stale tokens; approval `401/403` refreshes and retries once; fail-closed error states added. |
| Sleep summary | Implemented with fallback | Last sleep, time in bed, awake, efficiency, naps, source, confidence, stage totals when measured, 7-night patterns, need/debt, planner. |
| Wearable sleep/naps/stages | Blocked pending capture | Current BLE captures do not prove sleep-session, nap, or stage packets. No fake sleep inference. |
| Steps/movement | Implemented with fallback | Today and Movement screen show steps, goal, source, confidence, active energy, distance, 7-day trend, daily rows. |
| Wearable steps | Blocked pending capture | Current BLE captures do not prove reliable step packet. No IMU-derived fake steps. |
| HealthKit fallback | Implemented | Anchored/incremental import for sleep, steps, distance, active energy, workouts, and other supported read types. |

# 2026-05-12 Device-First Packet Gap Update

| Area | Status | Notes |
| --- | --- | --- |
| Confirmed wearable packet use | Implemented for current safe decoded packets | Frame/reassembly, command response, HelloHarvard, metadata, event, firmware log, R10 HR/IMU summary, R11 scaffold, R21 optical summary, standard HR/battery. |
| Device diagnostics | Improved | Battery, charging, wrist, double tap, haptic event, and temperature-event parsing now have structured paths. Raw payload byte windows are not displayed. |
| Activity/workout packets | Blocked pending capture | No reliable wearable activity, workout, calorie, or strain/load summary packet is confirmed from current captures. |
| HRV/respiratory/SpO2 | Blocked pending capture | No true RR/IBI, validated respiratory source, or calibrated SpO2 source confirmed from BLE. |

# 2026-05-12 Notification, Call, and Vibration Update

| Area | Status | Notes |
| --- | --- | --- |
| Notification vibration settings | Removed | Received-notification wearable vibration settings, app rules, and forwarding extensions were removed. |
| All-app notification runtime capture | Removed / platform-blocked | A normal iOS app is not a universal notification listener. Whoordan does not claim all-app mirroring. |
| Selected-app notification runtime matching | Scaffolded / partial | Rules are stored and can match only when safe source information is available. Unknown source returns a visible limitation reason. |
| Vibration editor | Implemented | Custom pattern recording, safety checks, local save, duplicate, delete, and live connected pulse feedback. |
| Exact custom wearable interval playback | Blocked pending BLE command validation | Custom patterns are saved but not played as exact segments on the wearable until protocol support is verified. |
| Call vibration settings | Scaffolded | Separate call pattern and double-tap decline preference exist. No Whoordan-owned VoIP call service is implemented. |
| Normal cellular call decline | Platform-blocked | Double tap returns a platform-blocked result and does not attempt private APIs. |
| Haptic fired/terminated diagnostics | Implemented, physical validation required | Event types 60 and 100 update diagnostics when observed. |

# 2026-05-12 Alarm Vibration Update

| Area | Status | Notes |
| --- | --- | --- |
| Wearable alarm model | Implemented | Alarm label, enabled state, time, timezone, repeat days, selected pattern, snooze settings, trigger timestamps, sync status, and delivery status. |
| Alarm UI | Implemented | Settings > Alarms supports create, edit, enable/disable, delete, repeat days, pattern preview, snooze configuration, and active-alarm snooze/dismiss. |
| Local iOS alarm fallback | Implemented | Schedules a local one-shot UserNotifications reminder for the next trigger. |
| Wearable alarm vibration | Implemented, physical validation required | Sends selected safe built-in pattern only when approved, app can run, and wearable is connected. |
| Alarm double tap | Implemented, physical validation required | Active supported call has priority; otherwise active alarm snoozes or dismisses. |
| Exact background wearable alarm delivery | Platform-limited | Not claimed while suspended; local notification is the honest fallback. |
