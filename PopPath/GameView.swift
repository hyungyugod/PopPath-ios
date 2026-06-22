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
                colorAssist: colorAssist,
                reduceMotion: reduceMotion,
                onFlick: { row, column, direction in
                    game.attemptPop(
                        row: row,
                        column: column,
                        direction: direction,
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
    let colorAssist: Bool
    let reduceMotion: Bool
    let onFlick: (Int, Int, Direction) -> Void

    @State private var pressedCell: BoardPosition?

    private let gridSpacing: CGFloat = 7
    private let boardPadding: CGFloat = 11
    private static let boardCoordinateSpace = "popPathBoard"

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

                            BoardCell(
                                block: board[row][column],
                                isOpen: openPositions.contains(position),
                                isPressed: pressedCell == position,
                                showOpenHint: colorAssist,
                                reduceMotion: reduceMotion
                            )
                        }
                    }

                    ForEach(escapingBlocks) { escapingBlock in
                        EscapingBlockView(
                            escapingBlock: escapingBlock,
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
                .coordinateSpace(name: Self.boardCoordinateSpace)
                .contentShape(Rectangle())
                .gesture(boardGesture(cellSize: cellSize))
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

    // One board-level drag gesture. The START cell is resolved from where the finger went
    // down (so a flick that drifts across tiles still pops the tile it began on), and the
    // flick is judged against that cell's arrow inside the model.
    private func boardGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.boardCoordinateSpace))
            .onChanged { value in
                if pressedCell == nil {
                    pressedCell = cellPosition(at: value.startLocation, cellSize: cellSize)
                }
            }
            .onEnded { value in
                let start = cellPosition(at: value.startLocation, cellSize: cellSize)
                pressedCell = nil
                guard let start,
                      let direction = resolvedSwipeDirection(value)
                else {
                    // A tap or a sub-threshold drag resolves to no direction → no-op.
                    return
                }
                onFlick(start.row, start.column, direction)
            }
    }

    private func cellPosition(at point: CGPoint, cellSize: CGFloat) -> BoardPosition? {
        let stride = cellSize + gridSpacing
        guard stride > 0 else { return nil }
        let column = Int((point.x / stride).rounded(.down))
        let row = Int((point.y / stride).rounded(.down))
        guard (0..<GameRules.rows).contains(row),
              (0..<GameRules.columns).contains(column)
        else {
            return nil
        }
        return BoardPosition(row: row, column: column)
    }

    private func resolvedSwipeDirection(_ value: DragGesture.Value) -> Direction? {
        if let direction = Direction.swipeDirection(
            for: value.translation,
            minimumDistance: 14,
            axisBias: 1.16
        ) {
            return direction
        }
        return Direction.swipeDirection(
            for: value.predictedEndTranslation,
            minimumDistance: 30,
            axisBias: 1.08
        )
    }
}

private struct EscapingBlockView: View {
    let escapingBlock: EscapingBlock
    let cellSize: CGFloat
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        let visibleProgress = reduceMotion ? 1 : progress
        let burstLevel = min(CGFloat(max(escapingBlock.chain, 1)) / 6 + 0.32, 1.18)
        let ringProgress = ppSmoothStep(ppUnit((visibleProgress - 0.04) / 0.66))
        let tileOpacity = 1 - ppSmoothStep(ppUnit((visibleProgress - 0.32) / 0.6))

        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(burstColor.opacity(Double((1 - ringProgress) * 0.7)), lineWidth: 2 + burstLevel * 2)
                .scaleEffect(0.9 + ringProgress * (0.54 + burstLevel * 0.16))
                .opacity(1 - ringProgress)

            ForEach(0..<particleCount, id: \.self) { index in
                PopBurstParticle(
                    index: index,
                    count: particleCount,
                    progress: visibleProgress,
                    cellSize: cellSize,
                    direction: escapingBlock.block.direction,
                    tone: escapingBlock.block.tone,
                    burstColor: burstColor,
                    intensity: burstLevel
                )
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(escapingBlock.block.tone.color)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(flashOpacity(visibleProgress)))
                }

            Image(systemName: escapingBlock.block.direction.symbolName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ppInkGray)
                .rotationEffect(.degrees(arrowRotation(visibleProgress)))
        }
        .frame(width: cellSize, height: cellSize)
        .offset(releaseOffset(progress: visibleProgress, burstLevel: burstLevel))
        .scaleEffect(popScale(visibleProgress))
        .opacity(tileOpacity)
        .zIndex(20)
        .compositingGroup()
        .onAppear {
            guard !reduceMotion else {
                progress = 1
                return
            }

            withAnimation(.timingCurve(0.18, 0.82, 0.24, 1, duration: escapingBlock.duration)) {
                progress = 1
            }
        }
    }

    private func pulseScale(_ value: CGFloat) -> CGFloat {
        if value < 0.22 {
            return 1 + ppEaseOutCubic(value / 0.22) * (0.16 + min(CGFloat(escapingBlock.chain), 6) * 0.01)
        }

        let shrinkProgress = ppSmoothStep(ppUnit((value - 0.22) / 0.78))
        return 1.16 - shrinkProgress * 1.0
    }

    private func popScale(_ value: CGFloat) -> CGFloat {
        max(0.16, pulseScale(value))
    }

    private var particleCount: Int {
        escapingBlock.chain >= 5 ? 8 : 6
    }

    private var burstColor: Color {
        .ppSoftCoral
    }

    private func flashOpacity(_ value: CGFloat) -> Double {
        Double(max(0, 0.58 - value * 1.9))
    }

    private func arrowRotation(_ value: CGFloat) -> Double {
        let direction: Double = escapingBlock.chain.isMultiple(of: 2) ? -1 : 1
        return direction * Double(ppSmoothStep(ppUnit(value / 0.72))) * Double(min(escapingBlock.chain, 6)) * 3.0
    }

    private func releaseOffset(progress: CGFloat, burstLevel: CGFloat) -> CGSize {
        guard !reduceMotion else { return .zero }

        let slideProgress = ppEaseOutCubic(ppUnit(progress / 0.7))
        let distance = cellSize * (0.34 + burstLevel * 0.18)
        return escapingBlock.block.direction.vector.scaled(by: distance * slideProgress)
    }
}

private struct PopBurstParticle: View {
    let index: Int
    let count: Int
    let progress: CGFloat
    let cellSize: CGFloat
    let direction: Direction
    let tone: BlockTone
    let burstColor: Color
    let intensity: CGFloat

    var body: some View {
        let delayedProgress = ppUnit((progress - delay) / (1 - delay))
        let travelProgress = ppEaseOutCubic(delayedProgress)
        let fadeProgress = ppSmoothStep(ppUnit((delayedProgress - 0.1) / 0.9))
        let offset = burstOffset(progress: travelProgress)
        let size = particleSize * (1 - fadeProgress * 0.48)

        Circle()
            .fill(particleColor.opacity(Double(1 - fadeProgress)))
            .frame(width: size, height: size)
            .offset(offset)
            .scaleEffect(1 + (1 - fadeProgress) * 0.16)
            .opacity(delayedProgress > 0 ? 1 : 0)
    }

    private var delay: CGFloat {
        CGFloat(index % 3) * 0.035
    }

    private var particleSize: CGFloat {
        cellSize * (0.09 + CGFloat(index % 3) * 0.018 + intensity * 0.018)
    }

    private var particleColor: Color {
        switch index % 4 {
        case 0:
            return tone.color
        case 1:
            return burstColor
        case 2:
            return .white
        default:
            return .ppMintButtonText.opacity(0.72)
        }
    }

    private func burstOffset(progress: CGFloat) -> CGSize {
        let angle = baseAngle + spreadAngle
        let distance = cellSize * (0.34 + intensity * 0.18 + CGFloat(index % 4) * 0.035)
        let wobble = sin(Double(progress) * .pi) * Double(cellSize * 0.08) * (index.isMultiple(of: 2) ? 1 : -1)
        let x = cos(angle) * Double(distance) * Double(progress) + cos(angle + .pi / 2) * wobble
        let y = sin(angle) * Double(distance) * Double(progress) + sin(angle + .pi / 2) * wobble

        return CGSize(width: CGFloat(x), height: CGFloat(y))
    }

    private var baseAngle: Double {
        switch direction {
        case .up:
            return -.pi / 2
        case .down:
            return .pi / 2
        case .left:
            return .pi
        case .right:
            return 0
        }
    }

    private var spreadAngle: Double {
        let centeredIndex = Double(index) - Double(count - 1) / 2
        return centeredIndex * 0.28
    }
}

private func ppUnit(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
}

private func ppSmoothStep(_ value: CGFloat) -> CGFloat {
    let value = ppUnit(value)
    return value * value * (3 - 2 * value)
}

private func ppEaseOutCubic(_ value: CGFloat) -> CGFloat {
    let remaining = 1 - ppUnit(value)
    return 1 - remaining * remaining * remaining
}

private struct BoardCell: View {
    @Environment(\.appLanguage) private var language

    let block: PopBlock?
    let isOpen: Bool
    let isPressed: Bool
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
        .scaleEffect(pressScale)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.62), value: isPressed)
        .onAppear {
            updatePulse()
        }
        .onChange(of: isOpen) { _, _ in
            updatePulse()
        }
        .onChange(of: showOpenHint) { _, _ in
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
        .modifier(ShakeEffect(shakes: block.isMiss ? 2 : 0))
        .animation(.linear(duration: 0.18), value: block.isMiss)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: pulse)
        .accessibilityLabel(accessibilityLabel(for: block))
    }

    private var pressScale: CGFloat {
        guard isPressed, block != nil, !reduceMotion else { return 1 }
        return 0.94
    }

    private func updatePulse() {
        // The pulsing highlight is only drawn when the colour-assist hint is on, so
        // don't run a forever-repeating animation on every open cell otherwise.
        guard isOpen, showOpenHint, !reduceMotion else {
            pulse = false
            return
        }
        pulse = true
    }

    private func accessibilityLabel(for block: PopBlock) -> String {
        let directionName = block.direction.accessibilityName(language: language)
        if isOpen {
            return language.text(
                "Swipe \(directionName) to clear",
                "\(directionName)으로 스와이프해서 제거"
            )
        }

        return language.text(
            "\(directionName) arrow, blocked",
            "\(directionName) 화살표, 막힌 길"
        )
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
    var vector: CGSize {
        switch self {
        case .up:
            return CGSize(width: 0, height: -1)
        case .down:
            return CGSize(width: 0, height: 1)
        case .left:
            return CGSize(width: -1, height: 0)
        case .right:
            return CGSize(width: 1, height: 0)
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
