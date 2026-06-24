import SwiftUI
import UIKit

struct GameView: View {
    @Environment(\.appLanguage) private var language

    @ObservedObject var game: GameModel
    // Bindings (not values) so the paused overlay can flip them mid-run (K17).
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var colorAssist: Bool
    let reduceMotion: Bool
    let onExit: () -> Void

    @State private var showExitConfirm = false
    @State private var showDailyRestartConfirm = false
    // The paused overlay is shown ONLY by the pause button. The exit / daily-restart
    // confirms also freeze the clock via game.pause(), but must not surface this overlay
    // (that would stack two modals), so they are gated on this flag, not on runState.
    @State private var showPausedOverlay = false
    /// Drives the red screen-edge penalty flash on a wrong flick; pulsed by `missFlashToken`.
    @State private var missFlash: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            topBar

            HUDView(game: game, reduceMotion: reduceMotion)

            // The reward/chain banner lives in its own lane *above* the board so it never covers
            // the blocks (a "MEGA CHAIN ×20" toast used to sit over the top rows). Fixed-height so
            // it never reflows the board mid-pop.
            boardToastLane

            BoardView(
                board: game.board,
                openPositions: game.openPositions,
                escapingBlocks: game.escapingBlocks,
                floatingScores: game.floatingScores,
                boardGeneration: game.boardGeneration,
                boardModifier: game.currentModifier,
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
        .overlay {
            if showPausedOverlay {
                PausedOverlay(
                    soundEnabled: $soundEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    colorAssist: $colorAssist,
                    onResume: {
                        game.resume()
                        showPausedOverlay = false
                    },
                    onQuit: {
                        showPausedOverlay = false
                        game.creditAndEndRun()
                        onExit()
                    }
                )
                .transition(.opacity)
            }
        }
        // Wrong-flick penalty: a red glow hugging the whole screen edge, fading out. A single
        // non-repeating pulse (no strobe) so it stays photosensitivity-safe (G8).
        .overlay {
            MissEdgeFlash(opacity: missFlash)
        }
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.2), value: showPausedOverlay)
        .confirmationDialog(
            language.text("End run?", "그만할까요?"),
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button(language.text("End run", "그만하기"), role: .destructive) {
                game.creditAndEndRun()
                onExit()
            }
            Button(language.text("Keep playing", "계속하기"), role: .cancel) { }
        } message: {
            // A practice run records nothing, so don't promise to save the score (it isn't).
            Text(game.isPractice
                ? language.text("Practice run — nothing is recorded.", "연습 판이라 기록되지 않아요.")
                : language.text("Your score so far will be saved.", "지금까지 점수는 저장돼요."))
        }
        .confirmationDialog(
            language.text("Restart today's challenge?", "오늘의 도전을 다시 할까요?"),
            isPresented: $showDailyRestartConfirm,
            titleVisibility: .visible
        ) {
            Button(language.text("Restart", "다시 시작"), role: .destructive) {
                game.newRound(mode: .daily)
                // newRound clears the practice latch, so re-derive it from the current toggle —
                // otherwise restarting today's Daily with the highlight still on would credit a
                // hinted run and consume the one daily attempt.
                game.setPracticeAssist(colorAssist)
            }
            Button(language.text("Keep playing", "계속하기"), role: .cancel) { }
        } message: {
            Text(language.text("This forfeits your current run.", "지금 진행 중인 판은 사라져요."))
        }
        // Any dismissal of a confirm that didn't end / restart the run (cancel button OR an
        // outside-tap that runs no button) must lift the clock-freeze, so the game can never
        // get stuck paused with no visible overlay.
        .onChange(of: showExitConfirm) { _, showing in
            if !showing && game.runState == .paused { game.resume() }
        }
        .onChange(of: showDailyRestartConfirm) { _, showing in
            if !showing && game.runState == .paused { game.resume() }
        }
        .onAppear {
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
            game.setPracticeAssist(colorAssist)
        }
        // Flipping the highlight on mid-run (paused overlay) latches the run into Practice Mode.
        .onChange(of: colorAssist) { _, _ in
            game.setPracticeAssist(colorAssist)
        }
        .onChange(of: soundEnabled) { _, _ in
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
        .onChange(of: hapticsEnabled) { _, _ in
            game.configureFeedback(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
        // Speak each board event (clear / fresh path / unlock / milestone chain) to VoiceOver,
        // throttled to events since it only fires when the toast changes (G6).
        .onChange(of: game.boardToast?.id) { _, _ in
            guard UIAccessibility.isVoiceOverRunning, let toast = game.boardToast else { return }
            UIAccessibility.post(notification: .announcement, argument: toast.announcement(language: language))
        }
        // Speak a board's variety modifier on every deal (keyed on boardGeneration, not the
        // modifier value, so two consecutive boards rolling the SAME modifier still announce),
        // so a VoiceOver player knows a Rush / Bonus board arrived — the banner is purely visual.
        .onChange(of: game.boardGeneration) { _, _ in
            guard UIAccessibility.isVoiceOverRunning, game.currentModifier != .none else { return }
            UIAccessibility.post(notification: .announcement, argument: game.currentModifier.announcement(language: language))
        }
        // A wrong flick bumps `missFlashToken`; snap the red edge glow on, then fade it out.
        .onChange(of: game.missFlashToken) { _, _ in
            missFlash = 0.95
            withAnimation(.easeOut(duration: reduceMotion ? 0.28 : 0.45)) {
                missFlash = 0
            }
        }
    }

    /// Fixed-height banner lane above the board. Holds the centered reward/chain toast so it can
    /// never overlap the blocks, and animates the toast in/out without reflowing the board.
    private var boardToastLane: some View {
        ZStack {
            if let toast = game.boardToast {
                BoardToastView(toast: toast)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .animation(.spring(response: 0.24, dampingFraction: 0.75), value: game.boardToast?.id)
    }

    private func requestExit() {
        game.pause()
        showExitConfirm = true
    }

    // Live difficulty/level pip (K19), reading the WI-4.1 source of truth. Updates as the
    // round's elapsed time and board clears raise the level; the HUD re-renders each tick.
    private var difficultyPip: some View {
        let level = game.currentDifficultyLevel
        return HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index <= level ? Color.ppMintText : Color.ppInkGray.opacity(0.15))
                    .frame(width: index == level ? 14 : 6, height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Difficulty level \(level + 1) of 5", "난이도 \(level + 1) / 5"))
    }

    // Surfaced whenever the run is in Practice Mode (Open-Path Highlight on) so the player knows
    // this run won't be recorded.
    private var practiceBadge: some View {
        Text(language.text("PRACTICE", "연습"))
            .font(.ppBody(9, weight: .heavy, language: language))
            .tracking(language == .korean ? 0 : 0.8)
            .foregroundStyle(Color.ppMintButtonText)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule(style: .continuous).fill(Color.ppFreshMint))
            .accessibilityLabel(language.text("Practice Mode, this run won't be recorded", "연습 모드, 이 판은 기록되지 않아요"))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: requestExit) {
                Image(systemName: "house.fill")
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
            .accessibilityLabel(language.text("Exit game", "게임 나가기"))

            Spacer()

            VStack(spacing: 3) {
                difficultyPip
                if game.isPractice {
                    practiceBadge
                }
            }

            Spacer()

            Button { game.pause(); showPausedOverlay = true } label: {
                Image(systemName: "pause.fill")
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
            .accessibilityLabel(language.text("Pause", "일시정지"))
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            footerLeading

            Spacer()

            Button {
                if game.mode == .daily {
                    game.pause()
                    showDailyRestartConfirm = true
                } else {
                    game.reshuffleBoard()
                }
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
            // Real HStack spacing instead of trailing-space gap hacks (I7).
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ppMintText)
                Text(language.text("DAILY", "데일리"))
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintText)
                Text(game.dailyChallenge.displayLabel(language: language))
                    .font(.ppDisplay(13, weight: .bold, language: language))
                    .foregroundStyle(Color.ppInkGray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        } else {
            HStack(spacing: 5) {
                Text(language.text("BEST", "최고"))
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

private struct PausedOverlay: View {
    @Environment(\.appLanguage) private var language

    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var colorAssist: Bool
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.ppInkGray.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(language.text("Paused", "일시정지"))
                    .font(.ppDisplay(30, weight: .bold, language: language))
                    .foregroundStyle(Color.ppWarmCream)
                    .padding(.bottom, 6)

                // In-game quick settings so common toggles can change mid-run (K17).
                VStack(spacing: 10) {
                    PausedToggle(label: language.text("Sound", "사운드"), systemImage: "speaker.wave.2.fill", isOn: $soundEnabled)
                    PausedToggle(label: language.text("Haptics", "진동"), systemImage: "iphone.radiowaves.left.and.right", isOn: $hapticsEnabled)
                    PausedToggle(label: language.text("Practice Mode", "연습 모드"), systemImage: "graduationcap.fill", isOn: $colorAssist)
                }
                .padding(.bottom, 6)

                PrimaryPopButton(language.text("Resume", "계속하기"), systemImage: "play.fill", action: onResume)

                Button(action: onQuit) {
                    Text(language.text("Quit to Home", "홈으로 나가기"))
                        .font(.ppDisplay(16, weight: .semibold, language: language))
                        .foregroundStyle(Color.ppWarmCream)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.ppWarmCream.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("Quit to Home", "홈으로 나가기"))
            }
            .padding(28)
            .frame(maxWidth: 320)
        }
    }
}

/// Compact toggle styled for the dark paused overlay.
private struct PausedToggle: View {
    @Environment(\.appLanguage) private var language
    let label: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ppWarmCream.opacity(0.9))
                    .frame(width: 22)
                Text(label)
                    .font(.ppDisplay(15, weight: .semibold, language: language))
                    .foregroundStyle(Color.ppWarmCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 10)
                Capsule(style: .continuous)
                    .fill(isOn ? Color.ppFreshMint : Color.ppWarmCream.opacity(0.25))
                    .frame(width: 44, height: 26)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle().fill(Color.white).frame(width: 20, height: 20).padding(3)
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ppWarmCream.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? language.text("On", "켬") : language.text("Off", "끔"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// Continuous low-time urgency state for the TIME tile (WI-5.4).
private struct TimeUrgency {
    let active: Bool
    let reduceMotion: Bool
}

/// Chain-decay indicator state for the CHAIN tile (WI-5.3). `fraction` is sampled by a
/// TimelineView so the model never publishes per frame; `isPaused` stops the sampling so the
/// bar freezes exactly where it was.
private struct ChainDecay {
    let isActive: Bool
    let isPaused: Bool
    let fraction: (Date) -> Double
    let reduceMotion: Bool
}

private struct HUDView: View {
    @Environment(\.appLanguage) private var language

    // Observes the model directly because the CHAIN tile samples chain-decay live. Every
    // publish re-runs this body, but the SCORE/TIME tiles take only value inputs so SwiftUI
    // value-diffs and skips re-rendering them; only the CHAIN tile (which must sample) re-bodies.
    @ObservedObject var game: GameModel
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 8) {
            HUDTile(label: language.text("SCORE", "점수"), value: game.score.formatted())
            HUDTile(
                label: language.text("TIME", "시간"),
                value: "\(game.time)",
                urgency: TimeUrgency(active: isTimeUrgent, reduceMotion: reduceMotion)
            )
            HUDTile(
                label: language.text("CHAIN", "체인"),
                value: "×\(game.chain)",
                isChain: true,
                boost: chainBoost,
                decay: ChainDecay(
                    isActive: game.chain > 0,
                    isPaused: game.runState != .running,
                    fraction: { game.chainDecayFraction(at: $0) },
                    reduceMotion: reduceMotion
                )
            )
        }
        .frame(height: 58)
    }

    private var isTimeUrgent: Bool {
        game.runState == .running && game.time <= GameModel.lowTimeUrgencySeconds && game.time > 0
    }

    private var chainBoost: Double {
        guard game.chain > 1 else { return 0 }
        return min(Double(game.chain) / 8, 1)
    }
}

private struct HUDTile: View {
    @Environment(\.appLanguage) private var language

    let label: String
    let value: String
    var isChain = false
    var boost = 0.0
    var urgency: TimeUrgency?
    var decay: ChainDecay?

    @State private var urgencyPulse = false

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.ppBody(10, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.9)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(value)
                .font(.ppDisplay(22, weight: .bold, language: language))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(valueColor)
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
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0,
                    y: 5
                )
        )
        .overlay(alignment: .bottom) { chainDecayBar }
        .scaleEffect(tileScale)
        .animation(.spring(response: 0.24, dampingFraction: 0.55), value: value)
        .animation(urgencyAnimation, value: urgencyPulse)
        .onChange(of: urgency?.active) { _, _ in syncUrgencyPulse() }
        .onAppear { syncUrgencyPulse() }
    }

    private var shouldPulse: Bool {
        isUrgentActive && !(urgency?.reduceMotion ?? true)
    }

    /// While urgency is active, the pulse repeats forever; the moment it ENDS the curve must
    /// become finite so flipping `urgencyPulse` back to false settles the tile to rest instead
    /// of leaving a repeatForever animation oscillating indefinitely.
    private var urgencyAnimation: Animation? {
        if shouldPulse {
            return .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
        }
        if urgency?.reduceMotion ?? true {
            return nil
        }
        return .easeInOut(duration: 0.25)
    }

    @ViewBuilder
    private var chainDecayBar: some View {
        if isChain, let decay {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !decay.isActive || decay.isPaused)) { context in
                let fraction = decay.isActive ? CGFloat(decay.fraction(context.date)) : 0
                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(fraction > 0.4 ? Color.ppFreshMint : Color.ppSoftCoral)
                        .frame(width: max(0, proxy.size.width * fraction))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 3)
                .opacity(decay.isActive ? 1 : 0)
                .padding(.horizontal, 11)
                .padding(.bottom, 5)
            }
        }
    }

    private var isUrgentActive: Bool {
        urgency?.active ?? false
    }

    private var labelColor: Color {
        if isUrgentActive { return .ppSoftCoral }
        return isChain ? .ppMintText : .ppWarmGray
    }

    private var valueColor: Color {
        if isUrgentActive { return .ppSoftCoral }
        guard isChain else { return .ppInkGray }
        return boost >= 0.62 ? .ppSoftCoral : .ppMintText
    }

    private var strokeColor: Color {
        if isUrgentActive { return Color.ppSoftCoral.opacity(0.45 + (urgencyPulse ? 0.35 : 0)) }
        guard isChain else { return .clear }
        return (boost >= 0.62 ? Color.ppSoftCoral : Color.ppFreshMint).opacity(0.28 + boost * 0.48)
    }

    private var strokeWidth: CGFloat {
        if isUrgentActive { return 1.5 }
        return isChain ? 1 + boost * 2 : 0
    }

    private var shadowColor: Color {
        if isUrgentActive { return Color.ppSoftCoral.opacity(0.22) }
        return isChain ? Color.ppFreshMint.opacity(0.12 + boost * 0.24) : Color.ppInkGray.opacity(0.14)
    }

    private var shadowRadius: CGFloat {
        isChain ? 13 + boost * 10 : 13
    }

    private var tileScale: CGFloat {
        if isUrgentActive, !(urgency?.reduceMotion ?? true) {
            return urgencyPulse ? 1.045 : 1
        }
        return isChain ? 1 + boost * 0.045 : 1
    }

    private func syncUrgencyPulse() {
        guard isUrgentActive, !(urgency?.reduceMotion ?? true) else {
            urgencyPulse = false
            return
        }
        urgencyPulse = true
    }
}

private struct BoardView: View {
    @Environment(\.appLanguage) private var language

    let board: [[PopBlock?]]
    let openPositions: Set<BoardPosition>
    let escapingBlocks: [EscapingBlock]
    let floatingScores: [FloatingScore]
    let boardGeneration: Int
    let boardModifier: BoardModifier
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
                                side: cellSize,
                                isOpen: openPositions.contains(position),
                                isPressed: pressedCell == position,
                                showOpenHint: colorAssist,
                                reduceMotion: reduceMotion,
                                onAccessibilityPop: {
                                    guard let block = board[row][column] else { return }
                                    // A wild block pops in any open lane, so activate it along a
                                    // direction that actually has a clear runway (its arrow is
                                    // only a hint and may be blocked).
                                    let direction = block.kind == .wild
                                        ? (Direction.allCases.first {
                                            GameRules.hasClearRunway(on: board, row: row, column: column, direction: $0)
                                        } ?? block.direction)
                                        : block.direction
                                    onFlick(row, column, direction)
                                }
                            )
                        }
                    }
                    // A board swap (deal / reshuffle) cross-fades the grid; per-pop changes
                    // keep the same identity and animate per-cell as before.
                    .id(boardGeneration)
                    .transition(.opacity)
                    // Group cells as one board element so VoiceOver navigates them row-major.
                    .accessibilityElement(children: .contain)

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

                    // Per-pop "+N" markers (E4), positioned at the cell that cleared and
                    // animating independently of the pop's own burst so the number stays
                    // legible as it rises.
                    ForEach(floatingScores) { floatingScore in
                        FloatingScoreView(amount: floatingScore.amount, reduceMotion: reduceMotion)
                            .frame(width: cellSize, height: cellSize)
                            .offset(
                                x: CGFloat(floatingScore.column) * (cellSize + gridSpacing),
                                y: CGFloat(floatingScore.row) * (cellSize + gridSpacing)
                            )
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: Self.boardCoordinateSpace)
                .contentShape(Rectangle())
                .gesture(boardGesture(cellSize: cellSize))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: boardGeneration)
                .padding(boardPadding)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.ppSoftSage)
                        .shadow(color: Color.ppMintText.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                // A special board reads via a colored border + corner chip — no wash over the
                // cells, so the arrows stay legible.
                .overlay {
                    if let color = modifierColor {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(color, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                }
                // Pinned to the bottom-leading corner — out of the top band where the centered
                // board toast lives, so the two never overlap.
                .overlay(alignment: .bottomLeading) {
                    if boardModifier != .none {
                        modifierChip
                            .padding(11)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: boardModifier)
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
        Direction.resolveFlick(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation
        )
    }

    private var modifierColor: Color? {
        switch boardModifier {
        case .none: return nil
        case .rush: return Color.ppSoftCoral
        case .bonus: return Color.ppMintText
        }
    }

    private var modifierChip: some View {
        HStack(spacing: 5) {
            Image(systemName: boardModifier == .rush ? "bolt.fill" : "gift.fill")
                .font(.system(size: 11, weight: .black, design: .rounded))
            Text(boardModifier.label(language: language))
                .font(.ppBody(11, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 0.6)
        }
        .foregroundStyle(Color.ppMintButtonText)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(boardModifier == .rush ? Color.ppSoftCoral : Color.ppFreshMint))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(boardModifier.announcement(language: language))
    }
}

private struct EscapingBlockView: View {
    let escapingBlock: EscapingBlock
    let cellSize: CGFloat
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        let visibleProgress = progress
        let burstLevel = min(CGFloat(max(escapingBlock.chain, 1)) / 6 + 0.32, 1.18)
        let ringProgress = ppSmoothStep(ppUnit((visibleProgress - 0.04) / 0.66))
        let tileOpacity = 1 - ppSmoothStep(ppUnit((visibleProgress - 0.32) / 0.6))

        ZStack {
            // The ring + particle burst are motion; under reduce-motion the pop is confirmed
            // by a quick opacity fade (plus the +N marker and haptic) instead (F3).
            if !reduceMotion {
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
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BlockFace.fillColor(for: escapingBlock.block))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(flashOpacity(visibleProgress)))
                }

            Image(systemName: escapingBlock.block.direction.symbolName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.ppInkGray)
                .rotationEffect(.degrees(reduceMotion ? 0 : arrowRotation(visibleProgress)))
        }
        .frame(width: cellSize, height: cellSize)
        .offset(releaseOffset(progress: visibleProgress, burstLevel: burstLevel))
        .scaleEffect(reduceMotion ? 1 : popScale(visibleProgress))
        .opacity(tileOpacity)
        .zIndex(20)
        .compositingGroup()
        .onAppear {
            // In both modes `progress` animates 0→1; reduce-motion just skips the slide/scale/
            // particles above and reads as a clean fade-out.
            let curve: Animation = reduceMotion
                ? .easeOut(duration: escapingBlock.duration)
                : .timingCurve(0.18, 0.82, 0.24, 1, duration: escapingBlock.duration)
            withAnimation(curve) {
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
        escapingBlock.chain >= 5 ? 7 : 6
    }

    private var burstColor: Color {
        .ppSoftCoral
    }

    // Photosensitivity guard (G8): the full-tile white flash is capped well below its old
    // 0.58 peak and suppressed entirely under reduce-motion, so a fast chain never strobes.
    private func flashOpacity(_ value: CGFloat) -> Double {
        guard !reduceMotion else { return 0 }
        return Double(max(0, 0.30 - value * 1.1))
    }

    private func arrowRotation(_ value: CGFloat) -> Double {
        let direction: Double = escapingBlock.chain.isMultiple(of: 2) ? -1 : 1
        return direction * Double(ppSmoothStep(ppUnit(value / 0.72))) * Double(min(escapingBlock.chain, 6)) * 3.0
    }

    private func releaseOffset(progress: CGFloat, burstLevel: CGFloat) -> CGSize {
        guard !reduceMotion else { return .zero }

        // Glide across more of the pop's life (0.85 vs 0.7) and travel further (≈0.55–0.8 of a
        // cell), so the block reads as smoothly sliding out rather than a quick hop.
        let slideProgress = ppEaseOutCubic(ppUnit(progress / 0.85))
        let distance = cellSize * (0.55 + burstLevel * 0.22)
        return escapingBlock.block.direction.vector.scaled(by: distance * slideProgress)
    }
}

private struct FloatingScoreView: View {
    let amount: Int
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        Text("+\(amount)")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.ppMintButtonText)
            .shadow(color: Color.ppWarmCream.opacity(0.85), radius: 2, x: 0, y: 1)
            .offset(y: reduceMotion ? -10 : -(8 + 34 * progress))
            .opacity(opacity)
            .scaleEffect(reduceMotion ? 1 : 0.7 + 0.5 * ppEaseOutCubic(ppUnit(progress / 0.4)))
            .onAppear {
                withAnimation(.easeOut(duration: 0.62)) {
                    progress = 1
                }
            }
    }

    private var opacity: Double {
        if reduceMotion {
            return Double(1 - ppSmoothStep(ppUnit((progress - 0.4) / 0.6)))
        }
        return Double(1 - ppSmoothStep(ppUnit((progress - 0.25) / 0.75)))
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
    /// The cell's side length, used to size the shared `BlockFace` so the board, the home guide,
    /// and the tutorial all render the same block from one code path.
    let side: CGFloat
    let isOpen: Bool
    let isPressed: Bool
    /// Emphasis for the open cue (the Open-Path Highlight setting). The cue is drawn on
    /// every open cell regardless; this only brightens/pulses it.
    let showOpenHint: Bool
    let reduceMotion: Bool
    /// VoiceOver pop: an open occupied cell exposes this as its activate action, since a
    /// VoiceOver user can't flick (WI-5.5). The board gates it on `isDealing`/`running`.
    var onAccessibilityPop: () -> Void = {}

    private var cornerRadius: CGFloat { side * 12 / 48 }

    var body: some View {
        ZStack {
            if let block {
                // Removed instantly (no fade) so it never ghosts behind the escaping-block
                // pop animation — that avoids the double-animation WI-8.2 warns about.
                blockView(block)
                    .transition(.identity)
            } else {
                // The empty slot fades in gently as the block clears (F8), honoring reduce motion.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ppInkGray.opacity(0.035))
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: block == nil)
        .scaleEffect(pressScale)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72), value: isPressed)
        .modifier(BoardCellAccessibility(
            label: block.map { accessibilityLabel(for: $0) },
            isButton: block != nil && isOpen,
            onPop: onAccessibilityPop
        ))
    }

    // The block's intrinsic face comes from the shared `BlockFace`; the board layers on the
    // run-state cues it owns (open-path highlight, miss stroke + shake) so those never leak into
    // the guide / tutorial previews.
    private func blockView(_ block: PopBlock) -> some View {
        BlockFace(block, side: side)
            .openPathCue(isOpen: isOpen, emphasized: showOpenHint, reduceMotion: reduceMotion, cornerRadius: cornerRadius)
            .overlay {
                if block.isMiss {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.ppSoftCoral.opacity(0.75), lineWidth: 2)
                }
            }
            .modifier(ShakeEffect(shakes: block.isMiss ? 2 : 0))
            .animation(.linear(duration: 0.18), value: block.isMiss)
    }

    private var pressScale: CGFloat {
        guard isPressed, block != nil, !reduceMotion else { return 1 }
        return 0.94
    }

    private func accessibilityLabel(for block: PopBlock) -> String {
        // A button when open; VoiceOver appends "double-tap to activate", which fires the pop.
        let state = isOpen ? language.text("open path", "열린 길") : language.text("blocked", "막힌 길")
        let directionName = block.direction.accessibilityName(language: language)

        switch block.kind {
        case .normal:
            return language.text("\(directionName) arrow, \(state)", "\(directionName) 화살표, \(state)")
        case .bomb:
            return language.text("Bomb, \(directionName) arrow, \(state)", "폭탄, \(directionName) 화살표, \(state)")
        case .armored:
            let armorState = block.armor > 0
                ? language.text("Armored", "단단한")
                : language.text("Cracked", "금 간")
            return language.text("\(armorState) \(directionName) arrow, \(state)", "\(armorState) \(directionName) 화살표, \(state)")
        case .wild:
            // Wild has no single required direction.
            return language.text("Wild block, \(state)", "만능 블록, \(state)")
        }
    }
}

/// Per-cell VoiceOver: occupied open cells are buttons whose activate action pops them;
/// blocked cells are described but not actionable; empty cells are hidden so VoiceOver skips
/// the dead space (WI-5.5).
private struct BoardCellAccessibility: ViewModifier {
    let label: String?
    let isButton: Bool
    let onPop: () -> Void

    func body(content: Content) -> some View {
        if let label {
            if isButton {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onPop() }
            } else {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
            }
        } else {
            content.accessibilityHidden(true)
        }
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
        // Spoken via UIAccessibility announcement on the board toast change, so the transient
        // visual doesn't also grab VoiceOver focus.
        .accessibilityHidden(true)
    }

    private var iconName: String {
        switch toast.style {
        case .chain: "sparkles"
        case .unlock: "key.fill"
        case .freshPath: "shuffle"
        case .clear: "checkmark"
        case .celebration: "crown.fill"
        case .penalty: "exclamationmark.triangle.fill"
        }
    }

    private var titleText: String {
        toast.localizedTitle(language: language)
    }

    private var detailText: String {
        toast.localizedDetail(language: language)
    }

    private var foregroundColor: Color {
        switch toast.style {
        case .chain, .unlock, .clear, .celebration: .ppMintButtonText
        case .freshPath: .ppMintText
        case .penalty: .white
        }
    }

    private var backgroundColor: Color {
        switch toast.style {
        case .chain, .celebration: .ppSoftCoral
        case .unlock: .ppFreshMint
        case .freshPath, .clear: .ppFreshMint
        case .penalty: .ppPenaltyRedDeep
        }
    }

    private var shadowColor: Color {
        switch toast.style {
        case .chain, .celebration: Color.ppSoftCoral.opacity(0.3)
        case .unlock: Color.ppMintText.opacity(0.25)
        case .freshPath, .clear: Color.ppMintText.opacity(0.22)
        case .penalty: Color.ppPenaltyRedDeep.opacity(0.32)
        }
    }
}

/// The wrong-flick penalty cue: a soft red glow hugging the whole screen edge. Driven by a
/// fading opacity so it reads as a single punishing pulse, not a strobe. Non-interactive.
private struct MissEdgeFlash: View {
    let opacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .stroke(Color.ppPenaltyRed, lineWidth: 22)
            .blur(radius: 11)
            .padding(-8)
            .ignoresSafeArea()
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    // The particle burst still reads its tint by tone; routed through the shared `fillColor` so a
    // tone's color is defined exactly once (in DesignSystem).
    var color: Color { fillColor }
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

    var symbolName: String {
        switch self {
        case .up: "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .left: "arrowtriangle.left.fill"
        case .right: "arrowtriangle.right.fill"
        }
    }
}
