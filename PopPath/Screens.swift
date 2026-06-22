import SwiftUI

struct HomeView: View {
    @Environment(\.appLanguage) private var language

    let best: Int
    let dailyBest: Int
    let dailyLabel: String
    let isDailyCompletedToday: Bool
    let stats: PlayerStats
    let achievementCount: Int
    let soundEnabled: Bool
    let onToggleSound: () -> Void
    let onPlay: () -> Void
    let onDaily: () -> Void
    let onSettings: () -> Void
    let onRecords: () -> Void

    private var isFirstTime: Bool { stats.roundsPlayed == 0 }

    private var dailyDetail: String {
        if isDailyCompletedToday {
            let streak = stats.currentStreak > 0 ? " · 🔥\(stats.currentStreak)" : ""
            return language.text("Done today", "오늘 완료") + streak
        }
        if dailyBest > 0 {
            return "\(language.text("BEST", "최고")) \(dailyBest.formatted())"
        }
        return "\(language.text("TODAY", "오늘")) \(dailyLabel)"
    }

    var body: some View {
        GeometryReader { proxy in
            let isShort = proxy.size.height < 680

            VStack(spacing: 0) {
                Spacer(minLength: isShort ? 22 : 42)

                DecorativeBlockCluster()
                    .accessibilityHidden(true)
                    .padding(.bottom, isShort ? 22 : 30)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("PopPath")
                        .foregroundStyle(Color.ppInkGray)
                    Text("!")
                        .foregroundStyle(Color.ppSoftCoral)
                }
                .font(.ppDisplay(isShort ? 42 : 46, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityLabel("PopPath")

                Text(language.text("Swipe the path. Chain the pop.", "길을 밀고, 체인 팡!"))
                    .font(.ppDisplay(15, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.top, 6)

                Spacer(minLength: isShort ? 20 : 30)

                if isFirstTime {
                    // Welcoming zero-state instead of a row of zeroes (K7).
                    Text(language.text("Your first run awaits — swipe, chain, pop!", "첫 판이 기다려요 — 밀고, 잇고, 팡!"))
                        .font(.ppDisplay(15, weight: .medium, language: language))
                        .foregroundStyle(Color.ppMintText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.bottom, isShort ? 14 : 18)
                } else {
                    PillStat(label: language.text("BEST", "최고"), value: best.formatted())
                        .padding(.bottom, isShort ? 10 : 12)

                    HStack(spacing: 8) {
                        MiniRecordStat(label: language.text("RUNS", "판수"), value: stats.roundsPlayed.formatted())
                        MiniRecordStat(label: language.text("AVG", "평균"), value: stats.averageScore.formatted())
                        MiniRecordStat(
                            label: language.text("STREAK", "연속"),
                            value: stats.currentStreak > 0 ? "🔥\(stats.currentStreak)" : "—"
                        )
                    }
                    .padding(.bottom, isShort ? 14 : 18)
                }

                PrimaryPopButton(language.text("Play", "플레이"), systemImage: "play.fill", action: onPlay)

                SecondaryPopButton(
                    title: language.text("Daily Challenge", "오늘의 길"),
                    detail: dailyDetail,
                    systemImage: isDailyCompletedToday ? "checkmark.seal.fill" : "calendar",
                    action: onDaily
                )
                .padding(.top, isShort ? 10 : 12)

                SecondaryPopButton(
                    title: language.text("Records", "기록"),
                    detail: "\(achievementCount)/\(AchievementCatalog.all.count) \(language.text("ACH", "업적"))",
                    systemImage: "chart.bar.fill",
                    action: onRecords
                )
                .overlay(alignment: .topTrailing) {
                    if stats.hasUnseenAchievements {
                        Circle()
                            .fill(Color.ppSoftCoral)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color.ppWarmCream, lineWidth: 2))
                            .offset(x: 4, y: -4)
                            .accessibilityLabel(language.text("New achievement", "새 업적"))
                    }
                }
                .padding(.top, isShort ? 8 : 10)

                HStack(spacing: 12) {
                    IconTileButton(
                        systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        accessibilityLabel: soundEnabled
                            ? language.text("Sound on", "사운드 켜짐")
                            : language.text("Sound off", "사운드 꺼짐"),
                        action: onToggleSound
                    )
                    IconTileButton(
                        systemName: "gearshape.fill",
                        accessibilityLabel: language.text("Settings", "설정"),
                        action: onSettings
                    )
                }
                .padding(.top, isShort ? 12 : 16)
                .padding(.bottom, isShort ? 18 : 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ppScreenPadding()
    }
}

private struct MiniRecordStat: View {
    @Environment(\.appLanguage) private var language

    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.ppDisplay(15, weight: .bold, language: language))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.ppBody(10, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.6)
                .foregroundStyle(Color.ppMintText.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ppSoftSage)
        )
    }
}

private struct DecorativeBlockCluster: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        HStack(spacing: 9) {
            DecorativeBlock(arrow: "▲", color: .ppMistBlue, rotation: -6, yOffset: 0)
            DecorativeBlock(arrow: "▶", color: .ppFreshMint, rotation: 0, yOffset: floating && !reduceMotion ? -7 : -2, isOpen: true)
            DecorativeBlock(arrow: "◀", color: .ppLavenderMist, rotation: 7, yOffset: 0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

private struct DecorativeBlock: View {
    let arrow: String
    let color: Color
    let rotation: Double
    let yOffset: CGFloat
    var isOpen = false

    var body: some View {
        ArrowGlyph(arrow: arrow, size: 18)
            .foregroundStyle(Color.ppInkGray)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(color)
                    .shadow(color: Color.ppInkGray.opacity(0.14), radius: 11, x: 0, y: 5)
                    .overlay {
                        if isOpen {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.ppFreshMint, lineWidth: 3)
                        }
                    }
            )
            .rotationEffect(.degrees(rotation))
            .offset(y: yOffset)
    }
}

struct ResultView: View {
    @Environment(\.appLanguage) private var language

    let summary: RoundSummary
    var canRetry: Bool = true
    let onRetry: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                resultContent
                    .padding(.top, 36)
                    .padding(.bottom, 20)
            }
            .ppScreenPadding()

            resultActions
        }
    }

    private var resultContent: some View {
        VStack(spacing: 0) {
            Text(summary.mode == .daily
                ? language.text("Daily complete", "오늘 길 완료!")
                : language.text("Time's up", "시간 끝!"))
                .font(.ppDisplay(16, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmGray)

            Text(headline)
                .font(.ppDisplay(25, weight: .semibold, language: language))
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.top, 2)

            Text(summary.score.formatted())
                .font(.ppDisplay(64, weight: .bold, language: language))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 16)

            Text(language.text("SCORE", "점수"))
                .font(.ppBody(12, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.72)
                .foregroundStyle(Color.ppWarmGray)
                .padding(.top, 2)

            if summary.isNewBest || summary.isNewDailyBest {
                Label(
                    summary.isNewDailyBest
                        ? language.text("New daily best", "오늘 최고 기록!")
                        : language.text("New personal best", "내 최고 기록!"),
                    systemImage: "crown.fill"
                )
                    .font(.ppDisplay(14, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppMintButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(Color.ppFreshMint))
                    .padding(.top, 14)
            }

            if summary.mode == .daily, summary.lifetimeStats.currentStreak > 0 {
                Label(
                    language.text(
                        "\(summary.lifetimeStats.currentStreak)-day streak",
                        "\(summary.lifetimeStats.currentStreak)일 연속"
                    ),
                    systemImage: "flame.fill"
                )
                    .font(.ppDisplay(14, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppSoftCoral)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(Color.ppSoftCoral.opacity(0.15)))
                    .padding(.top, 12)
            }

            HStack(spacing: 10) {
                ResultStatCard(
                    value: resultBestValue,
                    label: summary.mode == .daily ? language.text("DAILY BEST", "오늘 최고") : language.text("BEST", "최고")
                )
                ResultStatCard(value: "×\(summary.maxChain)", label: language.text("MAX CHAIN", "최고 체인"), valueColor: .ppMintText)
            }
            .padding(.top, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ResultStatCard(value: "\(summary.metrics.unlocks)", label: language.text("UNLOCKS", "길 열림"), valueColor: .ppMintText)
                ResultStatCard(value: "\(summary.metrics.accuracyPercent)%", label: language.text("ACCURACY", "정확도"))
                ResultStatCard(value: "\(summary.metrics.boardClears)", label: language.text("CLEARS", "싹쓸이"))
                ResultStatCard(value: "\(summary.metrics.difficultyPeak + 1) / 5", label: language.text("PEAK LV", "최고 단계"))
            }
            .padding(.top, 10)

            if !summary.unlockedAchievements.isEmpty {
                VStack(spacing: 8) {
                    Text(language.text("NEW ACHIEVEMENTS", "새 업적"))
                        .font(.ppBody(11, weight: .heavy, language: language))
                        .tracking(language == .korean ? 0 : 0.8)
                        .foregroundStyle(Color.ppWarmGray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(summary.unlockedAchievements) { achievement in
                        AchievementBadge(achievement: achievement, unlocked: true)
                    }
                }
                .padding(.top, 20)
            }
        }
    }

    private var resultActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ShareLink(item: summary.shareText(language: language)) {
                    ResultActionButton(title: language.text("Share", "공유"), systemImage: "square.and.arrow.up", style: .secondary)
                }

                if canRetry {
                    Button(action: onRetry) {
                        ResultActionButton(title: language.text("Retry", "다시"), systemImage: "arrow.clockwise", style: .primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    // One-shot Daily: no replay today, so the primary action returns Home (K13).
                    Button(action: onHome) {
                        ResultActionButton(title: language.text("Home", "홈"), systemImage: "house.fill", style: .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if canRetry {
                Button(language.text("Home", "홈"), action: onHome)
                    .font(.ppDisplay(15, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
            }
        }
        .ppScreenPadding()
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.ppWarmCream)
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 14, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var headline: String {
        if summary.isNewBest || summary.isNewDailyBest {
            return language.text("Best run yet!", "최고 기록!")
        }
        return summary.mode == .daily
            ? language.text("Today's run!", "오늘도 팡팡!")
            : language.text("Nice run!", "잘 터뜨렸어요!")
    }

    private var resultBestValue: String {
        if summary.mode == .daily {
            return (summary.dailyBest ?? summary.score).formatted()
        }

        return summary.best.formatted()
    }
}

private struct ResultActionButton: View {
    @Environment(\.appLanguage) private var language

    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.ppDisplay(17, weight: .semibold, language: language))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 13, x: 0, y: 6)
            )
    }

    private var foregroundColor: Color {
        style == .primary ? .ppMintButtonText : .ppInkGray
    }

    private var backgroundColor: Color {
        style == .primary ? .ppFreshMint : .ppCardCream
    }

    private var strokeColor: Color {
        style == .primary ? .white.opacity(0.28) : .ppMintText.opacity(0.13)
    }

    private var shadowColor: Color {
        style == .primary ? .ppMintText.opacity(0.24) : .ppInkGray.opacity(0.09)
    }
}

private struct ResultStatCard: View {
    @Environment(\.appLanguage) private var language

    let value: String
    let label: String
    var valueColor: Color = .ppInkGray

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.ppDisplay(22, weight: .bold, language: language))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.ppBody(11, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.8)
                .foregroundStyle(Color.ppMintText.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ppSoftSage)
        )
    }
}

struct RecordsView: View {
    @Environment(\.appLanguage) private var language

    let stats: PlayerStats
    let achievements: [Achievement]
    let onBack: () -> Void

    private var unlockedCount: Int {
        achievements.filter { stats.isAchievementUnlocked($0) }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ppInkGray)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.text("Back", "뒤로"))

                    Text(language.text("Records", "기록"))
                        .font(.ppDisplay(25, weight: .semibold, language: language))
                        .foregroundStyle(Color.ppInkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()
                }
                .padding(.top, 18)
                .padding(.bottom, 22)

                // Classic and Daily bests reported distinctly (E8).
                HStack(spacing: 10) {
                    ResultStatCard(value: stats.bestClassicScore.formatted(), label: language.text("CLASSIC BEST", "클래식 최고"))
                    ResultStatCard(value: stats.bestDailyScore.formatted(), label: language.text("DAILY BEST", "오늘 최고"), valueColor: .ppMintText)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    RecordMetricTile(title: language.text("Rounds", "판수"), value: stats.roundsPlayed.formatted(), icon: "flag.fill")
                    RecordMetricTile(title: language.text("Average", "평균"), value: stats.averageScore.formatted(), icon: "chart.line.uptrend.xyaxis")
                    RecordMetricTile(title: language.text("Best Chain", "최고 체인"), value: "×\(stats.bestChain)", icon: "link")
                    RecordMetricTile(title: language.text("Accuracy", "정확도"), value: "\(stats.bestAccuracy)%", icon: "scope")
                    RecordMetricTile(title: language.text("Swipes", "스와이프"), value: stats.totalPops.formatted(), icon: "hand.draw.fill")
                    RecordMetricTile(title: language.text("Unlocks", "길 열림"), value: stats.totalUnlocks.formatted(), icon: "key.fill")
                    RecordMetricTile(title: language.text("Board Clears", "싹쓸이"), value: stats.totalBoardClears.formatted(), icon: "rectangle.grid.2x2.fill")
                    RecordMetricTile(title: language.text("Best Streak", "최고 연속"), value: "🔥\(stats.longestStreak)", icon: "flame.fill")
                }
                .padding(.top, 12)

                if stats.recentScores.count >= 2 {
                    RecentScoresTrend(scores: stats.recentScores)
                        .padding(.top, 12)
                }

                VStack(spacing: 8) {
                    Text(language.text("ACHIEVEMENTS", "업적"))
                        .font(.ppBody(11, weight: .heavy, language: language))
                        .tracking(language == .korean ? 0 : 0.8)
                        .foregroundStyle(Color.ppWarmGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)

                    ForEach(achievements) { achievement in
                        AchievementBadge(
                            achievement: achievement,
                            unlocked: stats.isAchievementUnlocked(achievement)
                        )
                    }
                }
                .padding(.bottom, 26)
            }
        }
        .ppScreenPadding()
    }
}

/// A compact bar trend of the most recent runs (K11). `scores` is most-recent-first; bars are
/// drawn oldest→newest left to right.
private struct RecentScoresTrend: View {
    @Environment(\.appLanguage) private var language
    let scores: [Int]

    var body: some View {
        let ordered = Array(scores.reversed())
        let peak = max(ordered.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: 10) {
            Text(language.text("RECENT RUNS", "최근 기록"))
                .font(.ppBody(11, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.8)
                .foregroundStyle(Color.ppWarmGray)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { index, score in
                    Capsule(style: .continuous)
                        .fill(index == ordered.count - 1 ? Color.ppMintText : Color.ppFreshMint)
                        .frame(height: max(6, CGFloat(score) / CGFloat(peak) * 56))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 56, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.ppSoftSage)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Recent runs trend", "최근 기록 추이"))
        .accessibilityValue(language.text("Latest \(scores.first ?? 0)", "최근 \(scores.first ?? 0)"))
    }
}

private struct RecordMetricTile: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ppMintText)

            Text(value)
                .font(.ppDisplay(22, weight: .bold, language: language))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.ppBody(11, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.65)
                .foregroundStyle(Color.ppWarmGray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.ppInkGray.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

private struct AchievementBadge: View {
    @Environment(\.appLanguage) private var language

    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.systemImage)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(Circle().fill(iconBackground))

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title(language: language))
                    .font(.ppDisplay(16, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray.opacity(unlocked ? 1 : 0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(achievement.subtitle(language: language))
                    .font(.ppBody(12, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(unlocked ? Color.ppMintText : Color.ppWarmGray.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(unlocked ? Color.ppCardCream : Color.ppInkGray.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(unlocked ? Color.ppMintText.opacity(0.11) : Color.ppInkGray.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private var iconColor: Color {
        unlocked ? .ppMintButtonText : .ppWarmGray
    }

    private var iconBackground: Color {
        unlocked ? .ppFreshMint : Color.ppInkGray.opacity(0.08)
    }
}

private extension Achievement {
    func title(language: AppLanguage) -> String {
        guard language == .korean else { return title }

        switch id {
        case "first_run":
            return "첫 스와이프"
        case "score_500":
            return "워밍업"
        case "score_1000":
            return "길 고수"
        case "score_2000":
            return "길 전설"
        case "chain_5":
            return "체인 착착"
        case "chain_10":
            return "팡팡 모드"
        case "clean_run":
            return "노 미스"
        case "sharp_run":
            return "명사수"
        case "unlock_5":
            return "길잡이"
        case "path_burst":
            return "길이 팡!"
        case "clear_2":
            return "싹쓸이"
        case "clear_4":
            return "싹쓸이 달인"
        case "daily_first":
            return "오늘도 출석"
        case "streak_3":
            return "연속 3일"
        case "streak_7":
            return "한 주 완주"
        case "ten_rounds":
            return "열 판째!"
        case "fifty_rounds":
            return "50판 클럽"
        case "hundred_pops":
            return "백 번 스와이프"
        case "total_25k":
            return "마라토너"
        default:
            return title
        }
    }

    func subtitle(language: AppLanguage) -> String {
        guard language == .korean else { return subtitle }

        switch id {
        case "first_run":
            return "첫 판 마무리"
        case "score_500":
            return "500점 넘기기"
        case "score_1000":
            return "1,000점 넘기기"
        case "score_2000":
            return "2,000점 넘기기"
        case "chain_5":
            return "체인 x5 달성"
        case "chain_10":
            return "체인 x10 달성"
        case "clean_run":
            return "실수 없이 마무리"
        case "sharp_run":
            return "정확도 95% 이상"
        case "unlock_5":
            return "한 판에서 길 5개 열기"
        case "path_burst":
            return "한 번에 길 3개 열기"
        case "clear_2":
            return "한 판에서 2번 싹쓸이"
        case "clear_4":
            return "한 판에서 4번 싹쓸이"
        case "daily_first":
            return "오늘의 길 마무리"
        case "streak_3":
            return "데일리 3일 연속"
        case "streak_7":
            return "데일리 7일 연속"
        case "ten_rounds":
            return "10판 마무리"
        case "fifty_rounds":
            return "50판 마무리"
        case "hundred_pops":
            return "블록 100개 스와이프"
        case "total_25k":
            return "누적 25,000점"
        default:
            return subtitle
        }
    }
}

/// One onboarding step: which mini-board cell is highlighted, the flick the player must
/// perform to advance, and the EN/KO copy. File scope (not private) so the taught copy and the
/// required gesture are unit-testable.
struct TutorialStep: Equatable {
    let highlightIndex: Int
    let arrow: String
    let expectedDirection: Direction
    let titleEN: String
    let titleKO: String
    let subtitleEN: String
    let subtitleKO: String
}

enum TutorialContent {
    /// Each step teaches a true rule (post-R1 direction-true input): the arrow-matching flick
    /// (H1), the runway-to-edge escapability rule (H2), clearing in order to open lanes, and
    /// chaining. The highlighted cell's displayed arrow matches `expectedDirection`.
    static let steps: [TutorialStep] = [
        TutorialStep(
            highlightIndex: 5,
            arrow: "▶",
            expectedDirection: .right,
            titleEN: "Flick the way the arrow points",
            titleKO: "화살표 방향으로 밀어요",
            subtitleEN: "Only a flick that matches the arrow clears a block.",
            subtitleKO: "화살표와 같은 방향으로 밀어야 사라져요"
        ),
        TutorialStep(
            highlightIndex: 0,
            arrow: "▲",
            expectedDirection: .up,
            titleEN: "Clear a lane to the edge",
            titleKO: "가장자리까지 길을 비워요",
            subtitleEN: "A block only pops if its arrow has a clear lane to the edge.",
            subtitleKO: "화살표 앞이 가장자리까지 뚫려 있어야 터져요"
        ),
        TutorialStep(
            highlightIndex: 2,
            arrow: "▼",
            expectedDirection: .down,
            titleEN: "Open new lanes in order",
            titleKO: "순서대로 새 길을 열어요",
            subtitleEN: "Clearing one block can free others to pop next.",
            subtitleKO: "한 블록을 치우면 다른 길이 열려요"
        ),
        TutorialStep(
            highlightIndex: 7,
            arrow: "▶",
            expectedDirection: .right,
            titleEN: "Chain flicks for a high score",
            titleKO: "연속으로 밀어 점수를 올려요",
            subtitleEN: "Keep flicking without a miss to build a chain.",
            subtitleKO: "막히지 않고 이어 밀면 체인이 쌓여요"
        )
    ]
}

struct TutorialView: View {
    @Environment(\.appLanguage) private var language

    let reduceMotion: Bool
    let onComplete: () -> Void

    @State private var step = 0
    @State private var pulse = false
    @State private var tries = 0
    @State private var wrongFlick = false

    private let steps = TutorialContent.steps
    private var totalSteps: Int { steps.count }
    private var currentStep: Int { min(step, totalSteps - 1) }
    private var config: TutorialStep { steps[currentStep] }
    private var isLastStep: Bool { currentStep == totalSteps - 1 }
    /// The flick is the taught path; the explicit button is the fallback that appears after a
    /// couple of misses (and always on the final step) so nobody is ever stuck (H4).
    private var showFallbackButton: Bool { tries >= 2 || isLastStep }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            miniBoard

            // Wraps rather than clamping to one line so the taught copy stays legible at
            // larger Dynamic Type sizes (H6).
            Text(localizedTitle)
                .font(.ppDisplay(16, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmCream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.ppInkGray))
                .shadow(color: Color.ppInkGray.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 12)
                .padding(.top, 34)

            Text(localizedSubtitle)
                .font(.ppBody(13, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 14)

            Text(flickHint)
                .font(.ppBody(12, weight: .heavy, language: language))
                .foregroundStyle(wrongFlick ? Color.ppSoftCoral : Color.ppMintText)
                .padding(.top, 10)

            Spacer()

            if showFallbackButton {
                PrimaryPopButton(primaryButtonTitle, systemImage: primaryButtonIcon, action: advance)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            Button(language.text("Skip", "건너뛰기"), action: onComplete)
                .font(.ppDisplay(15, weight: .semibold, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .padding(.bottom, 16)
                .accessibilityHint(language.text("Skips the tutorial", "튜토리얼을 건너뛰어요"))

            stepDots
                .padding(.bottom, 24)
        }
        .ppScreenPadding()
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: showFallbackButton)
        .onAppear {
            // Drives the pointing-hand bob. The open-path highlight pulses itself inside
            // the shared OpenPathCue modifier.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var miniBoard: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(52), spacing: 8), count: 4),
            spacing: 8
        ) {
            tutorialCell(index: 0, arrow: "▲", color: .ppMistBlue)
            tutorialCell(index: 1, arrow: nil, color: .ppMistBlue)
            tutorialCell(index: 2, arrow: "▼", color: .ppLavenderMist)
            tutorialCell(index: 3, arrow: "◀", color: .ppMistBlue)
            tutorialCell(index: 4, arrow: nil, color: .ppMistBlue)
            tutorialCell(index: 5, arrow: "▶", color: .ppFreshMint, foreground: .ppMintButtonText)
            tutorialCell(index: 6, arrow: "▲", color: .ppLavenderMist)
            tutorialCell(index: 7, arrow: "▶", color: .ppMistBlue)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppSoftSage)
                .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        // The taught gesture: only a flick matching the highlighted arrow advances (H4). It
        // uses the same resolver as the live board so the tutorial can't teach a different
        // flick than the game accepts.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded(handleFlick)
        )
        // VoiceOver users can't flick, so the board is also an activate-able element.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Practice board", "연습 보드"))
        .accessibilityHint(flickHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { advance() }
    }

    @ViewBuilder
    private func tutorialCell(index: Int, arrow: String?, color: Color, foreground: Color = .ppInkGray) -> some View {
        if let arrow {
            ZStack(alignment: .bottomTrailing) {
                MiniCell(arrow, color: color, foreground: foreground)
                    .openPathCue(
                        isOpen: index == config.highlightIndex,
                        emphasized: true,
                        reduceMotion: reduceMotion,
                        cornerRadius: 13
                    )

                if index == config.highlightIndex {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.ppInkGray)
                        .shadow(color: Color.ppInkGray.opacity(0.18), radius: 6, x: 0, y: 4)
                        .offset(tutorialHandOffset(for: arrow))
                }
            }
        } else {
            MiniEmptyCell()
        }
    }

    private func handleFlick(_ value: DragGesture.Value) {
        guard let direction = Direction.resolveFlick(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation
        ) else {
            return // a tap or too-diagonal drag: no-op, no penalty
        }

        if direction == config.expectedDirection {
            advance()
        } else {
            tries += 1
            withAnimation(.easeInOut(duration: 0.2)) { wrongFlick = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.easeInOut(duration: 0.2)) { wrongFlick = false }
            }
        }
    }

    private func advance() {
        wrongFlick = false
        if isLastStep {
            onComplete()
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                step += 1
                tries = 0
            }
        }
    }

    private var localizedTitle: String { language.text(config.titleEN, config.titleKO) }
    private var localizedSubtitle: String { language.text(config.subtitleEN, config.subtitleKO) }

    private var flickHint: String {
        let directionName = config.expectedDirection.accessibilityName(language: language)
        if wrongFlick {
            return language.text("Flick \(directionName) to clear it", "\(directionName) 방향으로 밀어요")
        }
        return language.text("Flick \(directionName)", "\(directionName)으로 밀어요")
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= currentStep ? Color.ppFreshMint : Color.ppInkGray.opacity(0.15))
                    .frame(width: index == currentStep ? 22 : 6, height: 6)
            }
        }
    }

    private func tutorialHandOffset(for arrow: String) -> CGSize {
        let distance: CGFloat = pulse && !reduceMotion ? 18 : 10
        switch arrow {
        case "▲":
            return CGSize(width: 10, height: 16 - distance)
        case "▼":
            return CGSize(width: 10, height: 4 + distance)
        case "◀":
            return CGSize(width: 16 - distance, height: 14)
        default:
            return CGSize(width: 4 + distance, height: 14)
        }
    }

    private var primaryButtonTitle: String {
        isLastStep ? language.text("Start", "시작") : language.text("Next", "다음")
    }

    private var primaryButtonIcon: String {
        isLastStep ? "play.fill" : "arrow.right"
    }
}

private struct MiniCell: View {
    let arrow: String
    let color: Color
    let foreground: Color

    init(_ arrow: String, color: Color, foreground: Color = .ppInkGray) {
        self.arrow = arrow
        self.color = color
        self.foreground = foreground
    }

    var body: some View {
        ArrowGlyph(arrow: arrow, size: 18)
            .foregroundStyle(foreground)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                    .shadow(color: Color.ppInkGray.opacity(0.12), radius: 8, x: 0, y: 4)
            )
    }
}

private struct MiniEmptyCell: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.ppInkGray.opacity(0.035))
            .frame(width: 52, height: 52)
    }
}

struct SettingsView: View {
    @Environment(\.appLanguage) private var appLanguage

    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var colorAssist: Bool
    @Binding var reduceMotion: Bool
    @Binding var dailyReminderEnabled: Bool
    @Binding var language: AppLanguage
    let onHowToPlay: () -> Void
    let onResetData: () -> Void
    let onBack: () -> Void

    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ppInkGray)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLanguage.text("Back", "뒤로"))

                Text(appLanguage.text("Settings", "설정"))
                    .font(.ppDisplay(25, weight: .semibold, language: appLanguage))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()
            }
            .padding(.top, 18)
            .padding(.bottom, 24)

            // Scrolls so the now-wrapping rows stay reachable at larger Dynamic Type, mirroring
            // Records/Result.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    LanguageSettingRow(language: $language)
                    SettingRow(
                        title: appLanguage.text("Sound", "사운드"),
                        subtitle: appLanguage.text("Soft swipes and round chimes", "스와이프와 라운드 효과음을 재생해요"),
                        isOn: $soundEnabled
                    )
                    SettingRow(
                        title: appLanguage.text("Haptics", "진동"),
                        subtitle: appLanguage.text("Gentle feedback on every swipe", "스와이프마다 짧은 손맛을 줘요"),
                        isOn: $hapticsEnabled
                    )
                    SettingRow(
                        title: appLanguage.text("Open-Path Highlight", "열린 길 강조"),
                        subtitle: appLanguage.text("Brighten and pulse open paths", "열린 길을 더 밝게 강조해요"),
                        isOn: $colorAssist
                    )
                    SettingRow(
                        title: appLanguage.text("Reduce Motion", "움직임 줄이기"),
                        subtitle: appLanguage.text("Keep motion calm and minimal", "움직임을 차분하게 줄여요"),
                        isOn: $reduceMotion
                    )
                    SettingRow(
                        title: appLanguage.text("Daily Reminder", "데일리 알림"),
                        subtitle: appLanguage.text("A nudge each evening to keep your streak", "매일 저녁 연속 기록 알림을 보내요"),
                        isOn: $dailyReminderEnabled
                    )

                    // Replayable tutorial entry, reachable regardless of hasSeenTutorial (H5).
                    SettingsLinkRow(
                        title: appLanguage.text("How to play", "플레이 방법"),
                        subtitle: appLanguage.text("Replay the tutorial", "튜토리얼 다시 보기"),
                        systemImage: "questionmark.circle.fill",
                        action: onHowToPlay
                    )

                    // Confirmed local-data wipe (K9).
                    SettingsLinkRow(
                        title: appLanguage.text("Reset data", "데이터 초기화"),
                        subtitle: appLanguage.text("Clear scores, records, and achievements", "점수·기록·업적을 모두 지워요"),
                        systemImage: "trash.fill",
                        tint: .ppSoftCoral,
                        titleColor: .ppSoftCoral,
                        action: { showResetConfirm = true }
                    )

                    Text("PopPath! v0")
                        .font(.ppBody(12, weight: .semibold, language: appLanguage))
                        .foregroundStyle(Color.ppWarmGray)
                        .padding(.top, 28)
                        .padding(.bottom, 26)
                }
            }
        }
        .ppScreenPadding()
        .confirmationDialog(
            appLanguage.text("Reset all local data?", "모든 데이터를 지울까요?"),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(appLanguage.text("Reset", "초기화"), role: .destructive, action: onResetData)
            Button(appLanguage.text("Cancel", "취소"), role: .cancel) { }
        } message: {
            Text(appLanguage.text(
                "Scores, records, achievements, and streak will be erased. This can't be undone.",
                "점수·기록·업적·연속 기록이 모두 사라져요. 되돌릴 수 없어요."
            ))
        }
    }
}

private struct LanguageSettingRow: View {
    @Environment(\.appLanguage) private var appLanguage
    @Binding var language: AppLanguage

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(appLanguage.text("Language", "언어"))
                    .font(.ppDisplay(17, weight: .semibold, language: appLanguage))
                    .foregroundStyle(Color.ppInkGray)
                Text(appLanguage.text("Switch game text", "말맛을 바꿔요"))
                    .font(.ppBody(13, weight: .medium, language: appLanguage))
                    .foregroundStyle(Color.ppWarmGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            language = option
                        }
                    } label: {
                        Text(option.shortName)
                            .font(.ppBody(12, weight: .heavy, language: option))
                            .foregroundStyle(language == option ? Color.ppMintButtonText : Color.ppWarmGray)
                            .frame(width: 40, height: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(language == option ? Color.ppFreshMint : .clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.displayName)
                    .accessibilityAddTraits(language == option ? [.isSelected] : [])
                }
            }
            .padding(3)
            .background(Capsule(style: .continuous).fill(Color.ppInkGray.opacity(0.08)))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.ppInkGray.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 14, x: 0, y: 7)
        )
    }
}

private struct SettingRow: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.ppDisplay(17, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray)
                    .fixedSize(horizontal: false, vertical: true)
                // Wraps instead of clamping to one line so larger Dynamic Type sizes stay
                // readable (I6).
                Text(subtitle)
                    .font(.ppBody(13, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    isOn.toggle()
                }
            } label: {
                Capsule(style: .continuous)
                    .fill(isOn ? Color.ppFreshMint : Color.ppInkGray.opacity(0.14))
                    .frame(width: 48, height: 28)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: Color.ppInkGray.opacity(0.18), radius: 6, x: 0, y: 2)
                            .padding(3)
                    }
                    // Keep the switch glyph compact but give it a ≥44pt hit target (G4).
                    .frame(width: 56, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? language.text("On", "켬") : language.text("Off", "끔"))
            .accessibilityAddTraits(.isToggle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.ppInkGray.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 14, x: 0, y: 7)
        )
    }
}

/// A tappable settings row that performs a navigational action (e.g. replay the tutorial),
/// styled to match `SettingRow`.
private struct SettingsLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .ppMintText
    var titleColor: Color = .ppInkGray
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.ppDisplay(17, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.ppBody(13, weight: .medium))
                        .foregroundStyle(Color.ppWarmGray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ppCardCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.ppInkGray.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.ppInkGray.opacity(0.08), radius: 14, x: 0, y: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
