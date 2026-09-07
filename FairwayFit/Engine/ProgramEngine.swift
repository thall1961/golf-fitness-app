import Foundation

/// A SwiftData `SessionCompletion` flattened to the two facts the engine needs.
/// Keeping this a plain value is what lets the suites run without a store.
struct CompletionRecord: Hashable, Sendable {
    let sessionID: String
    let isFinished: Bool
}

enum ProgramEngine {

    /// The first session in program order with no finished completion.
    /// A bailed session is offered again so it can be resumed.
    static func nextSession(program: Program,
                            completions: [CompletionRecord]) -> (index: Int, session: Session)? {
        let finished = finishedIDs(completions)
        for (index, session) in program.sessions.enumerated() where !finished.contains(session.id) {
            return (index, session)
        }
        return nil
    }

    static func progress(program: Program,
                         completions: [CompletionRecord]) -> (completed: Int, total: Int) {
        let finished = finishedIDs(completions)
        let done = program.sessions.count { finished.contains($0.id) }
        return (done, program.sessions.count)
    }

    static func isComplete(program: Program, completions: [CompletionRecord]) -> Bool {
        nextSession(program: program, completions: completions) == nil
    }

    /// Records for sessions this program no longer contains are simply absent
    /// from the lookup, which is how removed content stops affecting progress
    /// without anyone deleting the user's history.
    private static func finishedIDs(_ completions: [CompletionRecord]) -> Set<String> {
        Set(completions.lazy.filter(\.isFinished).map(\.sessionID))
    }
}
