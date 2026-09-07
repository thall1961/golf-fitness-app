import Foundation
import SwiftData

enum BandLevel: String, Codable, CaseIterable, Sendable {
    case light, medium, heavy

    var label: String { rawValue.capitalized }
}

@Model
final class SetLog {
    /// A content exercise id.
    var exerciseID: String
    var setNumber: Int
    /// Exactly one of these is set, matching the prescription's target kind.
    var actualReps: Int?
    var actualSeconds: Int?
    var bandLevelRaw: String?
    var completion: SessionCompletion?

    init(exerciseID: String,
         setNumber: Int,
         actualReps: Int? = nil,
         actualSeconds: Int? = nil,
         bandLevel: BandLevel? = nil) {
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.actualReps = actualReps
        self.actualSeconds = actualSeconds
        self.bandLevelRaw = bandLevel?.rawValue
    }

    var bandLevel: BandLevel? {
        get { bandLevelRaw.flatMap(BandLevel.init(rawValue:)) }
        set { bandLevelRaw = newValue?.rawValue }
    }

    /// The single number this set contributes to a benchmark chart.
    var achievedValue: Int? { actualReps ?? actualSeconds }
}
