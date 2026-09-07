import Foundation
import SwiftData

@Model
final class Enrollment {
    /// A content program id. Never an index.
    var programID: String
    var startedAt: Date
    var finishedAt: Date?
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \SessionCompletion.enrollment)
    var completions: [SessionCompletion] = []

    init(programID: String, startedAt: Date, isActive: Bool = true) {
        self.programID = programID
        self.startedAt = startedAt
        self.isActive = isActive
    }

    /// Flattened for `ProgramEngine`, which never sees SwiftData types.
    var completionRecords: [CompletionRecord] {
        completions.map { CompletionRecord(sessionID: $0.sessionID, isFinished: $0.finishedAt != nil) }
    }
}
