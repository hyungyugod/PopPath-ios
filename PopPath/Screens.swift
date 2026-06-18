import SwiftUI

struct HomeView: View {
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

                Text("Open the path. Pop the chain.")
                    .font(.ppDisplay(14, weight: .medium))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.top, 6)

                Spacer(minLength: isShort ? 20 : 30)

                PillStat(label: "BEST", value: best.formatted())
                    .padding(.bottom, isShort ? 10 : 12)

                HStack(spacing: 8) {
                    MiniRecordStat(label: "RUNS", value: stats.roundsPlayed.formatted())
                    MiniRecordStat(label: "AVG", value: stats.averageScore.formatted())
                    MiniRecordStat(label: "ACH", value: "\(achievementCount)/\(AchievementCatalog.all.count)")
                }
                .padding(.bottom, isShort ? 14 : 18)

                PrimaryPopButton("Play", systemImage: "play.fill", action: onPlay)

                SecondaryPopButton(
                    title: "Daily Challenge",
                    detail: dailyBest > 0 ? "BEST \(dailyBest.formatted())" : "TODAY \(dailyLabel)",
                    systemImage: "calendar",
                    action: onDaily
                )
                .padding(.top, isShort ? 10 : 12)

                SecondaryPopButton(
                    title: "Records",
                    detail: "\(achievementCount)/\(AchievementCatalog.all.count) ACH",
                    systemImage: "chart.bar.fill",
                    action: onRecords
                )
                .padding(.top, isShort ? 8 : 10)

                HStack(spacing: 12) {
                    IconTileButton(
                        systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        accessibilityLabel: soundEnabled ? "Sound on" : "Sound off",
                        action: onToggleSound
                    )
                    IconTileButton(
                        systemName: "gearshape.fill",
                        accessibilityLabel: "Settings",
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
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.ppDisplay(15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.ppBody(9, weight: .heavy))
                .tracking(0.6)
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
            Text(summary.mode == .daily ? "Daily complete" : "Time's up")
                .font(.ppDisplay(15, weight: .medium))
                .foregroundStyle(Color.ppWarmGray)

            Text(headline)
                .font(.ppDisplay(24, weight: .semibold))
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.top, 2)

            Text(summary.score.formatted())
                .font(.ppDisplay(64, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 16)

            Text("SCORE")
                .font(.ppBody(12, weight: .heavy))
                .tracking(0.72)
                .foregroundStyle(Color.ppWarmGray)
                .padding(.top, 2)

            if summary.isNewBest || summary.isNewDailyBest {
                Label(summary.isNewDailyBest ? "New daily best" : "New personal best", systemImage: "crown.fill")
                    .font(.ppDisplay(13, weight: .semibold))
                    .foregroundStyle(Color.ppMintButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule(style: .continuous).fill(Color.ppFreshMint))
                    .padding(.top, 14)
            }

            HStack(spacing: 10) {
                ResultStatCard(
                    value: resultBestValue,
                    label: summary.mode == .daily ? "DAILY BEST" : "BEST"
                )
                ResultStatCard(value: "×\(summary.maxChain)", label: "MAX CHAIN", valueColor: .ppMintText)
            }
            .padding(.top, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                spacing: 10
            ) {
                ResultStatCard(value: "\(summary.metrics.unlocks)", label: "UNLOCKS", valueColor: .ppMintText)
                ResultStatCard(value: "\(summary.metrics.accuracyPercent)%", label: "ACCURACY")
                ResultStatCard(value: "\(summary.metrics.boardClears)", label: "CLEARS")
                ResultStatCard(value: "LV \(summary.metrics.difficultyPeak + 1)", label: "PEAK")
            }
            .padding(.top, 10)

            if !summary.unlockedAchievements.isEmpty {
                VStack(spacing: 8) {
                    Text("NEW ACHIEVEMENTS")
                        .font(.ppBody(10, weight: .heavy))
                        .tracking(0.8)
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
                ShareLink(item: summary.shareText) {
                    ResultActionButton(title: "Share", systemImage: "square.and.arrow.up", style: .secondary)
                }

                Button(action: onRetry) {
                    ResultActionButton(title: "Retry", systemImage: "arrow.clockwise", style: .primary)
                }
                .buttonStyle(.plain)
            }

            Button("Home", action: onHome)
                .font(.ppDisplay(15, weight: .semibold))
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
            return "Best run yet!"
        }
        return summary.mode == .daily ? "Today's run!" : "Nice run!"
    }

    private var resultBestValue: String {
        if summary.mode == .daily {
            return (summary.dailyBest ?? summary.score).formatted()
        }

        return summary.best.formatted()
    }
}

private struct ResultActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.ppDisplay(17, weight: .semibold))
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
    let value: String
    let label: String
    var valueColor: Color = .ppInkGray

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.ppDisplay(22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.ppBody(10, weight: .heavy))
                .tracking(0.8)
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
                    .accessibilityLabel("Back")

                    Text("Records")
                        .font(.ppDisplay(24, weight: .semibold))
                        .foregroundStyle(Color.ppInkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer()
                }
                .padding(.top, 18)
                .padding(.bottom, 22)

                HStack(spacing: 10) {
                    ResultStatCard(value: stats.bestScore.formatted(), label: "BEST")
                    ResultStatCard(value: "\(unlockedCount)/\(achievements.count)", label: "ACHIEVEMENTS", valueColor: .ppMintText)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    RecordMetricTile(title: "Rounds", value: stats.roundsPlayed.formatted(), icon: "flag.fill")
                    RecordMetricTile(title: "Average", value: stats.averageScore.formatted(), icon: "chart.line.uptrend.xyaxis")
                    RecordMetricTile(title: "Best Chain", value: "×\(stats.bestChain)", icon: "link")
                    RecordMetricTile(title: "Accuracy", value: "\(stats.bestAccuracy)%", icon: "scope")
                    RecordMetricTile(title: "Pops", value: stats.totalPops.formatted(), icon: "hand.tap.fill")
                    RecordMetricTile(title: "Unlocks", value: stats.totalUnlocks.formatted(), icon: "key.fill")
                    RecordMetricTile(title: "Board Clears", value: stats.totalBoardClears.formatted(), icon: "rectangle.grid.2x2.fill")
                    RecordMetricTile(title: "Daily Best", value: stats.bestDailyScore.formatted(), icon: "calendar")
                }
                .padding(.top, 12)

                VStack(spacing: 8) {
                    Text("ACHIEVEMENTS")
                        .font(.ppBody(10, weight: .heavy))
                        .tracking(0.8)
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
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ppMintText)

            Text(value)
                .font(.ppDisplay(22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.ppInkGray)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.ppBody(10, weight: .heavy))
                .tracking(0.65)
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
                Text(achievement.title)
                    .font(.ppDisplay(15, weight: .semibold))
                    .foregroundStyle(Color.ppInkGray.opacity(unlocked ? 1 : 0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(achievement.subtitle)
                    .font(.ppBody(11, weight: .medium))
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

struct TutorialView: View {
    let reduceMotion: Bool
    let onComplete: () -> Void
    @State private var step = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            miniBoard

            Text("Trace the arrow to the edge")
                .font(.ppDisplay(15, weight: .medium))
                .foregroundStyle(Color.ppWarmCream)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Color.ppInkGray))
                .shadow(color: Color.ppInkGray.opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.top, 40)

            Text("막히지 않은 길을 찾아요")
                .font(.ppBody(12, weight: .medium))
                .foregroundStyle(Color.ppWarmGray)
                .padding(.top, 14)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index <= step ? Color.ppFreshMint : Color.ppInkGray.opacity(0.15))
                        .frame(width: index == step ? 22 : 6, height: 6)
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
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(52), spacing: 8), count: 4),
            spacing: 8
        ) {
            MiniCell("▲", color: .ppMistBlue)
            MiniEmptyCell()
            MiniCell("▼", color: .ppLavenderMist)
            MiniCell("◀", color: .ppMistBlue)
            MiniEmptyCell()
            Button(action: tapTutorialBlock) {
                ZStack(alignment: .bottomTrailing) {
                    MiniCell("▶", color: .ppFreshMint, foreground: .ppMintButtonText)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(
                                    Color.ppFreshMint.opacity(pulse && !reduceMotion ? 0.42 : 0.95),
                                    lineWidth: pulse && !reduceMotion ? 7 : 3
                                )
                        }

                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.ppInkGray)
                        .shadow(color: Color.ppInkGray.opacity(0.18), radius: 6, x: 0, y: 4)
                        .offset(x: 12, y: 15)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap glowing block")
            MiniCell("▲", color: .ppLavenderMist)
            MiniCell("▶", color: .ppMistBlue)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppSoftSage)
                .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }

    private func tapTutorialBlock() {
        if step >= 2 {
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
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var colorAssist: Bool
    @Binding var reduceMotion: Bool
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
                .accessibilityLabel("Back")

                Text("Settings")
                    .font(.ppDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()
            }
            .padding(.top, 18)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                SettingRow(title: "Sound", subtitle: "Soft taps and round chimes", isOn: $soundEnabled)
                SettingRow(title: "Haptics", subtitle: "Gentle feedback on every pop", isOn: $hapticsEnabled)
                SettingRow(title: "Color Assist", subtitle: "Show open-path outlines", isOn: $colorAssist)
                SettingRow(title: "Reduce Motion", subtitle: "Keep motion calm and minimal", isOn: $reduceMotion)
            }

            Spacer()

            Text("PopPath! v0")
                .font(.ppBody(12, weight: .semibold))
                .foregroundStyle(Color.ppWarmGray)
                .padding(.bottom, 26)
        }
        .ppScreenPadding()
    }
}

private struct SettingRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.ppDisplay(16, weight: .semibold))
                    .foregroundStyle(Color.ppInkGray)
                Text(subtitle)
                    .font(.ppBody(12, weight: .medium))
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
            .accessibilityValue(isOn ? "On" : "Off")
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
