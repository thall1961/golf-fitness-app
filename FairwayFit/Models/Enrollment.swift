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

extension Enrollment {
    /// Finishes this cycle and opens a new one for the same program. History
    /// stays split per cycle, so a second run of a maintenance block does not
    /// look like a continuation of the first.
    @discardableResult
    func completeAndRepeat(in context: ModelContext) -> Enrollment {
        isActive = false
        finishedAt = finishedAt ?? .now
        let fresh = Enrollment(programID: programID, startedAt: .now)
        context.insert(fresh)
        try? context.save()
        return fresh
    }
}
