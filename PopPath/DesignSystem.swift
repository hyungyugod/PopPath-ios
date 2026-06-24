import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .korean:
            return "한국어"
        }
    }

    var shortName: String {
        switch self {
        case .english:
            return "EN"
        case .korean:
            return "한"
        }
    }

    func text(_ english: String, _ korean: String) -> String {
        switch self {
        case .english:
            return english
        case .korean:
            return korean
        }
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }

    static let ppWarmCream = Color(hex: 0xF7F4EE)
    static let ppCardCream = Color(hex: 0xFFFDF9)
    static let ppSoftSage = Color(hex: 0xDDEBE4)
    static let ppMistBlue = Color(hex: 0xAFC8DA)
    static let ppLavenderMist = Color(hex: 0xC9C2E8)
    static let ppFreshMint = Color(hex: 0x8FD8B5)
    static let ppSoftCoral = Color(hex: 0xF3A38A)
    static let ppInkGray = Color(hex: 0x2F3942)
    // Darkened from 0x7E878E to clear AA (≥4.5:1) for secondary text on cream/sage (G5).
    static let ppWarmGray = Color(hex: 0x5C6469)
    static let ppMintText = Color(hex: 0x3F7A5E)
    static let ppMintButtonText = Color(hex: 0x23413A)

    // Special-block fills — added so bomb / armored / wild read at a glance, not just via a
    // tiny badge. Each is light enough to keep the dark ink arrow at AAA contrast, hue-distinct
    // from the two normal tones, and deliberately *off* the reserved mint (open-path cue) and
    // coral (miss stroke) colors so a persistent special fill can never be mistaken for either.
    static let ppBombBlush = Color(hex: 0xF6D9C4)    // bomb — warm peach-sand
    static let ppArmorSteel = Color(hex: 0xCED9DE)   // armored, intact — cool plated steel
    static let ppArmorCrack = Color(hex: 0xE3E8EA)   // armored, cracked — paler "drained" steel
    static let ppWildButter = Color(hex: 0xF1E6B8)   // wild — soft butter-gold (well off mint)
    static let ppSpecialRing = Color(hex: 0x6E5A4E)  // cocoa-taupe ink for special frames/badges
}

extension Font {
    // All custom fonts are bound to a Dynamic Type text style via `relativeTo:` so they
    // scale with the user's preferred content size (G2/G3) instead of staying pixel-fixed.
    // Korean (Jua) renders visually smaller at a given point size, so it gets a small uplift.
    static func ppDisplay(
        _ size: CGFloat,
        weight: Font.Weight = .semibold,
        language: AppLanguage = .english,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        if language == .korean {
            return .custom("Jua-Regular", size: koreanSize(size), relativeTo: textStyle)
                .weight(koreanWeight(for: weight))
        }

        return .custom(fredokaName(for: weight), size: size, relativeTo: textStyle)
    }

    static func ppBody(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        language: AppLanguage = .english,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        if language == .korean {
            return .custom("Jua-Regular", size: koreanSize(size), relativeTo: textStyle)
                .weight(koreanWeight(for: weight))
        }

        return .custom(nunitoName(for: weight), size: size, relativeTo: textStyle)
    }

    private static func koreanSize(_ size: CGFloat) -> CGFloat {
        (size * 1.03).rounded()
    }

    private static func fredokaName(for weight: Font.Weight) -> String {
        if weight == .bold || weight == .heavy || weight == .black {
            return "Fredoka-Bold"
        }
        if weight == .semibold {
            return "Fredoka-SemiBold"
        }
        if weight == .medium {
            return "Fredoka-Medium"
        }
        return "Fredoka-Regular"
    }

    private static func nunitoName(for weight: Font.Weight) -> String {
        if weight == .heavy || weight == .black {
            return "Nunito-ExtraBold"
        }
        if weight == .bold {
            return "Nunito-Bold"
        }
        if weight == .semibold {
            return "Nunito-SemiBold"
        }
        if weight == .medium {
            return "Nunito-Medium"
        }
        return "Nunito-Regular"
    }

    private static func koreanWeight(for weight: Font.Weight) -> Font.Weight {
        if weight == .heavy || weight == .black || weight == .bold {
            return .bold
        }
        if weight == .semibold {
            return .semibold
        }
        if weight == .medium {
            return .medium
        }
        return .regular
    }
}

extension Bundle {
    /// Real app version for display, e.g. "v1.0 (3)" — replaces the hardcoded "v0" (I4).
    var appVersionDisplay: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

extension View {
    func ppScreenPadding() -> some View {
        padding(.horizontal, 26)
    }

    /// A left-edge swipe-right that triggers `action` (a back affordance for the manual route
    /// switch, K15). Lower-priority `.gesture` so vertical scrolling still wins; only a clearly
    /// horizontal drag starting near the left edge resolves to a back.
    func edgeSwipeBack(perform action: @escaping () -> Void) -> some View {
        gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.startLocation.x < 28,
                       value.translation.width > 70,
                       abs(value.translation.height) < 60 {
                        action()
                    }
                }
        )
    }
}

struct PrimaryPopButton: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                Text(title)
                    .font(.ppDisplay(22, weight: .semibold, language: language))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.ppMintButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.ppFreshMint)
                    .shadow(color: Color.ppMintText.opacity(0.28), radius: 22, x: 0, y: 11)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.34))
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct SecondaryPopButton: View {
    @Environment(\.appLanguage) private var language

    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(width: 22)

                Text(title)
                    .font(.ppDisplay(16, weight: .semibold, language: language))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 10)

                Text(detail)
                    .font(.ppBody(12, weight: .heavy, language: language))
                    .foregroundStyle(Color.ppMintText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(Color.ppInkGray)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ppCardCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.ppMintText.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.ppInkGray.opacity(0.09), radius: 13, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct IconTileButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ppInkGray)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.ppCardCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.ppInkGray.opacity(0.07), lineWidth: 1)
                        )
                        .shadow(color: Color.ppInkGray.opacity(0.16), radius: 10, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PillStat: View {
    @Environment(\.appLanguage) private var language

    let label: String
    let value: String
    var valueColor: Color = .ppInkGray

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.ppBody(12, weight: .heavy, language: language))
                .foregroundStyle(Color.ppMintText.opacity(0.82))
            Text(value)
                .font(.ppDisplay(17, weight: .bold, language: language))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(Color.ppSoftSage))
    }
}

struct ArrowGlyph: View {
    let arrow: String
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .symbolRenderingMode(.monochrome)
    }

    private var symbolName: String {
        switch arrow {
        case "▲": "arrowtriangle.up.fill"
        case "▼": "arrowtriangle.down.fill"
        case "◀": "arrowtriangle.left.fill"
        case "▶": "arrowtriangle.right.fill"
        default: "arrowtriangle.right.fill"
        }
    }
}

/// The "this path is open" affordance — a mint outline plus a dark corner pip with a slow
/// pulse — drawn ONLY when `emphasized` is on. `emphasized` is the Practice Mode / Open-Path
/// Highlight setting (off by default), so a normal run shows no open cue at all and the player
/// reads the arrows themselves; turning it on reveals the open paths and flips the run into
/// Practice Mode. One definition shared by the live board and the tutorial (which always
/// emphasizes, since it's a teaching surface) so the two can't drift. The cue reads as a shape
/// + brightness change, not a hue, so it survives grayscale.
struct OpenPathCue: ViewModifier {
    let isOpen: Bool
    let emphasized: Bool
    let reduceMotion: Bool
    var cornerRadius: CGFloat = 12

    @State private var pulse = false

    private var showsCue: Bool { isOpen && emphasized }

    func body(content: Content) -> some View {
        content
            .overlay {
                if showsCue {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                        .shadow(color: Color.ppMintText.opacity(0.22), radius: 12, x: 0, y: 5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsCue {
                    Circle()
                        .fill(Color.ppMintButtonText)
                        .frame(width: 7, height: 7)
                        .padding(6)
                }
            }
            .onAppear { syncPulse() }
            .onChange(of: isOpen) { _, _ in syncPulse() }
            .onChange(of: emphasized) { _, _ in syncPulse() }
            .onChange(of: reduceMotion) { _, _ in syncPulse() }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                value: pulse
            )
    }

    // `pulse` oscillates the stroke between resting and bright via the repeating animation above.
    private var strokeColor: Color {
        guard showsCue else { return .clear }
        return Color.ppFreshMint.opacity(pulse && !reduceMotion ? 0.45 : 0.95)
    }

    private var strokeWidth: CGFloat {
        guard showsCue else { return 0 }
        return pulse && !reduceMotion ? 7 : 3
    }

    private func syncPulse() {
        guard showsCue, !reduceMotion else {
            pulse = false
            return
        }
        pulse = true
    }
}

extension View {
    func openPathCue(
        isOpen: Bool,
        emphasized: Bool,
        reduceMotion: Bool,
        cornerRadius: CGFloat = 12
    ) -> some View {
        modifier(
            OpenPathCue(
                isOpen: isOpen,
                emphasized: emphasized,
                reduceMotion: reduceMotion,
                cornerRadius: cornerRadius
            )
        )
    }
}

/// A faint, per-tone shape in the block's corner. The two block tones are purely decorative
/// (assigned by board parity), but a colorblind player can't tell them apart by hue — this
/// gives each a distinct grayscale-legible motif so the board reads as varied, not as a flat
/// mass, without ever implying the tone carries state. Kept subordinate to the arrow glyph.
struct BlockToneMotif: View {
    let tone: BlockTone

    var body: some View {
        motif
            .foregroundStyle(Color.ppInkGray.opacity(0.11))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(8)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var motif: some View {
        switch tone {
        case .mistBlue:
            Circle()
                .stroke(lineWidth: 1.5)
                .frame(width: 7, height: 7)
        case .lavenderMist:
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(45))
        }
    }
}

extension BlockTone {
    /// The cell fill for a normal block of this tone — the single source of truth shared by the
    /// board cell, the escaping-pop animation, the home block guide, and the tutorial card.
    var fillColor: Color {
        switch self {
        case .mistBlue: return .ppMistBlue
        case .lavenderMist: return .ppLavenderMist
        }
    }
}

/// A small static zig-zag drawn behind the arrow on a cracked armored block — a literal,
/// motion-free "the shell broke" cue (so it survives reduce-motion and grayscale).
private struct CrackMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY))
        return path
    }
}

/// The intrinsic face of a block — fill, tone motif, special frame, centered glyph, and corner
/// emblem — rendered identically wherever a block is shown: the live board cell, the home block
/// guide, and the tutorial intro card. It carries NO run-state (no press scale, open-path cue,
/// miss stroke, or accessibility); the board cell layers those on top. Keeping the face here is
/// what stops the three surfaces from drifting apart. Every inner metric scales from `side`, so
/// the board (≈cell size), the guide (44), and the tutorial (38) all render from one code path.
struct BlockFace: View {
    let kind: BlockKind
    var tone: BlockTone = .mistBlue
    var direction: Direction = .right
    /// Armored only: the shell has been cracked (one flick left). Ignored for other kinds.
    var isCracked: Bool = false
    var side: CGFloat = 48

    init(
        kind: BlockKind,
        tone: BlockTone = .mistBlue,
        direction: Direction = .right,
        isCracked: Bool = false,
        side: CGFloat = 48
    ) {
        self.kind = kind
        self.tone = tone
        self.direction = direction
        self.isCracked = isCracked
        self.side = side
    }

    /// Build a face straight from a model block (maps armored `armor == 0` to the cracked face).
    init(_ block: PopBlock, side: CGFloat = 48) {
        self.init(
            kind: block.kind,
            tone: block.tone,
            direction: block.direction,
            isCracked: block.kind == .armored && block.armor == 0,
            side: side
        )
    }

    private var scale: CGFloat { side / 48 }
    private var cornerRadius: CGFloat { 12 * scale }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            shape
                .fill(BlockFace.fillColor(kind: kind, tone: tone, isCracked: isCracked))
                .shadow(color: Color.ppInkGray.opacity(0.13), radius: 9 * scale, x: 0, y: 4 * scale)
                .overlay(alignment: .top) {
                    shape
                        .fill(.white.opacity(0.45))
                        .frame(height: 1)
                        .padding(.horizontal, 10 * scale)
                }

            // The decorative tone motif is a normal-block-only cue; specials carry their own
            // detailing, so it's suppressed there to keep them clean.
            if kind == .normal {
                BlockToneMotif(tone: tone)
            }

            if kind == .armored, isCracked {
                CrackMark()
                    .stroke(
                        Color.ppSpecialRing.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: side * 0.4, height: side * 0.5)
                    .offset(x: side * 0.1, y: -side * 0.02)
                    .allowsHitTesting(false)
            }

            specialFrame(shape)

            glyph
        }
        .frame(width: side, height: side)
        .overlay(alignment: .topLeading) { badge }
    }

    @ViewBuilder
    private var glyph: some View {
        if kind == .wild {
            // Wild pops in any open direction — a four-way glyph, not a single arrow.
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ppInkGray)
        } else {
            ArrowGlyph(arrow: direction.arrow, size: 18 * scale)
                .foregroundStyle(Color.ppInkGray)
        }
    }

    /// A shape-based frame per special kind, each distinct from the others AND from the two
    /// run-state strokes the board layers on top (the solid pulsing mint open-path cue and the
    /// solid coral miss stroke). Bomb = warm dashed ring; armored intact = heavy solid plate;
    /// armored cracked = thin broken ring; wild = fine dark dotted ring (off mint, which the
    /// open-path cue owns — wild sits on already-open cells where that cue overlays it).
    @ViewBuilder
    private func specialFrame(_ shape: RoundedRectangle) -> some View {
        switch kind {
        case .bomb:
            shape.strokeBorder(
                Color.ppSpecialRing.opacity(0.55),
                style: StrokeStyle(lineWidth: 2.5 * scale, dash: [4 * scale, 3 * scale])
            )
        case .armored:
            if isCracked {
                shape.strokeBorder(
                    Color.ppSpecialRing.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5 * scale, dash: [3 * scale, 3 * scale])
                )
            } else {
                shape.strokeBorder(Color.ppSpecialRing.opacity(0.6), lineWidth: 3 * scale)
            }
        case .wild:
            shape.strokeBorder(
                Color.ppInkGray.opacity(0.4),
                style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, dash: [1.5 * scale, 3 * scale])
            )
        case .normal:
            EmptyView()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let symbol = badgeSymbol {
            Image(systemName: symbol)
                .font(.system(size: 10 * scale, weight: .black, design: .rounded))
                .foregroundStyle(badgeGlyphColor)
                .frame(width: 18 * scale, height: 18 * scale)
                .background(
                    Circle()
                        .fill(Color.ppCardCream)
                        .overlay(Circle().strokeBorder(badgeKeyline, lineWidth: 0.75 * scale))
                )
                .padding(3 * scale)
        }
    }

    private var badgeSymbol: String? {
        switch kind {
        case .normal: return nil
        case .bomb: return "burst.fill"
        case .armored: return isCracked ? "shield.lefthalf.filled" : "shield.fill"
        case .wild: return "sparkles"
        }
    }

    private var badgeGlyphColor: Color {
        kind == .wild ? .ppMintText : .ppSpecialRing
    }

    private var badgeKeyline: Color {
        if kind == .wild { return Color.ppMintText.opacity(0.5) }
        if kind == .armored, isCracked { return Color.ppSpecialRing.opacity(0.4) }
        return Color.ppSpecialRing.opacity(0.75)
    }

    /// The fill for any block — the single mapping used by the board, the escaping-pop animation,
    /// the guide, and the tutorial, so a kind's color is defined exactly once.
    static func fillColor(kind: BlockKind, tone: BlockTone, isCracked: Bool) -> Color {
        switch kind {
        case .normal: return tone.fillColor
        case .bomb: return .ppBombBlush
        case .armored: return isCracked ? .ppArmorCrack : .ppArmorSteel
        case .wild: return .ppWildButter
        }
    }

    static func fillColor(for block: PopBlock) -> Color {
        fillColor(
            kind: block.kind,
            tone: block.tone,
            isCracked: block.kind == .armored && block.armor == 0
        )
    }
}

/// A board-modifier emblem (Rush / Bonus) shown in the block guide and tutorial card. Modifiers
/// are board states, not blocks, so they get a distinct treatment — the reserved coral / mint
/// border from the live board banner, not a `BlockFace` tint — visually teaching "these are
/// boards, not blocks."
struct ModifierChip: View {
    let modifier: BoardModifier
    var side: CGFloat = 44

    var body: some View {
        let scale = side / 44
        RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
            .fill(Color.ppCardCream)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2 * scale)
            )
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 18 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ppInkGray)
            }
            .frame(width: side, height: side)
    }

    private var borderColor: Color {
        switch modifier {
        case .rush: return .ppSoftCoral
        case .bonus, .none: return .ppFreshMint
        }
    }

    private var symbol: String {
        switch modifier {
        case .rush: return "bolt.fill"
        case .bonus, .none: return "gift.fill"
        }
    }
}

/// What a guide / tutorial row previews: a real block face or a board modifier. Shared by the
/// home block guide and the tutorial intro card so both preview blocks exactly as the board does.
enum GuideFaceKind: Equatable {
    case block(BlockKind, cracked: Bool)
    case modifier(BoardModifier)
}

/// Renders a `GuideFaceKind` at a given size — a `BlockFace` for blocks, a `ModifierChip` for
/// board modifiers.
struct GuideFace: View {
    let kind: GuideFaceKind
    var direction: Direction = .right
    var tone: BlockTone = .mistBlue
    var side: CGFloat = 44

    var body: some View {
        switch kind {
        case let .block(blockKind, cracked):
            BlockFace(kind: blockKind, tone: tone, direction: direction, isCracked: cracked, side: side)
        case let .modifier(modifier):
            ModifierChip(modifier: modifier, side: side)
        }
    }
}
