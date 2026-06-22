import XCTest
import CoreGraphics
@testable import PopPath

final class GameRulesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: GameModel.bestScoreStorageKey)
        UserDefaults.standard.removeObject(forKey: GameModel.dailyBestStorageKey(for: DailyChallenge.today().id))
        UserDefaults.standard.removeObject(forKey: GameModel.playerStatsStorageKey)
        UserDefaults.standard.removeObject(forKey: GameModel.recentBoardSignaturesStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GameModel.bestScoreStorageKey)
        UserDefaults.standard.removeObject(forKey: GameModel.dailyBestStorageKey(for: DailyChallenge.today().id))
        UserDefaults.standard.removeObject(forKey: GameModel.playerStatsStorageKey)
        UserDefaults.standard.removeObject(forKey: GameModel.recentBoardSignaturesStorageKey)
        super.tearDown()
    }

    func testDailyChallengeSeedIsStableForDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 18
        ).date ?? Date()

        let challenge = DailyChallenge.challenge(for: date, calendar: calendar)

        XCTAssertEqual(challenge.id, "20260618")
        XCTAssertEqual(challenge, DailyChallenge.challenge(for: date, calendar: calendar))
    }

    func testDailyChallengeSeedChangesAcrossDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let firstDate = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 18
        ).date ?? Date()
        let secondDate = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 19
        ).date ?? Date()

        XCTAssertNotEqual(
            DailyChallenge.challenge(for: firstDate, calendar: calendar).seed,
            DailyChallenge.challenge(for: secondDate, calendar: calendar).seed
        )
    }

    func testRoundLengthIsSixtySeconds() {
        XCTAssertEqual(GameRules.roundSeconds, 60)
    }

    func testDifficultyProfilesTightenAsLevelRises() {
        let easy = BoardGenerationProfile.difficulty(level: 0)
        let hard = BoardGenerationProfile.difficulty(level: 4)

        XCTAssertLessThan(hard.maximumOpenCells, easy.maximumOpenCells)
        XCTAssertGreaterThan(hard.minimumFilledCells, easy.minimumFilledCells)
    }

    func testBoardSignatureIgnoresIdentityAndTransientState() {
        var first = GameRules.emptyBoard()
        var second = GameRules.emptyBoard()
        var transientBlock = PopBlock(direction: .right, tone: .mistBlue)
        transientBlock.isMiss = true

        first[0][0] = transientBlock
        second[0][0] = PopBlock(direction: .right, tone: .mistBlue)

        XCTAssertEqual(GameRules.boardSignature(first), GameRules.boardSignature(second))
    }

    func testSeededBoardGenerationIsDeterministic() {
        var firstRandom = SeededRandomNumberGenerator(seed: 2_026_06_18)
        var secondRandom = SeededRandomNumberGenerator(seed: 2_026_06_18)

        let first = GameRules.generatedBoard(using: &firstRandom)
        let second = GameRules.generatedBoard(using: &secondRandom)

        XCTAssertEqual(boardSignature(first), boardSignature(second))
    }

    func testGeneratedBoardsHaveHealthyOpeningChoices() {
        for seed in UInt64(1)...50 {
            var random = SeededRandomNumberGenerator(seed: seed)
            let board = GameRules.generatedBoard(using: &random)

            XCTAssertGreaterThanOrEqual(
                GameRules.openPositions(in: board).count,
                BoardGenerationProfile.standard.minimumOpenCells,
                "Seed \(seed) should start with enough playable moves."
            )
        }
    }

    func testGeneratedBoardsAreClearable() {
        for seed in UInt64(1)...50 {
            var random = SeededRandomNumberGenerator(seed: seed)
            let board = GameRules.generatedBoard(using: &random)

            XCTAssertTrue(
                GameRules.isClearable(board),
                "Seed \(seed) should produce a board that can continue to clear."
            )
        }
    }

    func testEscapableRequiresClearPathToEdge() {
        var board = GameRules.emptyBoard()
        board[3][2] = PopBlock(direction: .right, tone: .mistBlue)

        XCTAssertTrue(GameRules.isEscapable(on: board, row: 3, column: 2))

        board[3][5] = PopBlock(direction: .left, tone: .lavenderMist)
        XCTAssertFalse(GameRules.isEscapable(on: board, row: 3, column: 2))
    }

    func testOpenPositionsRecomputeAfterCellClears() {
        var board = GameRules.emptyBoard()
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][4] = PopBlock(direction: .right, tone: .lavenderMist)

        XCTAssertFalse(GameRules.openPositions(in: board).contains(BoardPosition(row: 2, column: 1)))

        board[2][4] = nil
        XCTAssertTrue(GameRules.openPositions(in: board).contains(BoardPosition(row: 2, column: 1)))
    }

    func testClearableDetectsLockedBoard() {
        var board = GameRules.emptyBoard()
        board[3][2] = PopBlock(direction: .right, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .left, tone: .lavenderMist)

        XCTAssertFalse(GameRules.hasPlayableMove(in: board))
        XCTAssertFalse(GameRules.isClearable(board))
    }

    @MainActor
    func testChainScoringIncrementsByCurrentChain() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[4][0] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.swipe(row: 4, column: 0, hapticsEnabled: false)

        XCTAssertEqual(model.chain, 2)
        XCTAssertEqual(model.maxChain, 2)
        XCTAssertEqual(model.score, 30)
    }

    @MainActor
    func testMissResetsCurrentChain() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][4] = PopBlock(direction: .left, tone: .lavenderMist)
        // Keep an open cell after the first pop so the board doesn't go stuck (which would
        // pay a stranded-block consolation and muddy the score assertion).
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        XCTAssertEqual(model.chain, 1)

        model.swipe(row: 2, column: 1, hapticsEnabled: false)
        XCTAssertEqual(model.chain, 0)
        XCTAssertEqual(model.score, 10)
    }

    @MainActor
    func testSuccessfulSwipeFreesPathImmediately() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][2] = PopBlock(direction: .right, tone: .lavenderMist)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        XCTAssertFalse(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 3, column: 2)))

        model.swipe(row: 3, column: 5, hapticsEnabled: false, soundEnabled: false)

        XCTAssertNil(model.board[3][5])
        XCTAssertEqual(model.escapingBlocks.count, 1)
        XCTAssertTrue(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 3, column: 2)))

        model.swipe(row: 3, column: 2, hapticsEnabled: false, soundEnabled: false)

        XCTAssertNil(model.board[3][2])
        XCTAssertEqual(model.chain, 2)
        XCTAssertEqual(model.escapingBlocks.count, 2)
    }

    @MainActor
    func testSwipeCreatesEscapeEffect() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false, soundEnabled: false)

        XCTAssertNil(model.board[3][5])
        XCTAssertEqual(model.escapingBlocks.count, 1)
        XCTAssertEqual(model.escapingBlocks.first?.chain, 1)
        XCTAssertEqual(model.chain, 1)
    }

    @MainActor
    func testUnlockBonusRewardsOpeningNewPath() async {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][2] = PopBlock(direction: .right, tone: .lavenderMist)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        XCTAssertFalse(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 3, column: 2)))

        model.swipe(row: 3, column: 5, hapticsEnabled: false, soundEnabled: false)
        try? await Task.sleep(nanoseconds: 420_000_000)

        XCTAssertTrue(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 3, column: 2)))
        // WI-5.1: pop (chain 1) = 10; unlock = 1 path * 14 * chain 1 = 14; total 24.
        XCTAssertEqual(model.score, 24)
        XCTAssertEqual(model.boardToast?.style, .unlock)
    }

    @MainActor
    func testAbandonRoundStopsWithoutSummary() {
        let model = GameModel(makeInitialBoard: false)
        model.newRound()

        model.abandonRound()

        XCTAssertFalse(model.running)
        XCTAssertEqual(model.runState, .idle)
        XCTAssertNil(model.roundSummary)
        XCTAssertEqual(model.chain, 0)
        XCTAssertEqual(model.stats.roundsPlayed, 0, "Abandon is the discard path; it must not credit stats")
    }

    @MainActor
    func testClassicBoardsRecordRecentSignatures() {
        let model = GameModel(makeInitialBoard: false)

        model.newRound()

        let signatures = UserDefaults.standard.stringArray(
            forKey: GameModel.recentBoardSignaturesStorageKey
        ) ?? []
        XCTAssertEqual(signatures.first, GameRules.boardSignature(model.board))
        XCTAssertLessThanOrEqual(signatures.count, 50)
    }

    @MainActor
    func testStuckBoardAutomaticallyDealsFreshPath() async {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][2] = PopBlock(direction: .right, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        XCTAssertEqual(GameRules.openPositions(in: model.board), Set([BoardPosition(row: 0, column: 0)]))

        model.swipe(row: 0, column: 0, hapticsEnabled: false, soundEnabled: false)
        try? await Task.sleep(nanoseconds: 1_050_000_000)

        XCTAssertTrue(model.running)
        XCTAssertGreaterThan(GameRules.openPositions(in: model.board).count, 0)
        XCTAssertTrue(GameRules.isClearable(model.board))
        XCTAssertEqual(model.time, GameRules.roundSeconds)
    }

    @MainActor
    func testBoardClearAwardsBonusAndDealsNextBoard() async {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 0, column: 0, hapticsEnabled: false, soundEnabled: false)
        await waitForBoardClearRefresh(in: model)

        XCTAssertTrue(model.running)
        XCTAssertGreaterThanOrEqual(model.score, 210)
        XCTAssertGreaterThan(GameRules.blockCount(in: model.board), 0)
        XCTAssertGreaterThan(GameRules.openPositions(in: model.board).count, 0)
    }

    @MainActor
    func testDailyRoundUsesStableTodayBoard() {
        let first = GameModel(makeInitialBoard: false)
        let second = GameModel(makeInitialBoard: false)

        first.newRound(mode: .daily)
        second.newRound(mode: .daily)

        XCTAssertEqual(first.mode, .daily)
        XCTAssertEqual(boardSignature(first.board), boardSignature(second.board))
    }

    @MainActor
    func testDailyBestPersistsSeparately() {
        let challenge = DailyChallenge.today()
        UserDefaults.standard.removeObject(forKey: GameModel.dailyBestStorageKey(for: challenge.id))
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[4][0] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board, mode: .daily)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.swipe(row: 4, column: 0, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        // WI-5.1: pops 10 + 20 = 30; board emptied at chain 2 → clear bonus 200 + 2*22 = 244;
        // total 274.
        XCTAssertEqual(model.dailyBest, 274)
        XCTAssertEqual(model.roundSummary?.dailyBest, 274)
        XCTAssertEqual(model.roundSummary?.mode, .daily)
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: GameModel.dailyBestStorageKey(for: challenge.id)),
            274
        )
    }

    @MainActor
    func testFinishRoundPersistsStatsAndAchievements() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[4][0] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false, soundEnabled: false)
        model.swipe(row: 4, column: 0, hapticsEnabled: false, soundEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        XCTAssertEqual(model.stats.roundsPlayed, 1)
        XCTAssertEqual(model.stats.totalPops, 2)
        // WI-5.1: pops 10 + 20 = 30; board clear at chain 2 = 200 + 2*22 = 244; total 274.
        XCTAssertEqual(model.stats.bestScore, 274)
        XCTAssertTrue(model.stats.unlockedAchievementIDs.contains("first_run"))
        XCTAssertEqual(GameModel.loadStats(), model.stats)
        XCTAssertEqual(model.roundSummary?.unlockedAchievements.map(\.id), ["first_run"])
    }

    func testShareTextContainsRoundDetails() {
        let metrics = RoundMetrics(
            pops: 12,
            misses: 1,
            unlocks: 3,
            bestUnlockBurst: 2,
            boardClears: 1,
            freshPaths: 0,
            difficultyPeak: 2
        )
        let summary = RoundSummary(
            score: 1_234,
            best: 2_000,
            maxChain: 6,
            metrics: metrics
        )

        XCTAssertTrue(summary.shareText.contains("Score 1,234"))
        XCTAssertTrue(summary.shareText.contains("Best 2,000"))
        XCTAssertTrue(summary.shareText.contains("Unlocks 3"))
        XCTAssertTrue(summary.shareText.contains("Accuracy 92%"))

        let koreanShareText = summary.shareText(language: .korean)
        XCTAssertTrue(koreanShareText.contains("점수 1,234"))
        XCTAssertTrue(koreanShareText.contains("최고 2,000"))
        XCTAssertTrue(koreanShareText.contains("정확도 92%"))
    }

    // MARK: - Sprint 1: direction-true input (WI-1.1)

    @MainActor
    func testAttemptPopRequiresMatchingDirection() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        // A second, untouched block keeps the board non-empty so the matching pop below
        // does not also trigger a board-clear bonus.
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        model.loadBoardForTesting(board)

        // A flick against the arrow registers a miss: the block stays, the chain resets.
        model.attemptPop(row: 3, column: 5, direction: .left, hapticsEnabled: false, soundEnabled: false)
        XCTAssertNotNil(model.board[3][5])
        XCTAssertEqual(model.chain, 0)
        XCTAssertEqual(model.score, 0)

        // A flick matching the arrow on an escapable block pops it.
        model.attemptPop(row: 3, column: 5, direction: .right, hapticsEnabled: false, soundEnabled: false)
        XCTAssertNil(model.board[3][5])
        XCTAssertEqual(model.chain, 1)
        XCTAssertEqual(model.score, 10)
    }

    func testTapDoesNotPopEscapableCell() {
        // The board gesture only forwards a pop when a flick resolves to a direction; a tap
        // (sub-threshold translation) resolves to nil and never reaches `attemptPop`.
        XCTAssertNil(Direction.swipeDirection(for: .zero, minimumDistance: 14, axisBias: 1.16))
        XCTAssertNil(Direction.swipeDirection(for: CGSize(width: 3, height: 4), minimumDistance: 14, axisBias: 1.16))
        XCTAssertEqual(
            Direction.swipeDirection(for: CGSize(width: 40, height: 3), minimumDistance: 14, axisBias: 1.16),
            .right
        )
        XCTAssertEqual(
            Direction.swipeDirection(for: CGSize(width: 2, height: -36), minimumDistance: 14, axisBias: 1.16),
            .up
        )
    }

    // MARK: - Sprint 1: ordered event queue (WI-1.2)

    @MainActor
    func testConcurrentRewardsEnqueueAll() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Three mutually non-blocking escapable blocks. Popping all three reaches chain 3
        // (chain toast) and empties the board on the final pop (board-clear toast), so two
        // events are produced by a single pop.
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[0][5] = PopBlock(direction: .up, tone: .mistBlue)
        board[6][0] = PopBlock(direction: .down, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 0, column: 0, hapticsEnabled: false, soundEnabled: false)
        model.swipe(row: 0, column: 5, hapticsEnabled: false, soundEnabled: false)
        model.swipe(row: 6, column: 0, hapticsEnabled: false, soundEnabled: false)

        XCTAssertEqual(model.chain, 3)
        // The highest-priority event (board clear) is displayed first…
        XCTAssertEqual(model.boardToast?.style, .clear)
        // …while the lower-priority chain event is enqueued, not dropped.
        XCTAssertTrue(model.queuedEventKinds.contains(.chain))
    }

    // MARK: - Sprint 1: off-main generation + guaranteed fallback (WI-1.3)

    func testAsyncGeneratedBoardMatchesSyncForSeed() async {
        let seed: UInt64 = 2_026_06_22
        var sync = SeededRandomNumberGenerator(seed: seed)
        let syncBoard = GameRules.generatedBoard(using: &sync, profile: .standard)
        let asyncBoard = await GameRules.generatedBoardAsync(seed: seed, profile: .standard)

        XCTAssertEqual(boardSignature(syncBoard), boardSignature(asyncBoard))
    }

    func testFinalFallbackBoardIsAlwaysClearable() {
        let board = GameRules.guaranteedClearableBoard()

        XCTAssertTrue(GameRules.isClearable(board))
        XCTAssertGreaterThan(GameRules.openPositions(in: board).count, 0)
        XCTAssertGreaterThanOrEqual(
            GameRules.blockCount(in: board),
            BoardGenerationProfile.standard.minimumOpenCells
        )
    }

    // MARK: - Sprint 3: lifecycle, wall-clock, destructive-action safety

    @MainActor
    func testPauseFreezesClockAndChain() {
        var fakeNow = Date(timeIntervalSinceReferenceDate: 1_000)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        XCTAssertEqual(model.chain, 1)
        XCTAssertEqual(model.time, 60)

        model.pause()
        XCTAssertEqual(model.runState, .paused)

        // 10 seconds pass while paused.
        fakeNow = fakeNow.addingTimeInterval(10)
        model.resume()

        XCTAssertEqual(model.runState, .running)
        XCTAssertEqual(model.time, 60, "Paused seconds must not be deducted from the clock")
        XCTAssertEqual(model.chain, 1, "Pause must preserve the chain")
    }

    @MainActor
    func testWallClockDeductsElapsedTimeOnForeground() {
        var fakeNow = Date(timeIntervalSinceReferenceDate: 5_000)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        XCTAssertEqual(model.time, 60)

        // Simulate 12s elapsing while backgrounded, then returning to the foreground.
        fakeNow = fakeNow.addingTimeInterval(12)
        model.handleForeground()

        XCTAssertEqual(model.time, 48, "Backgrounded time keeps burning the wall clock")
    }

    @MainActor
    func testReshuffleBoardKeepsScoreAndTime() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        let scoreBefore = model.score
        let timeBefore = model.time

        model.reshuffleBoard()

        XCTAssertEqual(model.score, scoreBefore, "Reshuffle keeps the score")
        XCTAssertEqual(model.time, timeBefore, "Reshuffle keeps the clock")
        XCTAssertEqual(model.chain, 1, "Reshuffle keeps the chain")
        XCTAssertTrue(model.running)
        XCTAssertGreaterThan(GameRules.blockCount(in: model.board), 0)
    }

    @MainActor
    func testExitCreditsLifetimeStats() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[4][0] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.swipe(row: 4, column: 0, hapticsEnabled: false)

        model.creditAndEndRun()

        XCTAssertFalse(model.running)
        XCTAssertNil(model.roundSummary, "Credited exit shows no summary screen")
        XCTAssertEqual(model.stats.roundsPlayed, 1)
        XCTAssertEqual(model.stats.totalPops, 2)
        XCTAssertEqual(model.stats.bestScore, 30)
        XCTAssertEqual(model.best, 30)
        XCTAssertEqual(GameModel.loadStats(), model.stats)
    }

    @MainActor
    func testMissAppliesTimePenalty() {
        var fakeNow = Date(timeIntervalSinceReferenceDate: 2_000)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })
        var board = GameRules.emptyBoard()
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][4] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        XCTAssertEqual(model.time, 60)

        // (2,1) points right into the blocked (2,4): a miss.
        model.swipe(row: 2, column: 1, hapticsEnabled: false)

        XCTAssertEqual(model.time, 58, "A miss shaves a small fixed amount off the clock")
    }

    @MainActor
    func testPopFeedbackEscalatesWithChain() {
        XCTAssertEqual(GameModel.feedbackEvent(forChain: 1), .escape)
        XCTAssertEqual(GameModel.feedbackEvent(forChain: 2), .chain)
        XCTAssertEqual(GameModel.feedbackEvent(forChain: 4), .chain)
        XCTAssertEqual(GameModel.feedbackEvent(forChain: 5), .bigChain)
        XCTAssertEqual(GameModel.feedbackEvent(forChain: 9), .bigChain)
    }

    @MainActor
    func testDailyRollsOverWhenDateChanges() {
        var fakeNow = dayDate(2026, 6, 22)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })
        let firstId = model.dailyChallenge.id

        // Jump to a clearly different calendar day (timezone-robust gap).
        fakeNow = dayDate(2026, 8, 15)
        model.refreshDailyIfDateChanged()

        XCTAssertNotEqual(model.dailyChallenge.id, firstId)
        XCTAssertEqual(model.dailyChallenge.id, DailyChallenge.today(now: fakeNow).id)
    }

    @MainActor
    func testPendingRefreshDoesNotBlockLaterBoardClear() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 0, column: 0, hapticsEnabled: false)
        // First clear awards the bonus and schedules an (async) refresh.
        XCTAssertGreaterThanOrEqual(model.score, 210)

        // Resetting the round while that refresh is still pending must clear the refresh
        // sentinel, or every future board clear would be silently blocked.
        var board2 = GameRules.emptyBoard()
        board2[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        model.loadBoardForTesting(board2)
        model.swipe(row: 0, column: 0, hapticsEnabled: false)

        XCTAssertGreaterThanOrEqual(
            model.score,
            210,
            "A pending board refresh must not block a later board clear from awarding its bonus"
        )
    }

    // MARK: - Sprint 4: fair, smooth difficulty

    @MainActor
    func testFreshPathDoesNotRaiseDifficulty() {
        let fixedNow = Date(timeIntervalSinceReferenceDate: 0)

        // A legit board clear raises difficulty…
        let clearer = GameModel(makeInitialBoard: false, now: { fixedNow })
        var clearBoard = GameRules.emptyBoard()
        clearBoard[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        clearer.loadBoardForTesting(clearBoard)
        let clearerBefore = clearer.currentDifficultyLevel
        clearer.swipe(row: 0, column: 0, hapticsEnabled: false)
        XCTAssertGreaterThan(clearer.currentDifficultyLevel, clearerBefore, "A legit board clear raises difficulty")

        // …but getting stuck (a fresh-path deal) must not.
        let stuck = GameModel(makeInitialBoard: false, now: { fixedNow })
        var stuckBoard = GameRules.emptyBoard()
        stuckBoard[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        stuckBoard[3][2] = PopBlock(direction: .right, tone: .mistBlue)
        stuckBoard[3][5] = PopBlock(direction: .left, tone: .lavenderMist)
        stuck.loadBoardForTesting(stuckBoard)
        let stuckBefore = stuck.currentDifficultyLevel
        stuck.swipe(row: 0, column: 0, hapticsEnabled: false)
        XCTAssertEqual(stuck.currentDifficultyLevel, stuckBefore, "Getting stuck must not raise difficulty")
    }

    func testLevel4HasHumaneOpenFloor() {
        XCTAssertGreaterThanOrEqual(
            BoardGenerationProfile.difficulty(level: 4).minimumOpenCells,
            4,
            "The hardest boards must still leave the player real choices"
        )
    }

    @MainActor
    func testFreshPathAwardsStrandedBonus() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[3][2] = PopBlock(direction: .right, tone: .mistBlue)
        board[3][5] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        // Popping (0,0) leaves (3,2)/(3,5) blocking each other -> stuck -> fresh path.
        model.swipe(row: 0, column: 0, hapticsEnabled: false)

        // 10 (the pop) + 2 stranded blocks * 3 consolation each.
        XCTAssertEqual(model.score, 16)
        XCTAssertEqual(model.boardToast?.style, .freshPath)
    }

    @MainActor
    func testFreshPathToastDoesNotLingerWhenQueuedBehindAnotherToast() async {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Pop A (3,5) frees (3,2) -> shows an UNLOCK toast.
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[3][2] = PopBlock(direction: .right, tone: .lavenderMist)
        // Two blocks that wall each other off, so Pop B (3,2) leaves the board stuck.
        board[5][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[5][4] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        XCTAssertEqual(model.boardToast?.style, .unlock)
        let generationBeforeDeal = model.boardGeneration
        model.swipe(row: 3, column: 2, hapticsEnabled: false)
        // The fresh-path event is queued behind the still-visible unlock toast.
        XCTAssertTrue(model.queuedEventKinds.contains(.freshPath))

        // Poll until the board has actually been dealt (boardGeneration bumps), rather than
        // racing a fixed sleep against the off-main generation.
        var waited: UInt64 = 0
        while model.boardGeneration == generationBeforeDeal && waited < 2_000_000_000 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 50_000_000
        }

        // The deal retires the stale fresh-path announcement, so it never surfaces for a
        // board that has already been swapped out.
        XCTAssertGreaterThan(model.boardGeneration, generationBeforeDeal, "Board should have been dealt")
        XCTAssertFalse(model.queuedEventKinds.contains(.freshPath))
        XCTAssertNotEqual(model.boardToast?.style, .freshPath)
    }

    // MARK: - Sprint 5A: scoring economy, feedback timing, chain decay

    @MainActor
    func testLongChainPerPopScoreIsCapped() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Eight mutually-independent escapable blocks: six pointing up along the top row, two
        // pointing down along the bottom row. Popping seven builds chain 1...7 with no
        // misses, no unlocks, and no board clear (one block always remains).
        for column in 0..<6 {
            board[0][column] = PopBlock(direction: .up, tone: .mistBlue)
        }
        board[6][0] = PopBlock(direction: .down, tone: .lavenderMist)
        board[6][1] = PopBlock(direction: .down, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        for column in 0..<6 {
            model.swipe(row: 0, column: column, hapticsEnabled: false)
        }
        model.swipe(row: 6, column: 0, hapticsEnabled: false)

        XCTAssertEqual(model.chain, 7)
        // chains 1...6 = 10+20+30+40+50+60 = 210; chain 7 is capped at 6 (60) plus one
        // continuation step (4) = 64; total 274 (an uncapped run would score 280).
        XCTAssertEqual(model.score, 274)
    }

    @MainActor
    func testBoardClearBonusAddsBaseAndChainScaledReward() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 0, column: 0, hapticsEnabled: false)

        // Pop (chain 1) = 10; board emptied → clear bonus 200 + 1*22 = 222; total 232.
        // Asserted synchronously, before the async next-board deal (which adds no score).
        XCTAssertEqual(model.score, 232)
    }

    @MainActor
    func testPerPopFloatingScoreEmitted() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)

        XCTAssertEqual(model.floatingScores.count, 1)
        let marker = model.floatingScores.first
        XCTAssertEqual(marker?.amount, 10)
        XCTAssertEqual(marker?.row, 3)
        XCTAssertEqual(marker?.column, 5)
    }

    @MainActor
    func testChainDecayFractionDepletesOverWindow() {
        let fixedNow = Date(timeIntervalSinceReferenceDate: 3_000)
        let model = GameModel(makeInitialBoard: false, now: { fixedNow })
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)

        // Right after the pop the decay window is essentially full…
        XCTAssertEqual(model.chainDecayFraction(at: fixedNow), 1, accuracy: 0.001)
        // …and fully depleted once the window (well under 3s for chain 1) has elapsed.
        XCTAssertEqual(model.chainDecayFraction(at: fixedNow.addingTimeInterval(3)), 0, accuracy: 0.001)
    }

    @MainActor
    func testPauseFreezesChainDecay() {
        let fakeNow = Date(timeIntervalSinceReferenceDate: 4_000)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        XCTAssertEqual(model.chainDecayFraction(at: fakeNow), 1, accuracy: 0.001)

        model.pause()
        // While paused the indicator freezes: sampling a much later time still reads full.
        XCTAssertEqual(model.chainDecayFraction(at: fakeNow.addingTimeInterval(100)), 1, accuracy: 0.001)
        XCTAssertEqual(model.chain, 1)
    }

    // MARK: - Sprint 5B: accessibility

    func testBoardToastAnnouncementIsLocalized() {
        let toast = BoardToast(title: "BOARD CLEAR", detail: "+240", style: .clear)

        let english = toast.announcement(language: .english)
        XCTAssertTrue(english.contains("BOARD CLEAR"))
        XCTAssertTrue(english.contains("+240"))

        let korean = toast.announcement(language: .korean)
        XCTAssertTrue(korean.contains("싹쓸이!"))
        XCTAssertTrue(korean.contains("+240"))
        XCTAssertFalse(korean.contains("BOARD CLEAR"))
    }

    // MARK: - Sprint 6: tutorial truth

    func testTutorialTeachesArrowMatchAndRunway() {
        let steps = TutorialContent.steps
        XCTAssertGreaterThanOrEqual(steps.count, 3, "Tutorial should teach arrow-match, runway, and chaining")

        // Step 1 teaches the arrow-matching flick (H1).
        let first = steps[0]
        XCTAssertTrue(
            (first.titleEN + " " + first.subtitleEN).lowercased().contains("arrow"),
            "First step must teach the arrow-matching flick"
        )

        // Some step teaches the escapability runway-to-edge rule (H2).
        XCTAssertTrue(
            steps.contains { $0.subtitleEN.lowercased().contains("edge") },
            "A step must teach that a block needs a clear lane to the edge"
        )
    }

    func testResolveFlickAcceptsQuickFlickViaPredictedEnd() {
        // A short actual translation (below the strict 14pt) but a far predicted end still
        // resolves — the lenient tier the live board and the tutorial now share.
        XCTAssertEqual(
            Direction.resolveFlick(
                translation: CGSize(width: 8, height: 1),
                predictedEndTranslation: CGSize(width: 44, height: 2)
            ),
            .right
        )
        // A decisive in-threshold translation resolves on the strict tier.
        XCTAssertEqual(
            Direction.resolveFlick(
                translation: CGSize(width: 2, height: -30),
                predictedEndTranslation: CGSize(width: 2, height: -30)
            ),
            .up
        )
        // A pure tap resolves to nothing on both tiers.
        XCTAssertNil(Direction.resolveFlick(translation: .zero, predictedEndTranslation: .zero))
    }

    func testTutorialExpectedDirectionsMatchDisplayedArrows() {
        // The gesture gate requires a flick matching the highlighted cell's arrow, so each
        // step's expectedDirection must agree with the arrow it shows.
        let arrowDirection: [String: Direction] = ["▲": .up, "▼": .down, "◀": .left, "▶": .right]
        for step in TutorialContent.steps {
            XCTAssertEqual(arrowDirection[step.arrow], step.expectedDirection, "Arrow \(step.arrow) must match its taught flick")
        }
    }

    private func dayDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private func boardSignature(_ board: [[PopBlock?]]) -> [[String]] {
        board.map { row in
            row.map { block in
                guard let block else { return "empty" }
                return "\(block.direction)-\(block.tone)"
            }
        }
    }

    @MainActor
    private func waitForBoardClearRefresh(
        in model: GameModel,
        timeoutNanoseconds: UInt64 = 2_400_000_000
    ) async {
        let interval: UInt64 = 50_000_000
        var elapsed: UInt64 = 0

        while (model.score < 210 || GameRules.blockCount(in: model.board) <= 1) &&
            elapsed < timeoutNanoseconds {
            try? await Task.sleep(nanoseconds: interval)
            elapsed += interval
        }
    }
}
