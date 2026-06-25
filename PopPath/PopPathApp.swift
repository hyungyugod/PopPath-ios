import SwiftUI

@main
struct PopPathApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private enum AppRoute {
    case home
    case tutorial
    case game
    case result
    case records
    case settings
}

/// What finishing (or skipping) the tutorial should do: start a first run of the chosen mode,
/// or return to the screen the player launched the replay from (WI-6.2).
private enum TutorialContext {
    case play(GameMode)
    case returnTo(AppRoute)
}

struct RootView: View {
    @StateObject private var game = GameModel()
    @State private var route: AppRoute = .home
    @State private var tutorialContext: TutorialContext = .play(.classic)
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    // Off by default: the open-path sparkle is now a learning aid, not a default crutch. When
    // ON it is the *only* thing that draws the open cue AND it flips the run into Practice Mode
    // (no records). The storage key is unchanged, so anyone who already turned it on keeps it —
    // they'll just now be practicing. See GameModel.isPractice.
    @AppStorage("colorAssist") private var colorAssist = false
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.korean.rawValue
    @State private var showDailyDoneInfo = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Effective reduce motion is the system setting OR the in-app toggle, derived once here
    /// and threaded into every animation site (G2), so honoring iOS Reduce Motion never
    /// depends on the user also flipping the in-app switch.
    private var effectiveReduceMotion: Bool { systemReduceMotion || reduceMotion }
    #if DEBUG
    @State private var handledLaunchArguments = false
    #endif

    /// Largest the portrait column is allowed to grow, centered on the warm-cream background past
    /// a large phone (~440×932) — on iPad the extra space would otherwise be wasted margin or a
    /// top-pinned phone layout. Every iPhone is inside the smaller box, so the cap is a no-op
    /// there; only iPad gets the centered column.
    ///
    /// Board-centric screens (the game, the tutorial board) fill wide — a big board reads well and
    /// is nicer to tap. Menu/text screens stay narrower so low-density cards and copy don't stretch
    /// into sparse full-width bars.
    private var contentMaxSize: CGSize {
        switch route {
        case .game, .tutorial: return CGSize(width: 760, height: 1180)
        default: return CGSize(width: 620, height: 1000)
        }
    }

    var body: some View {
        ZStack {
            Color.ppWarmCream
                .ignoresSafeArea()

            currentScreen
                .environment(\.appLanguage, appLanguage)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                // The game is designed as a one-hand portrait column. On iPad (and any width
                // past a large phone) cap the content and center it on the warm background so it
                // reads as a deliberate layout instead of a stretched phone — every screen lives
                // inside `currentScreen`, so one cap covers Home/Game/Result/Records/Settings.
                .frame(maxWidth: contentMaxSize.width, maxHeight: contentMaxSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
        // Fonts scale with Dynamic Type (WI-5.6), but this is a real-time tile game with a
        // fixed single-viewport board/HUD layout. Cap at xxLarge — the largest size the fixed
        // tiles and one-screen Home/Game layouts hold without clipping — so accessibility sizes
        // still get a meaningful bump without shattering the layout.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .onAppear {
            handleDebugLaunchArgumentsIfNeeded()
        }
        .onChange(of: game.roundSummary?.id) { _, _ in
            guard game.roundSummary != nil else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                route = .result
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // The wall clock keeps running while backgrounded (an explicit pause does not);
            // on return, reflect the elapsed time and pick up a Daily date rollover.
            if phase == .active {
                game.handleForeground()
            }
        }
        .onChange(of: dailyReminderEnabled) { _, enabled in
            if enabled {
                DailyReminder.enable(language: appLanguage) {
                    dailyReminderEnabled = false
                }
            } else {
                DailyReminder.disable()
            }
        }
        .onChange(of: appLanguageRaw) { _, _ in
            guard dailyReminderEnabled else { return }
            DailyReminder.reschedule(language: appLanguage)
        }
        .onChange(of: soundEnabled) { _, enabled in
            // Confirm the toggle with a short preview tone the moment sound is switched on (J5).
            if enabled {
                SoundEffects.shared.prepare(enabled: true)
                SoundEffects.shared.play(.unlock, enabled: true)
            }
        }
        .alert(
            appLanguage.text("Daily done for today", "오늘의 도전 완료"),
            isPresented: $showDailyDoneInfo
        ) {
            Button(appLanguage.text("OK", "확인"), role: .cancel) { }
        } message: {
            Text(dailyDoneMessage)
        }
    }

    private var dailyDoneMessage: String {
        // Explains the seeded, shared, one-attempt nature of the Daily (K18) and surfaces the
        // result/streak (K2).
        let best = game.dailyBest
        let streak = game.currentStreak
        return appLanguage.text(
            "Everyone plays the same Daily board, once per day. Today: best \(best), streak \(streak). A fresh challenge arrives at midnight.",
            "모두가 같은 오늘의 보드를 하루 한 번 플레이해요. 오늘: 최고 \(best), 연속 \(streak). 자정에 새 도전이 열려요."
        )
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch route {
        case .home:
            HomeView(
                best: game.best,
                dailyBest: game.dailyBest,
                dailyLabel: game.dailyChallenge.displayLabel(language: appLanguage),
                isDailyCompletedToday: game.isDailyCompletedToday,
                stats: game.stats,
                achievementCount: game.stats.unlockedAchievementIDs.count,
                soundEnabled: soundEnabled,
                onToggleSound: { soundEnabled.toggle() },
                onPlay: {
                    if hasSeenTutorial {
                        startGame()
                    } else {
                        presentTutorial(context: .play(.classic))
                    }
                },
                onDaily: {
                    // One-shot per day (K2): once today's Daily is done, show the explainer/
                    // result instead of re-rolling. First-time players are taught first (H3).
                    if game.isDailyCompletedToday {
                        showDailyDoneInfo = true
                    } else if hasSeenTutorial {
                        startGame(mode: .daily)
                    } else {
                        presentTutorial(context: .play(.daily))
                    }
                },
                onSettings: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .settings
                    }
                },
                onRecords: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .records
                    }
                }
            )
            .onAppear { game.refreshDailyIfDateChanged() }
        case .tutorial:
            TutorialView(
                reduceMotion: effectiveReduceMotion,
                onComplete: completeTutorial
            )
        case .game:
            GameView(
                game: game,
                soundEnabled: $soundEnabled,
                hapticsEnabled: $hapticsEnabled,
                colorAssist: $colorAssist,
                reduceMotion: effectiveReduceMotion,
                onExit: {
                    // GameView already finalized the round (credited exit); just route home.
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .home
                    }
                }
            )
        case .result:
            let goHome = { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { route = .home } }
            let summary = game.roundSummary ?? fallbackSummary
            ResultView(
                summary: summary,
                // A one-shot Daily can't be replayed today — Retry returns Home instead (K13) —
                // but a *practice* Daily was never consumed, so it can always be retried.
                canRetry: summary.mode != .daily || summary.isPractice,
                onRetry: { startGame(mode: game.roundSummary?.mode ?? game.mode) },
                onHome: goHome
            )
            .edgeSwipeBack(perform: goHome)
        case .records:
            let goHome = { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { route = .home } }
            RecordsView(
                stats: game.stats,
                achievements: AchievementCatalog.all,
                onPlay: {
                    if hasSeenTutorial {
                        startGame()
                    } else {
                        presentTutorial(context: .play(.classic))
                    }
                },
                onBack: goHome
            )
            .onAppear { game.markAchievementsSeen() }
            .edgeSwipeBack(perform: goHome)
        case .settings:
            let goHome = { withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { route = .home } }
            SettingsView(
                soundEnabled: $soundEnabled,
                hapticsEnabled: $hapticsEnabled,
                colorAssist: $colorAssist,
                reduceMotion: $reduceMotion,
                dailyReminderEnabled: $dailyReminderEnabled,
                language: appLanguageBinding,
                onHowToPlay: { presentTutorial(context: .returnTo(.settings)) },
                onResetData: {
                    game.resetLocalData()
                    hasSeenTutorial = false
                },
                onBack: goHome
            )
            .edgeSwipeBack(perform: goHome)
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .korean
    }

    private var appLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { appLanguage },
            set: { appLanguageRaw = $0.rawValue }
        )
    }

    private var fallbackSummary: RoundSummary {
        RoundSummary(
            score: game.score,
            best: game.best,
            maxChain: game.maxChain,
            mode: game.mode,
            dailyBest: game.mode == .daily ? game.dailyBest : nil,
            dailyId: game.mode == .daily ? game.dailyChallenge.id : nil,
            lifetimeStats: game.stats
        )
    }

    private func startGame(mode: GameMode = .classic) {
        game.newRound(mode: mode)
        // Latch Practice Mode from the highlight setting at round start; GameView keeps it in
        // sync if the toggle is flipped mid-run from the paused overlay.
        game.setPracticeAssist(colorAssist)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            route = .game
        }
    }

    private func presentTutorial(context: TutorialContext) {
        tutorialContext = context
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            route = .tutorial
        }
    }

    /// Completing or skipping the tutorial marks it seen, then either starts the intended
    /// first run or returns to the screen the replay was launched from (WI-6.2).
    private func completeTutorial() {
        hasSeenTutorial = true
        switch tutorialContext {
        case .play(let mode):
            startGame(mode: mode)
        case .returnTo(let destination):
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                route = destination
            }
        }
    }

    private func handleDebugLaunchArgumentsIfNeeded() {
        #if DEBUG
        guard !handledLaunchArguments else { return }
        handledLaunchArguments = true

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-popPathStartDaily") {
            hasSeenTutorial = true
            startGame(mode: .daily)
            return
        }

        if arguments.contains("-popPathStartGame") {
            hasSeenTutorial = true
            startGame()
            return
        }

        if arguments.contains("-popPathShowRecords") {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                route = .records
            }
            return
        }

        if arguments.contains("-popPathShowTutorial") {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                route = .tutorial
            }
            return
        }

        if arguments.contains("-popPathShowResult") {
            showDebugResult()
        }
        #endif
    }

    #if DEBUG
    private func showDebugResult() {
        var previewStats = PlayerStats()
        previewStats.roundsPlayed = 12
        previewStats.classicRounds = 9
        previewStats.dailyRounds = 3
        previewStats.totalScore = 9_420
        previewStats.totalPops = 184
        previewStats.totalMisses = 18
        previewStats.totalUnlocks = 39
        previewStats.totalBoardClears = 7
        previewStats.bestScore = 1_420
        previewStats.bestDailyScore = 1_180
        previewStats.bestChain = 9
        previewStats.bestAccuracy = 96
        previewStats.mostUnlocksInRound = 11
        previewStats.mostBoardClearsInRound = 3
        previewStats.unlockedAchievementIDs = ["first_run", "score_500", "chain_5"]

        let metrics = RoundMetrics(
            pops: 38,
            misses: 2,
            unlocks: 11,
            bestUnlockBurst: 3,
            boardClears: 2,
            freshPaths: 1,
            difficultyPeak: 3
        )
        game.roundSummary = RoundSummary(
            score: 1_420,
            best: 1_420,
            maxChain: 9,
            metrics: metrics,
            isNewBest: true,
            unlockedAchievements: Array(AchievementCatalog.all.prefix(3)),
            lifetimeStats: previewStats
        )

        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            route = .result
        }
    }
    #endif
}
