import SwiftUI

struct GameView: View {
    @Environment(\.appLanguage) private var language

    @ObservedObject var game: GameModel
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let colorAssist: Bool
    let reduceMotion: Bool
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            topBar

            HUDView(score: game.score, time: game.time, chain: game.chain)

            BoardView(
                board: game.board,
                openPositions: game.openPositions,
                escapingBlocks: game.escapingBlocks,
                boardToast: game.boardToast,
                chain: game.chain,
                colorAssist: colorAssist,
                reduceMotion: reduceMotion,
                onTap: { row, column in
                    game.tap(
                        row: row,
                        column: column,
                        hapticsEnabled: hapticsEnabled,
                        soundEnabled: soundEnabled
                    )
                }
            )

            footer
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 16)
        .onAppear {
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
        .onChange(of: soundEnabled) { _, _ in
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
        .onChange(of: hapticsEnabled) { _, _ in
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ppInkGray.opacity(0.82))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.ppCardCream)
                            .shadow(color: Color.ppInkGray.opacity(0.11), radius: 9, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text("Exit game", "게임 나가기"))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text(language.text("\(GameRules.roundSeconds)s", "\(GameRules.roundSeconds)초"))
                    .font(.ppDisplay(14, weight: .bold, language: language))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.ppMintText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule(style: .continuous).fill(Color.ppSoftSage))
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            footerLeading

            Spacer()

            Button {
                game.newBoard()
            } label: {
                Label(
                    game.mode == .daily
                        ? language.text("Restart", "다시")
                        : language.text("New board", "새 보드"),
                    systemImage: "arrow.clockwise"
                )
                    .font(.ppDisplay(14, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppInkGray.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.ppCardCream)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.ppInkGray.opacity(0.07), lineWidth: 1)
                            )
                            .shadow(color: Color.ppInkGray.opacity(0.12), radius: 10, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var footerLeading: some View {
        if game.mode == .daily {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ppMintText)
                Text(language.text("DAILY ", "데일리 "))
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintText)
                Text(game.dailyChallenge.displayLabel)
                    .font(.ppDisplay(13, weight: .bold, language: language))
                    .foregroundStyle(Color.ppInkGray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        } else {
            HStack(spacing: 0) {
                Text(language.text("BEST ", "최고 "))
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppWarmGray)
                Text(game.best.formatted())
                    .font(.ppDisplay(13, weight: .bold, language: language))
                    .foregroundStyle(Color.ppInkGray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
    }
}

private struct HUDView: View {
    @Environment(\.appLanguage) private var language

    let score: Int
    let time: Int
    let chain: Int

    var body: some View {
        HStack(spacing: 8) {
            HUDTile(label: language.text("SCORE", "점수"), value: score.formatted())
            HUDTile(label: language.text("TIME", "시간"), value: "\(time)")
            HUDTile(label: language.text("CHAIN", "체인"), value: "×\(chain)", isChain: true, boost: chainBoost)
        }
        .frame(height: 58)
    }

    private var chainBoost: Double {
        guard chain > 1 else { return 0 }
        return min(Double(chain) / 8, 1)
    }
}

private struct HUDTile: View {
    @Environment(\.appLanguage) private var language

    let label: String
    let value: String
    var isChain = false
    var boost = 0.0

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.ppBody(10, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.9)
                .foregroundStyle(isChain ? Color.ppMintText : Color.ppWarmGray)
            Text(value)
                .font(.ppDisplay(22, weight: .bold, language: language))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(chainValueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.ppCardCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(chainStrokeColor, lineWidth: isChain ? 1 + boost * 2 : 0)
                )
                .shadow(
                    color: isChain ? Color.ppFreshMint.opacity(0.12 + boost * 0.24) : Color.ppInkGray.opacity(0.14),
                    radius: isChain ? 13 + boost * 10 : 13,
                    x: 0,
                    y: 5
                )
        )
        .scaleEffect(isChain ? 1 + boost * 0.045 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.55), value: value)
    }

    private var chainValueColor: Color {
        guard isChain else { return .ppInkGray }
        return boost >= 0.62 ? .ppSoftCoral : .ppMintText
    }

    private var chainStrokeColor: Color {
        guard isChain else { return .clear }
        return (boost >= 0.62 ? Color.ppSoftCoral : Color.ppFreshMint).opacity(0.28 + boost * 0.48)
    }
}

private struct BoardView: View {
    let board: [[PopBlock?]]
    let openPositions: Set<BoardPosition>
    let escapingBlocks: [EscapingBlock]
    let boardToast: BoardToast?
    let chain: Int
    let colorAssist: Bool
    let reduceMotion: Bool
    let onTap: (Int, Int) -> Void

    private let gridSpacing: CGFloat = 7
    private let boardPadding: CGFloat = 11

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: GameRules.columns)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * CGFloat(GameRules.columns) / CGFloat(GameRules.rows))
            let cellSize = (
                width - boardPadding * 2 - gridSpacing * CGFloat(GameRules.columns - 1)
            ) / CGFloat(GameRules.columns)

            VStack {
                ZStack(alignment: .topLeading) {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(0..<(GameRules.rows * GameRules.columns), id: \.self) { index in
                            let row = index / GameRules.columns
                            let column = index % GameRules.columns
                            let position = BoardPosition(row: row, column: column)
                            let escapeOffset = board[row][column]?.direction.escapeOffset(
                                row: row,
                                column: column,
                                cellSize: cellSize,
                                spacing: gridSpacing,
                                padding: boardPadding
                            ) ?? .zero

                            BoardCell(
                                block: board[row][column],
                                isOpen: openPositions.contains(position),
                                escapeOffset: escapeOffset,
                                chain: chain,
                                showOpenHint: colorAssist,
                                reduceMotion: reduceMotion
                            )
                            .contentShape(Rectangle())
                            .instantTouch {
                                onTap(row, column)
                            }
                        }
                    }

                    ForEach(escapingBlocks) { escapingBlock in
                        let escapeOffset = escapingBlock.block.direction.escapeOffset(
                            row: escapingBlock.row,
                            column: escapingBlock.column,
                            cellSize: cellSize,
                            spacing: gridSpacing,
                            padding: boardPadding
                        )
                        EscapingBlockView(
                            escapingBlock: escapingBlock,
                            escapeOffset: escapeOffset,
                            cellSize: cellSize,
                            reduceMotion: reduceMotion
                        )
                        .offset(
                            x: CGFloat(escapingBlock.column) * (cellSize + gridSpacing),
                            y: CGFloat(escapingBlock.row) * (cellSize + gridSpacing)
                        )
                        .allowsHitTesting(false)
                    }
                }
                .padding(boardPadding)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.ppSoftSage)
                        .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .overlay(alignment: .top) {
                    if let boardToast {
                        BoardToastView(toast: boardToast)
                            .padding(.top, 13)
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.75), value: boardToast?.id)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(GameRules.columns) / CGFloat(GameRules.rows), contentMode: .fit)
    }
}

private struct EscapingBlockView: View {
    let escapingBlock: EscapingBlock
    let escapeOffset: CGSize
    let cellSize: CGFloat
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
            let progress = escapeProgress(at: timeline.date)
            let easedProgress = easeOutCubic(progress)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(escapingBlock.block.tone.color)
                    .shadow(color: Color.ppInkGray.opacity(0.11), radius: 8, x: 0, y: 4)

                Image(systemName: escapingBlock.block.direction.symbolName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ppInkGray)
            }
            .frame(width: cellSize, height: cellSize)
            .offset(reduceMotion ? .zero : escapeOffset.scaled(by: easedProgress))
            .scaleEffect(1 - easedProgress * 0.12)
            .opacity(1 - easedProgress * 0.32)
            .zIndex(20)
        }
    }

    private func escapeProgress(at date: Date) -> CGFloat {
        guard !reduceMotion else { return 1 }

        let elapsed = date.timeIntervalSince(escapingBlock.startedAt)
        let rawProgress = elapsed / max(escapingBlock.duration, 0.001)
        return CGFloat(min(max(rawProgress, 0), 1))
    }

    private func easeOutCubic(_ progress: CGFloat) -> CGFloat {
        let remaining = 1 - progress
        return 1 - remaining * remaining * remaining
    }
}

private struct BoardCell: View {
    @Environment(\.appLanguage) private var language

    let block: PopBlock?
    let isOpen: Bool
    let escapeOffset: CGSize
    let chain: Int
    let showOpenHint: Bool
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if let block {
                blockView(block)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ppInkGray.opacity(0.035))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            updatePulse()
        }
        .onChange(of: isOpen) { _, _ in
            updatePulse()
        }
    }

    private func blockView(_ block: PopBlock) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(block.tone.color)
                .shadow(color: Color.ppInkGray.opacity(0.13), radius: 9, x: 0, y: 4)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.45))
                        .frame(height: 1)
                        .padding(.horizontal, 10)
                }

            Image(systemName: block.direction.symbolName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ppInkGray)

            if showOpenHint && isOpen {
                Circle()
                    .fill(Color.ppMintButtonText)
                    .frame(width: 6, height: 6)
                    .offset(x: 14, y: -14)
            }

            if block.isLeaving && !reduceMotion {
                PopTrail(direction: block.direction, chain: chain)
            }
        }
        .overlay {
            if showOpenHint && isOpen {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        Color.ppFreshMint.opacity(pulse && !reduceMotion ? 0.4 : 0.95),
                        lineWidth: pulse && !reduceMotion ? 7 : 3
                    )
                    .shadow(color: Color.ppMintText.opacity(0.22), radius: 12, x: 0, y: 5)
            }
        }
        .overlay {
            if block.isMiss {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.ppSoftCoral.opacity(0.75), lineWidth: 2)
            }
        }
        .offset(block.isLeaving ? escapeOffset : .zero)
        .scaleEffect(block.isLeaving ? 0.92 : 1)
        .opacity(block.isLeaving ? 0.96 : 1)
        .zIndex(block.isLeaving ? 10 : 1)
        .modifier(ShakeEffect(shakes: block.isMiss ? 2 : 0))
        .animation(.easeIn(duration: reduceMotion ? 0.16 : 0.34), value: block.isLeaving)
        .animation(.linear(duration: 0.18), value: block.isMiss)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: pulse)
        .accessibilityLabel(accessibilityLabel(for: block))
    }

    private func updatePulse() {
        guard isOpen, !reduceMotion else {
            pulse = false
            return
        }
        pulse = true
    }

    private func accessibilityLabel(for block: PopBlock) -> String {
        let state = isOpen ? language.text("open path", "열린 길") : language.text("blocked", "막힌 길")
        return "\(block.direction.accessibilityName(language: language)) \(language.text("arrow", "화살표")), \(state)"
    }
}

private struct BoardToastView: View {
    @Environment(\.appLanguage) private var language

    let toast: BoardToast

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .black, design: .rounded))
            Text(titleText)
                .font(.ppBody(12, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.8)
            Text(detailText)
                .font(.ppDisplay(16, weight: .bold, language: language))
                .monospacedDigit()
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: 14, x: 0, y: 7)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    private var iconName: String {
        switch toast.style {
        case .chain: "sparkles"
        case .unlock: "key.fill"
        case .freshPath: "shuffle"
        case .clear: "checkmark"
        }
    }

    private var titleText: String {
        guard language == .korean else { return toast.title }

        switch toast.title {
        case "MEGA CHAIN":
            return "메가 체인"
        case "BIG CHAIN":
            return "빅 체인"
        case "CHAIN":
            return "체인"
        case "PATH BURST":
            return "길이 팡!"
        case "DOUBLE UNLOCK":
            return "길 두 개!"
        case "UNLOCK":
            return "길 열림"
        case "FRESH PATH":
            return "새 길!"
        case "BOARD CLEAR":
            return "싹쓸이!"
        default:
            return toast.title
        }
    }

    private var detailText: String {
        guard language == .korean else { return toast.detail }
        return toast.detail == "NO MOVES" ? "갈 곳 없음" : toast.detail
    }

    private var foregroundColor: Color {
        switch toast.style {
        case .chain, .unlock, .clear: .ppMintButtonText
        case .freshPath: .ppMintText
        }
    }

    private var backgroundColor: Color {
        switch toast.style {
        case .chain: .ppSoftCoral
        case .unlock: .ppFreshMint
        case .freshPath, .clear: .ppFreshMint
        }
    }

    private var shadowColor: Color {
        switch toast.style {
        case .chain: Color.ppSoftCoral.opacity(0.3)
        case .unlock: Color.ppMintText.opacity(0.25)
        case .freshPath, .clear: Color.ppMintText.opacity(0.22)
        }
    }
}

private struct PopTrail: View {
    let direction: Direction
    let chain: Int

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.72 - Double(index) * 0.14))
                    .frame(width: 5 + CGFloat(index) * 2, height: 5 + CGFloat(index) * 2)
                    .offset(trailOffset(for: index))
            }
        }
        .opacity(chain > 1 ? 1 : 0.68)
    }

    private var color: Color {
        chain >= 5 ? .ppSoftCoral : .ppFreshMint
    }

    private func trailOffset(for index: Int) -> CGSize {
        let distance = CGFloat(index + 1) * 9
        switch direction {
        case .up:
            return CGSize(width: CGFloat(index - 1) * 5, height: distance)
        case .down:
            return CGSize(width: CGFloat(index - 1) * 5, height: -distance)
        case .left:
            return CGSize(width: distance, height: CGFloat(index - 1) * 5)
        case .right:
            return CGSize(width: -distance, height: CGFloat(index - 1) * 5)
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 4
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: sin(shakes * .pi * 2) * travelDistance,
            y: 0
        ))
    }
}

private struct InstantTouchModifier: ViewModifier {
    let action: () -> Void
    @State private var hasFired = false

    func body(content: Content) -> some View {
        content.highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !hasFired else { return }
                    hasFired = true
                    action()
                }
                .onEnded { _ in
                    hasFired = false
                }
        )
    }
}

private extension View {
    func instantTouch(_ action: @escaping () -> Void) -> some View {
        modifier(InstantTouchModifier(action: action))
    }
}

private extension CGSize {
    func scaled(by amount: CGFloat) -> CGSize {
        CGSize(width: width * amount, height: height * amount)
    }
}

private extension BlockTone {
    var color: Color {
        switch self {
        case .mistBlue: .ppMistBlue
        case .lavenderMist: .ppLavenderMist
        }
    }
}

private extension Direction {
    func escapeOffset(
        row: Int,
        column: Int,
        cellSize: CGFloat,
        spacing: CGFloat,
        padding: CGFloat
    ) -> CGSize {
        let stride = cellSize + spacing

        switch self {
        case .up:
            return CGSize(width: 0, height: -padding - CGFloat(row + 1) * stride)
        case .down:
            return CGSize(width: 0, height: padding + CGFloat(GameRules.rows - row) * stride)
        case .left:
            return CGSize(width: -padding - CGFloat(column + 1) * stride, height: 0)
        case .right:
            return CGSize(width: padding + CGFloat(GameRules.columns - column) * stride, height: 0)
        }
    }

    var accessibilityName: String {
        accessibilityName(language: .english)
    }

    func accessibilityName(language: AppLanguage) -> String {
        switch self {
        case .up:
            return language.text("Up", "위쪽")
        case .down:
            return language.text("Down", "아래쪽")
        case .left:
            return language.text("Left", "왼쪽")
        case .right:
            return language.text("Right", "오른쪽")
        }
    }

    var symbolName: String {
        switch self {
        case .up: "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .left: "arrowtriangle.left.fill"
        case .right: "arrowtriangle.right.fill"
        }
    }
}
