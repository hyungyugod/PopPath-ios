# Sprint Status

## Sprint 0: Project Foundation

Status: Complete

- Created the SwiftUI iOS project structure.
- Set Bundle ID to `com.hyungyu.poppath`.
- Confirmed the app target builds and the test target runs.

## Sprint 1: Game Feel and Board Quality

Status: Complete

- Added seeded random generation for deterministic boards.
- Added board quality checks so new rounds start with healthy playable choices.
- Reset the current chain after a miss.
- Added rule coverage for generation, scoring, and chain behavior.

## Sprint 2: Visual QA and Responsive Polish

Status: Complete

- Added safer text scaling and stable HUD sizing.
- Checked home and game screens on iPhone 17 simulator.
- Added DEBUG launch arguments for faster visual QA.

## Sprint 3: Daily Challenge

Status: Complete

- Added date-seeded Daily Challenge mode.
- Added daily best score storage separate from overall best.
- Added Daily entry point on the home screen.
- Added Daily state to game and result screens.
- Added tests for daily seeds, daily board stability, and daily best persistence.

## Sprint 4: Brand, Icon, and Launch Prep

Status: Complete

- Added a branded launch background color asset.
- Integrated the final owner-provided app icon from `design_handoff_app_icon/app-icon.svg`.
- Generated opaque PNG app icon assets for iPhone, iPad, and App Store marketing slots.
- Connected `AppIcon` in the app target for Debug and Release.
- Documented icon regeneration notes and App Store prep.
- Confirmed no ad, purchase, or tracking code exists in the repository.
- Re-verified Debug build, Release simulator build, and unit tests after icon integration.

## Gameplay Quality Pass: Flow and Chain Feel

Status: Complete

- Added clearable board generation so newly dealt boards have a valid solve flow.
- Added automatic fresh-path recovery when a live round reaches a no-move state.
- Added board-clear bonus and continuation into the next board.
- Changed block pop motion so blocks travel beyond the board edge before being removed.
- Added stronger chain feedback through HUD glow, chain toasts, pop trails, sound, and haptics.
- Added tests for clearable boards, locked-board detection, stuck-board recovery, and board-clear continuation.

## Quality Expansion Pass: Records, Sharing, and Mastery

Status: Complete

- Added a local plan in `docs/QUALITY_EXPANSION_PLAN.md`.
- Added recent classic board signature storage to reduce repeated board patterns.
- Added level-based board profiles so rounds tighten as score and board clears rise.
- Added per-round metrics for pops, misses, unlocks, board clears, fresh paths, and peak difficulty.
- Added persistent lifetime records and a Records screen.
- Added a local achievement catalog with persistent unlocks.
- Added shareable run summaries from the result screen.
- Added tests for signatures, difficulty profiles, recent board recording, stats persistence, achievements, and share text.

## Sprint 5A: Scoring economy, feedback timing & HUD cues

Status: Complete

- Rebalanced the economy (WI-5.1): per-pop chain multiplier capped with a small continuation reward, board-clear bonus scaled with a chain cap lifted above 10, unlock bonus retuned upward, and per-pop floating "+N" markers at the cleared cell.
- Synced audio/haptics to the visual pop by removing the 10ms feedback hop, and stopped cutting in-flight pops when the round ends (WI-5.2).
- Added a visible, pause-aware chain-decay indicator on the CHAIN tile driven by a published decay deadline sampled through a TimelineView (WI-5.3).
- Added a low-time urgency cue on the TIME tile: a visual pulse/colour shift plus a distinct per-second tick haptic in the final seconds (WI-5.4).
- Added tests for the per-pop cap, board-clear scaling, floating score, and chain-decay freeze-on-pause; recomputed the affected score assertions.
- Adversarial review pass: fixed an end-of-urgency pulse that never settled and tightened chain-decay state hygiene (miss path, duration reset, distinct tick haptic, mid-deal suppression).

## Remaining Owner-Side Release Inputs

- Apple Developer Team/signing account for device archive and App Store upload.
- Final App Store screenshots and store copy approval.
- App Store Connect privacy and age-rating answers.
