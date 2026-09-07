import Foundation
import Testing
@testable import FairwayFit

@Suite struct ContentValidatorTests {

    private func messages(_ content: Content) -> [String] {
        ContentValidator.validate(content).map(\.message)
    }

    @Test func acceptsAValidDocument() {
        let content = makeContent(exercises: [makeExercise(isBenchmark: true)])
        #expect(ContentValidator.validate(content).isEmpty)
    }

    @Test func rejectsUnsupportedSchemaVersion() {
        let content = makeContent(schemaVersion: 2, exercises: [makeExercise(isBenchmark: true)])
        #expect(messages(content).contains { $0.contains("schemaVersion") })
    }

    @Test func rejectsNonPositiveVersion() {
        let content = makeContent(version: 0, exercises: [makeExercise(isBenchmark: true)])
        #expect(messages(content).contains { $0.contains("version") })
    }

    @Test func rejectsDuplicateExerciseIDs() {
        let content = makeContent(
            exercises: [makeExercise(id: "dup", isBenchmark: true), makeExercise(id: "dup")],
            programs: [makeProgram(sessions: [makeSession(
                blocks: [Block(kind: .main, prescriptions: [makePrescription(exerciseID: "dup")])])])]
        )
        #expect(messages(content).contains { $0.contains("duplicate exercise id") })
    }

    @Test func rejectsUnresolvedPrescriptionReference() {
        let content = makeContent(
            exercises: [makeExercise(id: "push-up", isBenchmark: true)],
            programs: [makeProgram(sessions: [makeSession(
                blocks: [Block(kind: .main, prescriptions: [makePrescription(exerciseID: "ghost")])])])]
        )
        #expect(messages(content).contains { $0.contains("ghost") })
    }

    @Test func rejectsExerciseWithTooFewCues() {
        let content = makeContent(exercises: [makeExercise(cues: ["Only one"], isBenchmark: true)])
        #expect(messages(content).contains { $0.contains("cues") })
    }

    @Test func rejectsNonHTTPSDemoURL() {
        let content = makeContent(exercises: [
            makeExercise(demoURL: URL(string: "http://example.com/v")!, isBenchmark: true)
        ])
        #expect(messages(content).contains { $0.contains("https") })
    }

    @Test func rejectsEmptyExerciseProse() {
        let content = makeContent(exercises: [
            makeExercise(setup: "   ", swingRationale: "", isBenchmark: true)
        ])
        #expect(messages(content).contains { $0.contains("setup") })
        #expect(messages(content).contains { $0.contains("swingRationale") })
    }

    @Test func rejectsDuplicateSessionIDsAcrossPrograms() {
        let shared = makeSession(id: "same")
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(id: "a", sessions: [shared]),
                       makeProgram(id: "b", sessions: [shared])]
        )
        #expect(messages(content).contains { $0.contains("duplicate session id") })
    }

    @Test func rejectsEmptySessionAndEmptyBlock() {
        let emptySession = makeSession(id: "empty-session", blocks: [])
        let emptyBlock = makeSession(id: "empty-block", blocks: [Block(kind: .main, prescriptions: [])])
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(sessions: [emptySession, emptyBlock])]
        )
        #expect(messages(content).contains { $0.contains("empty-session") })
        #expect(messages(content).contains { $0.contains("empty-block") })
    }

    @Test func rejectsBlocksOutOfOrder() {
        let session = makeSession(id: "wrong-order", blocks: [
            Block(kind: .main, prescriptions: [makePrescription()]),
            Block(kind: .warmup, prescriptions: [makePrescription()])
        ])
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(sessions: [session])]
        )
        #expect(messages(content).contains { $0.contains("block order") })
    }

    @Test func rejectsProgramWithNoSessions() {
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(id: "hollow", sessions: [])]
        )
        #expect(messages(content).contains { $0.contains("hollow") })
    }

    @Test func rejectsNonPositivePacingAndSetsAndTargets() {
        let session = makeSession(blocks: [Block(kind: .main, prescriptions: [
            makePrescription(sets: 0, target: Target(kind: .reps, value: 0))
        ])])
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(weeks: 0, sessionsPerWeek: 0, sessions: [session])]
        )
        let found = messages(content)
        #expect(found.contains { $0.contains("weeks") })
        #expect(found.contains { $0.contains("sessionsPerWeek") })
        #expect(found.contains { $0.contains("sets") })
        #expect(found.contains { $0.contains("target") })
    }

    @Test func rejectsDocumentWithNoBenchmarkExercise() {
        let content = makeContent(exercises: [makeExercise(isBenchmark: false)])
        #expect(messages(content).contains { $0.contains("isBenchmark") })
    }

    @Test func rejectsNegativeRestSeconds() {
        let session = makeSession(blocks: [Block(kind: .main, prescriptions: [
            makePrescription(restSeconds: -1)
        ])])
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(sessions: [session])]
        )
        #expect(messages(content).contains { $0.contains("restSeconds") })
    }

    @Test func rejectsExerciseIDWithWhitespace() {
        let content = makeContent(exercises: [makeExercise(id: "push-up ", isBenchmark: true)])
        #expect(messages(content).contains { $0.contains("whitespace") })
    }

    @Test func rejectsProgramIDWithWhitespace() {
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(id: "program ")]
        )
        #expect(messages(content).contains { $0.contains("whitespace") })
    }

    @Test func rejectsSessionIDWithWhitespace() {
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(sessions: [makeSession(id: "s1 ")])]
        )
        #expect(messages(content).contains { $0.contains("whitespace") })
    }

    @Test func rejectsEmptyProgramSubtitle() {
        let content = makeContent(
            exercises: [makeExercise(isBenchmark: true)],
            programs: [makeProgram(subtitle: "   ")]
        )
        #expect(messages(content).contains { $0.contains("subtitle") })
    }

    @Test func decoderRejectsMalformedJSON() {
        #expect(throws: ContentError.malformed) {
            try ContentDecoder.decode(Data("{ not json".utf8))
        }
    }

    @Test func decoderRejectsOversizedData() {
        let big = Data(repeating: 0x20, count: ContentDecoder.maximumBytes + 1)
        #expect(throws: ContentError.tooLarge) {
            try ContentDecoder.decode(big)
        }
    }

    @Test func decoderRejectsUnsupportedSchemaBeforeValidating() throws {
        let json = """
        { "schemaVersion": 99, "version": 1, "exercises": [], "programs": [] }
        """
        #expect(throws: ContentError.unsupportedSchema(99)) {
            try ContentDecoder.decode(Data(json.utf8))
        }
    }

    @Test func decoderAcceptsAValidDocument() throws {
        let content = makeContent(exercises: [makeExercise(isBenchmark: true)])
        let data = try JSONEncoder().encode(content)
        let decoded = try ContentDecoder.decode(data)
        #expect(decoded.version == content.version)
    }

    @Test func decoderRejectsInvalidDocument() throws {
        let content = makeContent(exercises: [makeExercise(isBenchmark: false)])
        let data = try JSONEncoder().encode(content)
        do {
            _ = try ContentDecoder.decode(data)
            Issue.record("expected ContentError.invalid to be thrown")
        } catch ContentError.invalid(let errors) {
            #expect(!errors.isEmpty)
        } catch {
            Issue.record("expected ContentError.invalid, got \(error)")
        }
    }
}
