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
}

enum BlockTone: CaseIterable, Codable {
    case mistBlue
    case lavenderMist
}

struct PopBlock: Identifiable, Equatable, Codable {
    var id = UUID()
    var direction: Direction
    var tone: BlockTone
    var isLeaving = false
    var isMiss = false
}

struct BoardPosition: Hashable {
    let row: Int
    let column: Int
}

struct BoardGenerationProfile: Equatable {
    var emptyChance: Double
    var minimumOpenCells: Int
    var maximumOpenCells: Int
    var minimumFilledCells: Int
    var maximumFilledCells: Int
    var maxAttempts: Int

    static let standard = BoardGenerationProfile(
        emptyChance: 0.24,
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
                emptyChance: 0.22,
                minimumOpenCells: 4,
                maximumOpenCells: 10,
                minimumFilledCells: 31,
                maximumFilledCells: 39,
                maxAttempts: 140
            )
        case 2:
            return BoardGenerationProfile(
                emptyChance: 0.2,
                minimumOpenCells: 3,
                maximumOpenCells: 9,
                minimumFilledCells: 32,
                maximumFilledCells: 39,
                maxAttempts: 150
            )
        case 3:
            return BoardGenerationProfile(
                emptyChance: 0.18,
                minimumOpenCells: 3,
                maximumOpenCells: 8,
                minimumFilledCells: 33,
                maximumFilledCells: 40,
                maxAttempts: 160
            )
        default:
            return BoardGenerationProfile(
                emptyChance: 0.16,
                minimumOpenCells: 2,
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

enum GameRules {
    static let rows = 7
    static let columns = 6
    static let roundSeconds = 60
    static let emptyChance = BoardGenerationProfile.standard.emptyChance

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

        return repairedBoard
    }

    static func generatedBoard() -> [[PopBlock?]] {
        var random = SystemRandomNumberGenerator()
        return generatedBoard(using: &random)
    }

    static func generatedBoard(profile: BoardGenerationProfile) -> [[PopBlock?]] {
        var random = SystemRandomNumberGenerator()
        return generatedBoard(using: &random, profile: profile)
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

    private static func randomBoard<R: RandomNumberGenerator>(
        using random: inout R,
        emptyChance: Double
    ) -> [[PopBlock?]] {
        (0..<rows).map { row in
            (0..<columns).map { column in
                guard Double.random(in: 0..<1, using: &random) >= emptyChance else {
                    return nil
                }

                return PopBlock(
                    direction: Direction.allCases.randomElement(using: &random) ?? .right,
                    tone: (row + column).isMultiple(of: 2) ? .mistBlue : .lavenderMist
                )
            }
        }
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
              let block = board[row][column],
              !block.isLeaving
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

enum Haptics {
    enum Event {
        case escape
        case chain
        case bigChain
        case unlock
        case freshPath
        case boardClear
        case miss
        case finish
    }

    static func play(_ event: Event, enabled: Bool) {
        guard enabled else { return }

        switch event {
        case .escape:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .chain:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        case .bigChain:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.88)
        case .unlock:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        case .freshPath:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
        case .boardClear:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .miss:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .finish:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    private var players: [AVAudioPlayer] = []

    private init() {}

    func play(_ event: Haptics.Event, enabled: Bool) {
        guard enabled else { return }

        let tones: [(frequency: Double, duration: Double, amplitude: Double, delay: Double)]
        switch event {
        case .escape:
            tones = [(440, 0.055, 0.11, 0)]
        case .chain:
            tones = [(520, 0.05, 0.1, 0), (700, 0.06, 0.08, 0.045)]
        case .bigChain:
            tones = [(580, 0.045, 0.11, 0), (760, 0.055, 0.09, 0.04), (920, 0.075, 0.075, 0.09)]
        case .unlock:
            tones = [(620, 0.045, 0.085, 0), (820, 0.055, 0.065, 0.04)]
        case .freshPath:
            tones = [(392, 0.055, 0.08, 0), (523, 0.07, 0.075, 0.055)]
        case .boardClear:
            tones = [(523, 0.06, 0.09, 0), (659, 0.06, 0.08, 0.055), (880, 0.11, 0.075, 0.115)]
        case .miss:
            tones = [(150, 0.08, 0.07, 0)]
        case .finish:
            tones = [(523, 0.08, 0.08, 0), (659, 0.08, 0.07, 0.075), (784, 0.11, 0.06, 0.15)]
        }

        for tone in tones {
            DispatchQueue.main.asyncAfter(deadline: .now() + tone.delay) { [weak self] in
                self?.playTone(
                    frequency: tone.frequency,
                    duration: tone.duration,
                    amplitude: tone.amplitude
                )
            }
        }
    }

    private func playTone(frequency: Double, duration: Double, amplitude: Double) {
        players = players.filter(\.isPlaying)

        do {
            let data = Self.makeToneData(
                frequency: frequency,
                duration: duration,
                amplitude: amplitude
            )
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()
            players.append(player)
        } catch {
            assertionFailure("Unable to play generated tone: \(error)")
        }
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
