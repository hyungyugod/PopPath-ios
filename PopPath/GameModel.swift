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
    static let recentScoresCap = 20

    var roundsPlayed = 0
    var classicRounds = 0
    var dailyRounds = 0
    var totalScore = 0
    var totalPops = 0
    var totalMisses = 0
    var totalUnlocks = 0
    var totalBoardClears = 0
    var bestScore = 0
    /// Classic-only best, reported distinctly from the Daily best so a high Daily score never
    /// masquerades as the Classic record (E8).
    var bestClassicScore = 0
    var bestDailyScore = 0
    var bestChain = 0
    var bestAccuracy = 0
    var mostUnlocksInRound = 0
    var mostBoardClearsInRound = 0
    /// Daily streak (K3). The day id of the last completed Daily and the consecutive-day count.
    var currentStreak = 0
    var longestStreak = 0
    var lastDailyCompletionDayID: String?
    var unlockedAchievementIDs: [String] = []
    /// Achievements the player has actually seen surfaced, so an unseen badge can be shown (K16).
    var seenAchievementIDs: [String] = []
    /// Most-recent-first capped score history for the Records trend (K11).
    var recentScores: [Int] = []

    init() {}

    // Decode each field with a default so persisted stats from an earlier schema (missing the
    // newer keys) still round-trip instead of resetting to zero.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roundsPlayed = try c.decodeIfPresent(Int.self, forKey: .roundsPlayed) ?? 0
        classicRounds = try c.decodeIfPresent(Int.self, forKey: .classicRounds) ?? 0
        dailyRounds = try c.decodeIfPresent(Int.self, forKey: .dailyRounds) ?? 0
        totalScore = try c.decodeIfPresent(Int.self, forKey: .totalScore) ?? 0
        totalPops = try c.decodeIfPresent(Int.self, forKey: .totalPops) ?? 0
        totalMisses = try c.decodeIfPresent(Int.self, forKey: .totalMisses) ?? 0
        totalUnlocks = try c.decodeIfPresent(Int.self, forKey: .totalUnlocks) ?? 0
        totalBoardClears = try c.decodeIfPresent(Int.self, forKey: .totalBoardClears) ?? 0
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        // Pre-Sprint-7 saves have no Classic best; fall back to the legacy all-modes best so
        // Records' "Classic Best" matches the migrated Home "BEST" instead of showing 0.
        bestClassicScore = try c.decodeIfPresent(Int.self, forKey: .bestClassicScore) ?? bestScore
        bestDailyScore = try c.decodeIfPresent(Int.self, forKey: .bestDailyScore) ?? 0
        bestChain = try c.decodeIfPresent(Int.self, forKey: .bestChain) ?? 0
        bestAccuracy = try c.decodeIfPresent(Int.self, forKey: .bestAccuracy) ?? 0
        mostUnlocksInRound = try c.decodeIfPresent(Int.self, forKey: .mostUnlocksInRound) ?? 0
        mostBoardClearsInRound = try c.decodeIfPresent(Int.self, forKey: .mostBoardClearsInRound) ?? 0
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        lastDailyCompletionDayID = try c.decodeIfPresent(String.self, forKey: .lastDailyCompletionDayID)
        unlockedAchievementIDs = try c.decodeIfPresent([String].self, forKey: .unlockedAchievementIDs) ?? []
        seenAchievementIDs = try c.decodeIfPresent([String].self, forKey: .seenAchievementIDs) ?? []
        recentScores = try c.decodeIfPresent([Int].self, forKey: .recentScores) ?? []
    }

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

    var hasUnseenAchievements: Bool {
        unlockedAchievementIDs.contains { !seenAchievementIDs.contains($0) }
    }

    mutating func unlockAchievement(_ id: String) {
        guard !unlockedAchievementIDs.contains(id) else { return }
        unlockedAchievementIDs.append(id)
    }

    mutating func markUnlockedAchievementsSeen() {
        for id in unlockedAchievementIDs where !seenAchievementIDs.contains(id) {
            seenAchievementIDs.append(id)
        }
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
            bestClassicScore = max(bestClassicScore, score)
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

        recentScores.insert(score, at: 0)
        if recentScores.count > Self.recentScoresCap {
            recentScores.removeLast(recentScores.count - Self.recentScoresCap)
        }
    }
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

enum AchievementCatalog {
    // Re-tiered (E5) so they no longer all unlock in the first round or two, with higher-
    // horizon, cumulative, and streak milestones added (K8) plus an accuracy stake (E7).
    static let all: [Achievement] = [
        Achievement(id: "first_run", title: "First Swipe", subtitle: "Finish a round", systemImage: "flag.fill"),
        Achievement(id: "score_500", title: "Warmed Up", subtitle: "Score 500+", systemImage: "flame.fill"),
        Achievement(id: "score_1000", title: "Path Master", subtitle: "Score 1,000+", systemImage: "star.fill"),
        Achievement(id: "score_2000", title: "Path Legend", subtitle: "Score 2,000+", systemImage: "star.circle.fill"),
        Achievement(id: "chain_5", title: "Clean Chain", subtitle: "Reach chain x5", systemImage: "link"),
        Achievement(id: "chain_10", title: "Flow State", subtitle: "Reach chain x10", systemImage: "sparkles"),
        Achievement(id: "clean_run", title: "No Misses", subtitle: "Finish with no misses", systemImage: "checkmark.seal.fill"),
        Achievement(id: "sharp_run", title: "Sharpshooter", subtitle: "Finish at 95%+ accuracy", systemImage: "scope"),
        Achievement(id: "unlock_5", title: "Key Finder", subtitle: "Open 5 paths in one round", systemImage: "key.fill"),
        Achievement(id: "path_burst", title: "Path Burst", subtitle: "Open 3 paths with one swipe", systemImage: "bolt.fill"),
        Achievement(id: "clear_2", title: "Board Sweeper", subtitle: "Clear 2 boards in one round", systemImage: "rectangle.grid.2x2.fill"),
        Achievement(id: "clear_4", title: "Sweep Master", subtitle: "Clear 4 boards in one round", systemImage: "square.grid.3x3.fill"),
        Achievement(id: "daily_first", title: "Daily Ritual", subtitle: "Finish a Daily Challenge", systemImage: "calendar"),
        Achievement(id: "streak_3", title: "On a Roll", subtitle: "3-day Daily streak", systemImage: "flame"),
        Achievement(id: "streak_7", title: "Week Warrior", subtitle: "7-day Daily streak", systemImage: "calendar.badge.checkmark"),
        Achievement(id: "ten_rounds", title: "Ten Runs", subtitle: "Finish 10 rounds", systemImage: "10.circle.fill"),
        Achievement(id: "fifty_rounds", title: "Half Century", subtitle: "Finish 50 rounds", systemImage: "50.circle.fill"),
        Achievement(id: "hundred_pops", title: "Hundred Swipes", subtitle: "Swipe 100 blocks", systemImage: "circle.grid.cross.fill"),
        Achievement(id: "total_25k", title: "Marathoner", subtitle: "Score 25,000 lifetime", systemImage: "infinity.circle.fill")
    ]

    /// Achievements that can be judged from the live round state alone (monotonic during a
    /// run) so they can be celebrated the moment they're earned (K5). Excludes anything that a
    /// later event could invalidate (no-misses, accuracy) or that depends on round totals.
    static func liveEligibleIDs(score: Int, maxChain: Int, metrics: RoundMetrics) -> [String] {
        [
            score >= 500 ? "score_500" : nil,
            score >= 1_000 ? "score_1000" : nil,
            score >= 2_000 ? "score_2000" : nil,
            maxChain >= 5 ? "chain_5" : nil,
            maxChain >= 10 ? "chain_10" : nil,
            metrics.unlocks >= 5 ? "unlock_5" : nil,
            metrics.bestUnlockBurst >= 3 ? "path_burst" : nil,
            metrics.boardClears >= 2 ? "clear_2" : nil,
            metrics.boardClears >= 4 ? "clear_4" : nil
        ].compactMap { $0 }
    }

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
            score >= 2_000 ? "score_2000" : nil,
            maxChain >= 5 ? "chain_5" : nil,
            maxChain >= 10 ? "chain_10" : nil,
            metrics.misses == 0 && metrics.pops >= 12 ? "clean_run" : nil,
            metrics.accuracyPercent >= 95 && metrics.pops >= 20 ? "sharp_run" : nil,
            metrics.unlocks >= 5 ? "unlock_5" : nil,
            metrics.bestUnlockBurst >= 3 ? "path_burst" : nil,
            metrics.boardClears >= 2 ? "clear_2" : nil,
            metrics.boardClears >= 4 ? "clear_4" : nil,
            mode == .daily ? "daily_first" : nil,
            updatedStats.currentStreak >= 3 ? "streak_3" : nil,
            updatedStats.currentStreak >= 7 ? "streak_7" : nil,
            updatedStats.roundsPlayed >= 10 ? "ten_rounds" : nil,
            updatedStats.roundsPlayed >= 50 ? "fifty_rounds" : nil,
            updatedStats.totalPops >= 100 ? "hundred_pops" : nil,
            updatedStats.totalScore >= 25_000 ? "total_25k" : nil
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
    /// This run was played in Practice Mode (Open-Path Highlight on) and credited nothing.
    let isPractice: Bool
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
        isPractice: Bool = false,
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
        self.isPractice = isPractice
        self.lifetimeStats = lifetimeStats
    }

    var shareText: String {
        shareText(language: .english)
    }

    /// Placeholder store link appended to shares until the live App Store URL is known (I2).
    static let shareURL = "https://apps.apple.com/app/poppath"

    func shareText(language: AppLanguage) -> String {
        let bestValue = mode == .daily ? (dailyBest ?? score) : best

        if language == .korean {
            let koreanModeLabel = mode == .daily ? "오늘의 길 · \(friendlyDailyDate(language: .korean))" : "클래식"
            let koreanBestLabel = mode == .daily ? "오늘 최고" : "최고"

            return """
            PopPath \(koreanModeLabel)
            점수 \(score.formatted()) | \(koreanBestLabel) \(bestValue.formatted())
            체인 x\(maxChain) | 길 열림 \(metrics.unlocks) | 싹쓸이 \(metrics.boardClears) | 정확도 \(metrics.accuracyPercent)%
            PopPath 하러 가기: \(Self.shareURL)
            """
        }

        let modeLabel = mode == .daily ? "Daily · \(friendlyDailyDate(language: .english))" : "Classic"
        let bestLabel = mode == .daily ? "Daily Best" : "Best"

        return """
        PopPath \(modeLabel)
        Score \(score.formatted()) | \(bestLabel) \(bestValue.formatted())
        Chain x\(maxChain) | Unlocks \(metrics.unlocks) | Clears \(metrics.boardClears) | Accuracy \(metrics.accuracyPercent)%
        Play PopPath: \(Self.shareURL)
        """
    }

    /// Turns the raw `YYYYMMDD` daily id into a friendly localized date (EN "Jun 22",
    /// KO "6월 22일") for the share sheet (I1).
    private func friendlyDailyDate(language: AppLanguage) -> String {
        guard let dailyId, let date = DailyChallenge.date(fromID: dailyId) else { return dailyId ?? "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .korean ? "ko_KR" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}

struct BoardToast: Identifiable, Equatable {
    enum Style: Equatable {
        case chain
        case unlock
        case freshPath
        case clear
        case celebration
    }

    let id = UUID()
    let title: String
    let detail: String
    let style: Style

    /// Localized title, shared by the on-screen toast and the VoiceOver announcement so the
    /// two can never drift (WI-5.5).
    func localizedTitle(language: AppLanguage) -> String {
        guard language == .korean else { return title }

        switch title {
        case "MEGA CHAIN": return "메가 체인"
        case "BIG CHAIN": return "빅 체인"
        case "CHAIN": return "체인"
        case "PATH BURST": return "길이 팡!"
        case "DOUBLE UNLOCK": return "길 두 개!"
        case "UNLOCK": return "길 열림"
        case "FRESH PATH": return "새 길!"
        case "BOARD CLEAR": return "싹쓸이!"
        case "NEW BEST": return "최고 기록!"
        case "ACHIEVEMENT": return "업적 달성!"
        default: return title
        }
    }

    func localizedDetail(language: AppLanguage) -> String {
        guard language == .korean else { return detail }
        return detail == "NO MOVES" ? "갈 곳 없음" : detail
    }

    /// Spoken VoiceOver announcement for this event, localized (G6).
    func announcement(language: AppLanguage) -> String {
        "\(localizedTitle(language: language)), \(localizedDetail(language: language))"
    }
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
        /// New best / achievement celebration — highest priority so it surfaces over routine
        /// reward toasts (K5/K12).
        case celebration

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
    /// The variety modifier on the current board (rolled per deal; deterministic for the Daily).
    /// Drives the score/decay tweaks below and the board's banner/tint in the view.
    @Published private(set) var currentModifier: BoardModifier = .none
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
    /// True once the Open-Path Highlight (Practice Mode) was on at any point during this run.
    /// A practice run is a pure sandbox: it credits nothing (no best, stats, daily best, streak,
    /// achievements, or live celebrations) and a practice Daily never consumes the day's attempt.
    /// It latches one-way so flipping the assist on mid-run can't be flipped back off to sneak a
    /// hinted run into the records. Reset to false only on `newRound`.
    @Published private(set) var isPractice = false
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
    /// Once-per-run guard so the live "NEW BEST!" celebration fires a single time (K12).
    private var surfacedNewBestThisRun = false
    /// Achievements already celebrated mid-run, so each surfaces at most once per round (K5).
    private var liveSurfacedAchievementIDs: Set<String> = []
    /// While true (one synchronous pop), reward haptics are collapsed to the single strongest
    /// tier instead of each firing — so an unlock+clear pop doesn't bury the pop confirmation
    /// under stacked impacts. Audio is unaffected (it is already async-staggered and pooled).
    private var suppressRewardHaptics = false
    private var strongestSuppressedHaptic: Haptics.Event?
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
    /// Flat points per block cleared by a bomb's detonation (its row + column). Not chain-scaled
    /// so a big blast doesn't dwarf everything else.
    private let bombDetonationReward = 12
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

        // `best` is now the Classic best specifically (E8). Seed it from the Classic lifetime
        // best; the legacy stored key (historically the all-modes best) is the migration floor.
        let storedBest = UserDefaults.standard.object(forKey: Self.bestScoreStorageKey) as? Int
        self.best = max(storedBest ?? 0, loadedStats.bestClassicScore)

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
        isPractice = false
        currentModifier = .none
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
        surfacedNewBestThisRun = false
        liveSurfacedAchievementIDs = []
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

        let level = currentDifficultyLevel
        let profile = BoardGenerationProfile.difficulty(level: level)
        currentModifier = rolledModifier(forDealIndex: boardDealIndex, level: level)
        board = makeClassicBoard(profile: profile)
        boardGeneration += 1
    }

    func pause() {
        guard runState == .running else { return }
        runState = .paused
        roundClock?.pause(at: now())
        // Freeze the chain-decay indicator at whatever was left, so resume restores exactly
        // that rather than handing back a fresh full window.
        freezeChainDecayIfNeeded()
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
        if chain > 0 {
            if pausedChainDecayRemaining != nil {
                restoreChainDecay()
            } else {
                scheduleChainReset()
            }
        }
        if let pendingRefreshReason {
            scheduleBoardRefresh(reason: pendingRefreshReason)
        }
    }

    /// Freezes the chain-decay clock at its current remaining and stops the reset timer, so an
    /// un-actionable window (pause, or the post-clear/post-stuck board deal) doesn't drain the
    /// chain the player can't act on. Idempotent: a window already frozen keeps its value.
    private func freezeChainDecayIfNeeded() {
        guard chain > 0, pausedChainDecayRemaining == nil, let deadline = chainDecayDeadline else { return }
        pausedChainDecayRemaining = max(0, deadline.timeIntervalSince(now()))
        chainResetTask?.cancel()
    }

    /// Restores a frozen chain-decay window onto the now-actionable board: the player gets back
    /// exactly the grace they had when the window froze, mirroring resume().
    private func restoreChainDecay() {
        guard chain > 0, let remaining = pausedChainDecayRemaining else { return }
        chainDecayDeadline = now().addingTimeInterval(remaining)
        pausedChainDecayRemaining = nil
        armChainResetTask(after: remaining)
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

        // Practice Mode credits nothing on a confirmed exit either (mirrors finishRound).
        guard !isPractice else {
            roundSummary = nil
            return
        }

        let completedMetrics = roundMetrics
        if mode == .classic, score > best {
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
        // A credited Daily exit consumes the day's one attempt: lock it and advance the
        // streak, exactly as a natural finish does, so the deterministic board can't be
        // re-ground for a higher best.
        if mode == .daily {
            applyDailyStreak(to: &updatedStats)
        }
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

    /// Latches the run into Practice Mode if the Open-Path Highlight is (or ever was) on during
    /// it. Called at round start and whenever the toggle changes, so a run that sees the hints
    /// — even briefly via the paused overlay — can never be credited. One-way: passing `false`
    /// after it's latched does nothing.
    func setPracticeAssist(_ assistOn: Bool) {
        guard assistOn else { return }
        let wasPractice = isPractice
        isPractice = true
        if !wasPractice {
            // Latching mid-run: drop any celebration queued on what is now an uncredited run, so
            // it can't over-promise a "NEW BEST"/achievement the run will never save.
            pendingEvents.removeAll { $0.kind == .celebration }
        }
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

        // What counts as a valid flick depends on the block's kind: a wild block pops with any
        // direction that has a clear lane; every other kind must be flicked along its own arrow.
        let validFlick: Bool
        let popDirection: Direction
        if block.kind == .wild {
            validFlick = GameRules.hasClearRunway(on: board, row: row, column: column, direction: direction)
            popDirection = direction
        } else {
            validFlick = direction == block.direction
                && GameRules.isEscapable(on: board, row: row, column: column)
            popDirection = block.direction
        }

        guard validFlick else {
            registerMiss(row: row, column: column, block: &block, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
            return
        }

        // Armored: the first valid flick only cracks it; it pops on the next one.
        if block.kind == .armored, block.armor > 0 {
            crackArmoredBlock(row: row, column: column, block: &block, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
            return
        }

        performPop(
            row: row,
            column: column,
            block: block,
            popDirection: popDirection,
            hapticsEnabled: hapticsEnabled,
            soundEnabled: soundEnabled
        )
    }

    private func performPop(
        row: Int,
        column: Int,
        block: PopBlock,
        popDirection: Direction,
        hapticsEnabled: Bool,
        soundEnabled: Bool
    ) {
        let openBeforeRemoval = openPositions
        let blockID = block.id
        let nextChain = chain + 1
        // The escaping visual is a plain pop sliding the flicked way (wild follows your flick);
        // a bomb's spectacle is its detonation, handled below.
        var poppedBlock = block
        poppedBlock.direction = popDirection
        poppedBlock.kind = .normal
        let escapingBlock = EscapingBlock(
            id: blockID,
            block: poppedBlock,
            row: row,
            column: column,
            chain: nextChain
        )
        addEscapingBlock(escapingBlock)
        updateCell(row: row, column: column, with: nil)

        roundMetrics.pops += 1
        chain = nextChain
        let popScore = scaledByModifier(perPopScore(forChain: chain))
        score += popScore
        emitFloatingScore(amount: popScore, row: row, column: column, chain: chain)
        maxChain = max(maxChain, chain)
        let feedbackEvent = Self.feedbackEvent(forChain: chain)
        showChainToastIfNeeded()
        scheduleChainReset()
        // Collapse this pop's haptics (pop tier + any unlock + any clear/fresh-path/bomb) into
        // one strongest impact so the bonus haptics don't bury the pop confirmation; sound
        // for each still plays (layered, async).
        suppressRewardHaptics = true
        strongestSuppressedHaptic = nil
        if block.kind == .bomb {
            // The blast clears a cross of cells and already pays detonation points, so we do NOT
            // also pay a player "unlock" bonus for lanes the explosion (not a skillful flick)
            // freed — that would double-count and inflate unlock stats. Skipping it also means
            // no UNLOCK toast is enqueued, so the bomb's own "BOOM" toast actually surfaces.
            detonateBomb(row: row, column: column, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
        } else {
            awardUnlockBonusIfNeeded(openBeforeRemoval: openBeforeRemoval)
        }
        resolveBoardAfterRemoval()
        queueFeedback(feedbackEvent, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
        suppressRewardHaptics = false
        if let popHaptic = strongestSuppressedHaptic {
            Haptics.play(popHaptic, enabled: hapticsEnabled)
        }
        surfaceLiveMilestones()
        // All rewards from this pop are now enqueued; surface the highest-priority one.
        drainEventQueue()

        Task { [weak self] in
            let lifetime = UInt64((escapingBlock.duration + 0.025) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: lifetime)
            self?.removeEscapingBlock(id: blockID)
        }
    }

    /// A bomb pops like a normal block, then clears every other block in its row and column,
    /// each as a little pop. Detonated blocks pay flat points and count as pops, but don't each
    /// advance the chain (the bomb's own pop already did). Detonated bombs do NOT chain-react —
    /// they clear as ordinary blocks, keeping the blast bounded.
    private func detonateBomb(row: Int, column: Int, hapticsEnabled: Bool, soundEnabled: Bool) {
        var targets: [BoardPosition] = []
        for otherColumn in 0..<GameRules.columns where otherColumn != column {
            if board[row][otherColumn] != nil { targets.append(BoardPosition(row: row, column: otherColumn)) }
        }
        for otherRow in 0..<GameRules.rows where otherRow != row {
            if board[otherRow][column] != nil { targets.append(BoardPosition(row: otherRow, column: column)) }
        }
        guard !targets.isEmpty else { return }

        var nextBoard = board
        for position in targets {
            guard let hit = nextBoard[position.row][position.column] else { continue }
            var poppedBlock = hit
            poppedBlock.kind = .normal
            let escaping = EscapingBlock(
                id: hit.id,
                block: poppedBlock,
                row: position.row,
                column: position.column,
                chain: max(chain, 1)
            )
            addEscapingBlock(escaping)
            nextBoard[position.row][position.column] = nil
            let escapingID = hit.id
            Task { [weak self] in
                let lifetime = UInt64((escaping.duration + 0.025) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: lifetime)
                self?.removeEscapingBlock(id: escapingID)
            }
        }
        board = nextBoard

        let detonated = targets.count
        roundMetrics.pops += detonated
        let bonus = scaledByModifier(detonated * bombDetonationReward)
        score += bonus
        queueFeedback(.boardClear, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
        enqueueEvent(
            BoardEvent(
                kind: .unlock,
                title: "BOOM",
                detail: "+\(bonus)",
                style: .chain,
                announce: "Boom. Plus \(bonus).",
                duration: 760_000_000
            )
        )
    }

    /// The first valid flick on an armored block only cracks it — no pop, no chain advance, and
    /// crucially no miss. It re-arms the decay window so engaging an armored block sustains a run.
    private func crackArmoredBlock(row: Int, column: Int, block: inout PopBlock, hapticsEnabled: Bool, soundEnabled: Bool) {
        block.armor -= 1
        updateCell(row: row, column: column, with: block)
        if chain > 0 {
            scheduleChainReset()
        }
        // A firm, distinct tap so a crack reads as progress, not a miss.
        queueFeedback(.unlock, hapticsEnabled: hapticsEnabled, soundEnabled: soundEnabled)
    }

    private func registerMiss(row: Int, column: Int, block: inout PopBlock, hapticsEnabled: Bool, soundEnabled: Bool) {
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

    /// Applies the current board modifier's score multiplier (rush doubles; others are 1×).
    private func scaledByModifier(_ base: Int) -> Int {
        guard currentModifier.scoreMultiplier != 1 else { return base }
        return Int((Double(base) * currentModifier.scoreMultiplier).rounded())
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

        // Practice Mode: credit nothing — no best, stats, daily best, streak, or achievements,
        // and no Daily lock — but still show the round's result so the player sees how they did.
        if isPractice {
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
                dailyBest: mode == .daily ? dailyBest : nil,
                dailyId: mode == .daily ? dailyChallenge.id : nil,
                metrics: completedMetrics,
                isNewBest: false,
                isNewDailyBest: false,
                unlockedAchievements: [],
                isPractice: true,
                lifetimeStats: stats
            )
            return
        }

        let previousStats = stats
        let isNewBest = mode == .classic && score > best
        let isNewDailyBest = mode == .daily && score > dailyBest

        if mode == .classic, score > best {
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
        if mode == .daily {
            applyDailyStreak(to: &updatedStats)
        }
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
            isPractice: false,
            lifetimeStats: updatedStats
        )
    }

    #if DEBUG
    func loadBoardForTesting(
        _ board: [[PopBlock?]],
        running: Bool = true,
        mode: GameMode = .classic,
        modifier: BoardModifier = .none
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
        self.isPractice = false
        self.currentModifier = modifier
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
        self.surfacedNewBestThisRun = false
        self.liveSurfacedAchievementIDs = []
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
        (1.4 + Double(min(max(chain, 1), 6)) * 0.16) * currentModifier.decayFactor
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
        // Headroom for a full bomb blast (the popped bomb + up to 11 detonated cells) so the
        // player's own flicked-block pop isn't trimmed off the front in favor of the secondary
        // detonation pops.
        let maximumVisibleEffects = 14
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
        currentModifier = rolledModifier(forDealIndex: boardDealIndex, level: level)

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

    /// Rolls the variety modifier for a board. Level-0 boards (the opener) are always plain.
    /// The Daily derives its roll from the challenge seed and deal index, so the same board on
    /// the same day carries the same modifier for everyone; Classic rolls freely.
    private func rolledModifier(forDealIndex index: Int, level: Int) -> BoardModifier {
        guard level >= 1 else { return .none }
        switch mode {
        case .daily:
            var random = SeededRandomNumberGenerator(
                seed: dailyChallenge.seed ^ (UInt64(index &+ 1) &* 0xD1B5_4A32_D192_ED03)
            )
            return BoardModifier.roll(using: &random)
        case .classic:
            var random = SystemRandomNumberGenerator()
            return BoardModifier.roll(using: &random)
        }
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
        let base = boardClearBaseBonus + min(max(chain, 1), boardClearChainCap) * boardClearChainStep
        let bonus = Int((Double(base) * currentModifier.clearMultiplier).rounded())
        score += bonus
        // A Bonus board hands back time when you sweep it.
        if currentModifier.clearTimeBonus > 0 {
            addRoundTime(currentModifier.clearTimeBonus)
        }
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

    /// Extends the round clock (used by the Bonus board's clear reward). No-op outside a running
    /// round.
    private func addRoundTime(_ seconds: TimeInterval) {
        guard runState == .running, roundClock != nil else { return }
        roundClock?.extendRemaining(by: seconds)
        syncTimeFromClock()
    }

    private func awardUnlockBonusIfNeeded(openBeforeRemoval: Set<BoardPosition>) {
        guard running else { return }

        let newlyOpened = openPositions.subtracting(openBeforeRemoval).count
        guard newlyOpened > 0 else { return }

        roundMetrics.unlocks += newlyOpened
        roundMetrics.bestUnlockBurst = max(roundMetrics.bestUnlockBurst, newlyOpened)

        let bonus = scaledByModifier(newlyOpened * unlockBaseBonus * max(chain, 1))
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
        // The post-clear / post-stuck deal is an un-actionable window (input is gated and the
        // board is empty/being replaced), so freeze the chain-decay clock across it just like
        // pause does — otherwise a kept-alive chain is charged time it can't spend, and a slow
        // off-main generation could even lapse the chain mid-deal. `dealNextBoard` restores it.
        freezeChainDecayIfNeeded()
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
        currentModifier = rolledModifier(forDealIndex: nextIndex, level: level)
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
        // The board is actionable again — give back the chain-decay grace frozen for the deal.
        restoreChainDecay()
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
        if suppressRewardHaptics {
            if hapticsEnabled {
                strongestSuppressedHaptic = Self.strongerHaptic(strongestSuppressedHaptic, event)
            }
            SoundEffects.shared.play(event, enabled: soundEnabled)
        } else {
            Haptics.play(event, enabled: hapticsEnabled)
            SoundEffects.shared.play(event, enabled: soundEnabled)
        }
    }

    private static func strongerHaptic(_ current: Haptics.Event?, _ candidate: Haptics.Event) -> Haptics.Event {
        guard let current else { return candidate }
        return hapticRank(candidate) >= hapticRank(current) ? candidate : current
    }

    private static func hapticRank(_ event: Haptics.Event) -> Int {
        switch event {
        case .boardClear: return 5
        case .bigChain: return 4
        case .unlock: return 3
        case .chain, .freshPath: return 2
        case .escape: return 1
        case .miss, .finish, .tick: return 0
        }
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

    /// True once today's Daily has been completed — the UI uses it to lock further attempts
    /// until midnight rollover (K2). It deliberately does NOT gate `newRound(mode:.daily)`, so
    /// the direct programmatic path (and tests) still works.
    var isDailyCompletedToday: Bool {
        stats.lastDailyCompletionDayID == dailyChallenge.id
    }

    var currentStreak: Int { stats.currentStreak }

    /// Advances the consecutive-day Daily streak (K3). Same-day re-completion is a no-op; a
    /// one-day gap continues the streak; any larger gap restarts it at 1.
    private func applyDailyStreak(to stats: inout PlayerStats) {
        let dayID = dailyChallenge.id
        guard stats.lastDailyCompletionDayID != dayID else { return }

        if let last = stats.lastDailyCompletionDayID,
           let delta = DailyChallenge.dayDifference(from: last, to: dayID, calendar: .autoupdatingCurrent),
           delta == 1 {
            stats.currentStreak += 1
        } else {
            stats.currentStreak = 1
        }
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        stats.lastDailyCompletionDayID = dayID
    }

    /// Celebrates milestones the moment they're reached during play (K5/K12): a once-per-run
    /// NEW BEST when the live score passes the mode's standing record, and each freshly-earned
    /// achievement once. Authoritative persistence still happens in `finishRound`.
    private func surfaceLiveMilestones() {
        // A practice run credits nothing, so it celebrates nothing — a "NEW BEST" or achievement
        // pop would be a lie about a run that won't be saved.
        guard !isPractice else { return }
        // At most one celebration per pop: they all share the `.celebration` kind, which the
        // event queue coalesces, so enqueuing several at once would silently drop all but the
        // last. NEW BEST takes priority; any freshly-eligible achievement waits for a later
        // pop (it stays eligible since score/chain/clears only rise), and on the final pop the
        // Result screen lists everything anyway. Guard flags flip only when actually enqueued.
        let standing = mode == .daily ? dailyBest : best
        if !surfacedNewBestThisRun, standing > 0, score > standing {
            surfacedNewBestThisRun = true
            enqueueEvent(
                BoardEvent(
                    kind: .celebration,
                    title: "NEW BEST",
                    detail: score.formatted(),
                    style: .celebration,
                    announce: nil,
                    duration: 1_000_000_000
                )
            )
            return
        }

        for id in AchievementCatalog.liveEligibleIDs(score: score, maxChain: maxChain, metrics: roundMetrics)
        where !stats.unlockedAchievementIDs.contains(id) && !liveSurfacedAchievementIDs.contains(id) {
            liveSurfacedAchievementIDs.insert(id)
            enqueueEvent(
                BoardEvent(
                    kind: .celebration,
                    title: "ACHIEVEMENT",
                    detail: "",
                    style: .celebration,
                    announce: nil,
                    duration: 950_000_000
                )
            )
            return
        }
    }

    /// Marks every unlocked achievement as seen, clearing the unseen badge (K16).
    func markAchievementsSeen() {
        guard stats.hasUnseenAchievements else { return }
        var updated = stats
        updated.markUnlockedAchievementsSeen()
        stats = updated
        Self.saveStats(updated)
    }

    /// Clears all locally persisted progress and in-memory state (K9). Called from a confirmed
    /// Settings action; `hasSeenTutorial` (an @AppStorage flag) is cleared by the caller.
    func resetLocalData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.bestScoreStorageKey)
        defaults.removeObject(forKey: Self.playerStatsStorageKey)
        defaults.removeObject(forKey: Self.recentBoardSignaturesStorageKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("dailyBest.") {
            defaults.removeObject(forKey: key)
        }

        stats = PlayerStats()
        best = 0
        dailyBest = 0
        recentBoardSignatures = []
        boardToast = nil
        pendingEvents = []
        liveSurfacedAchievementIDs = []
        surfacedNewBestThisRun = false
    }
}
