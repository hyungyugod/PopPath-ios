import Foundation

struct RoundMetrics: Codable, Equatable {
    static let zero = RoundMetrics()

    var pops = 0
    var misses = 0
    var unlocks = 0
    var bestUnlockBurst = 0
    var boardClears = 0
    var freshPaths = 0
    var difficultyPeak = 0

    var attempts: Int {
        pops + misses
    }

    var accuracyPercent: Int {
        guard attempts > 0 else { return 0 }
        return Int((Double(pops) / Double(attempts) * 100).rounded())
    }
}

struct PlayerStats: Codable, Equatable {
    var roundsPlayed = 0
    var classicRounds = 0
    var dailyRounds = 0
    var totalScore = 0
    var totalPops = 0
    var totalMisses = 0
    var totalUnlocks = 0
    var totalBoardClears = 0
    var bestScore = 0
    var bestDailyScore = 0
    var bestChain = 0
    var bestAccuracy = 0
    var mostUnlocksInRound = 0
    var mostBoardClearsInRound = 0
    var unlockedAchievementIDs: [String] = []

    var averageScore: Int {
        guard roundsPlayed > 0 else { return 0 }
        return Int((Double(totalScore) / Double(roundsPlayed)).rounded())
    }

    var lifetimeAccuracyPercent: Int {
        let attempts = totalPops + totalMisses
        guard attempts > 0 else { return 0 }
        return Int((Double(totalPops) / Double(attempts) * 100).rounded())
    }

    func isAchievementUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievementIDs.contains(achievement.id)
    }

    mutating func unlockAchievement(_ id: String) {
        guard !unlockedAchievementIDs.contains(id) else { return }
        unlockedAchievementIDs.append(id)
    }

    mutating func recordRound(
        score: Int,
        mode: GameMode,
        maxChain: Int,
        metrics: RoundMetrics
    ) {
        roundsPlayed += 1
        switch mode {
        case .classic:
            classicRounds += 1
        case .daily:
            dailyRounds += 1
            bestDailyScore = max(bestDailyScore, score)
        }

        totalScore += score
        totalPops += metrics.pops
        totalMisses += metrics.misses
        totalUnlocks += metrics.unlocks
        totalBoardClears += metrics.boardClears
        bestScore = max(bestScore, score)
        bestChain = max(bestChain, maxChain)
        bestAccuracy = max(bestAccuracy, metrics.accuracyPercent)
        mostUnlocksInRound = max(mostUnlocksInRound, metrics.unlocks)
        mostBoardClearsInRound = max(mostBoardClearsInRound, metrics.boardClears)
    }
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first_run", title: "First Pop", subtitle: "Finish a round", systemImage: "flag.fill"),
        Achievement(id: "score_500", title: "Warmed Up", subtitle: "Score 500+", systemImage: "flame.fill"),
        Achievement(id: "score_1000", title: "Path Master", subtitle: "Score 1,000+", systemImage: "star.fill"),
        Achievement(id: "chain_5", title: "Clean Chain", subtitle: "Reach chain x5", systemImage: "link"),
        Achievement(id: "chain_10", title: "Flow State", subtitle: "Reach chain x10", systemImage: "sparkles"),
        Achievement(id: "clean_run", title: "No Misses", subtitle: "Finish with no misses", systemImage: "checkmark.seal.fill"),
        Achievement(id: "unlock_5", title: "Key Finder", subtitle: "Open 5 paths in one round", systemImage: "key.fill"),
        Achievement(id: "path_burst", title: "Path Burst", subtitle: "Open 3 paths with one pop", systemImage: "bolt.fill"),
        Achievement(id: "clear_2", title: "Board Sweeper", subtitle: "Clear 2 boards in one round", systemImage: "rectangle.grid.2x2.fill"),
        Achievement(id: "daily_first", title: "Daily Ritual", subtitle: "Finish a Daily Challenge", systemImage: "calendar"),
        Achievement(id: "ten_rounds", title: "Ten Runs", subtitle: "Finish 10 rounds", systemImage: "10.circle.fill"),
        Achievement(id: "hundred_pops", title: "Hundred Pops", subtitle: "Pop 100 blocks", systemImage: "circle.grid.cross.fill")
    ]

    static func newlyUnlocked(
        score: Int,
        maxChain: Int,
        metrics: RoundMetrics,
        mode: GameMode,
        previousStats: PlayerStats,
        updatedStats: PlayerStats
    ) -> [Achievement] {
        let qualifyingIDs = Set([
            updatedStats.roundsPlayed >= 1 ? "first_run" : nil,
            score >= 500 ? "score_500" : nil,
            score >= 1_000 ? "score_1000" : nil,
            maxChain >= 5 ? "chain_5" : nil,
            maxChain >= 10 ? "chain_10" : nil,
            metrics.misses == 0 && metrics.pops >= 12 ? "clean_run" : nil,
            metrics.unlocks >= 5 ? "unlock_5" : nil,
            metrics.bestUnlockBurst >= 3 ? "path_burst" : nil,
            metrics.boardClears >= 2 ? "clear_2" : nil,
            mode == .daily ? "daily_first" : nil,
            updatedStats.roundsPlayed >= 10 ? "ten_rounds" : nil,
            updatedStats.totalPops >= 100 ? "hundred_pops" : nil
        ].compactMap { $0 })

        return all.filter { achievement in
            qualifyingIDs.contains(achievement.id) &&
                !previousStats.unlockedAchievementIDs.contains(achievement.id)
        }
    }
}

struct RoundSummary: Identifiable, Equatable {
    let id = UUID()
    let score: Int
    let best: Int
    let maxChain: Int
    let mode: GameMode
    let dailyBest: Int?
    let dailyId: String?
    let metrics: RoundMetrics
    let isNewBest: Bool
    let isNewDailyBest: Bool
    let unlockedAchievements: [Achievement]
    let lifetimeStats: PlayerStats

    init(
        score: Int,
        best: Int,
        maxChain: Int,
        mode: GameMode = .classic,
        dailyBest: Int? = nil,
        dailyId: String? = nil,
        metrics: RoundMetrics = .zero,
        isNewBest: Bool = false,
        isNewDailyBest: Bool = false,
        unlockedAchievements: [Achievement] = [],
        lifetimeStats: PlayerStats = PlayerStats()
    ) {
        self.score = score
        self.best = best
        self.maxChain = maxChain
        self.mode = mode
        self.dailyBest = dailyBest
        self.dailyId = dailyId
        self.metrics = metrics
        self.isNewBest = isNewBest
        self.isNewDailyBest = isNewDailyBest
        self.unlockedAchievements = unlockedAchievements
        self.lifetimeStats = lifetimeStats
    }

    var shareText: String {
        shareText(language: .english)
    }

    func shareText(language: AppLanguage) -> String {
        let modeLabel = mode == .daily ? "Daily \(dailyId ?? "")" : "Classic"
        let bestLabel = mode == .daily ? "Daily Best" : "Best"
        let bestValue = mode == .daily ? (dailyBest ?? score) : best

        if language == .korean {
            let koreanModeLabel = mode == .daily ? "오늘의 길 \(dailyId ?? "")" : "클래식"
            let koreanBestLabel = mode == .daily ? "오늘 최고" : "최고"

            return """
            PopPath \(koreanModeLabel)
            점수 \(score.formatted()) | \(koreanBestLabel) \(bestValue.formatted())
            체인 x\(maxChain) | 길 열림 \(metrics.unlocks) | 싹쓸이 \(metrics.boardClears) | 정확도 \(metrics.accuracyPercent)%
            """
        }

        return """
        PopPath \(modeLabel)
        Score \(score.formatted()) | \(bestLabel) \(bestValue.formatted())
        Chain x\(maxChain) | Unlocks \(metrics.unlocks) | Clears \(metrics.boardClears) | Accuracy \(metrics.accuracyPercent)%
        """
    }
}

struct BoardToast: Identifiable, Equatable {
    enum Style: Equatable {
        case chain
        case unlock
        case freshPath
        case clear
    }

    let id = UUID()
    let title: String
    let detail: String
    let style: Style
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var board: [[PopBlock?]]
    @Published private(set) var score = 0
    @Published private(set) var chain = 0
    @Published private(set) var maxChain = 0
    @Published private(set) var time = GameRules.roundSeconds
    @Published private(set) var running = false
    @Published private(set) var best: Int
    @Published private(set) var dailyBest: Int
    @Published private(set) var mode: GameMode = .classic
    @Published private(set) var dailyChallenge: DailyChallenge
    @Published private(set) var boardToast: BoardToast?
    @Published private(set) var stats: PlayerStats
    @Published private(set) var escapingBlocks: [EscapingBlock] = []
    @Published var roundSummary: RoundSummary?

    nonisolated static let bestScoreStorageKey = "bestScore"
    nonisolated static let playerStatsStorageKey = "playerStats.v1"
    nonisolated static let recentBoardSignaturesStorageKey = "recentClassicBoardSignatures.v1"

    private var timerTask: Task<Void, Never>?
    private var chainResetTask: Task<Void, Never>?
    private var boardRefreshTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var feedbackHapticsEnabled = true
    private var feedbackSoundEnabled = true
    private var boardDealIndex = 0
    private var recentBoardSignatures: [String] = []
    private var roundMetrics = RoundMetrics.zero

    var openPositions: Set<BoardPosition> {
        GameRules.openPositions(in: board)
    }

    init(makeInitialBoard: Bool = true) {
        let challenge = DailyChallenge.today()
        let loadedStats = Self.loadStats()
        self.dailyChallenge = challenge
        self.stats = loadedStats
        self.recentBoardSignatures = Self.loadRecentBoardSignatures()
        self.board = makeInitialBoard ? GameRules.generatedBoard() : GameRules.emptyBoard()

        let storedBest = UserDefaults.standard.object(forKey: Self.bestScoreStorageKey) as? Int
        self.best = max(storedBest ?? 0, loadedStats.bestScore)

        let storedDailyBest = UserDefaults.standard.object(
            forKey: Self.dailyBestStorageKey(for: challenge.id)
        ) as? Int
        self.dailyBest = storedDailyBest ?? 0
    }

    deinit {
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        toastTask?.cancel()
    }

    nonisolated static func dailyBestStorageKey(for id: String) -> String {
        "dailyBest.\(id)"
    }

    nonisolated static func loadStats() -> PlayerStats {
        guard let data = UserDefaults.standard.data(forKey: Self.playerStatsStorageKey),
              let stats = try? JSONDecoder().decode(PlayerStats.self, from: data)
        else {
            return PlayerStats()
        }

        return stats
    }

    nonisolated static func saveStats(_ stats: PlayerStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: Self.playerStatsStorageKey)
    }

    nonisolated static func loadRecentBoardSignatures() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.recentBoardSignaturesStorageKey) ?? []
    }

    func newRound(mode: GameMode = .classic) {
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        toastTask?.cancel()

        self.mode = mode
        if mode == .daily {
            refreshDailyChallenge()
        }
        boardDealIndex = 0
        score = 0
        chain = 0
        maxChain = 0
        roundMetrics = .zero
        escapingBlocks = []
        board = makeBoard(for: mode)
        time = GameRules.roundSeconds
        running = true
        boardToast = nil
        roundSummary = nil

        startTimer()
    }

    func newBoard() {
        newRound(mode: mode)
    }

    func abandonRound() {
        running = false
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        toastTask?.cancel()
        chain = 0
        boardToast = nil
        escapingBlocks = []
        roundSummary = nil
    }

    func configureFeedback(soundEnabled: Bool, hapticsEnabled: Bool) {
        feedbackSoundEnabled = soundEnabled
        feedbackHapticsEnabled = hapticsEnabled
        Haptics.prepare(enabled: hapticsEnabled)
        SoundEffects.shared.prepare(enabled: soundEnabled)
    }

    func tap(row: Int, column: Int, hapticsEnabled: Bool, soundEnabled: Bool = false) {
        guard running,
              GameRules.isInside(row: row, column: column),
              var block = board[row][column],
              !block.isLeaving
        else {
            return
        }

        if GameRules.isEscapable(on: board, row: row, column: column) {
            let openBeforeRemoval = GameRules.openPositions(in: board)
            let blockID = block.id
            let escapingBlock = EscapingBlock(id: blockID, block: block, row: row, column: column)
            escapingBlocks.append(escapingBlock)
            updateCell(row: row, column: column, with: nil)

            roundMetrics.pops += 1
            chain += 1
            score += 10 * chain
            maxChain = max(maxChain, chain)
            let feedbackEvent = feedbackEvent(for: chain)
            Haptics.play(feedbackEvent, enabled: hapticsEnabled)
            SoundEffects.shared.play(feedbackEvent, enabled: soundEnabled)
            showChainToastIfNeeded()
            scheduleChainReset()
            awardUnlockBonusIfNeeded(openBeforeRemoval: openBeforeRemoval)
            resolveBoardAfterRemoval()

            Task { [weak self] in
                let lifetime = UInt64((escapingBlock.duration + 0.035) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: lifetime)
                self?.removeEscapingBlock(id: blockID)
            }
        } else {
            chainResetTask?.cancel()
            chain = 0
            roundMetrics.misses += 1

            block.isMiss = true
            updateCell(row: row, column: column, with: block)
            Haptics.play(.miss, enabled: hapticsEnabled)
            SoundEffects.shared.play(.miss, enabled: soundEnabled)

            let blockID = block.id
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                self?.clearMiss(id: blockID, row: row, column: column)
            }
        }
    }

    func finishRound(hapticsEnabled: Bool? = nil, soundEnabled: Bool? = nil) {
        guard running else { return }

        running = false
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        toastTask?.cancel()
        escapingBlocks = []

        let completedMetrics = roundMetrics
        let previousStats = stats
        let isNewBest = score > best
        let isNewDailyBest = mode == .daily && score > dailyBest

        if score > best {
            best = score
            UserDefaults.standard.set(score, forKey: Self.bestScoreStorageKey)
        }

        let summaryDailyBest = updateDailyBestIfNeeded()
        var updatedStats = stats
        updatedStats.recordRound(
            score: score,
            mode: mode,
            maxChain: maxChain,
            metrics: completedMetrics
        )
        let unlockedAchievements = AchievementCatalog.newlyUnlocked(
            score: score,
            maxChain: maxChain,
            metrics: completedMetrics,
            mode: mode,
            previousStats: previousStats,
            updatedStats: updatedStats
        )
        for achievement in unlockedAchievements {
            updatedStats.unlockAchievement(achievement.id)
        }
        stats = updatedStats
        Self.saveStats(updatedStats)

        Haptics.play(.finish, enabled: hapticsEnabled ?? feedbackHapticsEnabled)
        SoundEffects.shared.play(.finish, enabled: soundEnabled ?? feedbackSoundEnabled)
        roundSummary = RoundSummary(
            score: score,
            best: best,
            maxChain: maxChain,
            mode: mode,
            dailyBest: summaryDailyBest,
            dailyId: mode == .daily ? dailyChallenge.id : nil,
            metrics: completedMetrics,
            isNewBest: isNewBest,
            isNewDailyBest: isNewDailyBest,
            unlockedAchievements: unlockedAchievements,
            lifetimeStats: updatedStats
        )
    }

    #if DEBUG
    func loadBoardForTesting(
        _ board: [[PopBlock?]],
        running: Bool = true,
        mode: GameMode = .classic
    ) {
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        toastTask?.cancel()

        self.mode = mode
        if mode == .daily {
            refreshDailyChallenge()
        }
        self.board = board
        self.score = 0
        self.chain = 0
        self.maxChain = 0
        self.time = GameRules.roundSeconds
        self.running = running
        self.boardDealIndex = 0
        self.roundMetrics = .zero
        self.boardToast = nil
        self.escapingBlocks = []
        self.roundSummary = nil
    }
    #endif

    private func startTimer() {
        timerTask?.cancel()

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard running else { return }

        if time > 0 {
            time -= 1
        }

        if time <= 0 {
            finishRound()
        }
    }

    private func scheduleChainReset() {
        chainResetTask?.cancel()
        chainResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            self?.resetChain()
        }
    }

    private func resetChain() {
        guard running else { return }
        chain = 0
    }

    private func removeBlock(id: UUID, row: Int, column: Int) {
        guard board[row][column]?.id == id else { return }
        let openBeforeRemoval = GameRules.openPositions(in: board)
        updateCell(row: row, column: column, with: nil)
        awardUnlockBonusIfNeeded(openBeforeRemoval: openBeforeRemoval)
        resolveBoardAfterRemoval()
    }

    private func removeEscapingBlock(id: UUID) {
        escapingBlocks.removeAll { $0.id == id }
    }

    private func clearMiss(id: UUID, row: Int, column: Int) {
        guard var block = board[row][column],
              block.id == id
        else {
            return
        }

        block.isMiss = false
        updateCell(row: row, column: column, with: block)
    }

    private func updateCell(row: Int, column: Int, with block: PopBlock?) {
        var nextBoard = board
        nextBoard[row][column] = block
        board = nextBoard
    }

    private func makeBoard(for mode: GameMode) -> [[PopBlock?]] {
        let level = currentDifficultyLevel
        let profile = BoardGenerationProfile.difficulty(level: level)
        roundMetrics.difficultyPeak = max(roundMetrics.difficultyPeak, level)

        switch mode {
        case .classic:
            return makeClassicBoard(profile: profile)
        case .daily:
            var random = SeededRandomNumberGenerator(seed: seedForDailyDeal())
            return GameRules.generatedBoard(using: &random, profile: profile)
        }
    }

    private var currentDifficultyLevel: Int {
        min(4, max(0, boardDealIndex + score / 500))
    }

    private func makeClassicBoard(profile: BoardGenerationProfile) -> [[PopBlock?]] {
        let recentSignatures = Set(recentBoardSignatures)
        var fallback = GameRules.generatedBoard(profile: profile)

        for attempt in 0..<24 {
            let candidate = attempt == 0 ? fallback : GameRules.generatedBoard(profile: profile)
            let signature = GameRules.boardSignature(candidate)
            if !recentSignatures.contains(signature) {
                rememberClassicBoard(candidate)
                return candidate
            }
            fallback = candidate
        }

        rememberClassicBoard(fallback)
        return fallback
    }

    private func rememberClassicBoard(_ board: [[PopBlock?]]) {
        let signature = GameRules.boardSignature(board)
        recentBoardSignatures.removeAll { $0 == signature }
        recentBoardSignatures.insert(signature, at: 0)
        recentBoardSignatures = Array(recentBoardSignatures.prefix(50))
        UserDefaults.standard.set(recentBoardSignatures, forKey: Self.recentBoardSignaturesStorageKey)
    }

    private func seedForDailyDeal() -> UInt64 {
        dailyChallenge.seed ^ (UInt64(boardDealIndex) &* 0x9E37_79B9_7F4A_7C15)
    }

    private func resolveBoardAfterRemoval() {
        guard running, boardRefreshTask == nil else { return }

        let remainingBlocks = GameRules.blockCount(in: board)
        if remainingBlocks == 0 {
            awardBoardClearBonus()
            scheduleBoardRefresh(reason: .clear)
        } else if !GameRules.hasPlayableMove(in: board) {
            roundMetrics.freshPaths += 1
            Haptics.play(.freshPath, enabled: feedbackHapticsEnabled)
            SoundEffects.shared.play(.freshPath, enabled: feedbackSoundEnabled)
            showToast(BoardToast(title: "FRESH PATH", detail: "NO MOVES", style: .freshPath), duration: 850_000_000)
            scheduleBoardRefresh(reason: .freshPath)
        }
    }

    private func awardBoardClearBonus() {
        roundMetrics.boardClears += 1
        let bonus = 180 + min(max(chain, 1), 10) * 20
        score += bonus
        Haptics.play(.boardClear, enabled: feedbackHapticsEnabled)
        SoundEffects.shared.play(.boardClear, enabled: feedbackSoundEnabled)
        showToast(BoardToast(title: "BOARD CLEAR", detail: "+\(bonus)", style: .clear), duration: 950_000_000)
    }

    private func awardUnlockBonusIfNeeded(openBeforeRemoval: Set<BoardPosition>) {
        guard running else { return }

        let newlyOpened = GameRules.openPositions(in: board).subtracting(openBeforeRemoval).count
        guard newlyOpened > 0 else { return }

        roundMetrics.unlocks += newlyOpened
        roundMetrics.bestUnlockBurst = max(roundMetrics.bestUnlockBurst, newlyOpened)

        let bonus = newlyOpened * 7 * max(chain, 1)
        score += bonus
        let feedbackEvent: Haptics.Event = newlyOpened >= 3 ? .bigChain : .unlock
        Haptics.play(feedbackEvent, enabled: feedbackHapticsEnabled)
        SoundEffects.shared.play(feedbackEvent, enabled: feedbackSoundEnabled)
        showToast(
            BoardToast(title: unlockTitle(for: newlyOpened), detail: "+\(bonus)", style: .unlock),
            duration: newlyOpened >= 3 ? 820_000_000 : 620_000_000
        )
    }

    private func unlockTitle(for newlyOpened: Int) -> String {
        if newlyOpened >= 3 {
            return "PATH BURST"
        }
        if newlyOpened == 2 {
            return "DOUBLE UNLOCK"
        }
        return "UNLOCK"
    }

    private enum BoardRefreshReason: Equatable {
        case clear
        case freshPath
    }

    private func scheduleBoardRefresh(reason: BoardRefreshReason) {
        boardRefreshTask?.cancel()
        boardRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: reason == .clear ? 260_000_000 : 220_000_000)
            if Task.isCancelled { return }
            self?.dealNextBoard()
        }
    }

    private func dealNextBoard() {
        guard running else { return }

        boardDealIndex += 1
        escapingBlocks = []
        board = makeBoard(for: mode)
        boardRefreshTask = nil
    }

    private func feedbackEvent(for chain: Int) -> Haptics.Event {
        if chain >= 5 {
            return .bigChain
        }
        if chain >= 2 {
            return .chain
        }
        return .escape
    }

    private func showChainToastIfNeeded() {
        guard chain >= 3 else { return }

        let title: String
        if chain >= 7 {
            title = "MEGA CHAIN"
        } else if chain >= 5 {
            title = "BIG CHAIN"
        } else {
            title = "CHAIN"
        }
        showToast(
            BoardToast(title: title, detail: "×\(chain)", style: .chain),
            duration: chain >= 7 ? 820_000_000 : chain >= 5 ? 720_000_000 : 560_000_000
        )
    }

    private func showToast(_ toast: BoardToast, duration: UInt64) {
        boardToast = toast
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            if Task.isCancelled { return }
            guard self?.boardToast?.id == toast.id else { return }
            self?.boardToast = nil
        }
    }

    private func refreshDailyChallenge() {
        let challenge = DailyChallenge.today()
        dailyChallenge = challenge

        let storedDailyBest = UserDefaults.standard.object(
            forKey: Self.dailyBestStorageKey(for: challenge.id)
        ) as? Int
        dailyBest = storedDailyBest ?? 0
    }

    private func updateDailyBestIfNeeded() -> Int? {
        guard mode == .daily else {
            return nil
        }

        if score > dailyBest {
            dailyBest = score
            UserDefaults.standard.set(score, forKey: Self.dailyBestStorageKey(for: dailyChallenge.id))
        }

        return dailyBest
    }
}
