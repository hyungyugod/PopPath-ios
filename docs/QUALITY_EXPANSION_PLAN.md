# PopPath Quality Expansion Plan

## Goal

Turn PopPath from a single-score arcade loop into a compact personal puzzle game with replay variety, light mastery, shareable records, and achievement-driven return loops.

## Feature Set

### 1. Recent Board Duplicate Guard

- Store recent classic board signatures locally.
- Avoid dealing boards seen in the recent window when possible.
- Keep Daily Challenge deterministic and unchanged for the same date.
- Target window: last 50 classic boards.

### 2. Difficulty Curve

- Start each round with the current readable board density.
- Increase difficulty as the round progresses through clears and score growth.
- Make higher levels denser and reduce obvious open-path choices.
- Preserve the no-move recovery system so a round never becomes unplayable.

### 3. Stronger Chain and Unlock Payoff

- Keep wall-exit pop movement.
- Add stronger labels for multi-path unlocks: `DOUBLE UNLOCK` and `PATH BURST`.
- Add higher chain labels such as `MEGA CHAIN`.
- Track unlock burst size for records and achievements.

### 4. Detailed Personal Records

- Persist lifetime stats locally:
  - rounds played
  - total score
  - total pops and misses
  - total unlocks and board clears
  - best score
  - best daily score
  - best chain
  - best accuracy
  - most unlocks in a round
  - most board clears in a round
- Show concise records from Home and a full Records screen.

### 5. Shareable Runs and Personal Bests

- Add `ShareLink` to the result screen.
- Share text should include mode, score, best, max chain, unlocks, board clears, and accuracy.
- Highlight new personal bests in the result screen.

### 6. Achievement System

- Persist unlocked achievements locally.
- Unlock achievements at round end.
- Show newly unlocked achievements on the result screen.
- Show full achievement progress in Records.

## Implementation Order

1. Add progression data models and persistence.
2. Add board signature helpers and recent-board storage.
3. Add difficulty profiles and route board generation through current difficulty.
4. Track per-round metrics inside `GameModel`.
5. Update result summary and sharing text.
6. Add Records screen and route from Home.
7. Add tests for persistence, achievements, board uniqueness, and sharing text.
8. Run Debug build, Release build, test suite, and simulator visual QA.

## Acceptance Criteria

- Classic mode avoids recent board duplicates when generation can find an alternative.
- Daily mode stays stable for the same date.
- Result screen shows detailed round stats and share action.
- Home exposes Records.
- Records screen shows lifetime stats and achievements.
- Achievements unlock once and persist.
- All existing build/test commands pass.
