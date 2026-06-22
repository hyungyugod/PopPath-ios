import Foundation
import AVFoundation
import UIKit

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
}

enum BlockTone: CaseIterable, Codable {
    case mistBlue
    case lavenderMist
}

struct PopBlock: Identifiable, Equatable, Codable {
    var id = UUID()
    var direction: Direction
    var tone: BlockTone
    var isMiss = false
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
        duration: TimeInterval = 0.18
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

struct BoardGenerationProfile: Equatable {
    var minimumOpenCells: Int
    var maximumOpenCells: Int
    var minimumFilledCells: Int
    var maximumFilledCells: Int
    var maxAttempts: Int

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
            return .standard
        case 1:
            return BoardGenerationProfile(
                minimumOpenCells: 4,
                maximumOpenCells: 10,
                minimumFilledCells: 31,
                maximumFilledCells: 39,
                maxAttempts: 140
            )
        case 2:
            return BoardGenerationProfile(
                minimumOpenCells: 3,
                maximumOpenCells: 9,
                minimumFilledCells: 32,
                maximumFilledCells: 39,
                maxAttempts: 150
            )
        case 3:
            return BoardGenerationProfile(
                minimumOpenCells: 3,
                maximumOpenCells: 8,
                minimumFilledCells: 33,
                maximumFilledCells: 40,
                maxAttempts: 160
            )
        default:
            // Level 4: humane open-cell floor of 4 (was 2) so the hardest boards still
            // give the player real choices (D3).
            return BoardGenerationProfile(
                minimumOpenCells: 4,
                maximumOpenCells: 7,
                minimumFilledCells: 34,
                maximumFilledCells: 40,
                maxAttempts: 180
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
    let displayLabel: String

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

        return DailyChallenge(
            id: id,
            seed: stableSeed(for: id),
            displayLabel: "\(month)/\(day)"
        )
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
                return directionCode(for: block.direction) + toneCode(for: block.tone)
            }
            .joined(separator: "")
        }
        .joined(separator: "|")
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

    static func isEscapable(on board: [[PopBlock?]], row: Int, column: Int) -> Bool {
        guard isInside(row: row, column: column),
              let block = board[row][column]
        else {
            return false
        }

        let step = block.direction.delta
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
            notification.notificationOccurred(.success)
            notification.prepare()
        case .miss:
            notification.notificationOccurred(.warning)
            notification.prepare()
        case .finish:
            notification.notificationOccurred(.success)
            notification.prepare()
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
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        didConfigureAudioSession = true
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
