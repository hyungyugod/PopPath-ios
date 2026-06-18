# Handoff: PopPath! — iOS Native App

## Overview
**PopPath!** is an iPhone-first, 90-second casual arrow-chain puzzle. The player taps arrow blocks that fly off the board when their path to the edge is clear. Clearing a block opens neighbors; tapping newly-opened blocks quickly builds an **Open Chain** for bonus score. The whole experience must feel **calm but satisfying** — "편안한데 탭할 때 반응이 기분 좋다."

This bundle documents the visual design and the core game logic so it can be rebuilt as a **native iOS app (SwiftUI recommended)**.

## About the Design Files
The file in this bundle (`PopPath Design Guide.dc.html`) is a **design reference created in HTML** — a prototype showing the intended look, layout, motion, and (for the Game screen) the actual playable behavior. **It is not production code to ship.** The task is to **recreate these designs natively in SwiftUI** (or UIKit) using the platform's idioms — `View`s, `@State`/`@Observable`, `withAnimation`, `Canvas`/`LazyVGrid`, `CoreHaptics`, `AVFoundation`. Lift the exact colors, type, spacing, motion timings, and game rules from this document; do not embed a WebView.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, radii, and motion are specified below and should be matched closely. The Game screen's logic (escape test, chain scoring, timer) is real and should be ported as-is.

---

## Design Tokens

### Colors
| Token | Hex | Use |
|---|---|---|
| Warm Cream | `#F7F4EE` | App background, all screens |
| Card Cream | `#FFFDF9` | Cards, HUD tiles, buttons (secondary) |
| Soft Sage | `#DDEBE4` | Game board background, stat pills |
| Mist Blue | `#AFC8DA` | Primary block |
| Lavender Mist | `#C9C2E8` | Secondary block |
| Fresh Mint | `#8FD8B5` | Open-Chain highlight, primary button fill |
| Soft Coral | `#F3A38A` | Perfect accent, Miss border |
| Ink Gray | `#2F3942` | Primary text, arrow glyphs |
| Warm Gray | `#7E878E` | Secondary/muted text |
| Mint Text | `#3F7A5E` | Chain label/value, "Do" accents |
| Mint Btn Text | `#23413A` | Text on mint primary buttons |
| Bezel (device) | `#23292E` | (mockup only — not in app) |

Saturation principle: **board + blocks stay low-contrast; only interaction highlights (Open-Chain mint ring) are vivid.** Never use pure black, neon, or hard red.

SwiftUI: define these in an `Color+PopPath.swift` extension (e.g. `Color(hex: 0xF7F4EE)`), or an Asset Catalog color set.

### Typography
- **Display / Logo / HUD numbers:** **Fredoka** (rounded sans). Weights 600–700. Use for `PopPath!` wordmark, big score numbers, button labels, HUD values.
- **Body / UI text:** **Nunito**. Weights 400–700.
- Both are Google Fonts → bundle the `.ttf`s in the app and register via `Info.plist` (`UIAppFonts`). If a system substitute is preferred, **SF Rounded** is the closest native match for Fredoka; **SF Pro / system** for Nunito.
- Numbers use **tabular figures** (`.monospacedDigit()` in SwiftUI) so the HUD doesn't jitter.

| Role | Font / Weight | Size (pt, @1x logical) |
|---|---|---|
| Hero logo | Fredoka 700 | 46 (Home), 74 (guide only) |
| Screen title | Fredoka 600 | 24 |
| Big score (Result) | Fredoka 700 | 72 |
| HUD value | Fredoka 700 | 21 |
| HUD label | Nunito 800, tracking +0.1em uppercase | 9 |
| Primary button | Fredoka 600 | 22–23 |
| Body | Nunito 400–500 | 14–16 |
| Caption / muted | Nunito 500 | 11–12 |

### Spacing & Radii
- Screen horizontal padding: **24–28pt**.
- Board: outer margin **16pt**, inner padding **11pt**, cell gap **7pt**.
- Radii: blocks/cells **12pt**, HUD tiles **15pt**, board **24pt**, primary button **22pt**, secondary card **18pt**, pills/toggles **999pt (capsule)**.

### Shadows (soft, no inner shadows)
- Block (Jelly, default): `color: Ink @ 13%, radius 9, y 4` + top inner highlight `white @ 50%`.
- Block (Flat option): `Ink @ 12%, radius 0, y 1`.
- Open-Chain block: **mint ring** = stroke `Fresh Mint @ 95%, width 3` + `mint @ 22% glow, radius 12, y 5`. No fill change beyond ring.
- Miss block: **coral ring** = stroke `Soft Coral @ 75%, width 2`.
- HUD tile: `Ink @ ~35%, radius 13, y 5` (very soft).
- Primary button: `mint-green @ 55%, radius 22, y 10–12` + top white inner highlight.

### Motion (the heart of the feel — "빠르지만 편안하게")
| Event | Duration | Curve / Motion |
|---|---|---|
| Block escape (fly-out) | **180–240ms** | ease-out; translate **130pt** in arrow direction + scale → **0.5** + opacity → 0, then remove |
| Open-Chain pulse | **0.8–1.2s loop** | ring opacity/width breathes (95%→40%, 3pt→7pt) |
| Perfect | **~200ms** | small scale-up then back |
| Pop Burst | **350–500ms** | soft radial wave from board center (no particles) |
| Miss | **120–180ms** | small horizontal shake (±4pt) |

SwiftUI curves: escape → `.easeOut`; pulses/springs → `.spring(response:0.4, dampingFraction:0.7)` or a custom `cubicBezier`. **Honor `accessibilityReduceMotion`** — disable pulses/bursts when on (mirrors the `reduceMotion` prop in the prototype).

---

## Screens / Views

> All screens: full-bleed **Warm Cream `#F7F4EE`** background, safe-area aware, portrait only.

### 1. Home
- **Purpose:** entry point; one tap to play.
- **Layout:** vertical center column, generous whitespace. Top→bottom: small decorative cluster of 3 tilted blocks (one mint-ringed, gentle float) → `PopPath!` logo (Fredoka 700, `!` in Soft Coral) → tagline "Open the path. Pop the chain." (Warm Gray) → flexible spacer → **BEST** capsule (Soft Sage bg, `BEST 1,240`) → **Play** button → row of two 46pt icon tiles (Sound, Settings).
- **Play button:** full-width, height **62pt**, radius 22, fill **Fresh Mint**, label "Play" Fredoka 600 / 22 in Mint-Btn-Text `#23413A`, soft green shadow + white top highlight.
- **Behavior:** Play → push Game; icons → Settings / toggle sound.

### 2. Game  *(this screen is the playable prototype — port its logic exactly)*
- **Purpose:** the actual round.
- **Layout (top→bottom):**
  1. **HUD row** — three equal tiles (Card Cream, radius 15), `SCORE` / `TIME` / `CHAIN`. Label 9pt uppercase Warm Gray (CHAIN label in Mint Text); value Fredoka 700 / 21 tabular. CHAIN shows `×{n}` in Mint Text.
  2. **Board** — fills remaining space; Soft Sage panel, radius 24, inner soft shadow; **6 columns × 7 rows** `LazyVGrid`, cell gap 7pt, cells square (`aspectRatio(1)`).
  3. **Footer row** — left `BEST 1,240`, right a "↻ New board" capsule (Card Cream) that resets the round.
- **Block cell:** square, radius 12, fill Mist Blue or Lavender Mist (alternating by `(row+col)%2`), centered arrow glyph **▲ ▼ ◀ ▶** (Ink Gray, ~17–20pt). States: default / open-chain (mint ring + pulse) / leaving (animating out) / miss (coral ring + shake). Empty cell = faint inset slot `Ink @ 3.5%`.
- **Behavior:** see **Game Logic** below.

### 3. Result
- **Purpose:** end-of-round summary; drive "한 판 더".
- **Layout:** centered. "Time's up" (muted) → "Nice run!" (Fredoka 600 / 24) → **big score** (Fredoka 700 / 72) → "SCORE" caption → row of two Soft Sage stat pills (**BEST**, **MAX CHAIN ×n**) → **Retry** button (primary mint, full-width, height **64pt** — the single biggest element on screen) → small "Home" text button (Warm Gray).
- **Rule:** Retry is the hero. **No ads, share, or achievements** on this screen.

### 4. Tutorial (first 3 taps only)
- **Purpose:** teach with the finger, not words.
- **Layout:** a small board with one **mint-ringed, pulsing** block + expanding ring + a 👆 pointer; one-line hint pill "Tap the glowing block →" (Ink bg, cream text) + sub-line "길이 열리면 블록이 빛나요"; 3-dot progress indicator (first dot = mint).
- **Rule:** never more than one line of instruction.

### 5. Settings (minimal, v0)
- **Purpose:** the few toggles that matter.
- **Layout:** back chevron + "Settings" title; vertical list of Card-Cream rows (radius 18) each = label + sub-label left, **capsule toggle** right. Rows: **Sound** (on), **Haptics** (on), **Color Assist** (off), **Reduce Motion** (off). Footer "PopPath! v0".
- **Toggle:** capsule 48×28; ON = Fresh Mint track; OFF = `Ink @ 14%` track; white 22pt knob with soft shadow.

---

## Game Logic  *(port verbatim — this is the real rule set)*

State per round:
- `board`: 7 rows × 6 cols, each cell `nil` or `{ id, dir: up|down|left|right, color }`.
- `score: Int = 0`, `chain: Int = 0`, `maxChain: Int = 0`, `time: Int = 90`, `best: Int`, `running: Bool = true`.

**Board generation:** for each of 42 cells, ~24% chance empty, else random direction and color alternating by `(row+col)%2` (Mist Blue / Lavender).

**Escape test** `escapable(r,c)`: from the cell, step repeatedly in its arrow direction (`up:(-1,0) down:(1,0) left:(0,-1) right:(0,1)`); if **every** cell between it and the board edge is empty → it can escape. Any occupied cell in the way → cannot.

**Open-Chain candidates:** every cell where `escapable` is currently true gets the mint ring + pulse. (Recompute after each removal.)

**Tap handler:**
- If not running → ignore.
- If tapped cell is **escapable**: mark `leaving` → animate out over **220ms** → set cell to `nil`. `chain += 1`; `score += 10 × chain`; `maxChain = max(maxChain, chain)`. Reset a **1.5s chain timer**; if it elapses with no further escape, `chain = 0`.
- If **not escapable**: brief miss shake (~180ms, coral ring), no score change.

**Timer:** 1s tick; `time` counts 90 → 0; at 0 set `running = false` and present **Result**.

**Scoring summary:** each escape = `10 × (current chain count)`; faster consecutive escapes = higher chain = more points. This is the entire reward loop — keep it gentle (no slot-machine payouts).

---

## State Management (SwiftUI shape)
- A `GameModel` (`@Observable` / `ObservableObject`) holding the state above; views read it via `@State`/`@Environment`.
- `AppRouter` enum for navigation: `.home → .game → .result → (.game | .home)`, plus `.settings`, `.tutorial`.
- Settings persisted in `@AppStorage` (sound, haptics, colorAssist, reduceMotion) + `best` score.
- Timer via a `Timer.publish` / `Task` loop on the model; cancel on disappear.

## Interactions & Behavior
- **Haptics** (CoreHaptics / `UIImpactFeedbackGenerator`): normal escape → light; Open-Chain → light; Perfect → medium; Pop Burst → medium pulse; Miss → short dull. Game must feel good with **haptics alone** (sound off).
- **Sound:** soft pop / higher pop / clear chime / warm whoosh+pop / dull thunk / calm time-up. Non-aggressive; fine to play without earphones.
- **Accessibility:** Color Assist = always show rings/shapes for state (not color alone); Reduce Motion = drop pulses/bursts; tap targets stay large (cells ≥ 44pt where possible); large readable HUD.

## Assets
- **Fonts:** Fredoka, Nunito (Google Fonts — bundle `.ttf` and register). No icons shipped from the prototype; arrow glyphs are Unicode ▲▼◀▶ (or draw `Triangle` shapes / SF Symbols `arrowtriangle.up.fill` etc. for crisper rendering). Home icons (🔊 ⚙️) are placeholders → replace with SF Symbols `speaker.wave.2.fill`, `gearshape.fill`.
- **No photographic backgrounds, textures, or 3D.** Only flat cream + soft sage board.

## Files
- `PopPath Design Guide.dc.html` — the full visual reference + playable Game screen. Open in a browser to see live colors, spacing, motion, and to play the board. All tokens above are lifted from it.
- `screenshots/01–07-guide.png` — sequential screenshots of the full design guide (header & foundations → core-screen mockups → components & block states → Do/Don't). Use as a quick visual reference for layout and color without opening the HTML.

## Do / Don't (carry into the build)
**Do:** big readable board & blocks · mint ring + small pulse for Open-Chain · Retry as the Result hero · soft shadows + low saturation · distinguish state by color **+ shape + motion**.
**Don't:** crowd screens with menus/banners/shop · use red/neon for states · clutter Result with ads/share/achievements · use hard contrast / black bg / flashing · rely on color alone for game info.
