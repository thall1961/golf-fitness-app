import Foundation

struct ContentValidationError: Error, Hashable, Sendable, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// The single rule set standing between a content edit and a user's phone.
/// Run in CI against the repo's content.json, and at runtime against anything fetched.
enum ContentValidator {

    static func validate(_ content: Content) -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        func fail(_ message: String) { errors.append(ContentValidationError(message: message)) }

        if content.schemaVersion != Content.supportedSchemaVersion {
            fail("unsupported schemaVersion \(content.schemaVersion), expected \(Content.supportedSchemaVersion)")
        }
        if content.version <= 0 {
            fail("version must be a positive integer, got \(content.version)")
        }

        var seenExerciseIDs: Set<String> = []
        for exercise in content.exercises {
            let id = exercise.id
            if id.trimmed.isEmpty { fail("exercise has an empty id") }
            if id.trimmed != id { fail("exercise '\(id)' id has leading or trailing whitespace") }
            if !seenExerciseIDs.insert(id).inserted { fail("duplicate exercise id '\(id)'") }
            if exercise.name.trimmed.isEmpty { fail("exercise '\(id)' has an empty name") }
            if exercise.setup.trimmed.isEmpty { fail("exercise '\(id)' has an empty setup") }
            if exercise.swingRationale.trimmed.isEmpty { fail("exercise '\(id)' has an empty swingRationale") }
            let realCues = exercise.cues.filter { !$0.trimmed.isEmpty }
            if realCues.count < 2 { fail("exercise '\(id)' needs at least two cues") }
            if exercise.demoURL.scheme?.lowercased() != "https" {
                fail("exercise '\(id)' demoURL must be https")
            }
        }
        if !content.exercises.contains(where: \.isBenchmark) {
            fail("at least one exercise must be flagged isBenchmark")
        }

        var seenProgramIDs: Set<String> = []
        var seenSessionIDs: Set<String> = []
        for program in content.programs {
            let pid = program.id
            if pid.trimmed.isEmpty { fail("program has an empty id") }
            if pid.trimmed != pid { fail("program '\(pid)' id has leading or trailing whitespace") }
            if !seenProgramIDs.insert(pid).inserted { fail("duplicate program id '\(pid)'") }
            if program.title.trimmed.isEmpty { fail("program '\(pid)' has an empty title") }
            if program.subtitle.trimmed.isEmpty { fail("program '\(pid)' has an empty subtitle") }
            if program.whoThisIsFor.trimmed.isEmpty { fail("program '\(pid)' has an empty whoThisIsFor") }
            if program.weeks <= 0 { fail("program '\(pid)' weeks must be positive") }
            if program.sessionsPerWeek <= 0 { fail("program '\(pid)' sessionsPerWeek must be positive") }
            if program.sessions.isEmpty { fail("program '\(pid)' has no sessions") }

            for session in program.sessions {
                let sid = session.id
                if sid.trimmed.isEmpty { fail("program '\(pid)' has a session with an empty id") }
                if sid.trimmed != sid { fail("session '\(sid)' id has leading or trailing whitespace") }
                if !seenSessionIDs.insert(sid).inserted { fail("duplicate session id '\(sid)'") }
                if session.name.trimmed.isEmpty { fail("session '\(sid)' has an empty name") }
                if session.estimatedMinutes <= 0 { fail("session '\(sid)' estimatedMinutes must be positive") }
                if session.blocks.isEmpty { fail("session '\(sid)' has no blocks") }

                let order = session.blocks.map(\.kind.order)
                if order != order.sorted() { fail("session '\(sid)' has blocks out of block order") }

                var seenBlockKinds: Set<BlockKind> = []
                for kind in session.blocks.map(\.kind) where !seenBlockKinds.insert(kind).inserted {
                    fail("session '\(sid)' has a duplicate \(kind.rawValue) block")
                }

                var seenPrescribedExerciseIDs: Set<String> = []
                for block in session.blocks {
                    if block.prescriptions.isEmpty {
                        fail("session '\(sid)' has an empty \(block.kind.rawValue) block")
                    }
                    for prescription in block.prescriptions {
                        if !seenPrescribedExerciseIDs.insert(prescription.exerciseID).inserted {
                            fail("session '\(sid)' prescribes '\(prescription.exerciseID)' more than once")
                        }
                        if !seenExerciseIDs.contains(prescription.exerciseID) {
                            fail("session '\(sid)' references unknown exercise '\(prescription.exerciseID)'")
                        }
                        if prescription.sets <= 0 {
                            fail("session '\(sid)' prescribes sets <= 0 for '\(prescription.exerciseID)'")
                        }
                        if prescription.target.value <= 0 {
                            fail("session '\(sid)' prescribes a target value <= 0 for '\(prescription.exerciseID)'")
                        }
                        if prescription.restSeconds < 0 {
                            fail("session '\(sid)' prescribes negative restSeconds for '\(prescription.exerciseID)'")
                        }
                    }
                }
            }
        }
        return errors
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
