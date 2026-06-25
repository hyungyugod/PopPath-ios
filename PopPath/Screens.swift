import SwiftUI
import UIKit

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

    @State private var showGuide = false
    @State private var showTiers = false

    private var isFirstTime: Bool { stats.roundsPlayed == 0 }
    /// The player's current rank, derived from their best score — drives the tappable badge.
    private var bestGrade: Grade { Grade.forScore(best) }

    private var dailyDetail: String {
        if isDailyCompletedToday {
            let streak = stats.currentStreak > 0
                ? language.text(" · streak \(stats.currentStreak)", " · \(stats.currentStreak)연속")
                : ""
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
                Color.clear
                    .frame(height: isShort ? 12 : 64)

                DecorativeBlockCluster()
                    .accessibilityHidden(true)
                    .padding(.bottom, isShort ? 14 : 20)

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

                Color.clear
                    .frame(height: isShort ? 14 : 24)

                if isFirstTime {
                    HomeFirstRunHook(isShort: isShort)
                        .padding(.bottom, isShort ? 12 : 16)
                } else {
                    PillStat(label: language.text("BEST", "최고"), value: best.formatted())
                        .padding(.bottom, 8)

                    Button { showTiers = true } label: {
                        HStack(spacing: 6) {
                            GradeBadge(grade: bestGrade, compact: true)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.ppWarmGray)
                        }
                        // Keep the badge visually compact but give the tap a ≥44pt target (G4).
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(language.text(
                        "Your grade: \(bestGrade.nameEN). View all tiers.",
                        "내 등급: \(bestGrade.nameKO). 전체 티어 보기."
                    ))
                    .accessibilityAddTraits(.isButton)
                    .padding(.bottom, isShort ? 10 : 12)

                    HStack(spacing: 8) {
                        MiniRecordStat(label: language.text("RUNS", "판수"), value: stats.roundsPlayed.formatted())
                        MiniRecordStat(label: language.text("AVG", "평균"), value: stats.averageScore.formatted())
                        MiniRecordStat(
                            label: language.text("STREAK", "연속"),
                            value: stats.currentStreak > 0 ? stats.currentStreak.formatted() : "—"
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
                        systemName: "questionmark.circle.fill",
                        accessibilityLabel: language.text("How blocks work", "블록 안내"),
                        action: { showGuide = true }
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ppScreenPadding()
        .sheet(isPresented: $showGuide) {
            // Re-inject the language: a sheet is a new presentation context and won't always
            // inherit the custom appLanguage environment key.
            BlockGuideSheet()
                .environment(\.appLanguage, language)
        }
        .sheet(isPresented: $showTiers) {
            TierLadderSheet(best: best)
                .environment(\.appLanguage, language)
        }
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

private struct HomeFirstRunHook: View {
    @Environment(\.appLanguage) private var language

    let isShort: Bool

    var body: some View {
        HStack(spacing: isShort ? 12 : 14) {
            HomeBoardPreview()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Label(language.text("Today's goal", "오늘 목표"), systemImage: "target")
                    .font(.ppBody(11, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintText)
                    .lineLimit(1)

                Text(language.text("Chase a 3-pop chain", "3연속 체인에 도전"))
                    .font(.ppDisplay(isShort ? 16 : 18, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(language.text("First record starts here", "첫 기록은 한 판이면 충분해요"))
                    .font(.ppBody(12, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isShort ? 10 : 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ppSoftSage)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.ppMintText.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(
            "Today's goal: chase a 3-pop chain. First record starts here.",
            "오늘 목표: 3연속 체인에 도전. 첫 기록은 한 판이면 충분해요."
        ))
    }
}

private struct HomeBoardPreview: View {
    private let cells: [[Direction?]] = [
        [nil, .right, nil, nil],
        [.up, .up, .up, nil]
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<cells.count, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(0..<cells[row].count, id: \.self) { column in
                        if let direction = cells[row][column] {
                            HomePreviewCell(direction: direction, isOpen: row == 1 && column < 3)
                        } else {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.ppInkGray.opacity(0.05))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.ppCardCream)
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

private struct HomePreviewCell: View {
    let direction: Direction
    let isOpen: Bool

    var body: some View {
        ArrowGlyph(arrow: direction.arrow, size: 10)
            .foregroundStyle(Color.ppInkGray)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOpen ? Color.ppFreshMint.opacity(0.78) : Color.ppMistBlue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(isOpen ? Color.ppMintText.opacity(0.35) : Color.clear, lineWidth: 1.5)
                    )
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

/// One row of the home block guide: a real block face / board chip + name + one-line ability.
struct BlockGuideEntry: Identifiable, Equatable {
    let id: String
    let face: GuideFaceKind
    var direction: Direction = .right
    var tone: BlockTone = .mistBlue
    let titleEN: String
    let titleKO: String
    let detailEN: String
    let detailKO: String

    /// Teaching order: the base rule, then the three specials, then the two board modifiers
    /// (rendered as chips, since modifiers are board states rather than blocks).
    static let all: [BlockGuideEntry] = [
        BlockGuideEntry(
            id: "normal", face: .block(.normal, cracked: false), tone: .mistBlue,
            titleEN: "Normal", titleKO: "기본 블록",
            detailEN: "Tap it, or flick the way its arrow points.",
            detailKO: "톡 누르거나 화살표 방향으로 밀어요."
        ),
        BlockGuideEntry(
            id: "bomb", face: .block(.bomb, cracked: false), tone: .lavenderMist,
            titleEN: "Bomb", titleKO: "폭탄",
            detailEN: "Pops, then clears its whole row and column.",
            detailKO: "팡 하고 같은 가로·세로 줄을 정리해요."
        ),
        BlockGuideEntry(
            id: "armored", face: .block(.armored, cracked: false), direction: .up, tone: .mistBlue,
            titleEN: "Armored", titleKO: "단단한 블록",
            detailEN: "Two taps to break — the first only cracks it.",
            detailKO: "두 번 눌러야 깨져요 — 처음엔 금만 가요."
        ),
        BlockGuideEntry(
            id: "wild", face: .block(.wild, cracked: false), tone: .lavenderMist,
            titleEN: "Wild", titleKO: "만능 블록",
            detailEN: "Tap it, or flick any open direction.",
            detailKO: "톡 누르거나 열린 쪽으로 밀어요."
        ),
        BlockGuideEntry(
            id: "rush", face: .modifier(.rush),
            titleEN: "Rush board", titleKO: "러시 보드",
            detailEN: "Double points, but chains fade faster.",
            detailKO: "점수 2배 — 대신 체인이 빨리 식어요."
        ),
        BlockGuideEntry(
            id: "bonus", face: .modifier(.bonus),
            titleEN: "Bonus board", titleKO: "보너스 보드",
            detailEN: "Big clear bonus and extra time.",
            detailKO: "클리어 보너스와 추가 시간!"
        )
    ]
}

/// A glance-and-dismiss reference, reachable from Home, showing what each block / board does —
/// every row previews the same `BlockFace` the live board draws, so players recognize them.
struct BlockGuideSheet: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(language.text("How blocks work", "블록 설명"))
                    .font(.ppDisplay(22, weight: .bold, language: language))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ppInkGray.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.ppCardCream)
                                .shadow(color: Color.ppInkGray.opacity(0.11), radius: 9, x: 0, y: 4)
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("Close", "닫기"))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(BlockGuideEntry.all) { entry in
                        BlockGuideRow(entry: entry)
                    }

                    // Reassures that the new tints are a bonus cue, not the only one (the badge
                    // and shape carry the meaning) — the colorblind-safety promise, stated plainly.
                    Text(language.text(
                        "Color is a bonus hint — the badge and shape tell you the kind.",
                        "색은 보조 힌트예요 — 모양과 배지로 구분해요."
                    ))
                    .font(.ppBody(12, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
        .ppScreenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ppWarmCream.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct BlockGuideRow: View {
    @Environment(\.appLanguage) private var language
    let entry: BlockGuideEntry

    var body: some View {
        HStack(spacing: 14) {
            GuideFace(kind: entry.face, direction: entry.direction, tone: entry.tone, side: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(language.text(entry.titleEN, entry.titleKO))
                    .font(.ppDisplay(16, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(language.text(entry.detailEN, entry.detailKO))
                    .font(.ppBody(13, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.ppInkGray.opacity(0.06), lineWidth: 1)
                )
        )
        // One combined element so VoiceOver reads "Bomb, Pops then clears its whole row and column."
        .accessibilityElement(children: .combine)
    }
}

/// The full rank ladder, reachable by tapping the grade badge on Home. Lists every tier with its
/// score band, highest first, and highlights the row the player's best score currently sits in.
struct TierLadderSheet: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    let best: Int

    private var currentTier: Int { Grade.forScore(best).tier }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("Tiers", "티어표"))
                        .font(.ppDisplay(22, weight: .bold, language: language))
                        .foregroundStyle(Color.ppInkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(language.text("By your best score", "최고 점수 기준"))
                        .font(.ppBody(12, weight: .medium, language: language))
                        .foregroundStyle(Color.ppWarmGray)
                }

                Spacer(minLength: 8)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ppInkGray.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.ppCardCream)
                                .shadow(color: Color.ppInkGray.opacity(0.11), radius: 9, x: 0, y: 4)
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("Close", "닫기"))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Grade.allTiers.reversed(), id: \.tier) { grade in
                        TierLadderRow(grade: grade, isCurrent: grade.tier == currentTier, best: best)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .ppScreenPadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ppWarmCream.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct TierLadderRow: View {
    @Environment(\.appLanguage) private var language
    let grade: Grade
    let isCurrent: Bool
    let best: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(grade.badgeColor)
                Image(systemName: grade.badgeSymbol)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(grade.badgeTextColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(grade.name(language: language))
                    .font(.ppDisplay(16, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(rangeText)
                    .font(.ppBody(12, weight: .medium, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)

            if isCurrent {
                Text(language.text("YOU \(best.formatted())", "현재 \(best.formatted())점"))
                    .font(.ppBody(11, weight: .heavy, language: language))
                    .monospacedDigit()
                    .foregroundStyle(grade.badgeTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(grade.badgeColor))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            // 0.10 (not 0.14) keeps the warmGray range text ≥4.5:1 on every tier's tint (G5);
            // the 2pt colored border + "현재" chip still make the player's row pop.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? grade.badgeColor.opacity(0.10) : Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isCurrent ? grade.badgeColor.opacity(0.55) : Color.ppInkGray.opacity(0.06),
                            lineWidth: isCurrent ? 2 : 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    /// The tier's score band: "lo–hi" for ranked tiers, "lo+" for the top tier, "0–hi" for Rookie.
    private var rangeText: String {
        let lo = grade.threshold
        guard let next = grade.next else {
            return language.text("\(lo.formatted())+", "\(lo.formatted())점 이상")
        }
        let hi = next.threshold - 1
        return language.text("\(lo.formatted())–\(hi.formatted())", "\(lo.formatted())~\(hi.formatted())점")
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
                    .padding(.bottom, 34)
            }
            .ppScreenPadding()

            resultActions
        }
    }

    private var resultContent: some View {
        VStack(spacing: 0) {
            if summary.isPractice {
                Label(language.text("Practice — not recorded", "연습 — 기록 안 됨"), systemImage: "graduationcap.fill")
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintButtonText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule(style: .continuous).fill(Color.ppFreshMint))
                    .padding(.bottom, 12)
            }

            Text(modeHeadline)
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

            // Score-based rank medal for this run, with a nudge toward the next tier.
            GradeBadge(grade: grade)
                .padding(.top, 16)

            Text(gradeProgressText)
                .font(.ppBody(12, weight: .semibold, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)

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

            if summary.mode == .daily, !summary.isPractice, summary.lifetimeStats.currentStreak > 0 {
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
        HStack(spacing: 10) {
            ShareLink(item: summary.shareText(language: language)) {
                ResultActionButton(title: language.text("Share", "공유"), systemImage: "square.and.arrow.up", style: .secondary)
            }

            Button(action: onHome) {
                ResultActionButton(
                    title: language.text("Home", "홈"),
                    systemImage: "house.fill",
                    style: canRetry ? .secondary : .primary
                )
            }
            .buttonStyle(.plain)

            if canRetry {
                Button(action: onRetry) {
                    ResultActionButton(title: language.text("Retry", "다시"), systemImage: "arrow.clockwise", style: .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .ppScreenPadding()
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.ppWarmCream)
                .shadow(color: Color.ppInkGray.opacity(0.08), radius: 14, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// This run's rank, derived purely from its score.
    private var grade: Grade { Grade.forScore(summary.score) }

    /// Either how far to the next tier, or a top-grade flourish at Grandmaster.
    private var gradeProgressText: String {
        guard let toNext = grade.pointsToNext(from: summary.score), let next = grade.next else {
            return language.text("Top grade reached!", "최고 등급 달성!")
        }
        return language.text(
            "\(toNext.formatted()) to \(next.nameEN)",
            "\(next.nameKO)까지 \(toNext.formatted())점"
        )
    }

    /// The small mode line above the headline. A practice run is neutral — it didn't "complete"
    /// the Daily (the day is still playable) — so it never claims "Daily complete".
    private var modeHeadline: String {
        if summary.isPractice {
            return language.text("Practice run", "연습 완료")
        }
        return summary.mode == .daily
            ? language.text("Daily complete", "오늘 길 완료!")
            : language.text("Time's up", "시간 끝!")
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
            .font(.ppDisplay(16, weight: .semibold, language: language))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
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
    let onPlay: () -> Void
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

                if stats.roundsPlayed == 0 {
                    RecordsZeroStateGoal(onPlay: onPlay)
                        .padding(.top, 12)
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
                    RecordMetricTile(title: language.text("Best Streak", "최고 연속"), value: stats.longestStreak.formatted(), icon: "flame.fill")
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

private struct RecordsZeroStateGoal: View {
    @Environment(\.appLanguage) private var language

    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ppMintButtonText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.ppFreshMint))

                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text("First record: one run", "첫 기록까지 한 판"))
                        .font(.ppDisplay(17, weight: .semibold, language: language))
                        .foregroundStyle(Color.ppInkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(language.text("Nearest badge: First Swipe", "가장 가까운 업적: 첫 스와이프"))
                        .font(.ppBody(12, weight: .medium, language: language))
                        .foregroundStyle(Color.ppWarmGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 0)
            }

            Button(action: onPlay) {
                Label(language.text("Play first run", "첫 판 플레이"), systemImage: "play.fill")
                    .font(.ppDisplay(15, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppMintButtonText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.ppFreshMint)
                            .shadow(color: Color.ppMintText.opacity(0.16), radius: 10, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(language.text("Starts a Classic run", "클래식 한 판을 시작해요"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.ppSoftSage)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.ppMintText.opacity(0.12), lineWidth: 1)
                )
        )
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

/// A single cell on the tutorial's small practice board.
struct TutorialCell: Equatable {
    var direction: Direction
    var tone: BlockTone
}

/// One interactive lesson: a real (small) board plus the ordered cells the player pops to
/// finish it. The engine validates flicks against the *actual* escapability rule on this board,
/// so the tutorial can only ever teach a legal move — and each correct flick visibly slides the
/// block off its edge and clears the lane behind it.
struct TutorialStage: Equatable {
    let titleEN: String
    let titleKO: String
    let subtitleEN: String
    let subtitleKO: String
    let board: [[TutorialCell?]]
    /// Cells to pop, in order; the head is the currently-highlighted target. Each is popped in
    /// its own arrow direction.
    let moves: [BoardPosition]
    var teachesChain = false
}

/// One row of the non-interactive heads-up card that introduces special blocks / boards.
struct TutorialInfoItem: Equatable {
    let systemImage: String
    let titleEN: String
    let titleKO: String
    let detailEN: String
    let detailKO: String
    /// When set, the row previews the REAL block face / board chip (the same pixels the live
    /// board draws) instead of a generic SF Symbol — so a player recognizes these in-game. Left
    /// optional with a default so the `systemImage` stays a back-compat fallback.
    var faceKind: GuideFaceKind? = nil
}

struct TutorialInfo: Equatable {
    let titleEN: String
    let titleKO: String
    let subtitleEN: String
    let subtitleKO: String
    let items: [TutorialInfoItem]
}

enum TutorialPage: Equatable {
    case board(TutorialStage)
    case info(TutorialInfo)
}

enum TutorialContent {
    static let columns = 4

    /// Same rule as the live game, on a small grid: a block escapes only if its arrow has a
    /// clear runway to the board edge. The tutorial engine validates every flick against this,
    /// so it can never teach a move the real game would reject.
    static func isEscapable(on board: [[TutorialCell?]], at pos: BoardPosition) -> Bool {
        guard board.indices.contains(pos.row),
              board[pos.row].indices.contains(pos.column),
              let cell = board[pos.row][pos.column]
        else {
            return false
        }
        let step = cell.direction.delta
        var row = pos.row + step.row
        var column = pos.column + step.column
        while board.indices.contains(row), board[row].indices.contains(column) {
            if board[row][column] != nil { return false }
            row += step.row
            column += step.column
        }
        return true
    }

    private static func grid(_ rows: [[Direction?]]) -> [[TutorialCell?]] {
        rows.enumerated().map { rowIndex, row in
            row.enumerated().map { columnIndex, direction in
                direction.map {
                    TutorialCell(
                        direction: $0,
                        tone: (rowIndex + columnIndex).isMultiple(of: 2) ? .mistBlue : .lavenderMist
                    )
                }
            }
        }
    }

    /// Lesson 1: a lone block with a clear lane — flick the way the arrow points and watch it
    /// slide off the edge. Lesson 2: a block trapped behind another — clear the blocker first
    /// and the trapped block's lane lights up. Lesson 3: pop a row in a row to build a chain.
    /// Then a heads-up on the special blocks and boards now in play.
    static let pages: [TutorialPage] = [
        .board(TutorialStage(
            titleEN: "Try it on the board",
            titleKO: "보드에서 직접 해보기",
            subtitleEN: "Flick the block toward its arrow — or just tap it — and it slides off the edge and pops.",
            subtitleKO: "화살표 방향으로 밀거나, 블록을 톡 눌러도 가장자리로 빠지며 팡!",
            board: grid([
                [nil, nil, nil, nil],
                [nil, .right, nil, nil]
            ]),
            moves: [BoardPosition(row: 1, column: 1)]
        )),
        .board(TutorialStage(
            titleEN: "Clear the lane first",
            titleKO: "막힌 길을 먼저 비워요",
            subtitleEN: "The left block is stuck — its lane is blocked. Clear the one in front, and its path opens up.",
            subtitleKO: "왼쪽 블록은 길이 막혀 못 가요. 앞의 블록을 먼저 치우면 길이 열려요.",
            board: grid([
                [nil, nil, nil, nil],
                [.right, .right, nil, nil]
            ]),
            moves: [BoardPosition(row: 1, column: 1), BoardPosition(row: 1, column: 0)]
        )),
        .board(TutorialStage(
            titleEN: "Chain your pops",
            titleKO: "이어서 팡팡, 체인!",
            subtitleEN: "Pop without missing to build a chain — longer chains score much more.",
            subtitleKO: "막히지 않고 이어 밀면 체인이 쌓여요 — 길수록 점수가 쑥쑥!",
            board: grid([
                [nil, nil, nil, nil],
                [.up, .up, .up, .up]
            ]),
            moves: [
                BoardPosition(row: 1, column: 0),
                BoardPosition(row: 1, column: 1),
                BoardPosition(row: 1, column: 2),
                BoardPosition(row: 1, column: 3)
            ],
            teachesChain: true
        )),
        .info(TutorialInfo(
            titleEN: "New: special blocks & boards",
            titleKO: "새로워진 블록과 보드",
            subtitleEN: "Keep an eye out for these — they shake up every round.",
            subtitleKO: "플레이하다 보면 등장해요 — 매 판이 달라져요.",
            items: [
                TutorialInfoItem(
                    systemImage: "burst.fill",
                    titleEN: "Bomb", titleKO: "폭탄",
                    detailEN: "Pops its whole row and column at once.",
                    detailKO: "같은 가로·세로 줄을 한 번에 정리해요.",
                    faceKind: .block(.bomb, cracked: false)
                ),
                TutorialInfoItem(
                    systemImage: "shield.lefthalf.filled",
                    titleEN: "Armored", titleKO: "단단한 블록",
                    detailEN: "Takes two taps to break.",
                    detailKO: "두 번 눌러야 깨져요.",
                    faceKind: .block(.armored, cracked: false)
                ),
                TutorialInfoItem(
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                    titleEN: "Wild", titleKO: "만능 블록",
                    detailEN: "Tap it, or flick any open direction.",
                    detailKO: "톡 누르거나 열린 쪽으로 밀어요.",
                    faceKind: .block(.wild, cracked: false)
                ),
                TutorialInfoItem(
                    systemImage: "bolt.fill",
                    titleEN: "Rush board", titleKO: "러시 보드",
                    detailEN: "Double points — but chains fade faster.",
                    detailKO: "점수 2배 — 대신 체인이 더 빨리 식어요.",
                    faceKind: .modifier(.rush)
                )
            ]
        ))
    ]
}

/// Drives the interactive tutorial: which page is showing, the live state of the small board,
/// and validation of each flick against the real escapability rule.
@MainActor
final class TutorialEngine: ObservableObject {
    /// A block currently sliding off the board after a correct flick.
    struct Popping: Identifiable, Equatable {
        let id = UUID()
        let row: Int
        let column: Int
        let direction: Direction
        let tone: BlockTone
    }

    let pages = TutorialContent.pages
    @Published private(set) var pageIndex = 0
    @Published private(set) var board: [[TutorialCell?]] = []
    @Published private(set) var moveIndex = 0
    @Published private(set) var chain = 0
    @Published private(set) var popping: [Popping] = []
    /// The cell that just rejected a flick (wrong direction on the target, or a flick on a
    /// still-blocked block), so the view can nudge it. Cleared after a beat.
    @Published private(set) var rejectedAt: BoardPosition?
    @Published private(set) var tries = 0

    private let reduceMotion: Bool
    private let onComplete: () -> Void
    /// Invalidates stale scheduled page-advances when the page changes out from under them.
    private var advanceToken = 0

    init(reduceMotion: Bool, onComplete: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        self.onComplete = onComplete
        loadCurrentPage()
    }

    var currentPage: TutorialPage { pages[min(pageIndex, pages.count - 1)] }
    var isLastPage: Bool { pageIndex >= pages.count - 1 }

    var currentStage: TutorialStage? {
        if case let .board(stage) = currentPage { return stage }
        return nil
    }

    var currentInfo: TutorialInfo? {
        if case let .info(info) = currentPage { return info }
        return nil
    }

    /// Next cell to pop on a board page (nil on an info page or once the stage is cleared).
    var highlight: BoardPosition? {
        guard let stage = currentStage, moveIndex < stage.moves.count else { return nil }
        return stage.moves[moveIndex]
    }

    var expectedDirection: Direction? {
        guard let highlight, let cell = cell(highlight.row, highlight.column) else { return nil }
        return cell.direction
    }

    func isEscapable(_ pos: BoardPosition) -> Bool {
        TutorialContent.isEscapable(on: board, at: pos)
    }

    func cell(_ row: Int, _ column: Int) -> TutorialCell? {
        guard board.indices.contains(row), board[row].indices.contains(column) else { return nil }
        return board[row][column]
    }

    private func loadCurrentPage() {
        moveIndex = 0
        chain = 0
        tries = 0
        rejectedAt = nil
        popping = []
        board = currentStage?.board ?? []
    }

    /// Validate a flick on the small board against the scripted next move.
    func flick(at pos: BoardPosition, direction: Direction) {
        guard let highlight, let expectedDirection else { return }
        if pos == highlight {
            if direction == expectedDirection, isEscapable(pos) {
                pop(at: pos)
            } else {
                reject(at: pos)
            }
        } else if cell(pos.row, pos.column) != nil {
            // A real block, just not the one that can move yet — nudge it so "it's blocked" lands.
            reject(at: pos)
        }
    }

    /// VoiceOver / "Show me" fallback: perform the next scripted move automatically.
    func performHintedMove() {
        guard let highlight else {
            if currentInfo != nil { advancePage() }
            return
        }
        pop(at: highlight)
    }

    private func pop(at pos: BoardPosition) {
        guard let popped = cell(pos.row, pos.column) else { return }
        rejectedAt = nil
        popping.append(Popping(row: pos.row, column: pos.column, direction: popped.direction, tone: popped.tone))
        board[pos.row][pos.column] = nil
        moveIndex += 1
        if currentStage?.teachesChain == true { chain += 1 }

        let slide = reduceMotion ? 0.22 : 0.34
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(slide * 1_000_000_000))
            self?.retireOldestPop()
        }

        if moveIndex >= (currentStage?.moves.count ?? 0) {
            advanceToken += 1
            let token = advanceToken
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((slide + 0.2) * 1_000_000_000))
                guard let self, token == self.advanceToken else { return }
                self.advancePage()
            }
        }
    }

    private func retireOldestPop() {
        if !popping.isEmpty { popping.removeFirst() }
    }

    private func reject(at pos: BoardPosition) {
        tries += 1
        rejectedAt = pos
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 850_000_000)
            if self?.rejectedAt == pos { self?.rejectedAt = nil }
        }
    }

    func advancePage() {
        advanceToken += 1
        if isLastPage {
            onComplete()
        } else {
            pageIndex += 1
            loadCurrentPage()
        }
    }

    func skip() {
        advanceToken += 1
        onComplete()
    }

    /// A "Show me" / "Next" affordance: appears after a couple of fumbles on a board page, and
    /// is the primary action on the info page — so nobody is ever stuck.
    var showsFallbackButton: Bool {
        if currentStage == nil { return true }
        return tries >= 2 && highlight != nil
    }
}

struct TutorialView: View {
    @Environment(\.appLanguage) private var language

    @StateObject private var engine: TutorialEngine
    private let reduceMotion: Bool

    @State private var handBob = false

    init(reduceMotion: Bool, onComplete: @escaping () -> Void) {
        self.reduceMotion = reduceMotion
        _engine = StateObject(wrappedValue: TutorialEngine(reduceMotion: reduceMotion, onComplete: onComplete))
    }

    private let cellSize: CGFloat = 52
    private let cellSpacing: CGFloat = 8
    private var cellStride: CGFloat { cellSize + cellSpacing }
    private static let boardSpace = "tutorialBoard"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: engine.skip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ppInkGray.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.ppCardCream)
                                .shadow(color: Color.ppInkGray.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("Skip tutorial", "튜토리얼 건너뛰기"))
            }
            .padding(.top, 12)

            Spacer(minLength: 4)

            pageContent
                .frame(maxWidth: .infinity)
                .id(engine.pageIndex)
                .transition(.opacity)

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
                .padding(.top, 30)

            Text(localizedSubtitle)
                .font(.ppBody(13, weight: .medium, language: language))
                .foregroundStyle(Color.ppWarmGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 14)

            if engine.currentStage != nil {
                Text(hintText)
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(engine.rejectedAt != nil ? Color.ppSoftCoral : Color.ppMintText)
                    .padding(.top, 10)
                    .animation(.easeInOut(duration: 0.2), value: engine.rejectedAt)
            }

            Spacer()

            if engine.showsFallbackButton {
                PrimaryPopButton(primaryButtonTitle, systemImage: primaryButtonIcon) {
                    engine.performHintedMove()
                }
                .padding(.bottom, 12)
                .transition(.opacity)
            } else if engine.currentStage != nil {
                TutorialActionCue(title: language.text("Pop the glowing block", "빛나는 블록 터뜨리기")) {
                    engine.performHintedMove()
                }
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            pageDots
                .padding(.bottom, 24)
        }
        .ppScreenPadding()
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: engine.showsFallbackButton)
        .animation(.easeInOut(duration: 0.25), value: engine.pageIndex)
        // A VoiceOver user activates the board (rather than flicking) and can't see the block
        // slide off, so speak the result of each pop and announce a page swap as a screen change
        // — mirroring the live game's announcement convention.
        .onChange(of: engine.moveIndex) { _, newValue in
            guard UIAccessibility.isVoiceOverRunning, newValue > 0 else { return }
            let message = hintText.isEmpty ? language.text("Cleared!", "비웠어요!") : hintText
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        .onChange(of: engine.pageIndex) { _, _ in
            guard UIAccessibility.isVoiceOverRunning else { return }
            UIAccessibility.post(notification: .screenChanged, argument: localizedTitle)
        }
        .onAppear {
            // Drives the pointing-hand bob. The open-path highlight pulses itself inside the
            // shared OpenPathCue modifier.
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                handBob = true
            }
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if engine.currentStage != nil {
            boardView
        } else if let info = engine.currentInfo {
            TutorialInfoCard(info: info)
        }
    }

    private var boardView: some View {
        let rows = engine.board.count
        let columns = TutorialContent.columns
        let width = CGFloat(columns) * cellStride - cellSpacing
        let height = CGFloat(rows) * cellStride - cellSpacing

        return ZStack(alignment: .topLeading) {
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { column in
                    cellView(row: row, column: column)
                        .offset(x: CGFloat(column) * cellStride, y: CGFloat(row) * cellStride)
                }
            }

            ForEach(engine.popping) { pop in
                TutorialPoppingBlock(direction: pop.direction, tone: pop.tone, reduceMotion: reduceMotion)
                    .frame(width: cellSize, height: cellSize)
                    .offset(x: CGFloat(pop.column) * cellStride, y: CGFloat(pop.row) * cellStride)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .coordinateSpace(name: Self.boardSpace)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppSoftSage)
                .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        // Uses the same flick resolver as the live board, so the tutorial can't teach a flick
        // the real game would reject.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.boardSpace))
                .onEnded { value in
                    guard let start = cellPosition(at: value.startLocation) else { return }
                    if let direction = Direction.resolveFlick(
                        translation: value.translation,
                        predictedEndTranslation: value.predictedEndTranslation
                    ) {
                        engine.flick(at: start, direction: direction)
                    } else if let tapped = engine.cell(start.row, start.column) {
                        // A tap also works, exactly like the live board: pop the tapped block
                        // along its own arrow.
                        engine.flick(at: start, direction: tapped.direction)
                    }
                }
        )
        // VoiceOver users can't flick, so the board is also an activate-able element that
        // performs the next taught move.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Practice board", "연습 보드"))
        .accessibilityHint(hintText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { engine.performHintedMove() }
    }

    @ViewBuilder
    private func cellView(row: Int, column: Int) -> some View {
        let pos = BoardPosition(row: row, column: column)
        ZStack {
            if let cell = engine.cell(row, column) {
                TutorialMiniCell(
                    direction: cell.direction,
                    tone: cell.tone,
                    rejected: engine.rejectedAt == pos
                )
                .openPathCue(isOpen: engine.isEscapable(pos), emphasized: true, reduceMotion: reduceMotion, cornerRadius: 13)

                if pos == engine.highlight, let direction = engine.expectedDirection {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.ppInkGray)
                        .shadow(color: Color.ppInkGray.opacity(0.18), radius: 6, x: 0, y: 4)
                        .offset(handOffset(for: direction))
                        .allowsHitTesting(false)
                }
            } else {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.ppInkGray.opacity(0.05))
            }
        }
        .frame(width: cellSize, height: cellSize)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: engine.moveIndex)
    }

    private func cellPosition(at point: CGPoint) -> BoardPosition? {
        guard cellStride > 0 else { return nil }
        let columns = TutorialContent.columns
        let rows = engine.board.count
        // The gesture's hit area extends into the board's 11pt padding, which sits past the
        // named coordinate space's origin — reject anything outside the actual grid bounds.
        guard point.x >= 0, point.y >= 0,
              point.x < CGFloat(columns) * cellStride,
              point.y < CGFloat(rows) * cellStride
        else {
            return nil
        }
        let column = Int(point.x / cellStride)
        let row = Int(point.y / cellStride)
        // Reject the inter-cell gap (the spacing to the right of / below each cell) so a flick
        // only ever resolves to a cell the player actually touched.
        guard point.x - CGFloat(column) * cellStride < cellSize,
              point.y - CGFloat(row) * cellStride < cellSize,
              row < rows, column < columns
        else {
            return nil
        }
        return BoardPosition(row: row, column: column)
    }

    private func handOffset(for direction: Direction) -> CGSize {
        let reach: CGFloat = (handBob && !reduceMotion) ? 17 : 9
        switch direction {
        case .up:
            return CGSize(width: 9, height: 14 - reach)
        case .down:
            return CGSize(width: 9, height: 2 + reach)
        case .left:
            return CGSize(width: 14 - reach, height: 12)
        case .right:
            return CGSize(width: 2 + reach, height: 12)
        }
    }

    private var localizedTitle: String {
        if let stage = engine.currentStage { return language.text(stage.titleEN, stage.titleKO) }
        if let info = engine.currentInfo { return language.text(info.titleEN, info.titleKO) }
        return ""
    }

    private var localizedSubtitle: String {
        if let stage = engine.currentStage { return language.text(stage.subtitleEN, stage.subtitleKO) }
        if let info = engine.currentInfo { return language.text(info.subtitleEN, info.subtitleKO) }
        return ""
    }

    private var hintText: String {
        guard let direction = engine.expectedDirection else { return "" }
        let name = direction.accessibilityName(language: language)
        if engine.rejectedAt != nil {
            return language.text("Tap the glowing block, or flick \(name)", "빛나는 블록을 톡 누르거나 \(name)으로 밀어요")
        }
        if engine.currentStage?.teachesChain == true, engine.chain > 0 {
            return language.text("Chain ×\(engine.chain) · tap or flick \(name)", "체인 ×\(engine.chain) · 톡 누르거나 \(name)으로 밀어요")
        }
        return language.text("Tap, or flick \(name)", "톡 누르거나 \(name)으로 밀어요")
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<engine.pages.count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= engine.pageIndex ? Color.ppFreshMint : Color.ppInkGray.opacity(0.15))
                    .frame(width: index == engine.pageIndex ? 22 : 6, height: 6)
            }
        }
    }

    private var primaryButtonTitle: String {
        if engine.currentInfo != nil {
            return engine.isLastPage ? language.text("Start", "시작") : language.text("Next", "다음")
        }
        return language.text("Show me", "보여주기")
    }

    private var primaryButtonIcon: String {
        if engine.currentInfo != nil {
            return engine.isLastPage ? "play.fill" : "arrow.right"
        }
        return "hand.draw.fill"
    }
}

private struct TutorialActionCue: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "hand.draw.fill")
                .font(.ppDisplay(15, weight: .semibold, language: language))
                .foregroundStyle(Color.ppMintButtonText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.ppFreshMint.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct TutorialMiniCell: View {
    let direction: Direction
    let tone: BlockTone
    let rejected: Bool

    var body: some View {
        ArrowGlyph(arrow: direction.arrow, size: 18)
            .foregroundStyle(Color.ppInkGray)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tone.fillColor)
                    .shadow(color: Color.ppInkGray.opacity(0.12), radius: 8, x: 0, y: 4)
            )
            .overlay {
                if rejected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.ppSoftCoral, lineWidth: 2.5)
                }
            }
            .scaleEffect(rejected ? 0.94 : 1)
            .animation(.easeInOut(duration: 0.18), value: rejected)
    }
}

/// The block sliding off the edge after a correct flick — the visible "it popped" feedback the
/// old static tutorial was missing.
private struct TutorialPoppingBlock: View {
    let direction: Direction
    let tone: BlockTone
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        ArrowGlyph(arrow: direction.arrow, size: 18)
            .foregroundStyle(Color.ppInkGray)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tone.fillColor)
                    .shadow(color: Color.ppInkGray.opacity(0.12), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(reduceMotion ? 1 : 1 - 0.22 * progress)
            .opacity(1 - Double(progress))
            .offset(slideOffset)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.32)) { progress = 1 }
            }
    }

    private var slideOffset: CGSize {
        guard !reduceMotion else { return .zero }
        let step = direction.delta
        let distance: CGFloat = 34 * progress
        return CGSize(width: CGFloat(step.column) * distance, height: CGFloat(step.row) * distance)
    }
}

private struct TutorialInfoCard: View {
    @Environment(\.appLanguage) private var language
    let info: TutorialInfo

    var body: some View {
        VStack(spacing: 9) {
            ForEach(Array(info.items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 12) {
                    if let faceKind = item.faceKind {
                        // Preview the REAL block face / board chip — the same pixels the live
                        // board draws — so these aren't a surprise in-game.
                        GuideFace(kind: faceKind, side: 38)
                    } else {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ppMintButtonText)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.ppFreshMint))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.text(item.titleEN, item.titleKO))
                            .font(.ppDisplay(15, weight: .semibold, language: language))
                            .foregroundStyle(Color.ppInkGray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(language.text(item.detailEN, item.detailKO))
                            .font(.ppBody(12, weight: .medium, language: language))
                            .foregroundStyle(Color.ppWarmGray)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.ppCardCream))
            }
        }
        .padding(13)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppSoftSage)
                .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
        )
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
                        title: appLanguage.text("Practice Mode", "연습 모드"),
                        subtitle: appLanguage.text(
                            "Highlight open paths — practice runs aren't recorded",
                            "열린 길을 표시해요 — 연습 판은 기록되지 않아요"
                        ),
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

                    Text("PopPath \(Bundle.main.appVersionDisplay)")
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
    @Environment(\.appLanguage) private var language

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
                        .font(.ppDisplay(17, weight: .semibold, language: language))
                        .foregroundStyle(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.ppBody(13, weight: .medium, language: language))
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
