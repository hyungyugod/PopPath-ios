# App Store Prep

## Product Posture

- Game name: PopPath
- Bundle ID: `com.hyungyu.poppath`
- Pricing: Free
- Monetization: None planned
- Ads: None
- In-app purchases: None
- Data collection: None in the current codebase
- Primary category: Games
- Secondary fit: Puzzle or Casual

## Feature Summary

PopPath is a quick 60-second arrow-chain puzzle. Players tap blocks only when their arrow has a clear path out of the board, chaining correct pops and opening new paths for bigger scores.

Current gameplay pillars:

- 60-second classic rounds
- Daily Challenge with a date-seeded board
- Local best score, daily best score, detailed records, and achievements
- Recent-board duplicate guard and a round difficulty curve
- Shareable run summaries through the iOS share sheet
- Sound, haptics, color assist, and reduce motion settings
- No ads, no purchases, no account, no tracking

## Store Copy Draft

Subtitle:

Quick arrow-chain puzzle

Short description:

Open paths, pop arrows, and chase a cleaner chain in fast 60-second rounds.

Description:

PopPath is a calm, tactile puzzle about finding the next open arrow. Tap only the blocks whose arrows can escape the board, keep your chain alive, unlock new paths, and race the timer for a better score.

Play a quick classic round anytime, return for the Daily Challenge to solve the same one-shot board as everyone else, collect achievements, and share your best runs from the result screen.

No ads. No purchases. Just a polished little puzzle built for quick, satisfying sessions.

Keywords:

arrow, puzzle, casual, chain, daily, board, logic, arcade, score

## Release Checklist

Completed locally:

- Final app icon added to `PopPath/Assets.xcassets/AppIcon.appiconset`.
- App target connected to `AppIcon`.
- App icon PNGs verified at required sizes with no alpha channel.
- `xcodebuild build` passes for Debug simulator.
- `xcodebuild build -configuration Release` passes for Release simulator.
- Privacy manifest bundled with UserDefaults required-reason API coverage.
- `xcodebuild test` passes on iPhone 17 simulator.
- Codebase still contains no ads, in-app purchases, StoreKit purchase flow, or tracking SDK.
- Universal iPhone + iPad target (`TARGETED_DEVICE_FAMILY = 1,2`), portrait-locked on
  iPhone and all four orientations on iPad. `UIRequiresFullScreen` is not set, so the
  iPad build is ready for multitasking / resizable-window expectations. Verified on
  iPhone 17, iPad mini, iPad Pro 13", and iPad Pro 13" landscape.
- `PopPath` has a shared Xcode scheme under `xcshareddata/xcschemes`, so fresh clones
  and CI can discover the app/test scheme without relying on local user data.
- `ITSAppUsesNonExemptEncryption = NO` set so uploads skip the export-compliance prompt.
- Korean declared in `CFBundleLocalizations` + `knownRegions` so the store lists ko.
- App Store screenshot sets captured under `app-store-assets/screenshots-2026-06-25/`
  for 6.9" iPhone (`1320x2868`) and 13" iPad (`2064x2752`), with 10 distinct screens
  per device set.
- App Store Connect metadata, review notes, privacy answers, and Notion-ready privacy /
  support page drafts prepared under `app-store-assets/app-store-connect/`.

Remaining owner-side App Store Connect tasks:

- Set Apple Developer Team/signing account for device archive and upload.
- Approve/upload the prepared iPhone and iPad screenshots.
- Publish the Notion privacy/support pages after reconnecting Notion, then paste the
  public URLs into App Store Connect.
- Replace the support email placeholder in the privacy/support pages.
- Confirm age rating remains suitable for all ages.
