import Foundation
import SwiftData

@Model
final class SessionCompletion {
    /// A content session id. Never an index — content is reorderable between releases.
    var sessionID: String
    var startedAt: Date
    /// nil means the session was bailed out of and can be resumed.
    var finishedAt: Date?
    var rpe: Int?
    var enrollment: Enrollment?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.completion)
    var setLogs: [SetLog] = []

    init(sessionID: String, startedAt: Date) {
        self.sessionID = sessionID
        self.startedAt = startedAt
    }

    var isFinished: Bool { finishedAt != nil }
}
