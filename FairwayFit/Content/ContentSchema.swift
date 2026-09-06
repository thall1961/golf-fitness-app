import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case mobility, power, strength, core, balance
}

enum Equipment: String, Codable, CaseIterable, Sendable {
    case none, band, club
}

enum BlockKind: String, Codable, CaseIterable, Sendable {
    case warmup, main, finisher

    /// The order blocks must appear in within a session.
    var order: Int {
        switch self {
        case .warmup: 0
        case .main: 1
        case .finisher: 2
        }
    }
}

/// How much of an exercise to do. Encoded flat because the JSON is hand-written.
struct Target: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case reps, repsPerSide, seconds, secondsPerSide
    }
    let kind: Kind
    let value: Int

    var isTimed: Bool { kind == .seconds || kind == .secondsPerSide }
}

struct Prescription: Codable, Hashable, Sendable {
    let exerciseID: String
    let sets: Int
    let target: Target
    let restSeconds: Int
    let note: String?
}

struct Block: Codable, Hashable, Sendable {
    let kind: BlockKind
    let prescriptions: [Prescription]
}

struct Session: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let estimatedMinutes: Int
    let blocks: [Block]

    var prescriptions: [Prescription] { blocks.flatMap(\.prescriptions) }
}

struct Program: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let weeks: Int
    let sessionsPerWeek: Int
    let whoThisIsFor: String
    let isRepeatable: Bool
    let sessions: [Session]
}

struct Content: Codable, Hashable, Sendable {
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let version: Int
    let exercises: [Exercise]
    let programs: [Program]

    func exercise(id: String) -> Exercise? { exercises.first { $0.id == id } }
    func program(id: String) -> Program? { programs.first { $0.id == id } }
}

struct Exercise: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let equipment: Equipment
    let setup: String
    let cues: [String]
    let swingRationale: String
    let demoURL: URL
    let isBenchmark: Bool
}
