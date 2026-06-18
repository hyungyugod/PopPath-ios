# Handoff: PopPath! App Icon

## Overview
The app icon for **PopPath!** — a comfortable, casual 90-second arrow-chain puzzle (iOS-first). The icon expresses the game's core idea: **a path of blocks rising, with the lead block "open" (coral)**. It is deliberately calm and low-noise to match the brand, but uses one bright coral accent so it stays catchy on a busy home screen.

Final direction: **"Coral Lead"** — three rounded blocks stepping diagonally upward on a mint field; the two trailing blocks are cream, the lead (top-right) block is coral.

## About the Design Files
The files in this bundle are **design references created in HTML/SVG** — they show the intended look exactly, but they are not production code to ship. The task is to **produce the real icon asset set** (PNG export sizes for the App Store / Xcode asset catalog) from the provided vector spec, using your normal icon pipeline. `app-icon.svg` is a clean, production-ready vector you can render to any size; the `.dc.html` files are interactive mockups for context only.

## Fidelity
**High-fidelity (hifi).** Final colors, geometry, and proportions. Reproduce exactly from `app-icon.svg` or the measurements below.

## The Asset
- **`app-icon.svg`** — the production icon, full-bleed 1024×1024. Render this to all required sizes. **Do not pre-round the corners** — export a full square; the OS applies its squircle mask. (The `.dc.html` mocks show rounded corners only to preview the masked result.)

## Geometry (canonical: 1024 × 1024 artboard)
Background is full-bleed. Coordinates are top-left origin (SVG convention).

| Element | x | y | width | height | corner radius | fill |
|---|---|---|---|---|---|---|
| Background | 0 | 0 | 1024 | 1024 | — (system mask) | mint gradient (below) |
| Block 1 (cream, trailing) | 154 | 546 | 324 | 324 | 94 | `#FBF8F2` |
| Block 2 (cream, middle) | 341 | 358 | 324 | 324 | 94 | `#FBF8F2` |
| Block 3 (coral, lead) | 529 | 170 | 324 | 324 | 94 | `#F3A38A` |

- **Block size** = 324px (≈31.6% of canvas). **Step** between blocks = 187–188px on both axes → blocks overlap ~137px, reading as one connected diagonal path bottom-left → top-right.
- **Block corner radius** = 94px (≈29% of block size — matches the in-game block radius spec).
- **Layer order:** Block 1 (bottom) → Block 2 → Block 3 (top).

### Proportional version (if you build at another base size S)
Multiply by `S/1024`: block = `0.3164·S`, radius = `0.0918·S`, step = `0.1829·S`; Block 1 top-left = `(0.150·S, 0.533·S)`, Block 2 = `(0.333·S, 0.350·S)`, Block 3 = `(0.517·S, 0.166·S)`.

## Design Tokens
**Colors**
| Token | Hex | Use |
|---|---|---|
| Mint (bg top) | `#83D4B2` | background gradient start |
| Mint (bg bottom) | `#5FBD97` | background gradient end |
| Cream | `#FBF8F2` | trailing blocks |
| Coral | `#F3A38A` | lead block (brand "Perfect"/open accent) |

**Background gradient:** linear, ~155° (top-left → bottom-right), `#83D4B2 → #5FBD97`. In SVG it's approximated with `x1=0.12 y1=0 → x2=0.9 y2=1`.

**Depth (optional, subtle — safe to drop for a flat export):**
- Cream blocks: drop shadow `dy 34, blur 28, #28503F @ 34%`; inner top highlight `inset 0 ~8px 0 rgba(255,255,255,.7)`.
- Coral block: drop shadow `dy 40, blur 30, #964637 @ 42%`; inner top highlight `rgba(255,255,255,.45)`.
- App-icon best practice: keep effects minimal; the flat shapes alone read cleanly down to 40px.

## Required export sizes (iOS)
Render `app-icon.svg` (full square, no rounding) to: **1024** (App Store), **180 / 120** (app @3x/@2x), **167 / 152** (iPad), **87 / 80 / 58** (settings/spotlight @3x/@2x), **60 / 40** (notification/spotlight). Drop into the Xcode `AppIcon` asset catalog. Verified legible from 1024 down to 40px (see the size strip in the Final mock).

## Files
- `app-icon.svg` — **production vector** (use this).
- `PopPath App Icon - Final.dc.html` — final presentation: hero, size scale, home-screen context, spec. Open in a browser (keep `support.js` alongside).
- `exploration/PopPath Icon - Blocks.dc.html` — the three "Coral Lead vs Pop Ring vs Lift Off" options that led to the final, for context.
- `support.js` — runtime needed to open the `.dc.html` mocks locally.

## Notes
- The coral lead block is the single focal accent — keep it; reverting to all-cream loses the "catchy" read that was the whole point of this round.
- Brand fonts (Fredoka / Nunito) appear only in the presentation mocks, **not** in the icon itself — the icon is pure shape, no text.
