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

## Sprint 5B: Accessibility completion & motion safety

Status: Complete

- VoiceOver (WI-5.5): occupied open cells are buttons whose activate action pops them (a VoiceOver user can't flick); blocked cells are described but not actionable; empty cells are hidden; the board is grouped for row-major navigation; board events (clear / fresh path / unlock / milestone chain) are spoken via localized `UIAccessibility` announcements; the transient toast and the Home decorative cluster are hidden from VoiceOver.
- Dynamic Type (WI-5.6): custom fonts now scale via `relativeTo:`, capped app-wide at xxLarge so the fixed-viewport board/HUD layout holds; Settings is scrollable and tutorial/settings copy wraps instead of clamping.
- Effective Reduce Motion (WI-5.6): derived once as system OR in-app toggle and threaded into gameplay and the tutorial; under reduce motion the pop is a clean fade plus the +N marker and haptic instead of a slide/burst.
- Photosensitivity (WI-5.6): the white pop flash is capped well below its old peak and suppressed entirely under reduce motion; the big-chain particle burst is trimmed.
- Toggle traits (WI-5.6) on settings switches; AA contrast for secondary text (WI-5.7, darkened warm gray); and ≥44pt tap targets for the home/pause, back, language, and toggle controls (WI-5.7).
- Added a localized-announcement test; adversarial review pass closed four Dynamic Type overflow regressions (global cap, scrollable Settings, shrinkable fixed-tile labels).

## Sprint 6: Onboarding & tutorial truth

Status: Complete

- Rewrote the tutorial to teach the real rules (WI-6.1): the arrow-matching flick, the runway-to-edge escapability rule, clearing in order to open lanes, and chaining. Steps live in a testable `TutorialContent`.
- Made the tutorial gesture-gated (WI-6.1): only a flick matching the highlighted cell's arrow (resolved by the same `Direction.swipeDirection` the live board uses) advances; a wrong flick shows a hint; a Next/Start fallback button appears after a couple of tries; a Skip link and a VoiceOver activate action are always available.
- First-time Daily players are now routed through the tutorial before their Daily run instead of being silently opted out (WI-6.2, H3).
- Added a replayable "How to play" entry in Settings that returns to Settings when finished, reachable regardless of `hasSeenTutorial` (WI-6.2, H5).
- Added tests for the taught copy (arrow + edge) and that each step's required flick matches its displayed arrow.

## Sprint 7: Retention, meta & navigation depth

Status: Complete

- Daily streak (WI-7.1): consecutive-day streak tracked from the DailyChallenge day ids, surfaced on Home/Result, with an opt-in local evening reminder (no server/account) toggled from Settings and welcoming first-run empty states.
- One-shot Daily (WI-7.2): today's Daily is a single attempt; once finished, Home routes to an explainer (seeded/shared, once-per-day, with result + streak) instead of re-rolling, and the Result Retry returns Home. The direct `newRound(mode:.daily)` path stays open.
- Live celebration & meta (WI-7.3): a "NEW BEST!" toast and per-achievement celebration surface mid-run via the event queue; the achievement catalog is re-tiered with cumulative/streak/accuracy milestones; Classic and Daily bests now report distinctly; the PEAK tile shows "n / 5"; an unseen-achievement badge appears until Records is opened.
- Tools & navigation (WI-7.4): confirmed "Reset data" wipes all local storage; Records gains a recent-runs trend and longest-streak; the pause overlay carries Sound/Haptics/Open-Path toggles for mid-run changes; an edge-swipe-back affordance is added to secondary screens; and a live difficulty pip sits in the HUD.
- `PlayerStats` gained decode-safe Codable so older saves migrate without losing progress. Added tests for streak math, one-shot lockout, mode-split bests, live new-best, reset, progressive achievements, and partial-JSON decode.

## Remaining Owner-Side Release Inputs

- Apple Developer Team/signing account for device archive and App Store upload.
- Final App Store screenshots and store copy approval.
- App Store Connect privacy and age-rating answers.
