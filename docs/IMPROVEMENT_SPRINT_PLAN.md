# PopPath Game-Experience Improvement — Sprint Blueprint

Status: **Plan only (not implemented).** Resolves all **91 distinct findings** (103 raw, consolidated by shared root) from the game-experience audit, down to every `[Low]`.

Coverage verification (adversarial): **91/91 mapped, 0 unmapped, 0 ordering violations.** One duplicate (`I6`) is resolved below.

Hard constraints preserved throughout: **no backend, no accounts, no IAP, no ads, no tracking.** Every sprint compiles, passes `xcodebuild test`, and is independently shippable with no regressions (before → after stated per item).

---

## 1. Four foundational refactors (land first, gate everything)

| # | Refactor | Replaces | Unblocks |
|---|----------|----------|----------|
| **R1 — Direction-true input pipeline** | One board-level `DragGesture` in a named coordinate space; resolve START cell from `gesture.startLocation` via `cellSize`/`gridSpacing`; new `GameModel.attemptPop(row:column:direction:…)` that pops only when `direction == block.direction` **and** `GameRules.isEscapable`. Keep legacy `swipe(row:column:…)` as a thin wrapper (delegates with the block's own direction) so existing tests stay green. | 42 per-cell `highPriorityGesture(DragGesture(minimumDistance:0))` + `shouldClear`'s `isOpen → true` shortcut (GameView.swift:265, 741–751) | A1–A9; prerequisite for the truthful tutorial (H1/H2), VoiceOver pop action (G1), miss time penalty (E2) |
| **R2 — Ordered BoardEvent queue** | A `BoardEvent` value type drained by one ordered queue (priority clear > unlock > chain), with a computed `boardToast` mirror for test compatibility. | single `@Published boardToast` slot + `toastTask` + 10ms `queueFeedback` Task hop (GameModel.swift:242, 254, 717, 742) | F1; substrate for per-pop +N (E4), VoiceOver announcements (G6), synced A/V (F9, J), live celebration (K5/K12) |
| **R3 — Off-main board generation** | `nonisolated async` producer awaited by `makeBoard`/`dealNextBoard`, board assigned on main actor, input gated by `isDealing`; hardened guaranteed-clearable fallback. | up-to-180-attempt synchronous loop on the `@MainActor` (GameCore.swift:211–251; GameModel.swift:698) | D1, D8; precedes board transitions (F6/F7) and the difficulty rewrite |
| **R4 — RunState + wall-clock RoundClock** | `RunState{idle,running,paused,finished}` (computed `running:Bool` kept) + `pause()/resume()`; `RoundClock` with a `deadline: Date`; `tick()` derives `remaining = ceil(deadline − now)` instead of `time -= 1`. | bare `running` Bool + `tick()`'s decrement (GameModel.swift:521–531) | C1, C2, C3, C4, C6, E2, F4, F5, K2, K17 |

**Cross-cutting locks**
- `attemptPop(row:column:direction:)` from R1 is consumed verbatim by the VoiceOver action (WI-5.5), the gesture-gated tutorial (WI-6.1), and the miss penalty (WI-3.4). Gesture tolerances (`minimumDistance`, `axisBias`, `predictedEnd`) are defined **once** in WI-1.1 and reused — never re-tuned per call site.
- The miss **time** penalty (E2) is implemented against the `RoundClock` deadline (not the legacy `Int time`), so it must land in the same sprint as R4.
- The scoring rebalance (WI-5.1) is the biggest test hotspot: `testChainScoringIncrementsByCurrentChain` (30), `testMissResetsCurrentChain` (10), `testUnlockBonusRewardsOpeningNewPath` (17), `testDailyBestPersistsSeparately`/`testFinishRoundPersistsStats` (250), `testBoardClearAwardsBonusAndDealsNextBoard` (≥210) hardcode formulas and **must be recomputed in the same commit**.
- Effective Reduce Motion is derived **once** in `RootView` as `@Environment(\.accessibilityReduceMotion) || @AppStorage("reduceMotion")` (WI-5.6); all animation sites read that single value.
- Any `PlayerStats` Codable addition (streak, `seenAchievementIDs`, `recentScores`) needs decode defaults so persisted stats round-trip.

---

## 2. Sequencing & dependency chain

```
Sprint 1  Foundations (R1 input, R2 queue, R3 async gen)
   │        WI-1.3 depends on WI-1.1
   ▼
Sprint 2  Readability (open cue default, rename, decorative tones) ── zero gameplay-logic risk
   ▼
Sprint 3  Lifecycle (R4 pause + wall-clock), destructive-action safety, miss penalty + haptics
   │        WI-3.2→3.1 ; WI-3.3→3.1 ; WI-3.4→3.2,1.1 ; WI-3.5→3.2
   ▼
Sprint 4  Fair difficulty + board transitions   (depends on R3)
   ▼
Sprint 5  Scoring rebalance + accessibility completion + motion safety
   │        WI-5.1→1.2,3.1 ; WI-5.3→5.1 ; WI-5.4→3.2 ; WI-5.5→1.1,1.2 ; WI-5.6→1.1
   ▼
Sprint 6  Tutorial truth   (depends on 1.1, 2.2, 4.1)
   ▼
Sprint 7  Retention / meta / navigation   (depends on 3.5, 3.3, 1.2, 5.1, 4.1)
   ▼
Sprint 8  Localization / copy / audio / final polish   (no downstream dependents)
```
**Invariant:** no work item is sequenced before any item it `dependsOn`.

---

## 3. Sprints

> Each work item: **WI-id · title · (resolves)** → approach · files · depends · risk · acceptance · before→after · verify.

### Sprint 1 — Foundations: input, generation, feedback queue
**Goal:** Land the three systemic roots so every later sprint builds on correct primitives, with **no visible balance change** and all existing tests green.
**Shippable:** Swipes are judged by direction against the cell the flick started on; deliberate misses register reliably; stray taps no longer pop or break a chain for free; board deals no longer hitch the timer; a non-clearable board can never be dealt; all rewards flow through one queue and display stacked. No new player-facing features.

- **WI-1.1 · Single board-level direction-true gesture → `attemptPop`** *(A1,A2,A3,A4,A5,A7,A8,A9)*
  - Approach: Remove the 42 per-cell `.directionalPopTouch` modifiers (GameView.swift:265) and `DirectionalPopTouchModifier`/`shouldClear` (741–751). Add one `DragGesture` on the board ZStack in a named coordinate space; derive START cell from `startLocation` using existing `gridSpacing(7)`/`boardPadding(11)`/`cellSize` math (A3); resolve the flick via `Direction.swipeDirection(for:minimumDistance:axisBias:)`. New `GameModel.attemptPop(row:column:direction:hapticsEnabled:soundEnabled:)`: pop only when `direction == block.direction && isEscapable` (A1); tap/sub-threshold → no-op (A2,A8); wrong-direction/blocked flick → miss with existing `ShakeEffect` + coral outline (A5). Keep overlays `allowsHitTesting(false)` (A4 collapses recognizer competition). Remove the open-cell directional drag preview that implied a flick is required (A7); keep a gentle whole-cell press-scale. Add `isDealing` flag set in `scheduleBoardRefresh`, cleared in `dealNextBoard`; `attemptPop` early-returns while dealing (A9). Keep legacy `swipe(...)` wrapper delegating with the block's direction.
  - Files: GameView.swift, GameModel.swift, GameRulesTests.swift · Depends: — · Risk: **highest** — start-cell math must match LazyVGrid layout exactly or pops land wrong; one gesture must not swallow system edge-swipe; wrapper must preserve current semantics.
  - Verify: new `testAttemptPopRequiresMatchingDirection`, `testTapDoesNotPopEscapableCell`; keep `testChainScoringIncrementsByCurrentChain` (wrapper still scores 30). Sim QA: wrong-way flick shows shake; cross-tile flick resolves to start cell.

- **WI-1.2 · BoardEvent feedback/announcement queue** *(F1)*
  - Approach: `BoardEvent`(kind/title/detail/style/announce) drained by one ordered queue publishing `currentToast`; concurrent chain+unlock+clear display in priority order (clear>unlock>chain). Route `awardBoardClearBonus`, `awardUnlockBonusIfNeeded`, `showChainToastIfNeeded`, fresh-path branch through `enqueue`. Expose computed `boardToast` mirror (queue head) so `testUnlockBonusRewardsOpeningNewPath` stays valid. Cap queue length.
  - Files: GameModel.swift, GameView.swift, GameRulesTests.swift · Depends: — · Risk: mirror must reflect most-relevant active event; cap + coalesce duplicates.
  - Verify: new `testConcurrentRewardsEnqueueAll`; update `testUnlockBonusRewardsOpeningNewPath` to read the mirror.

- **WI-1.3 · Off-main async generation + guaranteed-clearable fallback** *(D1,D8)*
  - Approach: Add `nonisolated async` producer (detached Task) around the pure `generatedBoard`/`clearableRandomBoard`/`isClearable`; `makeBoard`/`dealNextBoard` await then assign on main actor (input already gated by `isDealing`). Pre-generate next board to hide latency. Keep Daily `SeededRandomNumberGenerator` draw order unchanged. Harden fallback (GameCore.swift:241–250): if repaired & best are both non-clearable, construct a guaranteed-clearable board (outward edge blocks) (D8).
  - Files: GameCore.swift, GameModel.swift · Depends: **WI-1.1** · Risk: async deal creates a stale-board window; determinism tests break if RNG draws reorder.
  - Verify: new `testAsyncGeneratedBoardMatchesSyncForSeed`, `testFinalFallbackBoardIsAlwaysClearable`; keep determinism tests green; Time Profiler: no main-thread frame >16ms on chained clears.

### Sprint 2 — Board readability foundation
**Goal:** Make open-vs-blocked legible by default and stop implying the two tones carry meaning, so onboarding & accessibility build on an honest visual contract. **No gameplay-logic change.**
**Shippable:** A fresh install distinguishes poppable from blocked blocks (open cue on by default, grayscale-distinguishable), tones read as decorative, the misnamed setting is renamed, and the tutorial's open cue matches the live board.

- **WI-2.1 · Open-path cue on by default; rename Color Assist; tones decorative** *(B1,B2,G7)*
  - Approach: In `BoardCell`, render a persistent subtle open treatment (outline + corner dot, existing visuals at 548–565) whenever `isOpen`; demote `colorAssist` to an intensity/pulse boost. Flip `@AppStorage("colorAssist")` default `false→true` as a backstop, keeping the storage key so users who turned it off keep their value. Rename Settings label `Color Assist`/`색상 보조` → `Open-Path Highlight`/`열린 길 강조` (G7). Treat `BlockTone` as purely decorative (B2).
  - Files: GameView.swift, Screens.swift, PopPathApp.swift · Depends: — · Risk: always-on cue on dense boards could clutter — keep resting cue subtle, reserve pulse for colorAssist; EN/KO parity.
  - Verify: wiped-sim QA: open cell outlined before any touch; renamed label in EN+KO.

- **WI-2.2 · Non-color tone differentiator + tutorial open-cue parity** *(B3,G9)*
  - Approach: Add a faint per-tone inner motif/texture so colorblind users distinguish tiles without inferring state (G9), keeping the arrow glyph dominant. Update `TutorialView.tutorialCell` (725) to reuse the exact same outline+dot the live `BoardCell` shows via a **shared open-cue modifier** so they can't drift (B3).
  - Files: GameView.swift, Screens.swift · Depends: **WI-2.1** · Risk: motif must not compete with outline/arrow.
  - Verify: Grayscale color-filter QA; run tutorial then a round, compare highlight.

### Sprint 3 — Lifecycle, timer & destructive-action safety
**Goal:** Explicit lifecycle with pause/resume, exploit-free wall-clock, non-destructive/confirmed New board / Exit / Daily semantics with progress credit, midnight rollover, and a miss time penalty pointed at the deadline. **No scoring regressions.**
**Shippable:** Players pause/resume; backgrounding no longer freezes the clock; Classic "New board" reshuffles in place; exiting confirms & credits stats; Daily rolls over at midnight and Restart is meaningful; a miss costs a little time.

- **WI-3.1 · RunState + pause/resume** *(C1)* — Approach: `RunState` (keep computed `running`) + `pause()/resume()` suspending `timerTask`/`chainResetTask`/`boardRefreshTask` and freezing the `RoundClock`; pause button in `topBar`; paused overlay (Resume/Settings/Quit). Files: GameModel.swift, GameView.swift · Depends: — · Risk: pause must also stop chain-decay & board-refresh. Verify: new `testPauseFreezesClockAndChain`.
- **WI-3.2 · Wall-clock RoundClock + background handling** *(C3)* — Approach: `RoundClock` with `deadline: Date` (+ accumulated paused duration); `tick()` → `remaining = ceil(deadline − now)`; keep `@Published time` derived (`== roundSeconds` at `newRound`). Observe `scenePhase`; background keeps elapsing (C3); explicit pause shifts deadline. Injectable now-provider for tests. Files: GameModel.swift, PopPathApp.swift · Depends: **WI-3.1** · Risk: exact-time test assertions; init `deadline = now + roundSeconds`. Verify: new injected-clock test; sim QA: background 10s ⇒ ~10s lost.
- **WI-3.3 · Non-destructive Classic "New board" / meaningful Daily Restart w/ confirm** *(C2,C6)* — Approach: split `newBoard()` into `reshuffleBoard()` that deals a fresh board **without** resetting score/chain/time/metrics (Classic footer, keep label) and must respect `recentBoardSignatures` and **not** increment the difficulty source of truth (coordinate WI-4.1); gate any full reset behind a confirm dialog (C2); Daily "Restart" routed through a confirm labeled as forfeiting (align WI-7.2), pausing the timer during the dialog (C6). Files: GameModel.swift, GameView.swift · Depends: **WI-3.1** · Verify: new `testReshuffleBoardKeepsScoreAndTime`.
- **WI-3.4 · Confirmed/credited Exit; miss time penalty; fire `.escape`; tier & rate-limit haptics** *(C4,A6,E2,J2,J3,J7)* — Approach: Exit shows "End run?" confirm; on confirm finalize through a lightweight credit so pops/score count toward lifetime totals & best (C4), keep a no-summary discard path. Miss branch subtracts a small fixed amount from the `RoundClock` deadline (E2). Fire `Haptics.Event.escape` on a successful pop (A6,J2). `feedbackEvent(for:)` → `.escape` chain 1 / `.chain` 2–4 / `.bigChain` 5+ (J3). `lastMissFeedbackAt` coalesces miss feedback within ~150ms (J7). Files: GameModel.swift, GameView.swift, PopPathApp.swift, GameCore.swift, GameRulesTests.swift · Depends: **WI-3.2, WI-1.1** · Risk: only credit lifetime totals/best (no summary unless finished); penalty small. Verify: new `testExitCreditsLifetimeStats`, `testMissAppliesTimePenalty`, distinct-event test; update `testAbandonRoundStopsWithoutSummary`.
- **WI-3.5 · Daily midnight rollover + fresh keys** *(C5)* — Approach: `refreshDailyIfDateChanged()` called on `scenePhase→active` & Home appear; if `DailyChallenge.today()` yields a new id, refresh `dailyChallenge`/`displayLabel` and reload `dailyBest` from `dailyBestStorageKey(for:)`; never roll over mid-run. Files: GameModel.swift, PopPathApp.swift · Depends: **WI-3.2** · Verify: new two-date `challenge(for:calendar:)` test; device-date QA.

### Sprint 4 — Fair, smooth difficulty
**Goal:** Rebuild difficulty on the async generator so it is monotonic & fair, never punishes getting stuck or scoring well, never deals a 2-open-cell board, wires/removes the dead `emptyChance` knob, rewards stranded blocks, and transitions board swaps smoothly.
**Shippable:** Cross-fade board transitions; NO MOVES toast no longer lingers; difficulty ramps over time (not from score or from being stuck); level-4 boards have a humane open-cell floor; stranded blocks pay out; the dead knob is wired/removed.

- **WI-4.1 · Fair, monotonic difficulty decoupled from stuck/score** *(D2,D3,D4,D5)* — Approach: replace `currentDifficultyLevel = min(4, max(0, boardDealIndex + score/500))` with a smoothed function of **legit clears + elapsed round time** (one step ≈ every 12s) that does not read score (D4) and does not increment on fresh-path/reshuffle deals (track legit clears separately) (D2); widen so it doesn't plateau immediately (D5). Raise `difficulty(level:4).minimumOpenCells` 2 → humane floor (~4) (D3). This level becomes the source of truth for WI-3.3 reshuffle and WI-7.4 live HUD. Files: GameModel.swift, GameCore.swift, GameRulesTests.swift · Depends: **WI-1.3** · Risk: keep `testDifficultyProfilesTightenAsLevelRises` relations; verify 50-seed clearable/healthy tests. Verify: new `testFreshPathDoesNotRaiseDifficulty`, `testLevel4HasHumaneOpenFloor`.
- **WI-4.2 · Reward stranded blocks; wire/remove dead `emptyChance`** *(D6,D7)* — Approach: fresh-path branch awards a small score for stranded blocks before dealing (D6); remove `emptyChance` from `BoardGenerationProfile` + `GameRules.emptyChance` mirror + all refs (it's ignored by `clearableRandomBoard`) (D7); keep Daily deterministic. Files: GameModel.swift, GameCore.swift, GameRulesTests.swift · Depends: **WI-1.3** · Verify: new `testFreshPathAwardsStrandedBonus`; build confirms no dangling refs.
- **WI-4.3 · Smooth board transitions; trim lingering fresh-path toast** *(F6,F7)* — Approach: brief cross-fade/scale on the board container keyed on a board-generation id (F6), reading effective reduce-motion (WI-5.6); clear the fresh-path toast the moment the new board is dealt (F7). Files: GameView.swift, GameModel.swift · Depends: **WI-1.3** · Risk: keep <~180ms, don't lag the input gate. Verify: sim QA with/without Reduce Motion.

### Sprint 5 — Scoring balance, accessibility completion & motion safety
**Goal:** Rebalance scoring so headline mechanics matter, then complete accessibility (VoiceOver poppability + announcements, Dynamic Type, contrast, 44pt targets, visible chain decay, motion-free feedback, photosensitivity guard, toggle traits).
**Shippable:** Chain pops no longer dwarf clear/unlock bonuses; per-pop +N shows at the block; VoiceOver users can pop & hear key events; text scales with Dynamic Type; secondary labels meet AA contrast; all tap targets ≥44pt; chain decay is visible & scaled; system Reduce Motion is honored with non-motion feedback; the white pop flash is photosensitivity-safe; switches read as toggles.

- **WI-5.1 · Rebalance economy: cap chain dominance, scale clear/unlock, per-pop +N, scale decay** *(E1,E3,E4,E6)* — Approach: cap/soften per-pop term (`10 * min(chain, CAP)` + small continuation reward); raise board-clear bonus to scale with blocks cleared / board size, lift the chain-multiplier cap above 10 (E6); re-tune unlock bonus relative to new per-pop. `scheduleChainReset` scales the window with chain/difficulty (not fixed 1.5s) driven by a **published decay deadline** (E3). Emit per-pop floating **+N** at the block via the WI-1.2 queue (E4). **Update all hardcoded score assertions in the same commit.** Files: GameModel.swift, GameView.swift, GameRulesTests.swift · Depends: **WI-1.2, WI-3.1** · Risk: biggest test-churn item. Verify: recompute all score tests + add "clear+unlock > equivalent pure-chain run" test.
- **WI-5.2 · Finish without cutting final pops; sync A/V to visual** *(F2,F9)* — Approach: defer/fade `escapingBlocks = []` in `finishRound` so in-flight pops complete (F2); remove the 10ms Task hop in `queueFeedback` so haptics/sound fire in sync (F9), keeping the WI-3.4 miss rate-limit. Files: GameModel.swift · Depends: **WI-1.2** · Verify: model test that `queueFeedback` no longer sleeps; sim QA expire-mid-pop.
- **WI-5.3 · Visible, pause-aware chain-decay indicator** *(F5)* — Approach: shrinking ring/bar on the CHAIN `HUDTile` driven by the published decay deadline (WI-5.1); freezes on pause; no per-frame re-render. Files: GameView.swift, GameModel.swift · Depends: **WI-5.1** · Verify: sim QA drain + pause-freeze.
- **WI-5.4 · Low-time urgency cue** *(F4)* — Approach: color shift/pulse + optional tick haptic on the TIME `HUDTile` in the final seconds, from `RoundClock` remaining (WI-3.2); respects `hapticsEnabled`/pause; honors reduce-motion. Files: GameView.swift · Depends: **WI-3.2** · Verify: play to 0:05.
- **WI-5.5 · VoiceOver: poppable blocks as buttons + board grouping + announcements** *(G1,G6,G10)* — Approach: each occupied **open** cell gets `.isButton` + `.accessibilityAction` calling `attemptPop` with the block's own direction (VoiceOver can't flick), respecting `isDealing`; blocked cells expose no pop action. Group board `.accessibilityElement(children:.contain)`, row-major; `.accessibilityHidden` empty cells; mark Home `DecorativeBlockCluster` decorative (G10). Subscribe to the WI-1.2 queue and `UIAccessibility.post(.announcement)` localized (EN/KO) for BOARD CLEAR / FRESH PATH / UNLOCK / milestone chains / new best / round end, **throttled to events** (G6). Files: GameView.swift, GameModel.swift, Screens.swift · Depends: **WI-1.1, WI-1.2** · Risk: actions main-actor, idempotent, no double-fire with gesture; throttle announcements. Verify: VoiceOver sim QA (pop via action, spoken EN+KO, empty cells silent) + logic XCTest.
- **WI-5.6 · Dynamic Type, effective Reduce Motion, motion-free feedback, photosensitivity, toggle traits, subtitle wrapping** *(G2,G3,G8,G11,G12,F3,H6,I6)* — Approach: wrap `Font.ppDisplay`/`ppBody` with `UIFontMetrics`/`relativeTo` so sizes track Dynamic Type, raise Korean (Jua) base / reduce shrink (G3,G12); remove one-line clamps fighting wrapping on tutorial title/subtitle (H6) **and Settings toggle subtitles (I6)**. Derive effective Reduce Motion once in `RootView` (`system OR app toggle`) and thread everywhere (G2). When reduced, replace the instant feedback-less pop with a quick opacity/color confirm + per-pop +N + haptic (F3). Cap `EscapingBlockView.flashOpacity` and white particle intensity/rate during big chains (G8). Add `.isToggle` to `SettingRow` switches (G11). Files: DesignSystem.swift, PopPathApp.swift, GameView.swift, Screens.swift · Depends: **WI-1.1** · Risk: verify XXL doesn't overflow fixed-height tiles; flash cap mustn't wash out juice. Verify: Dynamic-Type sweep EN/KO; system Reduce Motion (no in-app toggle) calms gameplay; frame-inspect a chain; VoiceOver reads "Sound, toggle, on".
- **WI-5.7 · Contrast and 44pt tap targets** *(G4,G5)* — Approach: darken `ppWarmGray` (and low-contrast secondary uses) to ≥4.5:1 on cream/sage (G5); enlarge exit (36→≥44), back chevrons (38→≥44), language/toggle controls via padding + `contentShape` keeping glyphs small (G4). Files: DesignSystem.swift, GameView.swift, Screens.swift · Depends: — · Verify: Accessibility Inspector contrast; tap-target QA.

### Sprint 6 — Onboarding & tutorial truth
**Goal:** Teach the real rules (arrow-matching flick + escapability runway), require the taught gesture, be replayable in release, wrap text, and be reachable even via Daily.
**Shippable:** New players learn a flick must match the arrow and a block needs a clear runway; tutorial requires the actual gesture (with a skip fallback); replayable from Settings; first-time Daily players are no longer silently opted out.

- **WI-6.1 · Correct rules, teach escapability, require the taught gesture** *(H1,H2,H4)* — Approach: rewrite `TutorialView` copy so step 1 accurately states the arrow-matching flick (now true under R1) (H1) and add a step teaching the escapability runway-to-edge rule (H2). Replace advance-on-any-tap with a gesture gate: correct directional flick on `highlightedIndex` using the WI-1.1 `Direction.swipeDirection` helper (H4); Skip/Next fallback after a few tries. EN/KO parity. Files: Screens.swift · Depends: **WI-1.1, WI-2.2, WI-4.1** · Verify: sim QA (wrong flick no-advance, correct advances); XCTest on step-1 copy constant mentioning runway/edge.
- **WI-6.2 · Tutorial reachable from Daily & replayable** *(H3,H5)* — Approach: route first-time Daily players through the tutorial (don't set `hasSeenTutorial` on the Daily path) (H3); add "How to play"/"플레이 방법" in Settings (and/or Home) routing to `.tutorial` regardless of `hasSeenTutorial`, returning to the originating screen via `onComplete` (H5). Files: PopPathApp.swift, Screens.swift · Depends: **WI-6.1** · Verify: wiped-install QA (Daily-first → tutorial; Settings → How to play → returns to Settings).

### Sprint 7 — Retention, meta & navigation depth
**Goal:** Local-only depth & re-engagement: daily streak + optional local reminder, one-shot Daily with stakes, live celebration, re-tiered achievements with mode-split bests & PEAK legend, empty states, data reset, richer records, in-game settings, back-stack/edge-swipe, live difficulty HUD. **All local — no backend/IAP/ads.**
**Shippable:** Streak + opt-in local reminder; one-shot Daily with streak tension & an in-app explainer; live best/achievement celebration; achievements no longer all unlock round 1–2; per-mode bests; PEAK legend + live difficulty pip; framed empty states; data reset; in-game settings via pause; per-mode/trend records; back affordance on secondary screens.

- **WI-7.1 · Daily streak + optional local reminder + empty states** *(K3,K7)* — Approach: add `currentStreak`/`longestStreak`/`lastDailyCompletionDate` to `PlayerStats` (decode defaults), updated in `recordRound` for `.daily` using the DailyChallenge day id + same `.autoupdatingCurrent` calendar as WI-3.5 (increment consecutive, reset on gap) (K3); **opt-in** local `UserNotifications` daily reminder (permission requested after first completed run, no server/account); frame brand-new Home/Records zero states with welcoming copy (K7); surface streak on Home & Result. Files: GameModel.swift, Screens.swift, PopPathApp.swift · Depends: **WI-3.5** · Risk: permission opt-in + graceful denial; streak math uses the DailyChallenge calendar; Codable decode defaults. Verify: new `testDailyStreakIncrementsAndResets` (injected dates); fresh-install empty-state QA; scheduled-notification QA.
- **WI-7.2 · One-shot Daily with tension + shared-board explainer** *(K1,K2,K13,K18)* — Approach: make Daily one-shot per calendar day — after finishing today's Daily record `dailyCompletedDate` and lock further attempts until midnight rollover (WI-3.5), showing result/streak instead of infinite re-rolls (K2); the seeded board gains stakes feeding the streak; one-shot framing + streak differentiate Daily from Classic (no second mode needed) (K1); add an in-app explainer of the seeded/shared one-attempt nature (K18); re-label/route Daily Retry per one-shot semantics, coordinating WI-3.3 (K13). **Lockout must not block the direct `newRound(mode:.daily)` path the tests use** — gate only repeat attempts after completion. Files: GameModel.swift, GameView.swift, Screens.swift, PopPathApp.swift · Depends: **WI-3.3, WI-7.1** · Risk: keep `testDailyRoundUsesStableTodayBoard`/`testDailyBestPersistsSeparately` green. Verify: new `testDailyLocksAfterCompletionUntilNextDay`.
- **WI-7.3 · Live celebration, in-the-moment achievements, re-tiered catalog, mode-split bests, PEAK legend, unseen badge, stakeful metrics** *(K5,K12,K16,E5,E7,E8,K8,K14)* — Approach: evaluate eligible achievements mid-round in the scoring path (guarded against re-unlock) and surface a celebratory toast via the WI-1.2 queue (K5); emit a once-per-run "NEW BEST!" live toast when score crosses best/dailyBest (K12); keep authoritative persistence in `finishRound`. Re-tier `newlyUnlocked` thresholds so they don't all unlock round 1–2 (E5) and add higher-horizon/cumulative/streak milestones (K8). Give Accuracy/No-Misses stakes via a tier/bonus (E7). Split the conflated global best so Daily & Classic bests report distinctly on Home/Result/Records (E8). Add a "LV n of 5" legend to the PEAK tile (K14). Track `seenAchievementIDs` (decode default) and show an unseen dot/badge on Home & Records (K16). Files: GameModel.swift, GameView.swift, Screens.swift, GameRulesTests.swift · Depends: **WI-1.2, WI-5.1, WI-7.1** · Risk: no double-count vs `finishRound`; keep/update `testFinishRoundPersistsStatsAndAchievements`. Verify: new `testNewBestEventFiresOnceWhenCrossed`, `testAchievementUnlockSurfacedDuringRun`, `testAchievementThresholdsAreProgressive`, `testClassicAndDailyBestReportedSeparately`.
- **WI-7.4 · Data reset, richer records, in-game settings, back-stack, live difficulty HUD** *(K9,K11,K17,K15,K19)* — Approach: confirmed "Reset local data" in Settings clearing `bestScore`, `playerStats.v1`, all `dailyBest.*`, `recentClassicBoardSignatures.v1`, `hasSeenTutorial`, streak, + in-memory state (K9); enrich Records with per-mode breakdown (classic/daily already tracked) + a capped `recentScores` trend (decode default) (K11); surface Settings from the pause overlay so toggles change mid-run (K17); add back-stack/edge-swipe-back to the manual `AppRoute` switch (adopt `NavigationStack`, or an edge-swipe gesture as lower-risk fallback — board is now a single gesture so edge conflict is low) (K15); add a live difficulty/level pip to the HUD from the WI-4.1 source of truth (K19). Files: Screens.swift, PopPathApp.swift, GameView.swift, GameModel.swift · Depends: **WI-3.1, WI-4.1, WI-7.3** · Risk: reset only from Home/Settings; NavigationStack migration could regress transitions (edge-swipe fallback); HUD derives, doesn't recompute per frame. Verify: new `testResetClearsAllLocalData` + recentScores capping; QA reset/in-game-settings/edge-swipe/live pip.

### Sprint 8 — Localization, copy, audio & final polish
**Goal:** Fix share/copy/date/version strings, the static timer badge & label-gap hacks, the fragile empty-cell swap, and audio-session/haptic-fidelity issues — the last layer with no further dependents.
**Shippable:** Friendly localized share date + download link; Korean date format; real version; the misleading static 60s badge gone; real label spacing; clean empty-cell swaps; audio robust to mute/interruption with distinct clear/finish haptics and a sound-toggle preview.

- **WI-8.1 · Share text, dates, version, static badge, label-gap hacks** *(I1,I2,I3,I4,I5,I7)* — Approach: format `shareText`'s raw YYYYMMDD into a friendly localized date (I1) + append an App Store/download link (placeholder URL until live) (I2); `DailyChallenge.displayLabel` per-language (KO `M월 D일`), fed by WI-3.5 (I5); replace `"PopPath! v0"` with real `CFBundleShortVersionString`/build (I4); remove the static `60s`/`60초` `topBar` badge (replace with a mode label or drop — pause/clock now in HUD) (I3); replace trailing-space gap hacks in HUD DAILY/BEST labels with real HStack spacing (I7). Files: GameModel.swift, GameCore.swift, Screens.swift, GameView.swift, GameRulesTests.swift · Depends: **WI-3.5** · Risk: keep `testShareTextContainsRoundDetails` substrings (add date+link, update test); keep `DailyChallenge.id` YYYYMMDD so `testDailyChallengeSeedIsStableForDate` stays green — only `displayLabel` becomes locale-aware. Verify: update share test + URL assertion; KO QA.
- **WI-8.2 · Smooth empty-cell swap transition** *(F8)* — Approach: with the board-level transition from WI-4.3 in place, give the cell content change (block→empty) a gentle transition/identity so the slide illusion is stable, or remove it in favor of the WI-4.3 board transition; avoid double-animation; honor effective reduce-motion (WI-5.6). Files: GameView.swift · Depends: **WI-4.3** · Verify: QA cell clears with/without Reduce Motion.
- **WI-8.3 · Audio-session robustness, distinct cues, sound-toggle preview** *(J1,J4,J5,J6)* — Approach: switch `AVAudioSession` `.ambient`→`.playback` (still gated by the in-app sound toggle; never play when off) so enabled SFX play regardless of the mute switch — a documented product decision (J1); add interruption/route-change/lifecycle handling via `AVAudioSession` notifications, reactivating on resume (J6); give board-clear vs round-finish distinct haptics (both `.success` today) (J4); play a short preview tone when Sound is toggled on (J5). *(J2/J3/J7 and A6 are handled in WI-3.4.)* Files: GameCore.swift, GameModel.swift, Screens.swift, PopPathApp.swift · Depends: **WI-3.4** · Risk: `.playback` can duck other audio — respect toggle, activate only when enabled; interruption handling mustn't crash if setup failed. Verify: mute-switch-on QA; toggle preview; simulated call interruption; clear vs finish haptics differ.

> **I6 resolution:** originally double-claimed by WI-5.6 and a separate WI-8.2. Folded entirely into **WI-5.6** (Dynamic Type wrapping already removes the `SettingRow` subtitle clamp). The former dedicated subtitle item is dropped; Sprint 8's WI-8.2 is now the empty-cell-swap polish.

---

## 4. Coverage matrix (finding → work item)

| Cluster | Findings → WI |
|---|---|
| **A Input** | A1,A2,A3,A4,A5,A7,A8,A9 → WI-1.1 · A6 → WI-3.4 |
| **B Readability** | B1,B2 → WI-2.1 · B3 → WI-2.2 |
| **C Lifecycle** | C1 → WI-3.1 · C2,C6 → WI-3.3 · C3 → WI-3.2 · C4 → WI-3.4 · C5 → WI-3.5 |
| **D Difficulty** | D1,D8 → WI-1.3 · D2,D3,D4,D5 → WI-4.1 · D6,D7 → WI-4.2 |
| **E Scoring** | E1,E3,E4,E6 → WI-5.1 · E2 → WI-3.4 · E5,E7,E8 → WI-7.3 |
| **F Feedback** | F1 → WI-1.2 · F2,F9 → WI-5.2 · F3 → WI-5.6 · F4 → WI-5.4 · F5 → WI-5.3 · F6,F7 → WI-4.3 · F8 → WI-8.2 |
| **G Accessibility** | G1,G6,G10 → WI-5.5 · G2,G3,G8,G11,G12 → WI-5.6 · G4,G5 → WI-5.7 · G7 → WI-2.1 · G9 → WI-2.2 |
| **H Onboarding** | H1,H2,H4 → WI-6.1 · H3,H5 → WI-6.2 · H6 → WI-5.6 |
| **I Localization** | I1,I2,I3,I4,I5,I7 → WI-8.1 · I6 → WI-5.6 |
| **J Audio/Haptics** | J2,J3,J7 → WI-3.4 · J1,J4,J5,J6 → WI-8.3 |
| **K Retention/Nav** | K3,K7 → WI-7.1 · K1,K2,K13,K18 → WI-7.2 · K5,K12,K16,K8,K14 → WI-7.3 · K9,K11,K17,K15,K19 → WI-7.4 |

**Total: 91/91. No unmapped, no duplicate (post-I6 resolution), no ordering violation.**

---

## 5. Per-sprint exit gate (run before merging each sprint)

```bash
xcodebuild build -scheme PopPath -destination 'generic/platform=iOS Simulator'
xcodebuild build -configuration Release -scheme PopPath -destination 'generic/platform=iOS Simulator'
xcodebuild test  -scheme PopPath -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```
Plus the per-item `verify` steps (new/updated XCTests + simulator QA). A sprint merges only when: all listed findings demonstrably resolved (before→after observable), the full test suite is green, and no prior sprint's behavior regressed.
