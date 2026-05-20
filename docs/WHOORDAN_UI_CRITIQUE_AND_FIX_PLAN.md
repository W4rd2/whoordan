# Whoordan UI Critique And Fix Plan

Date: 2026-05-11
Branch: `swift-app`

## Screenshots Reviewed

The user reported screenshot findings for Today, Recovery, Sleep, and Heart. The screenshots themselves were not visible in this chat turn, so this pass used the user's listed critique plus direct inspection of the current SwiftUI source.

## Problems Confirmed

- `SignalScreen` repeated page identity by rendering a giant icon/title and also setting `navigationTitle`.
- Today used a horizontal split hero that wrapped copy poorly.
- Missing data showed heavy `--` or `Unavailable` language.
- Long safety copy was competing with primary content.
- Most content used the same bordered card treatment.
- Bottom navigation used visually heavy symbols and default tab presentation without any tab-bar treatment.
- Recovery, Sleep, and Heart used the same generic template instead of screen-specific hierarchy.

## Design Direction Applied

- One visible header per screen.
- Matte dark surfaces with lower-border weight.
- Compact status strip on Today.
- Vertical hero modules instead of split cards.
- Clear missing-data CTAs.
- Signal rows for scannable contributor/state lists.
- Compact summary tiles for Today.
- Long disclaimers moved into footnote/info sheets.
- SF Symbols kept consistent with hierarchical rendering and restrained sizing.
- No fake metrics added.

## Screen Fixes

### Today

- Header is `Today` plus date.
- Status strip shows approval, local/cloud mode, and source state.
- Hero shows `Building your baseline` or recovery score.
- CTAs: `Connect Apple Health`, `Pair wearable`, `Build baseline`.
- Compact grid: Recovery, Sleep, Strain, Heart.
- Body signals list appears only when useful source data exists.

### Recovery

- Removed duplicated giant title pattern.
- Added recovery hero instrument.
- Added contributor list for HRV, resting heart rate, respiratory rate, and temperature.
- Added missing-signal CTAs.
- Moved non-medical copy to an info sheet.

### Sleep

- Removed duplicated giant title pattern.
- Added last-sleep hero with intentional empty state.
- Added sleep need, sleep debt, efficiency, and source rows.
- Added source CTAs.
- Kept stages absent unless verified source data exists.

### Heart

- Removed duplicated giant title pattern.
- Added heart source hero.
- Added rows for RHR, HRV, SpO2, and zones.
- Added CTAs for Apple Health, wearable pairing, and max heart-rate configuration.
- Kept diagnosis copy in a small info sheet.

## Tests Added

- No repeated generic `SignalScreen` title pattern for Recovery, Sleep, Heart.
- Today missing-data CTAs exist.
- Recovery contributor list exists.
- Sleep source CTA exists and does not fake stages.
- Heart connect/configure CTAs exist.
- Primary screens avoid heavy `--` and `Unavailable` empty copy.
- Approval gate still blocks protected services before approval.

## Manual Visual QA Still Needed

- iPhone screenshots on physical device for Today, Recovery, Sleep, and Heart.
- Dynamic Type sizes.
- VoiceOver pass.
- Reduced Motion pass.
- Long localized/system text pass.
- Dark matte contrast pass on real display.
