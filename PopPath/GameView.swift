import SwiftUI
import UIKit

struct GameView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var game: GameModel
    // Bindings (not values) so the paused overlay can flip them mid-run (K17).
    @Binding var soundEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var colorAssist: Bool
    let reduceMotion: Bool
    var startsPaused = false
    let onExit: () -> Void

    @State private var showDailyRestartConfirm = false
    // The paused overlay is shown ONLY by the pause button. The daily-restart confirm also
    // freezes the clock via game.pause(), but must not surface this overlay (that would stack
    // two modals), so it is gated on this flag, not on runState. Quitting to Home now lives
    // inside this overlay (the old separate Home button was redundant with it).
    @State private var showPausedOverlay = false
    @State private var didApplyInitialPause = false
    /// Drives the red screen-edge penalty flash on a wrong flick; pulsed by `missFlashToken`.
    @State private var missFlash: Double = 0

    // Tier theming (driven purely from published score/best — no model/scoring changes). The
    // board's surface, glow, and the HUD tier badge all read `currentGrade`; `displayedTier`
    // tracks the last-rendered tier so crossing UP into a new one mid-run fires a one-shot
    // flourish. Starts at -1 so the initial value is adopted on appear without celebrating.
    @State private var displayedTier = -1
    /// Non-nil briefly while the "new tier" flourish is on screen.
    @State private var tierUpFlash: Grade?
    /// Springs the HUD tier badge on a rank-up.
    @State private var tierBadgePulse = false
    /// The single owner of the flourish auto-dismiss timer, so a second rank-up cancels the
    /// first's stale timer instead of letting it nil the newer celebration out early.
    @State private var tierFlourishTask: Task<Void, Never>?

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
                tierGrade: currentGrade,
                colorAssist: colorAssist,
                reduceMotion: reduceMotion,
                onFlick: { row, column, direction in
                    game.attemptPop(
                        row: row,
                        column: column,
                        direction: direction,
                        hapticsEnabled: hapticsEnabled,
                        soundEnabled: soundEnabled,
                        reduceMotion: reduceMotion
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
                    isDaily: game.mode == .daily,
                    onNewBoard: {
                        game.reshuffleBoard()
                    },
                    onRestartDaily: {
                        showPausedOverlay = false
                        showDailyRestartConfirm = true
                    },
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
        // "New tier" flourish — a brief, non-interactive celebration when this run climbs into a
        // rank above where it started. `allowsHitTesting(false)` (inside the view) means taps keep
        // landing on the blocks underneath, so it never adds the input delay we just removed.
        .overlay {
            if let grade = tierUpFlash {
                TierUpFlourish(grade: grade, reduceMotion: reduceMotion)
                    .id(grade.tier)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0 : 0.2), value: showPausedOverlay)
        .onAppear {
            guard startsPaused, !didApplyInitialPause else { return }
            didApplyInitialPause = true
            game.pause()
            showPausedOverlay = true
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
        // Any dismissal of a confirm that didn't restart the run (cancel button OR an outside-tap
        // that runs no button) must lift the clock-freeze, so the game can never get stuck paused
        // with no visible overlay.
        .onChange(of: showDailyRestartConfirm) { _, showing in
            if !showing && game.runState == .paused { game.resume() }
        }
        // Adopt the starting tier silently (a Gold player's board opens Gold — that's not a
        // "new tier" moment), then celebrate only genuine upward crossings during the run.
        .onAppear { displayedTier = currentGrade.tier }
        .onChange(of: currentGrade.tier) { _, newTier in
            if displayedTier >= 0, newTier > displayedTier {
                celebrateTierUp(currentGrade)
            }
            displayedTier = newTier
        }
        .onDisappear { tierFlourishTask?.cancel() }
        // Leaving the foreground mid-round (incoming call, Control/Notification Center, the app
        // switcher, or a full background) must not burn the 60s wall clock — that loses a whole
        // run to a single interruption. Freeze the clock + chain via the same pause() the manual
        // pause button uses, and surface the paused overlay so the player resumes deliberately on
        // return (RootView.handleForeground stays a no-op while paused). Guarded on `.running` so
        // we never stack on an already-open confirm/pause overlay or re-pause a finished round.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, game.runState == .running {
                game.pause()
                showPausedOverlay = true
            }
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

    /// The tier driving the in-game theme. `max(best, score)` means the board always reflects at
    /// least the player's *established* rank (the persistent theme), and climbs live the moment
    /// this run's score passes a new threshold (the in-run evolution) — the two halves of the
    /// "both" tier treatment, computed entirely from already-published values.
    private var currentGrade: Grade {
        let establishedBest = game.mode == .daily ? game.dailyBest : game.best
        return Grade.forScore(max(establishedBest, game.score))
    }

    /// One-shot rank-up celebration: pulse the HUD badge, surface the flourish, speak it to
    /// VoiceOver, then auto-dismiss. Purely presentational — no model state is touched.
    private func celebrateTierUp(_ grade: Grade) {
        // A practice run credits nothing, so it celebrates nothing — a "NEW TIER" moment +
        // VoiceOver shout for a rank that won't be saved would be a lie (mirrors the model's
        // surfaceLiveMilestones `!isPractice` guard). The ambient board tint still follows the
        // live score; only the explicit celebration is suppressed.
        guard !game.isPractice else { return }

        if reduceMotion {
            tierUpFlash = grade
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { tierBadgePulse = true }
            withAnimation(.easeOut(duration: 0.3)) { tierUpFlash = grade }
        }
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: language.text("Reached \(grade.nameEN) tier", "\(grade.nameKO) 등급 달성")
            )
        }
        // One owner for the auto-dismiss timer: cancel any in-flight flourish so a second rank-up
        // within ~1.4s (the low tiers are only 5k apart) can't have its celebration nilled out
        // early by the previous one's stale timer. Guard after each sleep so a cancelled timer
        // makes no further mutations.
        tierFlourishTask?.cancel()
        tierFlourishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { tierBadgePulse = false }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { tierUpFlash = nil }
        }
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
        HStack(spacing: 8) {
            // Leading: the live rank badge. It fills the slot the old Home button used to occupy
            // (exit now lives inside the pause overlay), and turns that space into progression
            // feedback — climbing tiers mid-run pulses it.
            GradeBadge(grade: currentGrade, compact: true)
                .scaleEffect(tierBadgePulse ? 1.16 : 1)
                .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.55), value: tierBadgePulse)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: currentGrade.tier)

            Spacer(minLength: 6)

            VStack(spacing: 3) {
                difficultyPip
                if game.isPractice {
                    practiceBadge
                }
            }

            Spacer(minLength: 6)

            // Single in-game control: pause → overlay (Resume / New board / Quit to Home). The
            // separate Home button was removed — its job (quitting) is the overlay's Quit action.
            Button { game.pause(); showPausedOverlay = true } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ppInkGray.opacity(0.82))
                    .frame(width: 38, height: 38)
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
            .accessibilityHint(language.text("Pause and open the menu", "일시정지하고 메뉴를 엽니다"))
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack {
            footerLeading

            Spacer(minLength: 12)

            if game.mode == .daily {
                Label(language.text("One run", "한 번의 도전"), systemImage: "seal.fill")
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(minHeight: 34)
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
    let isDaily: Bool
    let onNewBoard: () -> Void
    let onRestartDaily: () -> Void
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

                PausedUtilityButton(
                    title: isDaily ? language.text("Restart Daily", "오늘 도전 다시") : language.text("New board", "새 보드"),
                    detail: isDaily
                        ? language.text("Forfeit this run", "현재 도전은 사라져요")
                        : language.text("Keep score and time", "점수와 시간은 유지"),
                    systemImage: "arrow.clockwise",
                    tint: isDaily ? .ppSoftCoral : .ppMintText,
                    action: isDaily ? onRestartDaily : onNewBoard
                )
                .padding(.bottom, 2)

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

private struct PausedUtilityButton: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.opacity(0.16)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.ppDisplay(15, weight: .semibold, language: language))
                        .foregroundStyle(Color.ppInkGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(detail)
                        .font(.ppBody(11, weight: .medium, language: language))
                        .foregroundStyle(Color.ppWarmGray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.ppCardCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
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
    /// The rank theme for the board surface + glow (persistent best, climbing live this run).
    let tierGrade: Grade
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
                // The board surface + glow carry the tier theme: the calm base sage warms toward
                // the rank's hue as you climb (Rookie = unchanged). Opaque surface (not a tint
                // overlay) so the empty-cell gaps never show through oddly; blocks sit on top, so
                // the dark-ink arrows keep their contrast.
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(tierGrade.boardSurface)
                        // Rookie keeps the exact original shadow (0.10 / 8 / 2) so a brand-new
                        // player's board is pixel-identical to before; ranked tiers get a slightly
                        // richer, tier-tinted glow.
                        .shadow(
                            color: tierGrade.boardGlow.opacity(tierGrade.tier == 0 ? 0.10 : 0.16),
                            radius: tierGrade.tier == 0 ? 8 : 9,
                            x: 0,
                            y: tierGrade.tier == 0 ? 2 : 3
                        )
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: tierGrade.tier)
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
                guard let start else { return }
                // A deliberate flick stays direction-true (a wrong-direction flick still misses).
                // A tap — or a sub-threshold drag — has no resolved direction, so we pop the block
                // along its OWN arrow (wild taps take any open lane): one touch clears it, no
                // precise swipe needed. Tapping a block with no clear runway still misses.
                guard let direction = resolvedSwipeDirection(value) ?? tapDirection(at: start) else { return }
                onFlick(start.row, start.column, direction)
            }
    }

    /// The direction a *tap* on this cell should pop: the block's own arrow, or for a wild block
    /// any lane with a clear runway. nil when the cell is empty. Mirrors the VoiceOver pop path.
    private func tapDirection(at pos: BoardPosition) -> Direction? {
        guard let block = board[pos.row][pos.column] else { return nil }
        if block.kind == .wild {
            return Direction.allCases.first {
                GameRules.hasClearRunway(on: board, row: pos.row, column: pos.column, direction: $0)
            } ?? block.direction
        }
        return block.direction
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

        // The burst (glow bloom + particle spray) is gone entirely — on a normal pop the tapped
        // block just vanishes the instant the cell clears, with no "잔상" left behind. Reduce-motion
        // users still get a quiet in-place fade of the tile (plus the +N marker and haptic) as
        // confirmation, since an abrupt disappearance is exactly what that setting is meant to avoid.
        ZStack {
            if reduceMotion {
                let tileOpacity = 1 - ppSmoothStep(ppUnit((visibleProgress - 0.04) / 0.42))
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BlockFace.fillColor(for: escapingBlock.block))
                    Image(systemName: escapingBlock.block.direction.symbolName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ppInkGray)
                }
                .opacity(tileOpacity)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .zIndex(20)
        .onAppear {
            // Drives the reduce-motion confirmation fade; on motion this view renders nothing, so
            // the escaping block is just held for its brief lifetime and then removed.
            withAnimation(.easeOut(duration: escapingBlock.duration)) {
                progress = 1
            }
        }
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
            // Dark ink-green on the light pastel board reads cleanly WITHOUT a drop shadow; the
            // shadow forced a per-marker offscreen pass and several of these animate at once on a
            // fast streak, so dropping it is a direct rapid-fire perf win.
            .foregroundStyle(Color.ppMintButtonText)
            // A short fade in place — no rise, no scaleEffect. The offset is a fixed transform (free)
            // and the only animated property is opacity, so even several markers at once on a fast
            // streak neither travel nor re-rasterize: the lightest possible "+N" confirmation.
            .offset(y: -10)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
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

private func ppUnit(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
}

private func ppSmoothStep(_ value: CGFloat) -> CGFloat {
    let value = ppUnit(value)
    return value * value * (3 - 2 * value)
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
                // The empty slot appears quickly as the block clears, keeping fast taps crisp.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.ppInkGray.opacity(0.035))
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: block == nil)
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

/// A brief, non-interactive "new tier" celebration shown when a run climbs into a higher rank
/// than it started in. Non-blocking (`allowsHitTesting(false)`) so rapid popping continues
/// underneath, and a single spring-in / fade-out (no repeat) so it stays photosensitivity- and
/// reduce-motion-safe. The rank-up is spoken to VoiceOver separately, so this is a11y-hidden.
private struct TierUpFlourish: View {
    @Environment(\.appLanguage) private var language
    let grade: Grade
    let reduceMotion: Bool
    @State private var shown = false

    var body: some View {
        VStack(spacing: 8) {
            Text(language.text("NEW TIER", "새 등급"))
                .font(.ppBody(11, weight: .heavy, language: language))
                .tracking(language == .korean ? 0 : 1.4)
                .foregroundStyle(grade.badgeColor)
            GradeBadge(grade: grade)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppCardCream)
                .shadow(color: grade.badgeColor.opacity(0.32), radius: 22, x: 0, y: 10)
        )
        .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.72))
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.42, dampingFraction: 0.6)) {
                shown = true
            }
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

private extension Direction {
    var symbolName: String {
        switch self {
        case .up: "arrowtriangle.up.fill"
        case .down: "arrowtriangle.down.fill"
        case .left: "arrowtriangle.left.fill"
        case .right: "arrowtriangle.right.fill"
        }
    }
}
