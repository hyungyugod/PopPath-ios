# PopPath iOS

Native SwiftUI build of **PopPath!**, a 60-second arrow-chain puzzle based on the design handoff in `design_handoff_poppath/`.

Bundle ID: `com.hyungyu.poppath`

PopPath is currently planned as a free game with no ads, no in-app purchases, no tracking, and no monetization layer.

## Current Features

- Classic 60-second arrow-chain rounds
- Daily Challenge with a date-seeded board
- Clearable board generation with automatic fresh-path recovery when no moves remain
- Wall-exit pop animation and stronger chain feedback
- Denser default boards with unlock bonuses for opening new paths
- Recent classic board duplicate guard
- Round difficulty curve that tightens as score and board clears rise
- Local overall best, daily best, detailed lifetime records, and achievements
- Shareable run summaries through the iOS share sheet
- Sound, haptics, color assist, and reduce motion settings
- iPhone portrait layout

## Open

```bash
open PopPath.xcodeproj
```

Run the `PopPath` scheme on an iPhone simulator.

## Verify

```bash
xcodebuild build -scheme PopPath -destination 'generic/platform=iOS Simulator'
xcodebuild build -configuration Release -scheme PopPath -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme PopPath -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

## Design Assets

- Fonts are bundled in `PopPath/Fonts`: Fredoka for display/HUD text and Nunito for body/UI text.
- App icon assets are generated from `design_handoff_app_icon/app-icon.svg` and connected through `AppIcon`.
- Launch background uses `PopPath/Assets.xcassets/LaunchBackground.colorset`.

## Planning Docs

- Sprint status: `docs/SPRINT_STATUS.md`
- Quality expansion plan: `docs/QUALITY_EXPANSION_PLAN.md`
- App icon handoff: `docs/APP_ICON_HANDOFF.md`
- App Store prep: `docs/APP_STORE_PREP.md`
