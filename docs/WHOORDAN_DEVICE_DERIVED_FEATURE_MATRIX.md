# Whoordan Device-Derived Feature Matrix

Date: 2026-05-12
Branch: `swift-app`

## Classification Key

- `DEVICE_DIRECT_IMPLEMENTED`: decoded device value can be used directly.
- `DEVICE_DERIVED_IMPLEMENTED`: validated derivation from device streams exists.
- `DEVICE_DERIVED_NOT_VALIDATED`: research/prototype possible but not production.
- `APPLE_HEALTH_FALLBACK_ONLY`: Apple Health is current usable source.
- `DERIVED_ESTIMATE_ONLY`: Whoordan estimate, clearly labeled.
- `PARTIAL_DEVICE_DERIVED`: some device inputs exist but not full metric.
- `BLOCKED_PENDING_PACKET_CAPTURE`: likely packet family needs capture.
- `BLOCKED_PENDING_ALGORITHM_VALIDATION`: raw streams exist but need validation.
- `PLATFORM_BLOCKED`: iOS or entitlement boundary blocks feature.
- `MISSING`: not implemented.

## Matrix

| Feature | Current status | Current source | Desired source | Wearable packet/source | Confidence | Next step |
|---|---|---|---|---|---|---|
| Sleep sessions | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Wearable direct or validated derived | Not captured | Medium when imported | Post-wake historical capture |
| Sleep stages | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Wearable direct stage records | Not captured | Source-dependent | Post-wake stage packet capture |
| Naps | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Wearable nap/session records | Not captured | Source-dependent | Post-nap historical capture |
| Sleep efficiency | `APPLE_HEALTH_FALLBACK_ONLY` | Sleep samples | Wearable direct/imported | Derived from sessions | Medium | Keep source labels |
| Sleep consistency | `DERIVED_ESTIMATE_ONLY` | Local sleep history | Local history from wearable first | Session history | Low/medium | More history |
| Sleep debt | `DERIVED_ESTIMATE_ONLY` | Local sleep history | Wearable/imported sleep history | Session history | Low | Conservative wording |
| Sleep need | `DERIVED_ESTIMATE_ONLY` | Local sleep history | Wearable/imported baselines | Session history | Low | Validate against history |
| Sleep planner | `DERIVED_ESTIMATE_ONLY` | Target wake + need estimate | Local planner | No direct packet | Low | User settings refinement |
| Steps | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Wearable direct step/activity | No explicit step packet confirmed; IMU only | Medium when imported | Walking/all-day capture with known step reference |
| Movement minutes | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health/workouts | Wearable derived activity | R10 IMU diagnostic only | Low | Algorithm validation |
| Distance | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Apple Health/GPS/device summary | Not captured | Medium | Keep fallback |
| Active energy/calories | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Device summary or estimate | Not captured | Medium/imported | Workout/all-day capture |
| Workouts | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health/manual | Device activity summary | Not captured | Medium/imported | Workout capture |
| Strength/muscular load | `MISSING` | Manual future | Manual/device future | Not captured | Unavailable | Separate feature |
| Heart rate | `DEVICE_DIRECT_IMPLEMENTED` | R10/GATT/Apple Health | Wearable direct | R10 HR, GATT 2A37 | Medium | Physical longer validation |
| Resting heart rate | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Wearable derived from rest/sleep HR | HR stream exists, rest windows not validated | Medium/imported | Rest-window algorithm |
| HRV | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | RR/IBI direct or validated PPG intervals | Not captured | Medium/imported | R21/interval capture |
| Respiratory rate | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Direct or validated sleep derivation | Not captured | Medium/imported | Sleep PPG/IMU capture |
| SpO2 | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Direct calibrated device value | Raw R21 debug only | Medium/imported | Find calibrated packet |
| Skin/wrist/body temperature | `PARTIAL_DEVICE_DERIVED` | Event scaffold + HealthKit | Direct validated device value | Event type 17 candidate | Low/medium | Charging/wrist/sleep captures |
| Recovery | `DERIVED_ESTIMATE_ONLY` | Local summary | Wearable-first inputs | Partial HR/IMU only | Low/medium | Add validated inputs |
| Strain | `DERIVED_ESTIMATE_ONLY` | Movement/workout/HR | Wearable HR/activity | Partial HR/IMU only | Low/medium | Activity packet capture |
| Personalized strain target | `DERIVED_ESTIMATE_ONLY` | Recovery/strain history | Local original formula | No direct packet | Low | Baseline validation |
| Stress signals | `BLOCKED_PENDING_ALGORITHM_VALIDATION` | None | HRV/HR baseline | HR partial, HRV missing | Unavailable | Validation research |
| Breathing/relaxation | `MISSING` | Manual future | App feature | No direct packet | Unavailable | Future app flow |
| Body signals/health monitor | `PARTIAL_DEVICE_DERIVED` | HealthKit + HR | Wearable-first body signals | Partial HR/temp event | Low/medium | More packets |
| VO2/cardio fitness | `APPLE_HEALTH_FALLBACK_ONLY` | Apple Health | Apple Health/device future | Not captured | Medium/imported | Keep fallback |
| Long-term trends | `DERIVED_ESTIMATE_ONLY` | Local history | Local history | Any persisted source | Source-dependent | Accumulate history |
| Menstrual cycle context | `MISSING` | None | Explicit consent/HealthKit | No BLE packet | Unavailable | Consent design |
| Pregnancy context | `MISSING` | None | Explicit consent/HealthKit | No BLE packet | Unavailable | Consent design |
| Irregular rhythm imported events | `MISSING` | Platform future | Imported platform event | No custom detector | Unavailable | HealthKit event review |
| Journal/habit insights | `DERIVED_ESTIMATE_ONLY` | Local journal | Local journal + trends | No direct packet | Low | Association only |
| Battery | `DEVICE_DIRECT_IMPLEMENTED` | Hello/event/GATT | Wearable direct | Hello, event 3, GATT 2A19 physically observed | Medium | Longer battery-state capture |
| Charging | `PARTIAL_DEVICE_DERIVED` | Hello/event | Wearable direct | Hello can report charging; events 7/8 not observed in latest capture | Low/medium | Dedicated charger on/off capture |
| Wrist on/off | `PARTIAL_DEVICE_DERIVED` | Hello/event | Wearable direct | Event 10 wrist-off physically observed; event 9 wrist-on not observed | Medium for wrist-off | Dedicated wrist on/off capture |
| Double tap | `DEVICE_DIRECT_IMPLEMENTED` | Event | Wearable direct | Event 14 physically observed | Medium | Route through alarm/haptic actions physically |
| Haptics/vibration | `PARTIAL_DEVICE_DERIVED` | Commands/events | Wearable direct | Commands implemented; events 60/100 not observed in latest capture | Low/medium | Haptic-preview capture with event confirmation |
| Alarms | `PARTIAL_DEVICE_DERIVED` | Local notification + haptic | Wearable haptic delivery | App command path; alarm events 56-59 | Low/medium | Physical alarm capture |
| Notifications/calls | `PLATFORM_BLOCKED` for all-app/cellular control | App-owned only | Public APIs only | No BLE issue | N/A | Keep honest UI |

## Current Safe Device Use

Whoordan can safely use the wearable now for:

- direct heart-rate samples when plausible,
- IMU sample-count/range diagnostics,
- raw/debug PPG presence diagnostics,
- battery/charging/wrist diagnostics when packets arrive,
- double-tap event routing,
- haptic command preview/stop with event diagnostics,
- firmware log summaries.

Whoordan must keep Apple Health fallback for sleep, stages, naps, steps,
distance, active energy, workouts, HRV, respiratory rate, SpO2, and VO2 until
direct packets or validated derivations exist.

## 2026-05-12 Physical Capture Matrix Update

The latest physical capture inspected 2,812 local records and 536 valid
reassembled protocol frames. It confirms that the app can collect and classify
standard HR, standard battery, command responses, realtime/raw realtime frames,
historical frames, metadata, firmware logs, R10/R11-like record families,
battery events, wrist-off events, and double-tap events.

No feature moved into `DEVICE_DERIVED_IMPLEMENTED` from this capture. The
historical frames and unknown events are not enough to classify sleep, naps,
steps, workouts, calories, respiratory rate, true HRV, SpO2, or temperature.
