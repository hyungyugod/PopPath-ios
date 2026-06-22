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
        Achievement(id: "first_run", title: "First Swipe", subtitle: "Finish a round", systemImage: "flag.fill"),
        Achievement(id: "score_500", title: "Warmed Up", subtitle: "Score 500+", systemImage: "flame.fill"),
        Achievement(id: "score_1000", title: "Path Master", subtitle: "Score 1,000+", systemImage: "star.fill"),
        Achievement(id: "chain_5", title: "Clean Chain", subtitle: "Reach chain x5", systemImage: "link"),
        Achievement(id: "chain_10", title: "Flow State", subtitle: "Reach chain x10", systemImage: "sparkles"),
        Achievement(id: "clean_run", title: "No Misses", subtitle: "Finish with no misses", systemImage: "checkmark.seal.fill"),
        Achievement(id: "unlock_5", title: "Key Finder", subtitle: "Open 5 paths in one round", systemImage: "key.fill"),
        Achievement(id: "path_burst", title: "Path Burst", subtitle: "Open 3 paths with one swipe", systemImage: "bolt.fill"),
        Achievement(id: "clear_2", title: "Board Sweeper", subtitle: "Clear 2 boards in one round", systemImage: "rectangle.grid.2x2.fill"),
        Achievement(id: "daily_first", title: "Daily Ritual", subtitle: "Finish a Daily Challenge", systemImage: "calendar"),
        Achievement(id: "ten_rounds", title: "Ten Runs", subtitle: "Finish 10 rounds", systemImage: "10.circle.fill"),
        Achievement(id: "hundred_pops", title: "Hundred Swipes", subtitle: "Swipe 100 blocks", systemImage: "circle.grid.cross.fill")
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

/// A single reward/announcement produced by the board. Drained by one ordered queue so
/// concurrent rewards (chain + unlock + clear from one pop) all surface in priority order
/// instead of clobbering a single slot. `announce` carries the VoiceOver string consumed in
/// a later sprint; nothing reads it yet.
struct BoardEvent: Identifiable, Equatable {
    enum Kind: Int, Comparable {
        case chain
        case freshPath
        case unlock
        case clear

        static func < (lhs: Kind, rhs: Kind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let style: BoardToast.Style
    var announce: String?
    let duration: UInt64
}

/// A per-pop floating "+N" that rises from the cell that was cleared, so the score earned by
/// each individual pop is legible at the point of action (E4). Carried in its own short-lived
/// list rather than the central toast queue, because it is positional, not an announcement.
struct FloatingScore: Identifiable, Equatable {
    let id = UUID()
    let row: Int
    let column: Int
    let amount: Int
    let chain: Int
}

/// Explicit round lifecycle. `running` (the actively-ticking state) is kept as a computed
/// mirror for existing call sites and tests.
enum RunState: Equatable {
    case idle
    case running
    case paused
    case finished
}

@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var board: [[PopBlock?]] {
        didSet { openPositions = GameRules.openPositions(in: board) }
    }
    /// Cached escapable positions. Recomputing this is O(rows·cols·max(rows,cols)),
    /// so we update it only when `board` changes instead of on every SwiftUI body
    /// pass (the per-second timer tick and every score/chain change re-render the view).
    private(set) var openPositions: Set<BoardPosition> = []
    @Published private(set) var score = 0
    @Published private(set) var chain = 0
    @Published private(set) var maxChain = 0
    @Published private(set) var time = GameRules.roundSeconds
    @Published private(set) var runState: RunState = .idle
    /// Actively ticking. Kept as a computed mirror of `runState`.
    var running: Bool { runState == .running }
    /// A round is in progress (running or explicitly paused).
    var isRoundActive: Bool { runState == .running || runState == .paused }
    @Published private(set) var best: Int
    @Published private(set) var dailyBest: Int
    @Published private(set) var mode: GameMode = .classic
    @Published private(set) var dailyChallenge: DailyChallenge
    /// The toast currently on screen — the head of the ordered event queue. Kept as the
    /// published mirror that `GameView` renders and tests inspect.
    @Published private(set) var boardToast: BoardToast?
    /// True while a board is being (re)dealt. Gates input so a stray flick during the
    /// async deal window can never pop into a half-replaced board.
    @Published private(set) var isDealing = false
    /// Bumps on every board swap (deal / reshuffle / new round) so the view can cross-fade
    /// the board container.
    @Published private(set) var boardGeneration = 0
    @Published private(set) var stats: PlayerStats
    @Published private(set) var escapingBlocks: [EscapingBlock] = []
    /// Short-lived per-pop "+N" markers (E4). The view animates each rising/fading at its
    /// cell; the model just owns the data and retires each after a fixed lifetime.
    @Published private(set) var floatingScores: [FloatingScore] = []
    /// Deadline at which the current chain decays to 0, published so the CHAIN HUD tile can
    /// draw a depleting indicator (E3/WI-5.3). `nil` when no chain is active. Frozen on pause
    /// (see `pausedChainDecayRemaining`). Updated only on pops — never per frame.
    @Published private(set) var chainDecayDeadline: Date?
    @Published var roundSummary: RoundSummary?

    /// Seconds remaining at which the TIME tile starts its low-time urgency cue (WI-5.4).
    /// Shared so the view's visual pulse and the model's tick haptic agree on the threshold.
    nonisolated static let lowTimeUrgencySeconds = 5

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
    private var pendingEvents: [BoardEvent] = []
    private var roundClock: RoundClock?
    private var pendingRefreshReason: BoardRefreshReason?
    private var lastMissFeedbackAt: Date?
    /// Full window (seconds) of the current chain's decay, used as the indicator's denominator.
    private var chainDecayDuration: TimeInterval = 0
    /// Remaining chain-decay seconds captured at pause, so the indicator freezes and resume
    /// restores exactly what was left instead of granting a fresh full window.
    private var pausedChainDecayRemaining: TimeInterval?
    private let now: () -> Date
    /// Seconds a miss shaves off the round deadline (E2).
    private let missTimePenalty: TimeInterval = 2
    /// Consolation points per block stranded when the board gets stuck (D6).
    private let strandedBlockReward = 3

    // MARK: Scoring economy (WI-5.1)
    /// Base points for a single pop, multiplied by the (capped) chain length.
    private let popBaseScore = 10
    /// Per-pop chain multiplier cap (E1): beyond this a chain keeps the chain mechanics alive
    /// but stops the per-pop term running away and dwarfing clear/unlock bonuses.
    private let perPopChainCap = 6
    /// Small flat reward for each pop sustained past the cap, so long chains still feel good.
    private let perPopContinuationStep = 4
    /// Board-clear bonus base, plus a chain-scaled term whose cap is lifted above 10 (E6).
    private let boardClearBaseBonus = 200
    private let boardClearChainCap = 15
    private let boardClearChainStep = 22
    /// Unlock bonus per newly opened path, scaled by chain — retuned up relative to the now
    /// capped per-pop term so opening paths is a headline reward (E1/E6).
    private let unlockBaseBonus = 14
    /// Lifetime of a per-pop floating "+N" marker before it is retired.
    private let floatingScoreLifetime: TimeInterval = 0.7

    init(makeInitialBoard: Bool = true, now: @escaping () -> Date = { Date() }) {
        self.now = now
        let challenge = DailyChallenge.today(now: now())
        let loadedStats = Self.loadStats()
        self.dailyChallenge = challenge
        self.stats = loadedStats
        self.recentBoardSignatures = Self.loadRecentBoardSignatures()
        let initialBoard = makeInitialBoard ? GameRules.generatedBoard() : GameRules.emptyBoard()
        self.board = initialBoard
        self.openPositions = GameRules.openPositions(in: initialBoard)

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
        boardRefreshTask = nil
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
        boardRefreshTask = nil
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
        floatingScores = []
        chainDecayDeadline = nil
        pausedChainDecayRemaining = nil
        chainDecayDuration = 0
        // Clock first so the difficulty source of truth sees elapsed == 0 for the opener.
        roundClock = RoundClock(start: now(), duration: TimeInterval(GameRules.roundSeconds))
        time = GameRules.roundSeconds
        board = makeBoard(for: mode)
        boardGeneration += 1
        runState = .running
        isDealing = false
        boardToast = nil
        pendingEvents = []
        pendingRefreshReason = nil
        lastMissFeedbackAt = nil
        roundSummary = nil

        startTimer()
    }

    /// Full reset to a fresh round (Daily "Restart", gated behind a confirm in the UI).
    func newBoard() {
        newRound(mode: mode)
    }

    /// Classic "New board": deal a fresh board in place, keeping score / chain / time /
    /// metrics. Does not advance `boardDealIndex`, so a manual reshuffle never ramps
    /// difficulty.
    func reshuffleBoard() {
        guard runState == .running else { return }
        boardRefreshTask?.cancel()
        boardRefreshTask = nil
        toastTask?.cancel()
        pendingRefreshReason = nil
        isDealing = false
        escapingBlocks = []
        floatingScores = []
        boardToast = nil
        pendingEvents = []

        let profile = BoardGenerationProfile.difficulty(level: currentDifficultyLevel)
        board = makeClassicBoard(profile: profile)
        boardGeneration += 1
    }

    func pause() {
        guard runState == .running else { return }
        runState = .paused
        roundClock?.pause(at: now())
        // Freeze the chain-decay indicator at whatever was left, so resume restores exactly
        // that rather than handing back a fresh full window.
        if chain > 0, let deadline = chainDecayDeadline {
            pausedChainDecayRemaining = max(0, deadline.timeIntervalSince(now()))
        }
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        // Keep pendingRefreshReason so resume() can re-deal; the cancelled task must not
        // linger as the non-nil sentinel that gates resolveBoardAfterRemoval.
        boardRefreshTask = nil
    }

    func resume() {
        guard runState == .paused else { return }
        roundClock?.resume(at: now())
        runState = .running
        syncTimeFromClock()
        startTimer()
        if chain > 0, let remaining = pausedChainDecayRemaining {
            chainDecayDeadline = now().addingTimeInterval(remaining)
            pausedChainDecayRemaining = nil
            armChainResetTask(after: remaining)
        } else if chain > 0 {
            scheduleChainReset()
        }
        if let pendingRefreshReason {
            scheduleBoardRefresh(reason: pendingRefreshReason)
        }
    }

    /// Confirmed exit: credit pops / score toward lifetime totals & best (no summary, no
    /// achievement popups), then stop. `abandonRound` is the no-credit discard path.
    func creditAndEndRun() {
        guard isRoundActive else { return }
        runState = .idle
        isDealing = false
        pendingRefreshReason = nil
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        boardRefreshTask = nil
        toastTask?.cancel()
        chain = 0
        chainDecayDeadline = nil
        pausedChainDecayRemaining = nil
        chainDecayDuration = 0
        boardToast = nil
        pendingEvents = []
        escapingBlocks = []
        floatingScores = []

        let completedMetrics = roundMetrics
        if score > best {
            best = score
            UserDefaults.standard.set(score, forKey: Self.bestScoreStorageKey)
        }
        _ = updateDailyBestIfNeeded()
        var updatedStats = stats
        updatedStats.recordRound(
            score: score,
            mode: mode,
            maxChain: maxChain,
            metrics: completedMetrics
        )
        stats = updatedStats
        Self.saveStats(updatedStats)
        roundSummary = nil
    }

    func abandonRound() {
        runState = .idle
        isDealing = false
        pendingRefreshReason = nil
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        boardRefreshTask = nil
        toastTask?.cancel()
        chain = 0
        chainDecayDeadline = nil
        pausedChainDecayRemaining = nil
        chainDecayDuration = 0
        boardToast = nil
        pendingEvents = []
        escapingBlocks = []
        floatingScores = []
        roundSummary = nil
    }

    /// If the calendar day rolled over since the round was set up, swap in today's Daily
    /// challenge and reload its best. Never rolls over mid-run (it would change the seed
    /// under the player). Call on foreground and when Home appears.
    func refreshDailyIfDateChanged() {
        guard !isRoundActive else { return }
        let today = DailyChallenge.today(now: now())
        guard today.id != dailyChallenge.id else { return }
        dailyChallenge = today
        let stored = UserDefaults.standard.object(
            forKey: Self.dailyBestStorageKey(for: today.id)
        ) as? Int
        dailyBest = stored ?? 0
    }

    /// Re-sync the wall clock after returning to the foreground: the clock kept running
    /// while backgrounded (an explicit pause does not), so reflect the elapsed time and
    /// finish if the deadline passed. Also picks up a Daily date rollover.
    func handleForeground() {
        refreshDailyIfDateChanged()
        guard runState == .running else { return }
        syncTimeFromClock()
        if time <= 0 {
            finishRound()
        } else {
            startTimer()
        }
    }

    func configureFeedback(soundEnabled: Bool, hapticsEnabled: Bool) {
        feedbackSoundEnabled = soundEnabled
        feedbackHapticsEnabled = hapticsEnabled
        Haptics.prepare(enabled: hapticsEnabled)
        SoundEffects.shared.prepare(enabled: soundEnabled)
    }

    /// Direction-true pop: a flick clears a block only when it matches the block's arrow
    /// AND the block has a clear runway to the edge. A matching flick into a blocked block,
    /// or any wrong-direction flick, registers a miss. The board gesture only forwards a
    /// resolved flick here — a tap never reaches this method.
    func attemptPop(
        row: Int,
        column: Int,
        direction: Direction,
        hapticsEnabled: Bool,
        soundEnabled: Bool = false
    ) {
        guard running,
              !isDealing,
              GameRules.isInside(row: row, column: column),
              var block = board[row][column]
        else {
            return
        }

        if direction == block.direction,
           GameRules.isEscapable(on: board, row: row, column: column) {
            let openBeforeRemoval = openPositions
            let blockID = block.id
            let nextChain = chain + 1
            let escapingBlock = EscapingBlock(
                id: blockID,
                block: block,
                row: row,
                column: column,
                chain: nextChain
            )
            addEscapingBlock(escapingBlock)
            updateCell(row: row, column: column, with: nil)

            roundMetrics.pops += 1
            chain = nextChain
            let popScore = perPopScore(forChain: chain)
            score += popScore
            emitFloatingScore(amount: popScore, row: row, column: column, chain: chain)
            maxChain = max(maxChain, chain)
            let feedbackEvent = Self.feedbackEvent(forChain: chain)
            showChainToastIfNeeded()
            scheduleChainReset()
            awardUnlockBonusIfNeeded(openBeforeRemoval: openBeforeRemoval)
            resolveBoardAfterRemoval()
            queueFeedback(feedbackEvent, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
            // All rewards from this pop are now enqueued; surface the highest-priority one.
            drainEventQueue()

            Task { [weak self] in
                let lifetime = UInt64((escapingBlock.duration + 0.025) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: lifetime)
                self?.removeEscapingBlock(id: blockID)
            }
        } else {
            chainResetTask?.cancel()
            chain = 0
            // A miss ends the chain, so retire the decay indicator with it (keeps the
            // invariant chain>0 ⇔ chainDecayDeadline != nil).
            chainDecayDeadline = nil
            pausedChainDecayRemaining = nil
            chainDecayDuration = 0
            roundMetrics.misses += 1

            block.isMiss = true
            updateCell(row: row, column: column, with: block)
            applyMissTimePenalty()
            // Coalesce rapid misses so a fumble doesn't machine-gun haptics/sound (J7).
            if shouldEmitMissFeedback() {
                queueFeedback(.miss, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
            }

            let blockID = block.id
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                self?.clearMiss(id: blockID, row: row, column: column)
            }
        }
    }

    private func applyMissTimePenalty() {
        guard runState == .running, roundClock != nil else { return }
        roundClock?.reduceRemaining(by: missTimePenalty)
        syncTimeFromClock()
        if time <= 0 {
            finishRound()
        }
    }

    private func shouldEmitMissFeedback() -> Bool {
        let current = now()
        if let last = lastMissFeedbackAt, current.timeIntervalSince(last) < 0.15 {
            return false
        }
        lastMissFeedbackAt = current
        return true
    }

    /// Legacy entry point: delegates to `attemptPop` using the block's own arrow, so a
    /// successful escapable block always pops. Preserves existing call sites and tests.
    func swipe(
        row: Int,
        column: Int,
        hapticsEnabled: Bool,
        soundEnabled: Bool = false
    ) {
        guard GameRules.isInside(row: row, column: column),
              let direction = board[row][column]?.direction
        else {
            return
        }

        attemptPop(
            row: row,
            column: column,
            direction: direction,
            hapticsEnabled: hapticsEnabled,
            soundEnabled: soundEnabled
        )
    }

    func finishRound(hapticsEnabled: Bool? = nil, soundEnabled: Bool? = nil) {
        guard running else { return }

        runState = .finished
        isDealing = false
        pendingRefreshReason = nil
        timerTask?.cancel()
        chainResetTask?.cancel()
        boardRefreshTask?.cancel()
        boardRefreshTask = nil
        toastTask?.cancel()
        // Leave `escapingBlocks` in place so any pop still mid-flight when the clock expires
        // finishes its animation instead of being cut off (F2); each block self-retires.
        chainDecayDeadline = nil
        pausedChainDecayRemaining = nil
        chainDecayDuration = 0
        pendingEvents = []

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

        queueFeedback(
            .finish,
            hapticsEnabled: hapticsEnabled ?? feedbackHapticsEnabled,
            soundEnabled: soundEnabled ?? feedbackSoundEnabled
        )
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
        boardRefreshTask = nil
        toastTask?.cancel()

        self.mode = mode
        if mode == .daily {
            refreshDailyChallenge()
        }
        self.board = board
        self.score = 0
        self.chain = 0
        self.maxChain = 0
        self.roundClock = RoundClock(start: now(), duration: TimeInterval(GameRules.roundSeconds))
        self.time = roundClock?.remainingSeconds(at: now()) ?? GameRules.roundSeconds
        self.runState = running ? .running : .idle
        self.isDealing = false
        self.boardDealIndex = 0
        self.roundMetrics = .zero
        self.boardToast = nil
        self.pendingEvents = []
        self.pendingRefreshReason = nil
        self.lastMissFeedbackAt = nil
        self.escapingBlocks = []
        self.floatingScores = []
        self.chainDecayDeadline = nil
        self.pausedChainDecayRemaining = nil
        self.chainDecayDuration = 0
        self.roundSummary = nil
    }

    /// Test-only view of the queued (not-yet-displayed) events, so a test can assert that
    /// concurrent rewards were all enqueued rather than dropped.
    var queuedEventKinds: [BoardEvent.Kind] {
        pendingEvents.map(\.kind)
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
        guard runState == .running, let roundClock else { return }

        time = roundClock.remainingSeconds(at: now())
        if time <= 0 {
            finishRound()
        } else if time <= Self.lowTimeUrgencySeconds, !isDealing {
            // Low-time urgency cue (WI-5.4): a distinct soft per-second tick in the final
            // seconds. Visual pulse/colour lives in the view; this is the optional haptic,
            // gated by the same toggle as every other haptic and suppressed mid-deal when the
            // player can't act.
            Haptics.play(.tick, enabled: feedbackHapticsEnabled)
        }
    }

    private func syncTimeFromClock() {
        guard let roundClock else { return }
        time = roundClock.remainingSeconds(at: now())
    }

    /// The chain-decay grace window grows with the chain (E3): a longer streak earns a little
    /// more breathing room before it lapses, and the indicator's denominator tracks it.
    private func chainDecayWindow(forChain chain: Int) -> TimeInterval {
        1.4 + Double(min(max(chain, 1), 6)) * 0.16
    }

    private func scheduleChainReset() {
        let window = chainDecayWindow(forChain: chain)
        chainDecayDuration = window
        chainDecayDeadline = now().addingTimeInterval(window)
        pausedChainDecayRemaining = nil
        armChainResetTask(after: window)
    }

    private func armChainResetTask(after seconds: TimeInterval) {
        chainResetTask?.cancel()
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        chainResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            if Task.isCancelled { return }
            self?.resetChain()
        }
    }

    private func resetChain() {
        guard running else { return }
        chain = 0
        chainDecayDeadline = nil
        pausedChainDecayRemaining = nil
        chainDecayDuration = 0
    }

    /// Remaining fraction (1→0) of the active chain's decay window at `date`. Frozen while
    /// paused. Sampled by the HUD's chain-decay indicator via a TimelineView, so the model
    /// never has to publish on every frame.
    func chainDecayFraction(at date: Date) -> Double {
        guard chain > 0, chainDecayDuration > 0 else { return 0 }
        let remaining: TimeInterval
        if let frozen = pausedChainDecayRemaining {
            remaining = frozen
        } else if let deadline = chainDecayDeadline {
            remaining = deadline.timeIntervalSince(date)
        } else {
            return 0
        }
        return min(1, max(0, remaining / chainDecayDuration))
    }

    /// Per-pop score with the runaway cap (E1): linear up to `perPopChainCap`, then a small
    /// flat continuation per pop so long chains still pay without dwarfing other rewards.
    private func perPopScore(forChain chain: Int) -> Int {
        let capped = min(chain, perPopChainCap)
        let continuation = max(0, chain - perPopChainCap)
        return popBaseScore * capped + continuation * perPopContinuationStep
    }

    private func emitFloatingScore(amount: Int, row: Int, column: Int, chain: Int) {
        let marker = FloatingScore(row: row, column: column, amount: amount, chain: chain)
        floatingScores.append(marker)
        let maximumVisible = 8
        if floatingScores.count > maximumVisible {
            floatingScores.removeFirst(floatingScores.count - maximumVisible)
        }
        let markerID = marker.id
        let lifetime = floatingScoreLifetime
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            self?.floatingScores.removeAll { $0.id == markerID }
        }
    }

    private func removeBlock(id: UUID, row: Int, column: Int) {
        guard board[row][column]?.id == id else { return }
        let openBeforeRemoval = openPositions
        updateCell(row: row, column: column, with: nil)
        awardUnlockBonusIfNeeded(openBeforeRemoval: openBeforeRemoval)
        resolveBoardAfterRemoval()
        drainEventQueue()
    }

    private func removeEscapingBlock(id: UUID) {
        escapingBlocks.removeAll { $0.id == id }
    }

    private func addEscapingBlock(_ escapingBlock: EscapingBlock) {
        escapingBlocks.append(escapingBlock)
        let maximumVisibleEffects = 8
        if escapingBlocks.count > maximumVisibleEffects {
            escapingBlocks.removeFirst(escapingBlocks.count - maximumVisibleEffects)
        }
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
            var random = SeededRandomNumberGenerator(seed: seedForDailyDeal(dealIndex: boardDealIndex))
            return GameRules.generatedBoard(using: &random, profile: profile)
        }
    }

    private let maxDifficultyLevel = 4

    /// The current difficulty level (0...4) — the single source of truth used by board
    /// generation, the Classic reshuffle, and (later) the live HUD pip.
    var currentDifficultyLevel: Int {
        difficultyLevel(forDealIndex: boardDealIndex)
    }

    /// Difficulty is monotonic and fair. Classic ramps on a smoothed function of legit
    /// board clears plus elapsed round time (~one step / 12s) and never reads score nor
    /// rises from getting stuck. Daily ramps purely on the deal index so the shared
    /// challenge stays deterministic for everyone.
    private func difficultyLevel(forDealIndex index: Int) -> Int {
        switch mode {
        case .daily:
            return min(maxDifficultyLevel, max(0, index))
        case .classic:
            let level = roundMetrics.boardClears + elapsedSeconds / 12
            return min(maxDifficultyLevel, max(0, level))
        }
    }

    private var elapsedSeconds: Int {
        guard let roundClock else { return 0 }
        return max(0, Int(roundClock.totalDuration) - roundClock.remainingSeconds(at: now()))
    }

    private func makeClassicBoard(profile: BoardGenerationProfile) -> [[PopBlock?]] {
        let board = GameRules.classicBoard(
            profile: profile,
            recentSignatures: Set(recentBoardSignatures)
        )
        rememberClassicBoard(board)
        return board
    }

    private func rememberClassicBoard(_ board: [[PopBlock?]]) {
        let signature = GameRules.boardSignature(board)
        recentBoardSignatures.removeAll { $0 == signature }
        recentBoardSignatures.insert(signature, at: 0)
        recentBoardSignatures = Array(recentBoardSignatures.prefix(50))
        UserDefaults.standard.set(recentBoardSignatures, forKey: Self.recentBoardSignaturesStorageKey)
    }

    private func seedForDailyDeal(dealIndex: Int) -> UInt64 {
        dailyChallenge.seed ^ (UInt64(dealIndex) &* 0x9E37_79B9_7F4A_7C15)
    }

    private func resolveBoardAfterRemoval() {
        guard running, boardRefreshTask == nil else { return }

        let remainingBlocks = GameRules.blockCount(in: board)
        if remainingBlocks == 0 {
            awardBoardClearBonus()
            scheduleBoardRefresh(reason: .clear)
        } else if openPositions.isEmpty {
            roundMetrics.freshPaths += 1
            // Getting stuck isn't a punishment: pay a small consolation for the blocks left
            // stranded on the board before dealing a fresh one (D6).
            let strandedBonus = remainingBlocks * strandedBlockReward
            score += strandedBonus
            queueFeedback(.freshPath, hapticsEnabled: feedbackHapticsEnabled, soundEnabled: feedbackSoundEnabled)
            enqueueEvent(
                BoardEvent(
                    kind: .freshPath,
                    title: "FRESH PATH",
                    detail: "+\(strandedBonus)",
                    style: .freshPath,
                    announce: "Fresh path. Plus \(strandedBonus).",
                    duration: 850_000_000
                )
            )
            scheduleBoardRefresh(reason: .freshPath)
        }
    }

    private func awardBoardClearBonus() {
        roundMetrics.boardClears += 1
        let bonus = boardClearBaseBonus + min(max(chain, 1), boardClearChainCap) * boardClearChainStep
        score += bonus
        queueFeedback(.boardClear, hapticsEnabled: feedbackHapticsEnabled, soundEnabled: feedbackSoundEnabled)
        enqueueEvent(
            BoardEvent(
                kind: .clear,
                title: "BOARD CLEAR",
                detail: "+\(bonus)",
                style: .clear,
                announce: "Board clear. Plus \(bonus).",
                duration: 950_000_000
            )
        )
    }

    private func awardUnlockBonusIfNeeded(openBeforeRemoval: Set<BoardPosition>) {
        guard running else { return }

        let newlyOpened = openPositions.subtracting(openBeforeRemoval).count
        guard newlyOpened > 0 else { return }

        roundMetrics.unlocks += newlyOpened
        roundMetrics.bestUnlockBurst = max(roundMetrics.bestUnlockBurst, newlyOpened)

        let bonus = newlyOpened * unlockBaseBonus * max(chain, 1)
        score += bonus
        let feedbackEvent: Haptics.Event = newlyOpened >= 3 ? .bigChain : .unlock
        queueFeedback(feedbackEvent, hapticsEnabled: feedbackHapticsEnabled, soundEnabled: feedbackSoundEnabled)
        let title = unlockTitle(for: newlyOpened)
        enqueueEvent(
            BoardEvent(
                kind: .unlock,
                title: title,
                detail: "+\(bonus)",
                style: .unlock,
                announce: "\(title). Plus \(bonus).",
                duration: newlyOpened >= 3 ? 820_000_000 : 620_000_000
            )
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
        // Remembered so resume() can re-schedule a deal that was pending when the player
        // paused inside the (brief) post-clear / post-stuck window.
        pendingRefreshReason = reason
        boardRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: reason == .clear ? 260_000_000 : 220_000_000)
            if Task.isCancelled { return }
            await self?.dealNextBoard()
        }
    }

    private func dealNextBoard() async {
        guard running else { return }

        // Gate input precisely across the board-replacement window — the off-main
        // generation plus the main-actor assignment — so a flick can never land in a
        // half-swapped board. (During the scheduled delay before this runs the board is
        // either empty or fully blocked, so leaving input open there is harmless.)
        isDealing = true
        // Compute against the *next* index but don't commit it until the deal succeeds, so
        // a deal superseded mid-generation (e.g. pause/resume) can't double-advance the
        // index and desync the Daily seed / difficulty — the replacement deal recomputes
        // the same value.
        let nextIndex = boardDealIndex + 1
        let level = difficultyLevel(forDealIndex: nextIndex)
        let profile = BoardGenerationProfile.difficulty(level: level)
        let dealMode = mode

        // Heavy generation runs off the main actor so a chained clear never hitches the
        // running timer. The difficulty level is captured on the main actor first, so the
        // dealt board is identical to the old synchronous path (no balance change).
        let nextBoard: [[PopBlock?]]
        switch dealMode {
        case .classic:
            let recentSignatures = Set(recentBoardSignatures)
            nextBoard = await Task.detached(priority: .userInitiated) {
                GameRules.classicBoard(profile: profile, recentSignatures: recentSignatures)
            }.value
        case .daily:
            nextBoard = await GameRules.generatedBoardAsync(
                seed: seedForDailyDeal(dealIndex: nextIndex),
                profile: profile
            )
        }

        // Bail if the round ended or a newer deal superseded this one during generation.
        guard running, !Task.isCancelled else {
            isDealing = false
            return
        }

        boardDealIndex = nextIndex
        roundMetrics.difficultyPeak = max(roundMetrics.difficultyPeak, level)
        if dealMode == .classic {
            rememberClassicBoard(nextBoard)
        }
        escapingBlocks = []
        floatingScores = []
        board = nextBoard
        boardGeneration += 1
        // The "FRESH PATH" announcement is about the board we just replaced; once a fresh
        // one is dealt it's stale. Drop it whether it's already on screen or still queued
        // behind another toast, so it can never surface after the swap (F7).
        pendingEvents.removeAll { $0.kind == .freshPath }
        if boardToast?.style == .freshPath {
            boardToast = nil
            toastTask?.cancel()
            drainEventQueue()
        }
        boardRefreshTask = nil
        pendingRefreshReason = nil
        isDealing = false
    }

    /// Pop haptic tier (J3): a single pop is the light `.escape`; a 2–4 chain steps up to
    /// `.chain`; 5+ is `.bigChain`.
    static func feedbackEvent(forChain chain: Int) -> Haptics.Event {
        if chain >= 5 {
            return .bigChain
        }
        if chain >= 2 {
            return .chain
        }
        return .escape
    }

    private func queueFeedback(_ event: Haptics.Event, hapticsEnabled: Bool, soundEnabled: Bool) {
        // Fire in sync with the visual pop (F9): the prior 10ms Task hop pushed audio/haptics
        // a frame behind the on-screen pop. Miss feedback is already rate-limited by the
        // caller via `shouldEmitMissFeedback`.
        Haptics.play(event, enabled: hapticsEnabled)
        SoundEffects.shared.play(event, enabled: soundEnabled)
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
        enqueueEvent(
            BoardEvent(
                kind: .chain,
                title: title,
                detail: "×\(chain)",
                style: .chain,
                announce: "\(title) times \(chain).",
                duration: chain >= 7 ? 820_000_000 : chain >= 5 ? 720_000_000 : 560_000_000
            )
        )
    }

    /// Appends an event, coalescing by kind (latest of each kind wins) and capping the
    /// queue. Does not start display — the caller drains once all of a pop's events land,
    /// so the highest-priority one shows first.
    private func enqueueEvent(_ event: BoardEvent) {
        pendingEvents.removeAll { $0.kind == event.kind }
        pendingEvents.append(event)
        let maximumQueued = 4
        if pendingEvents.count > maximumQueued {
            pendingEvents.removeFirst(pendingEvents.count - maximumQueued)
        }
    }

    /// Shows the highest-priority pending event (clear > unlock > freshPath > chain) when no
    /// toast is on screen, then schedules the next drain when it expires.
    private func drainEventQueue() {
        guard boardToast == nil else { return }
        guard let next = pendingEvents.max(by: { $0.kind < $1.kind }) else { return }
        pendingEvents.removeAll { $0.id == next.id }

        let toast = BoardToast(title: next.title, detail: next.detail, style: next.style)
        let duration = next.duration
        boardToast = toast
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            if Task.isCancelled { return }
            guard let self else { return }
            if self.boardToast?.id == toast.id {
                self.boardToast = nil
            }
            self.drainEventQueue()
        }
    }

    private func refreshDailyChallenge() {
        let challenge = DailyChallenge.today(now: now())
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
