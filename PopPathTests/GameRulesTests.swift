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
        // The miss breaks the chain and shaves the small score penalty (10 − 5).
        XCTAssertEqual(model.score, 5)
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

    @MainActor
    func testPracticeRunCreditsNothing() {
        // Practice Mode (Open-Path Highlight on) is a pure sandbox: it must credit nothing in any
        // mode and a practice Daily must not consume the day's one attempt.
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[4][0] = PopBlock(direction: .left, tone: .lavenderMist)

        model.loadBoardForTesting(board, mode: .daily)
        model.setPracticeAssist(true)
        XCTAssertTrue(model.isPractice)

        let bestBefore = model.best
        let dailyBestBefore = model.dailyBest
        let roundsBefore = model.stats.roundsPlayed
        let streakBefore = model.stats.currentStreak
        let lastDailyBefore = model.stats.lastDailyCompletionDayID

        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.swipe(row: 4, column: 0, hapticsEnabled: false)
        XCTAssertGreaterThan(model.score, 0, "Practice still plays normally and shows a score")

        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        XCTAssertEqual(model.roundSummary?.isPractice, true, "Result must be flagged as practice")
        XCTAssertEqual(model.roundSummary?.isNewBest, false)
        XCTAssertEqual(model.stats.roundsPlayed, roundsBefore, "Practice must not record a round")
        XCTAssertEqual(model.best, bestBefore, "Practice must not set the best")
        XCTAssertEqual(model.dailyBest, dailyBestBefore, "Practice must not set a daily best")
        XCTAssertEqual(model.stats.currentStreak, streakBefore, "Practice Daily must not advance the streak")
        XCTAssertEqual(model.stats.lastDailyCompletionDayID, lastDailyBefore, "Practice Daily must not consume the day")
    }

    @MainActor
    func testPracticeAssistLatchesAndResetsOnNewRound() {
        let model = GameModel(makeInitialBoard: false)
        model.newRound()
        XCTAssertFalse(model.isPractice)

        // Latches one-way: turning it on sticks, turning it back off does not un-practice the run.
        model.setPracticeAssist(true)
        XCTAssertTrue(model.isPractice)
        model.setPracticeAssist(false)
        XCTAssertTrue(model.isPractice, "Practice must not be undoable mid-run")

        // A fresh round clears it.
        model.newRound()
        XCTAssertFalse(model.isPractice)
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
        XCTAssertTrue(summary.shareText.contains("Play PopPath: \(RoundSummary.shareURL)"))

        let koreanShareText = summary.shareText(language: .korean)
        XCTAssertTrue(koreanShareText.contains("점수 1,234"))
        XCTAssertTrue(koreanShareText.contains("최고 2,000"))
        XCTAssertTrue(koreanShareText.contains("정확도 92%"))
        XCTAssertTrue(koreanShareText.contains(RoundSummary.shareURL))
    }

    // MARK: - Sprint 8: localization, copy & audio polish

    func testDailyShareTextUsesFriendlyDateNotRawID() {
        let summary = RoundSummary(
            score: 500,
            best: 0,
            maxChain: 3,
            mode: .daily,
            dailyBest: 500,
            dailyId: "20260622"
        )

        let text = summary.shareText(language: .english)
        XCTAssertTrue(text.contains("Daily ·"))
        XCTAssertFalse(text.contains("20260622"), "Raw YYYYMMDD id must be replaced by a friendly date")
        XCTAssertTrue(text.contains("Daily Best 500"))
        XCTAssertTrue(text.contains(RoundSummary.shareURL))
    }

    func testDailyDisplayLabelIsLocalized() {
        let challenge = DailyChallenge.challenge(for: dayDate(2026, 6, 22), calendar: .autoupdatingCurrent)

        let english = challenge.displayLabel(language: .english)
        XCTAssertFalse(english.isEmpty)
        XCTAssertNotEqual(english, "20260622", "Label must be a friendly date, not the raw id")

        let korean = challenge.displayLabel(language: .korean)
        XCTAssertTrue(korean.contains("월"), "Korean label should use the localized date format")
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
    func testMissScorePenaltyClampsAtZero() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // (2,1) points right into the blocked (2,4): an immediate miss while the score is still 0.
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][4] = PopBlock(direction: .left, tone: .lavenderMist)
        model.loadBoardForTesting(board)

        model.swipe(row: 2, column: 1, hapticsEnabled: false)
        XCTAssertEqual(model.score, 0, "The miss penalty never drives the score negative")
    }

    @MainActor
    func testMissShowsPenaltyToastWhenPointsDeducted() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)   // pop → score 10
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)   // points right into the wall
        board[2][4] = PopBlock(direction: .left, tone: .lavenderMist)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)      // keeps the board unstuck
        model.loadBoardForTesting(board)

        model.swipe(row: 3, column: 5, hapticsEnabled: false)        // score 10, chain 1
        model.swipe(row: 2, column: 1, hapticsEnabled: false)        // miss → −5, score 5

        XCTAssertEqual(model.score, 5)
        XCTAssertEqual(model.boardToast?.style, .penalty, "A deducting miss surfaces the red penalty toast")
        XCTAssertEqual(model.boardToast?.detail, "−5")
    }

    @MainActor
    func testMissAtZeroScoreShowsNoPenaltyToast() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[2][1] = PopBlock(direction: .right, tone: .mistBlue)
        board[2][4] = PopBlock(direction: .left, tone: .lavenderMist)
        model.loadBoardForTesting(board)

        model.swipe(row: 2, column: 1, hapticsEnabled: false)        // miss at score 0
        XCTAssertEqual(model.score, 0)
        XCTAssertNil(model.boardToast, "Nothing was deducted, so there is no penalty toast")
    }

    func testGradeLadderForScore() {
        XCTAssertEqual(Grade.forScore(0).tier, 0)          // Rookie
        XCTAssertEqual(Grade.forScore(7_499).tier, 0)      // still Rookie just under the gate
        XCTAssertEqual(Grade.forScore(7_500).tier, 1)      // Bronze
        XCTAssertEqual(Grade.forScore(12_499).tier, 1)
        XCTAssertEqual(Grade.forScore(12_500).tier, 2)     // Silver
        XCTAssertEqual(Grade.forScore(52_499).tier, 9)     // Master, one below the top gate
        XCTAssertEqual(Grade.forScore(52_500).tier, 10)    // Grandmaster
        XCTAssertEqual(Grade.forScore(1_000_000).tier, 10) // never exceeds the top tier

        // Ten ranked tiers, 5,000 apart starting at 7,500.
        XCTAssertEqual(Grade.ranked.count, 10)
        XCTAssertEqual(
            Grade.ranked.map(\.threshold),
            Array(stride(from: 7_500, through: 52_500, by: 5_000))
        )

        // Progress-to-next reads off the live score; the top tier reports none.
        XCTAssertEqual(Grade.forScore(10_000).pointsToNext(from: 10_000), 2_500) // → Silver at 12.5k
        XCTAssertNil(Grade.forScore(60_000).pointsToNext(from: 60_000))
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

    func testTutorialBoardLessonsTeachOnlyLegalMovesAndOpenLanesInOrder() {
        let boardStages: [TutorialStage] = TutorialContent.pages.compactMap {
            if case let .board(stage) = $0 { return stage }
            return nil
        }
        XCTAssertGreaterThanOrEqual(boardStages.count, 3, "Tutorial should teach arrow-match, lane, and chaining interactively")

        for stage in boardStages {
            XCTAssertFalse(stage.moves.isEmpty, "Every board lesson needs at least one taught move")
            var board = stage.board
            for move in stage.moves {
                XCTAssertNotNil(board[move.row][move.column], "A taught move must point at a real block")
                // Each scripted move must be escapable at the moment it is played — the tutorial
                // never asks for a flick the real escapability rule would reject.
                XCTAssertTrue(
                    TutorialContent.isEscapable(on: board, at: move),
                    "Taught move \(move) must have a clear lane when it is reached"
                )
                board[move.row][move.column] = nil // pop it; later moves see the opened lane
            }
            let remaining = board.flatMap { $0 }.compactMap { $0 }.count
            XCTAssertEqual(remaining, 0, "The taught moves should clear the whole stage")
        }

        // A lesson must demonstrate a lane opening: a move that is BLOCKED on the initial board
        // and becomes legal only after an earlier pop clears its runway (the H2 escapability
        // lesson, now shown rather than just stated).
        let teachesLaneOpening = boardStages.contains { stage in
            stage.moves.dropFirst().contains { !TutorialContent.isEscapable(on: stage.board, at: $0) }
        }
        XCTAssertTrue(teachesLaneOpening, "A lesson must show clearing a blocker to open a trapped lane")

        // A lesson must teach chaining.
        XCTAssertTrue(boardStages.contains { $0.teachesChain }, "A lesson must teach chaining")

        // The taught copy still names the arrow-match and the lane/edge rule.
        let copy = boardStages.map { ($0.titleEN + " " + $0.subtitleEN).lowercased() }.joined(separator: " ")
        XCTAssertTrue(copy.contains("arrow"), "A lesson must teach the arrow-matching flick")
        XCTAssertTrue(copy.contains("lane") || copy.contains("edge"), "A lesson must teach the clear-lane-to-edge rule")
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

    @MainActor
    func testTutorialEnginePlaysThroughEveryLessonToCompletion() async {
        // Driving the engine with each lesson's own scripted flicks must walk it all the way to
        // the end (onComplete), proving the board lessons are completable purely by legal flicks.
        var completed = false
        let engine = TutorialEngine(reduceMotion: true, onComplete: { completed = true })

        let boardStageCount = TutorialContent.pages.filter {
            if case .board = $0 { return true }
            return false
        }.count

        for _ in 0..<boardStageCount {
            guard let stage = engine.currentStage else { break }
            for move in stage.moves {
                guard let direction = engine.cell(move.row, move.column)?.direction else {
                    return XCTFail("Expected a block at taught move \(move)")
                }
                engine.flick(at: move, direction: direction)
            }
            // Let the engine's post-stage auto-advance fire before driving the next page.
            try? await Task.sleep(nanoseconds: 600_000_000)
        }

        // The engine should now be on the heads-up page; its primary action finishes the tutorial.
        engine.performHintedMove()
        XCTAssertTrue(completed, "Playing every taught flick should finish the tutorial")
    }

    func testTutorialIntroducesSpecialBlocksAndBoards() {
        // The final page must onboard the new special blocks / boards so they aren't a surprise.
        let infoPages: [TutorialInfo] = TutorialContent.pages.compactMap {
            if case let .info(info) = $0 { return info }
            return nil
        }
        XCTAssertFalse(infoPages.isEmpty, "Tutorial should introduce the special blocks/boards")

        let titles = infoPages.flatMap { $0.items }.map { $0.titleEN.lowercased() }
        for expected in ["bomb", "armored", "wild"] {
            XCTAssertTrue(titles.contains { $0.contains(expected) }, "Tutorial must introduce the \(expected) block")
        }
    }

    func testTutorialIntroPreviewsRealBlockFaces() {
        // The intro rows must preview the ACTUAL block faces (not generic SF Symbols), so a player
        // recognizes them in-game: each special item carries a `faceKind` driving a real BlockFace.
        let items = TutorialContent.pages.compactMap { page -> TutorialInfo? in
            if case let .info(info) = page { return info }
            return nil
        }.flatMap { $0.items }

        func item(_ needle: String) -> TutorialInfoItem? {
            items.first { $0.titleEN.lowercased().contains(needle) }
        }

        XCTAssertEqual(item("bomb")?.faceKind, GuideFaceKind.block(.bomb, cracked: false))
        XCTAssertEqual(item("armored")?.faceKind, GuideFaceKind.block(.armored, cracked: false))
        XCTAssertEqual(item("wild")?.faceKind, GuideFaceKind.block(.wild, cracked: false))
        XCTAssertEqual(item("rush")?.faceKind, GuideFaceKind.modifier(.rush))
    }

    func testBlockGuideCoversEveryBlockKindAndBoardModifier() {
        // The home guide must explain every special kind and both board modifiers, each with
        // non-empty copy in both languages, so nothing the generator can produce goes unexplained.
        let faces = BlockGuideEntry.all.map { $0.face }
        XCTAssertTrue(faces.contains(.block(.normal, cracked: false)))
        XCTAssertTrue(faces.contains(.block(.bomb, cracked: false)))
        XCTAssertTrue(faces.contains(.block(.armored, cracked: false)))
        XCTAssertTrue(faces.contains(.block(.wild, cracked: false)))
        XCTAssertTrue(faces.contains(.modifier(.rush)))
        XCTAssertTrue(faces.contains(.modifier(.bonus)))

        for entry in BlockGuideEntry.all {
            XCTAssertFalse(entry.titleEN.isEmpty, "\(entry.id) needs an English name")
            XCTAssertFalse(entry.titleKO.isEmpty, "\(entry.id) needs a Korean name")
            XCTAssertFalse(entry.detailEN.isEmpty, "\(entry.id) needs an English ability line")
            XCTAssertFalse(entry.detailKO.isEmpty, "\(entry.id) needs a Korean ability line")
        }
    }

    // MARK: - Sprint 7: retention, meta & navigation

    func testPlayerStatsDecodesPartialJSONWithDefaults() {
        // Persisted stats from an earlier schema (missing the newer keys) must round-trip with
        // defaults rather than failing to decode and wiping progress.
        let json = Data(#"{"roundsPlayed":5,"bestScore":123,"unlockedAchievementIDs":["first_run"]}"#.utf8)
        let stats = try? JSONDecoder().decode(PlayerStats.self, from: json)

        XCTAssertEqual(stats?.roundsPlayed, 5)
        XCTAssertEqual(stats?.bestScore, 123)
        XCTAssertEqual(stats?.unlockedAchievementIDs, ["first_run"])
        XCTAssertEqual(stats?.currentStreak, 0)
        XCTAssertEqual(stats?.recentScores, [])
        XCTAssertNil(stats?.lastDailyCompletionDayID)
        // Migration: a save without the Classic-best key backfills from the legacy best so
        // Records and Home agree rather than showing 0.
        XCTAssertEqual(stats?.bestClassicScore, 123)
    }

    @MainActor
    func testCreditedDailyExitLocksAndAdvancesStreak() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board, mode: .daily)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.creditAndEndRun()

        // A credited mid-run Daily exit consumes the day's attempt: it locks and advances the
        // streak so the deterministic board can't be re-ground for a higher best.
        XCTAssertTrue(model.isDailyCompletedToday)
        XCTAssertEqual(model.currentStreak, 1)
    }

    @MainActor
    func testClassicAndDailyBestReportedSeparately() {
        let model = GameModel(makeInitialBoard: false)

        // A small Classic round sets the Classic best to 10.
        var classicBoard = GameRules.emptyBoard()
        classicBoard[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        classicBoard[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        classicBoard[6][0] = PopBlock(direction: .down, tone: .lavenderMist)
        model.loadBoardForTesting(classicBoard, mode: .classic)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)
        XCTAssertEqual(model.best, 10)

        // A bigger Daily round must not bleed into the Classic best (E8).
        var dailyBoard = GameRules.emptyBoard()
        dailyBoard[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        dailyBoard[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        dailyBoard[6][0] = PopBlock(direction: .down, tone: .lavenderMist)
        model.loadBoardForTesting(dailyBoard, mode: .daily)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.swipe(row: 0, column: 0, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        XCTAssertEqual(model.best, 10, "Classic best is unaffected by a Daily score")
        XCTAssertEqual(model.stats.bestClassicScore, 10)
        XCTAssertEqual(model.stats.bestDailyScore, 30)
        XCTAssertEqual(model.dailyBest, 30)
    }

    @MainActor
    func testDailyLocksAfterCompletionUntilNextDay() {
        let model = GameModel(makeInitialBoard: false)
        XCTAssertFalse(model.isDailyCompletedToday)

        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        model.loadBoardForTesting(board, mode: .daily)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        XCTAssertTrue(model.isDailyCompletedToday, "Finishing today's Daily locks further attempts until rollover")
    }

    @MainActor
    func testDailyStreakIncrementsAndResets() {
        var fakeNow = dayDate(2026, 6, 20)
        let model = GameModel(makeInitialBoard: false, now: { fakeNow })

        finishDailyRound(model)
        XCTAssertEqual(model.currentStreak, 1)

        // Next calendar day → streak continues.
        fakeNow = dayDate(2026, 6, 21)
        finishDailyRound(model)
        XCTAssertEqual(model.currentStreak, 2)

        // A multi-day gap → streak restarts at 1, longest preserved.
        fakeNow = dayDate(2026, 6, 25)
        finishDailyRound(model)
        XCTAssertEqual(model.currentStreak, 1)
        XCTAssertEqual(model.stats.longestStreak, 2)
    }

    @MainActor
    func testAchievementThresholdsAreProgressive() {
        // A tiny first round should unlock only "first_run" — not the whole catalog (E5).
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        board[6][0] = PopBlock(direction: .down, tone: .lavenderMist)

        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)

        XCTAssertEqual(model.roundSummary?.unlockedAchievements.map(\.id), ["first_run"])
    }

    @MainActor
    func testNewBestEventFiresOnceWhenCrossed() {
        let model = GameModel(makeInitialBoard: false)
        // Establish a Classic best of 10.
        var first = GameRules.emptyBoard()
        first[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        first[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        first[6][0] = PopBlock(direction: .down, tone: .lavenderMist)
        model.loadBoardForTesting(first)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)
        XCTAssertEqual(model.best, 10)

        // New run: the pop that pushes the live score past 10 surfaces a celebration toast.
        var second = GameRules.emptyBoard()
        second[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        second[0][0] = PopBlock(direction: .up, tone: .mistBlue)
        second[6][0] = PopBlock(direction: .down, tone: .lavenderMist)
        model.loadBoardForTesting(second)
        model.swipe(row: 3, column: 5, hapticsEnabled: false) // score 10, not yet over best
        XCTAssertNotEqual(model.boardToast?.style, .celebration)
        model.swipe(row: 0, column: 0, hapticsEnabled: false) // score 30, crosses best
        XCTAssertEqual(model.boardToast?.style, .celebration)
    }

    @MainActor
    func testResetClearsAllLocalData() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        model.loadBoardForTesting(board)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)
        XCTAssertGreaterThan(model.stats.roundsPlayed, 0)
        XCTAssertGreaterThan(model.best, 0)

        model.resetLocalData()

        XCTAssertEqual(model.stats, PlayerStats())
        XCTAssertEqual(model.best, 0)
        XCTAssertEqual(model.dailyBest, 0)
        XCTAssertEqual(GameModel.loadStats(), PlayerStats(), "Persisted stats are cleared too")
    }

    @MainActor
    func testChainDecayFreezesDuringPostClearDeal() {
        let fixedNow = Date(timeIntervalSinceReferenceDate: 6_000)
        let model = GameModel(makeInitialBoard: false, now: { fixedNow })
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        // This pop clears the board: the chain is kept alive for the next board and a deal is
        // scheduled. The decay must freeze across that un-actionable window rather than draining.
        model.swipe(row: 0, column: 0, hapticsEnabled: false)

        XCTAssertEqual(model.chain, 1, "Chain is kept alive across a board clear")
        // Far past the decay window: without the freeze this would read 0 (lapsed); frozen it
        // stays full because the player can't act during the deal.
        XCTAssertEqual(
            model.chainDecayFraction(at: fixedNow.addingTimeInterval(10)),
            1,
            accuracy: 0.001
        )
    }

    // MARK: - Special blocks & board modifiers

    func testWildBlockIsEscapableViaAnyClearLane() {
        var board = GameRules.emptyBoard()
        // A wild block whose own arrow (up) is blocked, but other lanes are clear.
        board[3][2] = PopBlock(direction: .up, tone: .mistBlue, kind: .wild)
        board[0][2] = PopBlock(direction: .down, tone: .mistBlue) // blocks the up lane
        XCTAssertTrue(GameRules.isEscapable(on: board, row: 3, column: 2), "Wild is open via right/left/down")

        // Now block every lane: up, down, left, right.
        board[6][2] = PopBlock(direction: .down, tone: .mistBlue)  // blocks down
        board[3][0] = PopBlock(direction: .left, tone: .mistBlue)  // blocks left
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue) // blocks right
        XCTAssertFalse(GameRules.isEscapable(on: board, row: 3, column: 2), "Fully boxed-in wild is blocked")
    }

    @MainActor
    func testWildBlockPopsInAnyOpenDirection() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Arrow points up, but we flick right (a clear lane). Wild accepts it.
        board[3][2] = PopBlock(direction: .up, tone: .mistBlue, kind: .wild)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue) // keep the board non-empty

        model.loadBoardForTesting(board)
        model.attemptPop(row: 3, column: 2, direction: .right, hapticsEnabled: false)

        XCTAssertNil(model.board[3][2], "A wild block pops on any flick with a clear lane")
        XCTAssertEqual(model.chain, 1)
        XCTAssertEqual(model.score, 10)
    }

    @MainActor
    func testBombDetonatesRowAndColumn() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Bomb points right with a clear lane (cols 3–5 empty). Row mates sit to the left;
        // column mates above/below. An off-axis block keeps the board from fully clearing.
        board[3][2] = PopBlock(direction: .right, tone: .mistBlue, kind: .bomb)
        board[3][0] = PopBlock(direction: .left, tone: .mistBlue)
        board[3][1] = PopBlock(direction: .left, tone: .mistBlue)
        board[1][2] = PopBlock(direction: .up, tone: .mistBlue)
        board[6][2] = PopBlock(direction: .down, tone: .mistBlue)
        board[0][5] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)
        model.attemptPop(row: 3, column: 2, direction: .right, hapticsEnabled: false)

        XCTAssertNil(model.board[3][2])
        for cleared in [(3, 0), (3, 1), (1, 2), (6, 2)] {
            XCTAssertNil(model.board[cleared.0][cleared.1], "Detonation clears the bomb's row and column")
        }
        XCTAssertNotNil(model.board[0][5], "Blocks off the bomb's row and column survive")
        XCTAssertEqual(model.chain, 1)
        // pop (chain 1) = 10; detonated 4 blocks * 12 = 48; total 58.
        XCTAssertEqual(model.score, 58)
    }

    @MainActor
    func testArmoredBlockNeedsTwoFlicks() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue, kind: .armored, armor: 1)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board)

        // First valid flick only cracks it — no pop, no chain, no score, not a miss.
        model.attemptPop(row: 3, column: 5, direction: .right, hapticsEnabled: false)
        XCTAssertNotNil(model.board[3][5])
        XCTAssertEqual(model.board[3][5]?.armor, 0)
        XCTAssertEqual(model.chain, 0)
        XCTAssertEqual(model.score, 0)

        // Second valid flick pops it normally.
        model.attemptPop(row: 3, column: 5, direction: .right, hapticsEnabled: false)
        XCTAssertNil(model.board[3][5])
        XCTAssertEqual(model.chain, 1)
        XCTAssertEqual(model.score, 10)
    }

    func testGeneratedDifficultyBoardsRemainClearableWithSpecials() {
        for level in 1...4 {
            let profile = BoardGenerationProfile.difficulty(level: level)
            XCTAssertGreaterThan(profile.maxSpecialBlocks, 0, "Levels 1+ should spawn specials")
            for seed in UInt64(1)...UInt64(16) {
                var random = SeededRandomNumberGenerator(seed: seed &* UInt64(level + 1) &+ 7)
                let board = GameRules.generatedBoard(using: &random, profile: profile)
                XCTAssertTrue(
                    GameRules.isClearable(board),
                    "Level \(level), seed \(seed): a board with specials must stay clearable"
                )
                XCTAssertTrue(GameRules.hasPlayableMove(in: board))
            }
        }
    }

    func testWildSpecialsArePlacedOnlyOnAlreadyOpenCells() {
        // Specials must be openness-neutral so they can't push a board past its difficulty
        // profile's open-cell ceiling. Turning every wild back into a plain arrow block must not
        // change how many cells are open — which only holds if wilds were placed solely on cells
        // already open as normal blocks.
        for level in 1...4 {
            let profile = BoardGenerationProfile.difficulty(level: level)
            for seed in UInt64(1)...UInt64(24) {
                var random = SeededRandomNumberGenerator(seed: seed &* 131 &+ UInt64(level))
                let board = GameRules.generatedBoard(using: &random, profile: profile)
                var demoted = board
                for row in 0..<GameRules.rows {
                    for column in 0..<GameRules.columns where demoted[row][column]?.kind == .wild {
                        demoted[row][column]?.kind = .normal
                    }
                }
                XCTAssertEqual(
                    GameRules.openPositions(in: board).count,
                    GameRules.openPositions(in: demoted).count,
                    "Level \(level), seed \(seed): wild specials must not add open cells"
                )
            }
        }
    }

    @MainActor
    func testBombPopDoesNotDoublePayUnlockBonus() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        // Bomb points right with a clear lane. Its detonation clears (3,1) and (5,3); removing
        // (5,3) frees (5,5)'s left lane. Without the fix that freed cell would also pay an
        // unlock bonus on top of the detonation points.
        board[3][3] = PopBlock(direction: .right, tone: .mistBlue, kind: .bomb)
        board[3][1] = PopBlock(direction: .left, tone: .mistBlue)
        board[5][3] = PopBlock(direction: .down, tone: .mistBlue)
        board[5][5] = PopBlock(direction: .left, tone: .mistBlue) // blocked by (5,3) until the blast

        model.loadBoardForTesting(board)
        XCTAssertFalse(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 5, column: 5)))

        model.attemptPop(row: 3, column: 3, direction: .right, hapticsEnabled: false)

        XCTAssertNil(model.board[3][3])
        XCTAssertNil(model.board[3][1])
        XCTAssertNil(model.board[5][3])
        XCTAssertNotNil(model.board[5][5])
        XCTAssertTrue(GameRules.openPositions(in: model.board).contains(BoardPosition(row: 5, column: 5)), "The blast freed (5,5)")
        // pop 10 + detonated 2 * 12 = 34. No unlock bonus for the blast-freed cell.
        XCTAssertEqual(model.score, 34)
        // The bomb's own "BOOM" toast surfaces (no longer coalesced away by an unlock toast).
        XCTAssertEqual(model.boardToast?.title, "BOOM")
    }

    @MainActor
    func testRushModifierDoublesPopScore() {
        let model = GameModel(makeInitialBoard: false)
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board, modifier: .rush)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)

        XCTAssertEqual(model.score, 20, "Rush doubles per-pop score (10 → 20)")
    }

    @MainActor
    func testBonusModifierTriplesClearBonusAndAddsTime() {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let model = GameModel(makeInitialBoard: false, now: { fixedNow })
        var board = GameRules.emptyBoard()
        board[0][0] = PopBlock(direction: .up, tone: .mistBlue)

        model.loadBoardForTesting(board, modifier: .bonus)
        let timeBefore = model.time
        model.swipe(row: 0, column: 0, hapticsEnabled: false) // clears the board

        // pop 10; clear base = 200 + chain1*22 = 222; ×3 (bonus) = 666; total 676.
        XCTAssertEqual(model.score, 676)
        XCTAssertEqual(model.time, timeBefore + 5, "A Bonus board hands back time on clear")
    }

    @MainActor
    private func finishDailyRound(_ model: GameModel) {
        var board = GameRules.emptyBoard()
        board[3][5] = PopBlock(direction: .right, tone: .mistBlue)
        model.loadBoardForTesting(board, mode: .daily)
        model.swipe(row: 3, column: 5, hapticsEnabled: false)
        model.finishRound(hapticsEnabled: false, soundEnabled: false)
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
