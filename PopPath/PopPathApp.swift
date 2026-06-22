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
    // Defaults on so a fresh install distinguishes open from blocked out of the box; the
    // open cue itself is now always drawn, so this only controls the brighter pulse. The
    // storage key is unchanged, so anyone who turned it off keeps their choice.
    @AppStorage("colorAssist") private var colorAssist = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.english.rawValue
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Effective reduce motion is the system setting OR the in-app toggle, derived once here
    /// and threaded into every animation site (G2), so honoring iOS Reduce Motion never
    /// depends on the user also flipping the in-app switch.
    private var effectiveReduceMotion: Bool { systemReduceMotion || reduceMotion }
    #if DEBUG
    @State private var handledLaunchArguments = false
    #endif

    var body: some View {
        ZStack {
            Color.ppWarmCream
                .ignoresSafeArea()

            currentScreen
                .environment(\.appLanguage, appLanguage)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
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
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch route {
        case .home:
            HomeView(
                best: game.best,
                dailyBest: game.dailyBest,
                dailyLabel: game.dailyChallenge.displayLabel,
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
                    // First-time Daily players are taught first instead of being silently
                    // opted out of onboarding (H3); the tutorial then starts the Daily run.
                    if hasSeenTutorial {
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
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                colorAssist: colorAssist,
                reduceMotion: effectiveReduceMotion,
                onExit: {
                    // GameView already finalized the round (credited exit); just route home.
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .home
                    }
                }
            )
        case .result:
            ResultView(
                summary: game.roundSummary ?? fallbackSummary,
                onRetry: { startGame(mode: game.roundSummary?.mode ?? game.mode) },
                onHome: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .home
                    }
                }
            )
        case .records:
            RecordsView(
                stats: game.stats,
                achievements: AchievementCatalog.all,
                onBack: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .home
                    }
                }
            )
        case .settings:
            SettingsView(
                soundEnabled: $soundEnabled,
                hapticsEnabled: $hapticsEnabled,
                colorAssist: $colorAssist,
                reduceMotion: $reduceMotion,
                language: appLanguageBinding,
                onHowToPlay: { presentTutorial(context: .returnTo(.settings)) },
                onBack: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        route = .home
                    }
                }
            )
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .english
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
