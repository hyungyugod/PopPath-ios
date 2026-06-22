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
    static let ppWarmGray = Color(hex: 0x7E878E)
    static let ppMintText = Color(hex: 0x3F7A5E)
    static let ppMintButtonText = Color(hex: 0x23413A)
}

extension Font {
    static func ppDisplay(
        _ size: CGFloat,
        weight: Font.Weight = .semibold,
        language: AppLanguage = .english
    ) -> Font {
        if language == .korean {
            return .custom("Jua-Regular", size: size).weight(koreanWeight(for: weight))
        }

        return .custom(fredokaName(for: weight), size: size)
    }

    static func ppBody(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        language: AppLanguage = .english
    ) -> Font {
        if language == .korean {
            return .custom("Jua-Regular", size: size).weight(koreanWeight(for: weight))
        }

        return .custom(nunitoName(for: weight), size: size)
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

extension View {
    func ppScreenPadding() -> some View {
        padding(.horizontal, 26)
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

/// The "this path is open" affordance — a mint outline plus a dark corner pip — drawn on
/// every escapable block *by default* (so open vs. blocked is legible without the setting),
/// and brightened with a slow pulse when `emphasized` (the Open-Path Highlight setting) is
/// on. One definition shared by the live board and the tutorial so the two can't drift. The
/// cue reads as a shape + brightness change, not a hue, so it survives grayscale.
struct OpenPathCue: ViewModifier {
    let isOpen: Bool
    let emphasized: Bool
    let reduceMotion: Bool
    var cornerRadius: CGFloat = 12

    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isOpen {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                        .shadow(
                            color: Color.ppMintText.opacity(emphasized ? 0.22 : 0.12),
                            radius: emphasized ? 12 : 6,
                            x: 0,
                            y: emphasized ? 5 : 3
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                if isOpen {
                    Circle()
                        .fill(Color.ppMintButtonText)
                        .frame(width: 7, height: 7)
                        .opacity(emphasized ? 1 : 0.9)
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

    // When emphasized, `pulse` oscillates the stroke between resting and bright via the
    // repeating animation above; when not, the cue rests at a subtle always-on outline.
    private var strokeColor: Color {
        guard isOpen else { return .clear }
        if emphasized {
            return Color.ppFreshMint.opacity(pulse && !reduceMotion ? 0.45 : 0.95)
        }
        return Color.ppFreshMint.opacity(0.55)
    }

    private var strokeWidth: CGFloat {
        guard isOpen else { return 0 }
        if emphasized {
            return pulse && !reduceMotion ? 7 : 3
        }
        return 2
    }

    private func syncPulse() {
        guard isOpen, emphasized, !reduceMotion else {
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
