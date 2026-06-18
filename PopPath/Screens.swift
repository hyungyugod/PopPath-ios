import SwiftUI

struct HomeView: View {
    @Environment(\.appLanguage) private var language

    let best: Int
    let dailyBest: Int
    let dailyLabel: String
    let stats: PlayerStats
    let achievementCount: Int
    let soundEnabled: Bool
    let onToggleSound: () -> Void
    let onPlay: () -> Void
    let onDaily: () -> Void
    let onSettings: () -> Void
    let onRecords: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let isShort = proxy.size.height < 680

            VStack(spacing: 0) {
                Spacer(minLength: isShort ? 22 : 42)

                DecorativeBlockCluster()
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

                Text(language.text("Open the path. Pop the chain.", "길을 열고, 체인 팡!"))
                    .font(.ppDisplay(15, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.top, 6)

                Spacer(minLength: isShort ? 20 : 30)

                PillStat(label: language.text("BEST", "최고"), value: best.formatted())
                    .padding(.bottom, isShort ? 10 : 12)

                HStack(spacing: 8) {
                    MiniRecordStat(label: language.text("RUNS", "판수"), value: stats.roundsPlayed.formatted())
                    MiniRecordStat(label: language.text("AVG", "평균"), value: stats.averageScore.formatted())
                    MiniRecordStat(label: language.text("ACH", "업적"), value: "\(achievementCount)/\(AchievementCatalog.all.count)")
                }
                .padding(.bottom, isShort ? 14 : 18)

                PrimaryPopButton(language.text("Play", "플레이"), systemImage: "play.fill", action: onPlay)

                SecondaryPopButton(
                    title: language.text("Daily Challenge", "오늘의 길"),
                    detail: dailyBest > 0
                        ? "\(language.text("BEST", "최고")) \(dailyBest.formatted())"
                        : "\(language.text("TODAY", "오늘")) \(dailyLabel)",
                    systemImage: "calendar",
                    action: onDaily
                )
                .padding(.top, isShort ? 10 : 12)

                SecondaryPopButton(
                    title: language.text("Records", "기록"),
                    detail: "\(achievementCount)/\(AchievementCatalog.all.count) \(language.text("ACH", "업적"))",
                    systemImage: "chart.bar.fill",
                    action: onRecords
                )
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
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
                ResultStatCard(value: "LV \(summary.metrics.difficultyPeak + 1)", label: language.text("PEAK", "최고 단계"))
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

                Button(action: onRetry) {
                    ResultActionButton(title: language.text("Retry", "다시"), systemImage: "arrow.clockwise", style: .primary)
                }
                .buttonStyle(.plain)
            }

            Button(language.text("Home", "홈"), action: onHome)
                .font(.ppDisplay(15, weight: .semibold, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .lineLimit(1)
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
                            .frame(width: 38, height: 38)
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

                HStack(spacing: 10) {
                    ResultStatCard(value: stats.bestScore.formatted(), label: language.text("BEST", "최고"))
                    ResultStatCard(value: "\(unlockedCount)/\(achievements.count)", label: language.text("ACHIEVEMENTS", "업적"), valueColor: .ppMintText)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    RecordMetricTile(title: language.text("Rounds", "판수"), value: stats.roundsPlayed.formatted(), icon: "flag.fill")
                    RecordMetricTile(title: language.text("Average", "평균"), value: stats.averageScore.formatted(), icon: "chart.line.uptrend.xyaxis")
                    RecordMetricTile(title: language.text("Best Chain", "최고 체인"), value: "×\(stats.bestChain)", icon: "link")
                    RecordMetricTile(title: language.text("Accuracy", "정확도"), value: "\(stats.bestAccuracy)%", icon: "scope")
                    RecordMetricTile(title: language.text("Pops", "팡"), value: stats.totalPops.formatted(), icon: "hand.tap.fill")
                    RecordMetricTile(title: language.text("Unlocks", "길 열림"), value: stats.totalUnlocks.formatted(), icon: "key.fill")
                    RecordMetricTile(title: language.text("Board Clears", "싹쓸이"), value: stats.totalBoardClears.formatted(), icon: "rectangle.grid.2x2.fill")
                    RecordMetricTile(title: language.text("Daily Best", "오늘 최고"), value: stats.bestDailyScore.formatted(), icon: "calendar")
                }
                .padding(.top, 12)

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
            return "첫 팡"
        case "score_500":
            return "워밍업"
        case "score_1000":
            return "길 고수"
        case "chain_5":
            return "체인 착착"
        case "chain_10":
            return "팡팡 모드"
        case "clean_run":
            return "노 미스"
        case "unlock_5":
            return "길잡이"
        case "path_burst":
            return "길이 팡!"
        case "clear_2":
            return "싹쓸이"
        case "daily_first":
            return "오늘도 출석"
        case "ten_rounds":
            return "열 판째!"
        case "hundred_pops":
            return "백 번 팡"
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
        case "chain_5":
            return "체인 x5 달성"
        case "chain_10":
            return "체인 x10 달성"
        case "clean_run":
            return "실수 없이 마무리"
        case "unlock_5":
            return "한 판에서 길 5개 열기"
        case "path_burst":
            return "한 번에 길 3개 열기"
        case "clear_2":
            return "한 판에서 2번 싹쓸이"
        case "daily_first":
            return "오늘의 길 마무리"
        case "ten_rounds":
            return "10판 마무리"
        case "hundred_pops":
            return "블록 100개 팡"
        default:
            return subtitle
        }
    }
}

struct TutorialView: View {
    @Environment(\.appLanguage) private var language

    let reduceMotion: Bool
    let onComplete: () -> Void
    @State private var step = 0
    @State private var pulse = false
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            miniBoard

            Text(title)
                .font(.ppDisplay(16, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmCream)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Color.ppInkGray))
                .shadow(color: Color.ppInkGray.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.top, 40)

            Text(subtitle)
                .font(.ppBody(13, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 14)

            Spacer()

            PrimaryPopButton(primaryButtonTitle, systemImage: primaryButtonIcon, action: advanceTutorial)
                .padding(.bottom, 18)

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index <= currentStep ? Color.ppFreshMint : Color.ppInkGray.opacity(0.15))
                        .frame(width: index == currentStep ? 22 : 6, height: 6)
                }
            }
            .padding(.bottom, 28)
        }
        .ppScreenPadding()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var miniBoard: some View {
        Button(action: advanceTutorial) {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonTitle)
    }

    @ViewBuilder
    private func tutorialCell(index: Int, arrow: String?, color: Color, foreground: Color = .ppInkGray) -> some View {
        if let arrow {
            ZStack(alignment: .bottomTrailing) {
                MiniCell(arrow, color: color, foreground: foreground)
                    .overlay {
                        if index == highlightedIndex {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    Color.ppFreshMint.opacity(pulse && !reduceMotion ? 0.42 : 0.95),
                                    lineWidth: pulse && !reduceMotion ? 7 : 3
                                )
                        }
                    }

                if index == highlightedIndex {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.ppInkGray)
                        .shadow(color: Color.ppInkGray.opacity(0.18), radius: 6, x: 0, y: 4)
                        .offset(x: 12, y: 15)
                }
            }
        } else {
            MiniEmptyCell()
        }
    }

    private var currentStep: Int {
        min(step, totalSteps - 1)
    }

    private var highlightedIndex: Int {
        [5, 2, 7][currentStep]
    }

    private var title: String {
        switch currentStep {
        case 0:
            return language.text("Trace the arrow to the edge", "화살표를 끝까지 톡!")
        case 1:
            return language.text("Clear paths to unlock more", "막힌 길을 하나씩 열어요")
        default:
            return language.text("Chain clean pops for a high score", "연속 팡으로 점수 쑥!")
        }
    }

    private var subtitle: String {
        switch currentStep {
        case 0:
            return language.text("Find a clear path.", "가장자리까지 뚫린 길을 찾아요")
        case 1:
            return language.text("A good order opens new paths.", "순서를 잘 고르면 길이 생겨요")
        default:
            return language.text("Every clean pop keeps the chain alive.", "막히지 않고 터뜨리면 체인이 이어져요")
        }
    }

    private var primaryButtonTitle: String {
        currentStep == totalSteps - 1 ? language.text("Start", "시작") : language.text("Next", "다음")
    }

    private var primaryButtonIcon: String {
        currentStep == totalSteps - 1 ? "play.fill" : "arrow.right"
    }

    private func advanceTutorial() {
        if currentStep >= totalSteps - 1 {
            onComplete()
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                step += 1
            }
        }
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
    @Binding var language: AppLanguage
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ppInkGray)
                        .frame(width: 38, height: 38)
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

            VStack(spacing: 12) {
                LanguageSettingRow(language: $language)
                SettingRow(
                    title: appLanguage.text("Sound", "사운드"),
                    subtitle: appLanguage.text("Soft taps and round chimes", "탭과 라운드 효과음을 재생해요"),
                    isOn: $soundEnabled
                )
                SettingRow(
                    title: appLanguage.text("Haptics", "진동"),
                    subtitle: appLanguage.text("Gentle feedback on every pop", "팝마다 짧은 손맛을 줘요"),
                    isOn: $hapticsEnabled
                )
                SettingRow(
                    title: appLanguage.text("Color Assist", "색상 보조"),
                    subtitle: appLanguage.text("Show open-path outlines", "열린 길을 테두리로 표시해요"),
                    isOn: $colorAssist
                )
                SettingRow(
                    title: appLanguage.text("Reduce Motion", "움직임 줄이기"),
                    subtitle: appLanguage.text("Keep motion calm and minimal", "움직임을 차분하게 줄여요"),
                    isOn: $reduceMotion
                )
            }

            Spacer()

            Text("PopPath! v0")
                .font(.ppBody(12, weight: .semibold, language: appLanguage))
                .foregroundStyle(Color.ppWarmGray)
                .padding(.bottom, 26)
        }
        .ppScreenPadding()
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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
                            .frame(width: 38, height: 28)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(language == option ? Color.ppFreshMint : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.displayName)
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
                Text(subtitle)
                    .font(.ppBody(13, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? language.text("On", "켬") : language.text("Off", "끔"))
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
