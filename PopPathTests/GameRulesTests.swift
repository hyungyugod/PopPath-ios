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
        XCTAssertEqual(model.score, 17)
        XCTAssertEqual(model.boardToast?.style, .unlock)
    }

    @MainActor
    func testAbandonRoundStopsWithoutSummary() {
        let model = GameModel(makeInitialBoard: false)
        model.newRound()

        model.abandonRound()

        XCTAssertFalse(model.running)
        XCTAssertNil(model.roundSummary)
        XCTAssertEqual(model.chain, 0)
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

        XCTAssertEqual(model.dailyBest, 250)
        XCTAssertEqual(model.roundSummary?.dailyBest, 250)
        XCTAssertEqual(model.roundSummary?.mode, .daily)
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: GameModel.dailyBestStorageKey(for: challenge.id)),
            250
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
        XCTAssertEqual(model.stats.bestScore, 250)
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
