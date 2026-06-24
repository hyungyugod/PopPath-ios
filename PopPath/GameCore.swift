import Foundation
import AVFoundation
import UIKit
import UserNotifications

enum Direction: CaseIterable, Codable {
    case up
    case down
    case left
    case right

    var arrow: String {
        switch self {
        case .up: "▲"
        case .down: "▼"
        case .left: "◀"
        case .right: "▶"
        }
    }

    var delta: (row: Int, column: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }

    /// Localized cardinal name, used by VoiceOver labels and the tutorial's flick hint.
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

    /// Resolves a drag translation into a cardinal flick direction, or `nil` when the
    /// gesture is a tap / too diagonal to be decisive. Defined once here so every input
    /// surface (board gesture, tutorial gate, VoiceOver) judges flicks identically.
    static func swipeDirection(
        for translation: CGSize,
        minimumDistance: CGFloat,
        axisBias: CGFloat
    ) -> Direction? {
        let absoluteX = abs(translation.width)
        let absoluteY = abs(translation.height)
        guard max(absoluteX, absoluteY) >= minimumDistance else { return nil }

        if absoluteX > absoluteY * axisBias {
            return translation.width > 0 ? .right : .left
        }
        if absoluteY > absoluteX * axisBias {
            return translation.height > 0 ? .down : .up
        }
        return nil
    }

    /// Two-tier flick resolution shared by every input surface (the live board and the
    /// tutorial gate) so they accept exactly the same flicks: a strict pass on the actual
    /// translation, then a lenient pass on the predicted end so a quick, decisive flick that
    /// lifts early still registers.
    static func resolveFlick(translation: CGSize, predictedEndTranslation: CGSize) -> Direction? {
        if let direction = swipeDirection(for: translation, minimumDistance: 14, axisBias: 1.16) {
            return direction
        }
        return swipeDirection(for: predictedEndTranslation, minimumDistance: 30, axisBias: 1.08)
    }
}

enum BlockTone: CaseIterable, Codable {
    case mistBlue
    case lavenderMist
}

/// What kind of block this is. Normal blocks follow the base rule (flick the arrow, needs a
/// clear lane). Specials add variety without breaking that contract:
/// - `bomb`: pops like a normal block, then detonates its whole row and column.
/// - `armored`: takes one extra flick — the first valid flick only cracks it.
/// - `wild`: pops with a flick in *any* direction that has a clear lane (its arrow is a hint,
///    not a requirement).
enum BlockKind: Equatable, Codable {
    case normal
    case bomb
    case armored
    case wild

    var isSpecial: Bool { self != .normal }
}

struct PopBlock: Identifiable, Equatable, Codable {
    var id = UUID()
    var direction: Direction
    var tone: BlockTone
    var isMiss = false
    var kind: BlockKind = .normal
    /// Remaining cracks before an armored block pops. A fresh armored block starts at 1, so the
    /// first valid flick cracks it (armor → 0) and the second pops it. Ignored for other kinds.
    var armor = 0

    // Decode each new field with a default so a board encoded by an earlier build still loads.
    init(
        id: UUID = UUID(),
        direction: Direction,
        tone: BlockTone,
        isMiss: Bool = false,
        kind: BlockKind = .normal,
        armor: Int = 0
    ) {
        self.id = id
        self.direction = direction
        self.tone = tone
        self.isMiss = isMiss
        self.kind = kind
        self.armor = armor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        direction = try c.decode(Direction.self, forKey: .direction)
        tone = try c.decode(BlockTone.self, forKey: .tone)
        isMiss = try c.decodeIfPresent(Bool.self, forKey: .isMiss) ?? false
        kind = try c.decodeIfPresent(BlockKind.self, forKey: .kind) ?? .normal
        armor = try c.decodeIfPresent(Int.self, forKey: .armor) ?? 0
    }
}

/// A per-board variety modifier rolled when a board is dealt (deterministic for the Daily).
/// Most boards are `none`; the others change the texture of a single board so no two rounds
/// feel identical.
enum BoardModifier: Equatable, Codable {
    case none
    /// Everything scores double, but chains decay faster — a high-octane board.
    case rush
    /// Clearing the board pays a much bigger bonus and grants extra time — go for the full sweep.
    case bonus

    /// Multiplier applied to per-pop / unlock / bomb scores.
    var scoreMultiplier: Double {
        switch self {
        case .rush: return 2.0
        case .none, .bonus: return 1.0
        }
    }

    /// Multiplier applied to the board-clear bonus.
    var clearMultiplier: Double {
        switch self {
        case .rush: return 2.0
        case .bonus: return 3.0
        case .none: return 1.0
        }
    }

    /// Factor applied to the chain-decay window (rush makes chains lapse faster).
    var decayFactor: Double {
        switch self {
        case .rush: return 0.7
        case .none, .bonus: return 1.0
        }
    }

    /// Seconds added to the round clock when this board is cleared.
    var clearTimeBonus: TimeInterval {
        switch self {
        case .bonus: return 5
        case .none, .rush: return 0
        }
    }

    static func roll<R: RandomNumberGenerator>(using random: inout R) -> BoardModifier {
        let value = Double.random(in: 0..<1, using: &random)
        if value < 0.18 { return .rush }
        if value < 0.30 { return .bonus }
        return .none
    }

    /// Short on-board chip label.
    func label(language: AppLanguage) -> String {
        switch self {
        case .none: return ""
        case .rush: return language.text("RUSH ×2", "러시 ×2")
        case .bonus: return language.text("BONUS", "보너스")
        }
    }

    /// Spoken VoiceOver announcement when the board's modifier changes.
    func announcement(language: AppLanguage) -> String {
        switch self {
        case .none: return ""
        case .rush: return language.text("Rush board. Double points, faster chains.", "러시 보드. 점수 2배, 더 빠른 체인.")
        case .bonus: return language.text("Bonus board. Big clear bonus and extra time.", "보너스 보드. 싹쓸이 보너스와 추가 시간.")
        }
    }
}

struct BoardPosition: Hashable {
    let row: Int
    let column: Int
}

struct EscapingBlock: Identifiable, Equatable {
    let id: UUID
    let block: PopBlock
    let row: Int
    let column: Int
    let chain: Int
    let startedAt: Date
    let duration: TimeInterval

    init(
        id: UUID,
        block: PopBlock,
        row: Int,
        column: Int,
        chain: Int = 1,
        startedAt: Date = .now,
        // A touch longer than the old 0.18 so a popped block glides out smoothly ("슥슥") instead
        // of snapping away; paired with a longer slide distance + gentler easing in the view.
        duration: TimeInterval = 0.26
    ) {
        self.id = id
        self.block = block
        self.row = row
        self.column = column
        self.chain = chain
        self.startedAt = startedAt
        self.duration = duration
    }
}

/// Score-based rank ladder: ten tiers starting at 10,000 points and rising in 5,000-point
/// steps (Bronze → Grandmaster), plus an unranked "Rookie" state below the first threshold.
/// Pure data — the tier's display color and badge glyph live in DesignSystem so this type
/// stays SwiftUI-free, mirroring how `BlockTone` keeps its color out of GameCore.
struct Grade: Equatable, Identifiable {
    /// 0 = unranked (below the first threshold); 1...10 = the ranked tiers, lowest first.
    let tier: Int
    let nameEN: String
    let nameKO: String
    /// The score at which this tier is reached. 0 for the unranked Rookie tier.
    let threshold: Int

    var id: Int { tier }

    func name(language: AppLanguage) -> String {
        language == .korean ? nameKO : nameEN
    }

    /// Shown before the player has crossed the first 10,000-point threshold.
    static let rookie = Grade(tier: 0, nameEN: "Rookie", nameKO: "새내기", threshold: 0)

    /// The ten ranked tiers, lowest first. Thresholds: 10k, 15k, … 55k.
    static let ranked: [Grade] = [
        Grade(tier: 1,  nameEN: "Bronze",      nameKO: "브론즈",       threshold: 10_000),
        Grade(tier: 2,  nameEN: "Silver",      nameKO: "실버",         threshold: 15_000),
        Grade(tier: 3,  nameEN: "Gold",        nameKO: "골드",         threshold: 20_000),
        Grade(tier: 4,  nameEN: "Platinum",    nameKO: "플래티넘",     threshold: 25_000),
        Grade(tier: 5,  nameEN: "Emerald",     nameKO: "에메랄드",     threshold: 30_000),
        Grade(tier: 6,  nameEN: "Sapphire",    nameKO: "사파이어",     threshold: 35_000),
        Grade(tier: 7,  nameEN: "Ruby",        nameKO: "루비",         threshold: 40_000),
        Grade(tier: 8,  nameEN: "Diamond",     nameKO: "다이아몬드",   threshold: 45_000),
        Grade(tier: 9,  nameEN: "Master",      nameKO: "마스터",       threshold: 50_000),
        Grade(tier: 10, nameEN: "Grandmaster", nameKO: "그랜드마스터", threshold: 55_000),
    ]

    /// All tiers including unranked Rookie, lowest first.
    static let allTiers: [Grade] = [rookie] + ranked

    /// The highest tier whose threshold `score` meets. Below 10,000 → Rookie.
    static func forScore(_ score: Int) -> Grade {
        ranked.last(where: { score >= $0.threshold }) ?? rookie
    }

    /// The next tier up, or nil once at the top (Grandmaster / Rookie has Bronze as next).
    var next: Grade? {
        Grade.ranked.first(where: { $0.tier == tier + 1 })
    }

    /// Points still needed to reach the next tier from `score`; nil at the top tier.
    func pointsToNext(from score: Int) -> Int? {
        guard let next else { return nil }
        return max(0, next.threshold - score)
    }
}

struct BoardGenerationProfile: Equatable {
    var minimumOpenCells: Int
    var maximumOpenCells: Int
    var minimumFilledCells: Int
    var maximumFilledCells: Int
    var maxAttempts: Int
    /// Upper bound on special blocks sprinkled onto a generated board (0 = none). The actual
    /// count is rolled in `0...maxSpecialBlocks` so some boards stay plain. `.standard` keeps
    /// this at 0, so the generic generator and its tests see no specials.
    var maxSpecialBlocks = 0
    /// Relative weights for which special kind to place. Ignored when `maxSpecialBlocks == 0`.
    var bombWeight = 0.0
    var armoredWeight = 0.0
    var wildWeight = 0.0

    static let standard = BoardGenerationProfile(
        minimumOpenCells: 4,
        maximumOpenCells: 11,
        minimumFilledCells: 30,
        maximumFilledCells: 38,
        maxAttempts: 120
    )

    static func difficulty(level: Int) -> BoardGenerationProfile {
        switch max(0, min(level, 4)) {
        case 0:
            // Plain opener: no specials yet so the very first board after the tutorial is clean.
            return .standard
        case 1:
            return BoardGenerationProfile(
                minimumOpenCells: 4,
                maximumOpenCells: 10,
                minimumFilledCells: 31,
                maximumFilledCells: 39,
                maxAttempts: 140,
                maxSpecialBlocks: 2,
                bombWeight: 1.0,
                armoredWeight: 0.9,
                wildWeight: 1.1
            )
        case 2:
            return BoardGenerationProfile(
                minimumOpenCells: 3,
                maximumOpenCells: 9,
                minimumFilledCells: 32,
                maximumFilledCells: 39,
                maxAttempts: 150,
                maxSpecialBlocks: 3,
                bombWeight: 1.2,
                armoredWeight: 1.0,
                wildWeight: 0.9
            )
        case 3:
            return BoardGenerationProfile(
                minimumOpenCells: 3,
                maximumOpenCells: 8,
                minimumFilledCells: 33,
                maximumFilledCells: 40,
                maxAttempts: 160,
                maxSpecialBlocks: 4,
                bombWeight: 1.3,
                armoredWeight: 1.2,
                wildWeight: 0.8
            )
        default:
            // Level 4: humane open-cell floor of 4 (was 2) so the hardest boards still
            // give the player real choices (D3).
            return BoardGenerationProfile(
                minimumOpenCells: 4,
                maximumOpenCells: 7,
                minimumFilledCells: 34,
                maximumFilledCells: 40,
                maxAttempts: 180,
                maxSpecialBlocks: 4,
                bombWeight: 1.4,
                armoredWeight: 1.3,
                wildWeight: 0.7
            )
        }
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x6A09_E667_F3BC_C909 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

enum GameMode: String, Codable, Equatable {
    case classic
    case daily
}

struct DailyChallenge: Equatable {
    let id: String
    let seed: UInt64

    static func today(
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> DailyChallenge {
        challenge(for: now, calendar: calendar)
    }

    static func challenge(
        for date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DailyChallenge {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2_026
        let month = components.month ?? 1
        let day = components.day ?? 1
        let id = String(format: "%04d%02d%02d", year, month, day)

        return DailyChallenge(id: id, seed: stableSeed(for: id))
    }

    /// Friendly, per-language label (EN "Jun 22", KO "6월 22일"), formatted at display time
    /// rather than baked in at creation so it follows the language setting (I5).
    func displayLabel(language: AppLanguage) -> String {
        guard let date = DailyChallenge.date(fromID: id) else { return id }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .korean ? "ko_KR" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    /// Parses a `YYYYMMDD` challenge id back to a date (anchored at noon to dodge DST edges),
    /// used to compute Daily-streak day gaps (K3).
    static func date(fromID id: String, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard id.count == 8,
              let year = Int(id.prefix(4)),
              let month = Int(id.dropFirst(4).prefix(2)),
              let day = Int(id.suffix(2))
        else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)
    }

    /// Whole-day difference between two challenge ids (`to` minus `from`), or nil if unparseable.
    static func dayDifference(from: String, to: String, calendar: Calendar = .autoupdatingCurrent) -> Int? {
        guard let fromDate = date(fromID: from, calendar: calendar),
              let toDate = date(fromID: to, calendar: calendar)
        else {
            return nil
        }
        return calendar.dateComponents([.day], from: fromDate, to: toDate).day
    }

    private static func stableSeed(for id: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325

        for byte in "PopPath.daily.\(id)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }

        return hash
    }
}

/// Wall-clock round timer. `remaining` is derived as `ceil(deadline - now)`, so leaving the
/// app running in the background still burns the clock (you can't freeze it by backgrounding),
/// while an explicit pause freezes it and shifts the deadline forward on resume. A miss pulls
/// the deadline in a little. Every read takes an injected `now`, so tests are deterministic.
struct RoundClock: Equatable {
    let totalDuration: TimeInterval
    private(set) var deadline: Date
    private(set) var pausedAt: Date?

    init(start: Date, duration: TimeInterval) {
        totalDuration = duration
        deadline = start.addingTimeInterval(duration)
        pausedAt = nil
    }

    var isPaused: Bool { pausedAt != nil }

    func remainingSeconds(at now: Date) -> Int {
        let reference = pausedAt ?? now
        return max(0, Int(deadline.timeIntervalSince(reference).rounded(.up)))
    }

    mutating func pause(at now: Date) {
        guard pausedAt == nil else { return }
        pausedAt = now
    }

    mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        deadline = deadline.addingTimeInterval(now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }

    mutating func reduceRemaining(by seconds: TimeInterval) {
        deadline = deadline.addingTimeInterval(-seconds)
    }

    mutating func extendRemaining(by seconds: TimeInterval) {
        deadline = deadline.addingTimeInterval(seconds)
    }
}

enum GameRules {
    static let rows = 7
    static let columns = 6
    static let roundSeconds = 60

    static func emptyBoard() -> [[PopBlock?]] {
        Array(
            repeating: Array(repeating: nil, count: columns),
            count: rows
        )
    }

    static func generatedBoard<R: RandomNumberGenerator>(
        using random: inout R,
        profile: BoardGenerationProfile = .standard
    ) -> [[PopBlock?]] {
        let base = baseGeneratedBoard(using: &random, profile: profile)
        // Specials are layered on last and only ever ADD escape options (wild) or extra effects
        // (bomb/armored), so they can't break the clearable guarantee `baseGeneratedBoard` makes.
        return applyingSpecials(to: base, using: &random, profile: profile)
    }

    private static func baseGeneratedBoard<R: RandomNumberGenerator>(
        using random: inout R,
        profile: BoardGenerationProfile = .standard
    ) -> [[PopBlock?]] {
        var bestBoard = emptyBoard()
        var bestScore = Int.min

        for _ in 0..<profile.maxAttempts {
            let candidate = clearableRandomBoard(using: &random, profile: profile)
            let openCount = openPositions(in: candidate).count
            let filledCount = blockCount(in: candidate)
            let clearable = isClearable(candidate)

            if isBalanced(openCount: openCount, filledCount: filledCount, profile: profile),
               clearable {
                return candidate
            }

            let score = qualityScore(
                openCount: openCount,
                filledCount: filledCount,
                clearable: clearable,
                profile: profile
            )
            if score > bestScore {
                bestScore = score
                bestBoard = candidate
            }
        }

        let repairedBoard = guaranteeingMinimumOpenCells(on: bestBoard, using: &random, profile: profile)
        if isClearable(repairedBoard) {
            return repairedBoard
        }

        if isClearable(bestBoard) {
            return bestBoard
        }

        // D8: never hand back a board that cannot be cleared. A ring of outward-pointing
        // edge blocks is escapable from every edge cell, so it is always clearable and
        // always leaves playable moves — a humane last-resort floor.
        return guaranteedClearableBoard()
    }

    static func generatedBoard() -> [[PopBlock?]] {
        var random = SystemRandomNumberGenerator()
        return generatedBoard(using: &random)
    }

    static func generatedBoard(profile: BoardGenerationProfile) -> [[PopBlock?]] {
        var random = SystemRandomNumberGenerator()
        return generatedBoard(using: &random, profile: profile)
    }

    /// Generates a seeded board off the main actor. Uses the same RNG and draw order as
    /// the synchronous path, so a given seed yields a byte-identical board (determinism is
    /// preserved for the Daily challenge).
    static func generatedBoardAsync(
        seed: UInt64,
        profile: BoardGenerationProfile = .standard
    ) async -> [[PopBlock?]] {
        await Task.detached(priority: .userInitiated) {
            var random = SeededRandomNumberGenerator(seed: seed)
            return generatedBoard(using: &random, profile: profile)
        }.value
    }

    /// Pure Classic-board picker: draws candidates until one is not in `recentSignatures`,
    /// falling back to the last candidate. Pulled out of `GameModel` so it can run off the
    /// main actor; signature bookkeeping stays on the model.
    static func classicBoard(
        profile: BoardGenerationProfile,
        recentSignatures: Set<String>,
        attempts: Int = 24
    ) -> [[PopBlock?]] {
        var fallback = generatedBoard(profile: profile)

        for attempt in 0..<max(attempts, 1) {
            let candidate = attempt == 0 ? fallback : generatedBoard(profile: profile)
            let signature = boardSignature(candidate)
            if !recentSignatures.contains(signature) {
                return candidate
            }
            fallback = candidate
        }

        return fallback
    }

    /// A board whose every block sits on the edge it points toward, so each one can escape
    /// immediately regardless of the others — guaranteed clearable, guaranteed playable.
    static func guaranteedClearableBoard() -> [[PopBlock?]] {
        var board = emptyBoard()
        for position in edgePositions() {
            board[position.row][position.column] = PopBlock(
                direction: outwardDirection(for: position),
                tone: tone(for: position)
            )
        }
        return board
    }

    static func blockCount(in board: [[PopBlock?]]) -> Int {
        board.reduce(0) { count, row in
            count + row.compactMap { $0 }.count
        }
    }

    static func boardSignature(_ board: [[PopBlock?]]) -> String {
        board.map { row in
            row.map { block in
                guard let block else { return ".." }
                // Normal blocks append no kind code, so plain boards keep their old signatures.
                return directionCode(for: block.direction) + toneCode(for: block.tone) + kindCode(for: block.kind)
            }
            .joined(separator: "")
        }
        .joined(separator: "|")
    }

    /// Upgrades up to `profile.maxSpecialBlocks` (rolled, so some boards stay plain) of the
    /// board's blocks into special kinds, chosen by the profile's weights. Runs on the same RNG
    /// and draw order as generation, so a seeded Daily board is byte-identical for everyone.
    private static func applyingSpecials<R: RandomNumberGenerator>(
        to board: [[PopBlock?]],
        using random: inout R,
        profile: BoardGenerationProfile
    ) -> [[PopBlock?]] {
        guard profile.maxSpecialBlocks > 0 else { return board }
        let totalWeight = profile.bombWeight + profile.armoredWeight + profile.wildWeight
        guard totalWeight > 0 else { return board }

        var positions = filledPositions(in: board)
        guard !positions.isEmpty else { return board }
        positions.shuffle(using: &random)

        let count = min(Int.random(in: 0...profile.maxSpecialBlocks, using: &random), positions.count)
        guard count > 0 else { return board }

        var board = board
        for position in positions.prefix(count) {
            guard var block = board[position.row][position.column] else { continue }
            var kind = pickSpecialKind(using: &random, profile: profile, totalWeight: totalWeight)
            // Wild adds escape directions, so making a *closed* cell wild would lift the board's
            // open-cell count above the difficulty profile's ceiling. Only turn an already-open
            // cell wild (openness-neutral); otherwise fall back to bomb, which keeps the cell's
            // original arrow and so leaves the open-cell count unchanged.
            if kind == .wild, !isEscapable(on: board, row: position.row, column: position.column) {
                kind = .bomb
            }
            switch kind {
            case .bomb:
                block.kind = .bomb
            case .armored:
                block.kind = .armored
                block.armor = 1
            case .wild:
                block.kind = .wild
            case .normal:
                continue
            }
            board[position.row][position.column] = block
        }
        return board
    }

    private static func pickSpecialKind<R: RandomNumberGenerator>(
        using random: inout R,
        profile: BoardGenerationProfile,
        totalWeight: Double
    ) -> BlockKind {
        var roll = Double.random(in: 0..<totalWeight, using: &random)
        if roll < profile.bombWeight { return .bomb }
        roll -= profile.bombWeight
        if roll < profile.armoredWeight { return .armored }
        return .wild
    }

    private static func filledPositions(in board: [[PopBlock?]]) -> [BoardPosition] {
        var result: [BoardPosition] = []
        for row in 0..<rows {
            for column in 0..<columns where board[row][column] != nil {
                result.append(BoardPosition(row: row, column: column))
            }
        }
        return result
    }

    private static func clearableRandomBoard<R: RandomNumberGenerator>(
        using random: inout R,
        profile: BoardGenerationProfile
    ) -> [[PopBlock?]] {
        var board = emptyBoard()
        let targetFilledCells = Int.random(
            in: profile.minimumFilledCells...profile.maximumFilledCells,
            using: &random
        )

        for _ in 0..<targetFilledCells {
            guard let nextBlock = nextClearableInsertion(on: board, using: &random) else {
                break
            }

            board[nextBlock.position.row][nextBlock.position.column] = PopBlock(
                direction: nextBlock.direction,
                tone: tone(for: nextBlock.position)
            )
        }

        return board
    }

    private static func nextClearableInsertion<R: RandomNumberGenerator>(
        on board: [[PopBlock?]],
        using random: inout R
    ) -> (position: BoardPosition, direction: Direction)? {
        var positions = allPositions().filter { board[$0.row][$0.column] == nil }
        positions.shuffle(using: &random)

        for position in positions {
            var directions = Direction.allCases
            directions.shuffle(using: &random)

            for direction in directions {
                var candidate = board
                candidate[position.row][position.column] = PopBlock(
                    direction: direction,
                    tone: tone(for: position)
                )

                if isEscapable(on: candidate, row: position.row, column: position.column) {
                    return (position, direction)
                }
            }
        }

        return nil
    }

    /// Whether the cell at (row,column) has a clear runway to the edge in `direction`. Pure
    /// geometry — it ignores the block's own arrow — so wild blocks (which pop in any open lane)
    /// and wild-flick validation can share it.
    static func hasClearRunway(on board: [[PopBlock?]], row: Int, column: Int, direction: Direction) -> Bool {
        guard isInside(row: row, column: column), board[row][column] != nil else { return false }

        let step = direction.delta
        var nextRow = row + step.row
        var nextColumn = column + step.column

        while isInside(row: nextRow, column: nextColumn) {
            if board[nextRow][nextColumn] != nil {
                return false
            }
            nextRow += step.row
            nextColumn += step.column
        }

        return true
    }

    static func isEscapable(on board: [[PopBlock?]], row: Int, column: Int) -> Bool {
        guard isInside(row: row, column: column),
              let block = board[row][column]
        else {
            return false
        }

        // A wild block is open if *any* direction has a clear lane; a normal/bomb/armored block
        // is open only along its own arrow.
        if block.kind == .wild {
            return Direction.allCases.contains {
                hasClearRunway(on: board, row: row, column: column, direction: $0)
            }
        }

        return hasClearRunway(on: board, row: row, column: column, direction: block.direction)
    }

    static func openPositions(in board: [[PopBlock?]]) -> Set<BoardPosition> {
        var positions = Set<BoardPosition>()

        for row in 0..<rows {
            for column in 0..<columns where isEscapable(on: board, row: row, column: column) {
                positions.insert(BoardPosition(row: row, column: column))
            }
        }

        return positions
    }

    static func hasPlayableMove(in board: [[PopBlock?]]) -> Bool {
        !openPositions(in: board).isEmpty
    }

    static func isClearable(_ board: [[PopBlock?]]) -> Bool {
        var remainingBoard = board

        while blockCount(in: remainingBoard) > 0 {
            let openPositions = openPositions(in: remainingBoard)
            guard !openPositions.isEmpty else {
                return false
            }

            for position in openPositions {
                remainingBoard[position.row][position.column] = nil
            }
        }

        return true
    }

    static func isInside(row: Int, column: Int) -> Bool {
        row >= 0 && row < rows && column >= 0 && column < columns
    }

    private static func isBalanced(
        openCount: Int,
        filledCount: Int,
        profile: BoardGenerationProfile
    ) -> Bool {
        openCount >= profile.minimumOpenCells &&
            openCount <= profile.maximumOpenCells &&
            filledCount >= profile.minimumFilledCells &&
            filledCount <= profile.maximumFilledCells
    }

    private static func qualityScore(
        openCount: Int,
        filledCount: Int,
        clearable: Bool,
        profile: BoardGenerationProfile
    ) -> Int {
        let openShortfall = max(0, profile.minimumOpenCells - openCount)
        let openOverage = max(0, openCount - profile.maximumOpenCells)
        let filledShortfall = max(0, profile.minimumFilledCells - filledCount)
        let filledOverage = max(0, filledCount - profile.maximumFilledCells)

        return 1_000
            + (clearable ? 1_200 : 0)
            - openShortfall * 80
            - openOverage * 18
            - filledShortfall * 28
            - filledOverage * 28
            + min(openCount, profile.maximumOpenCells) * 4
    }

    private static func guaranteeingMinimumOpenCells<R: RandomNumberGenerator>(
        on board: [[PopBlock?]],
        using random: inout R,
        profile: BoardGenerationProfile
    ) -> [[PopBlock?]] {
        var board = board
        var edges = edgePositions()
        edges.shuffle(using: &random)

        for position in edges {
            if openPositions(in: board).count >= profile.minimumOpenCells {
                break
            }

            board[position.row][position.column] = PopBlock(
                direction: outwardDirection(for: position),
                tone: (position.row + position.column).isMultiple(of: 2) ? .mistBlue : .lavenderMist
            )
        }

        return board
    }

    private static func edgePositions() -> [BoardPosition] {
        var positions: [BoardPosition] = []

        for column in 0..<columns {
            positions.append(BoardPosition(row: 0, column: column))
            positions.append(BoardPosition(row: rows - 1, column: column))
        }

        for row in 1..<(rows - 1) {
            positions.append(BoardPosition(row: row, column: 0))
            positions.append(BoardPosition(row: row, column: columns - 1))
        }

        return positions
    }

    private static func allPositions() -> [BoardPosition] {
        var positions: [BoardPosition] = []

        for row in 0..<rows {
            for column in 0..<columns {
                positions.append(BoardPosition(row: row, column: column))
            }
        }

        return positions
    }

    private static func outwardDirection(for position: BoardPosition) -> Direction {
        if position.row == 0 { return .up }
        if position.row == rows - 1 { return .down }
        if position.column == 0 { return .left }
        return .right
    }

    private static func tone(for position: BoardPosition) -> BlockTone {
        (position.row + position.column).isMultiple(of: 2) ? .mistBlue : .lavenderMist
    }

    private static func directionCode(for direction: Direction) -> String {
        switch direction {
        case .up: "U"
        case .down: "D"
        case .left: "L"
        case .right: "R"
        }
    }

    private static func toneCode(for tone: BlockTone) -> String {
        switch tone {
        case .mistBlue: "B"
        case .lavenderMist: "P"
        }
    }

    private static func kindCode(for kind: BlockKind) -> String {
        switch kind {
        case .normal: ""
        case .bomb: "b"
        case .armored: "a"
        case .wild: "w"
        }
    }
}

/// Opt-in local Daily reminder (K3). Pure on-device `UserNotifications` — no server, account,
/// or tracking. Enabling requests authorization and, if granted, schedules a single repeating
/// 7pm notification; disabling cancels it. All calls are safe no-ops if authorization is denied.
enum DailyReminder {
    static let identifier = "poppath.dailyReminder"
    static let storageKey = "dailyReminderEnabled"

    static func enable(language: AppLanguage) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            // Authorization is async; the user may have toggled the reminder back off while
            // the prompt was up. Re-check the live setting on the main queue before scheduling.
            DispatchQueue.main.async {
                guard UserDefaults.standard.bool(forKey: storageKey) else { return }
                schedule(language: language)
            }
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func schedule(language: AppLanguage) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "PopPath"
        content.body = language.text(
            "Today's Daily Challenge is ready — keep your streak going!",
            "오늘의 도전이 준비됐어요 — 연속 기록을 이어가요!"
        )
        content.sound = .default

        var when = DateComponents()
        when.hour = 19
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}

@MainActor
enum Haptics {
    enum Event: CaseIterable, Equatable {
        case escape
        case chain
        case bigChain
        case unlock
        case freshPath
        case boardClear
        case miss
        case finish
        /// Low-time urgency tick (WI-5.4) — a distinct soft tap so it reads as a clock cue,
        /// not the `.escape` pop confirmation.
        case tick
    }

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare(enabled: Bool) {
        guard enabled else { return }

        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }

    static func play(_ event: Event, enabled: Bool) {
        guard enabled else { return }

        switch event {
        case .escape:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .chain:
            mediumImpact.impactOccurred(intensity: 0.7)
            mediumImpact.prepare()
        case .bigChain:
            heavyImpact.impactOccurred(intensity: 0.88)
            heavyImpact.prepare()
        case .unlock:
            rigidImpact.impactOccurred(intensity: 0.72)
            rigidImpact.prepare()
        case .freshPath:
            softImpact.impactOccurred(intensity: 0.65)
            softImpact.prepare()
        case .boardClear:
            // Distinct from the round-finish cue (J4): a punchy heavy impact for a board clear
            // vs the success notification for finishing a round.
            heavyImpact.impactOccurred(intensity: 0.9)
            heavyImpact.prepare()
        case .miss:
            notification.notificationOccurred(.warning)
            notification.prepare()
        case .finish:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .tick:
            softImpact.impactOccurred(intensity: 0.4)
            softImpact.prepare()
        }
    }
}

@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    private var toneDataCache: [Tone: Data] = [:]
    private var playerPool: [Tone: [AVAudioPlayer]] = [:]
    private var playerCursor: [Tone: Int] = [:]
    private var didConfigureAudioSession = false
    private var didRegisterSessionObservers = false

    private init() {}

    func prepare(enabled: Bool) {
        guard enabled else { return }

        configureAudioSessionIfNeeded()
        for event in warmupEvents {
            for tone in tones(for: event) {
                preparePlayers(for: tone)
            }
        }
    }

    func play(_ event: Haptics.Event, enabled: Bool) {
        guard enabled else { return }

        for tone in tones(for: event) {
            DispatchQueue.main.asyncAfter(deadline: .now() + tone.delay) { [weak self] in
                self?.playTone(tone)
            }
        }
    }

    private func tones(for event: Haptics.Event) -> [Tone] {
        switch event {
        case .escape:
            return [Tone(frequency: 440, duration: 0.055, amplitude: 0.11, delay: 0)]
        case .chain:
            return [
                Tone(frequency: 520, duration: 0.05, amplitude: 0.1, delay: 0),
                Tone(frequency: 700, duration: 0.06, amplitude: 0.08, delay: 0.045)
            ]
        case .bigChain:
            return [
                Tone(frequency: 580, duration: 0.045, amplitude: 0.11, delay: 0),
                Tone(frequency: 760, duration: 0.055, amplitude: 0.09, delay: 0.04),
                Tone(frequency: 920, duration: 0.075, amplitude: 0.075, delay: 0.09)
            ]
        case .unlock:
            return [
                Tone(frequency: 620, duration: 0.045, amplitude: 0.085, delay: 0),
                Tone(frequency: 820, duration: 0.055, amplitude: 0.065, delay: 0.04)
            ]
        case .freshPath:
            return [
                Tone(frequency: 392, duration: 0.055, amplitude: 0.08, delay: 0),
                Tone(frequency: 523, duration: 0.07, amplitude: 0.075, delay: 0.055)
            ]
        case .boardClear:
            return [
                Tone(frequency: 523, duration: 0.06, amplitude: 0.09, delay: 0),
                Tone(frequency: 659, duration: 0.06, amplitude: 0.08, delay: 0.055),
                Tone(frequency: 880, duration: 0.11, amplitude: 0.075, delay: 0.115)
            ]
        case .miss:
            return [Tone(frequency: 150, duration: 0.08, amplitude: 0.07, delay: 0)]
        case .finish:
            return [
                Tone(frequency: 523, duration: 0.08, amplitude: 0.08, delay: 0),
                Tone(frequency: 659, duration: 0.08, amplitude: 0.07, delay: 0.075),
                Tone(frequency: 784, duration: 0.11, amplitude: 0.06, delay: 0.15)
            ]
        case .tick:
            // The low-time tick is a haptic-only cue; no sound so it never machine-guns audio.
            return []
        }
    }

    private func playTone(_ tone: Tone) {
        do {
            let player = try preparedPlayer(for: tone)
            if player.isPlaying {
                player.stop()
            }
            player.currentTime = 0
            player.play()
        } catch {
            assertionFailure("Unable to play generated tone: \(error)")
        }
    }

    private func configureAudioSessionIfNeeded() {
        guard !didConfigureAudioSession else { return }

        let session = AVAudioSession.sharedInstance()
        // .playback (not .ambient) so enabled SFX still play with the silent switch on — a
        // deliberate product decision; .mixWithOthers keeps the player's own music going (J1).
        // Audio only ever plays when the in-app Sound toggle is on, so this never makes noise
        // the user didn't ask for.
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        registerSessionObserversIfNeeded()
        didConfigureAudioSession = true
    }

    // Reactivate the session after an interruption (call, Siri, other app) ends or the audio
    // route changes, so SFX resume instead of going silent (J6).
    private func registerSessionObserversIfNeeded() {
        guard !didRegisterSessionObservers else { return }
        didRegisterSessionObservers = true

        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended
            else {
                return
            }
            Task { @MainActor in SoundEffects.shared.reactivateSession() }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in SoundEffects.shared.reactivateSession() }
        }
    }

    func reactivateSession() {
        guard didConfigureAudioSession else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func preparePlayers(for tone: Tone) {
        guard playerPool[tone] == nil else { return }

        let data = data(for: tone)
        let players = (0..<3).compactMap { _ -> AVAudioPlayer? in
            do {
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                return player
            } catch {
                return nil
            }
        }

        playerPool[tone] = players
    }

    private func preparedPlayer(for tone: Tone) throws -> AVAudioPlayer {
        configureAudioSessionIfNeeded()
        preparePlayers(for: tone)

        guard let players = playerPool[tone], !players.isEmpty else {
            return try AVAudioPlayer(data: data(for: tone))
        }

        let cursor = playerCursor[tone, default: 0]
        playerCursor[tone] = (cursor + 1) % players.count
        return players[cursor]
    }

    private func data(for tone: Tone) -> Data {
        if let data = toneDataCache[tone] {
            return data
        }

        let data = Self.makeToneData(
            frequency: tone.frequency,
            duration: tone.duration,
            amplitude: tone.amplitude
        )
        toneDataCache[tone] = data
        return data
    }

    private struct Tone: Hashable {
        let frequency: Double
        let duration: Double
        let amplitude: Double
        let delay: Double
    }

    private var warmupEvents: [Haptics.Event] {
        [.escape, .chain, .unlock, .miss]
    }

    private static func makeToneData(frequency: Double, duration: Double, amplitude: Double) -> Data {
        let sampleRate = 44_100
        let channelCount = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let sampleCount = Int(Double(sampleRate) * duration)
        let dataSize = sampleCount * channelCount * bytesPerSample

        var data = Data()
        appendASCII("RIFF", to: &data)
        append(UInt32(36 + dataSize), to: &data)
        appendASCII("WAVE", to: &data)
        appendASCII("fmt ", to: &data)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(channelCount), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * channelCount * bytesPerSample), to: &data)
        append(UInt16(channelCount * bytesPerSample), to: &data)
        append(UInt16(bitsPerSample), to: &data)
        appendASCII("data", to: &data)
        append(UInt32(dataSize), to: &data)

        let attackSamples = max(1, Int(Double(sampleRate) * 0.006))
        let releaseSamples = max(1, Int(Double(sampleRate) * 0.035))

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let attack = min(1, Double(index) / Double(attackSamples))
            let release = min(1, Double(sampleCount - index) / Double(releaseSamples))
            let envelope = min(attack, release)
            let sample = sin(2 * .pi * frequency * time) * amplitude * envelope
            append(Int16(sample * Double(Int16.max)), to: &data)
        }

        return data
    }

    private static func appendASCII(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
