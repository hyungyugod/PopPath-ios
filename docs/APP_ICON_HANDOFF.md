# App Icon Integration

PopPath's final app icon has been integrated from the owner-provided design handoff.

## Source

- Source vector: `design_handoff_app_icon/app-icon.svg`
- Design notes: `design_handoff_app_icon/README.md`
- Final direction: Coral Lead, using three rounded blocks on a mint field.

The source SVG is full square at `1024x1024`. It should not be pre-rounded because iOS applies the system icon mask.

## Generated Assets

Generated PNG files live in:

`PopPath/Assets.xcassets/AppIcon.appiconset`

The set includes iPhone, iPad, and App Store marketing slots from 20px through 1024px. The PNGs were generated from an alpha-free 1024px master and verified as opaque.

## Project Setting

The app target now sets:

`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`

for both Debug and Release.

## Regeneration Notes

If the icon source changes later:

1. Render `design_handoff_app_icon/app-icon.svg` to a `1024x1024` PNG.
2. Flatten it to remove alpha.
3. Regenerate all PNG sizes in `AppIcon.appiconset`.
4. Keep `Contents.json` mapped to the generated files.
5. Run:

```bash
xcodebuild build -scheme PopPath -destination 'generic/platform=iOS Simulator'
xcodebuild test -scheme PopPath -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```
