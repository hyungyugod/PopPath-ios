# PopPath Final Release Audit - 2026-06-25

## Scope

- Release/build sanity for `PopPath.xcodeproj`
- App Store-facing metadata, privacy manifest, app icon, and iPad targeting
- iPad visual spot check from fresh screenshots captured during this audit

## Commands Run

- `xcodebuild test -project PopPath.xcodeproj -scheme PopPath -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/PopPathDD-iPhone17 -quiet`
- `xcodebuild build -project PopPath.xcodeproj -scheme PopPath -configuration Release -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.5' -derivedDataPath /tmp/PopPathDD-iPadProRelease CODE_SIGNING_ALLOWED=NO -quiet`
- `xcodebuild build -project PopPath.xcodeproj -scheme PopPath -configuration Release -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro),OS=26.5' -derivedDataPath /tmp/PopPathDD-iPadMiniRelease CODE_SIGNING_ALLOWED=NO -quiet`
- `xcodebuild build -project PopPath.xcodeproj -scheme PopPath -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/PopPathDD-GenericIOS CODE_SIGNING_ALLOWED=NO -quiet`
- `sips -g pixelWidth -g pixelHeight -g hasAlpha PopPath/Assets.xcassets/AppIcon.appiconset/*.png`
- `sips -g pixelWidth -g pixelHeight audit/final-release-audit-2026-06-25/*.png`
- Source greps for tracking, ads, IAP, network URLs, placeholders, debug text, and App Store placeholder links.

## Post-Fix Verification

- `UIRequiresFullScreen` removed from `PopPath/Info.plist`.
- iPad now declares portrait, upside-down portrait, landscape left, and landscape right.
- `xcodebuild test` passed again on iPhone 17 / iOS 26.5 after the iPad setting change.
- Generic iOS Release build passed again with signing disabled.
- iPad Pro 13-inch Release simulator build passed again.
- iPad mini Release simulator build passed again.
- Shared scheme added at `PopPath.xcodeproj/xcshareddata/xcschemes/PopPath.xcscheme` and detected by `xcodebuild -list`.
- Landscape iPad Pro 13-inch visual QA captured in `post-fix-screenshots/`.

## Result

- PASS: iPhone 17 unit tests passed.
- PASS: Release simulator builds passed for iPad Pro 13-inch and iPad mini.
- PASS: Generic iOS Release build passed with signing disabled.
- PASS: Universal targeting is enabled with `TARGETED_DEVICE_FAMILY = "1,2"`.
- PASS: iPad no longer opts out of multitasking with `UIRequiresFullScreen`, and declares all four iPad orientations.
- PASS: `PopPath` now has a shared Xcode scheme for CI / fresh-clone builds.
- PASS: App icons include iPhone, iPad, and marketing slots, with correct pixel sizes and no alpha.
- PASS: Privacy manifest declares no tracking, no collected data, and UserDefaults required-reason API use.
- PASS: No ad SDK, IAP SDK, tracking SDK, backend URL, localhost URL, or temporary share/download link found in app source.

## Captured Screens

1. `01-ipad-pro-home.png` - Healthy. Centered, intentional iPad column with no clipping.
2. `02-ipad-pro-game.png` - Healthy. Large board, HUD, pause/home controls, and best label fit.
3. `03-ipad-pro-records.png` - Healthy. Top of scroll view is clean; lower achievement list continues below fold as expected.
4. `04-ipad-pro-result.png` - Healthy. Score, cards, achievement rows, and bottom actions fit.
5. `05-ipad-mini-home.png` - Healthy. Wider iPad layout remains balanced and readable.
6. `06-ipad-mini-game.png` - Healthy. Board is large but usable; HUD and best label remain visible.
7. `post-fix-screenshots/10-ipad-pro-landscape-home-readable.png` - Healthy. Home remains centered and readable after iPad landscape rotation.
8. `post-fix-screenshots/11-ipad-pro-landscape-game-readable.png` - Healthy. Game board, HUD, controls, and best label fit after iPad landscape rotation.

## Remaining Owner-Side Checks

- Upload/approve final iPhone and iPad screenshots in App Store Connect. The captured iPad Pro 13 screenshots are `2064x2752`, matching Apple's required 13-inch iPad portrait size for apps that run on iPad.
- Confirm App Privacy answers as "no data collected" and "no tracking" to match `PrivacyInfo.xcprivacy`.
- Confirm age rating and App Review notes.
- Archive/upload from the Apple Developer account tied to team `VADVCLGY8Y`.

## Closed Follow-Up

- The previous `UIRequiresFullScreen` watch item was fixed after this audit: the key was removed and iPad landscape orientations were added.
