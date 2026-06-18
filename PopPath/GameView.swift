import SwiftUI

struct GameView: View {
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
            .accessibilityLabel("Exit game")

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text("\(GameRules.roundSeconds)s")
                    .font(.ppDisplay(13, weight: .bold))
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
                Label(game.mode == .daily ? "Restart" : "New board", systemImage: "arrow.clockwise")
                    .font(.ppDisplay(13, weight: .semibold))
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
                Text("DAILY ")
                    .font(.ppBody(12, weight: .heavy))
                    .foregroundStyle(Color.ppMintText)
                Text(game.dailyChallenge.displayLabel)
                    .font(.ppDisplay(13, weight: .bold))
                    .foregroundStyle(Color.ppInkGray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        } else {
            HStack(spacing: 0) {
                Text("BEST ")
                    .font(.ppBody(12, weight: .heavy))
                    .foregroundStyle(Color.ppWarmGray)
                Text(game.best.formatted())
                    .font(.ppDisplay(13, weight: .bold))
                    .foregroundStyle(Color.ppInkGray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
    }
}

private struct HUDView: View {
    let score: Int
    let time: Int
    let chain: Int

    var body: some View {
        HStack(spacing: 8) {
            HUDTile(label: "SCORE", value: score.formatted())
            HUDTile(label: "TIME", value: "\(time)")
            HUDTile(label: "CHAIN", value: "×\(chain)", isChain: true, boost: chainBoost)
        }
        .frame(height: 58)
    }

    private var chainBoost: Double {
        guard chain > 1 else { return 0 }
        return min(Double(chain) / 8, 1)
    }
}

private struct HUDTile: View {
    let label: String
    let value: String
    var isChain = false
    var boost = 0.0

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.ppBody(9, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(isChain ? Color.ppMintText : Color.ppWarmGray)
            Text(value)
                .font(.ppDisplay(21, weight: .bold))
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
                        .onTapGesture {
                            onTap(row, column)
                        }
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

private struct BoardCell: View {
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
        let state = isOpen ? "open path" : "blocked"
        return "\(block.direction.accessibilityName) arrow, \(state)"
    }
}

private struct BoardToastView: View {
    let toast: BoardToast

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .black, design: .rounded))
            Text(toast.title)
                .font(.ppBody(11, weight: .heavy))
                .tracking(0.8)
            Text(toast.detail)
                .font(.ppDisplay(15, weight: .bold))
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
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
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
