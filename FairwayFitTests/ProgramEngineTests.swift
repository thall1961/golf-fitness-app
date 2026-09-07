import Testing
@testable import FairwayFit

@Suite struct ProgramEngineTests {

    private let program = makeProgram(sessions: [
        makeSession(id: "s1"), makeSession(id: "s2"), makeSession(id: "s3")
    ])

    @Test func firstSessionWhenNothingIsDone() throws {
        let next = try #require(ProgramEngine.nextSession(program: program, completions: []))
        #expect(next.index == 0)
        #expect(next.session.id == "s1")
    }

    @Test func skipsFinishedSessions() throws {
        let done = [CompletionRecord(sessionID: "s1", isFinished: true)]
        let next = try #require(ProgramEngine.nextSession(program: program, completions: done))
        #expect(next.index == 1)
        #expect(next.session.id == "s2")
    }

    @Test func offersAnUnfinishedSessionAgain() throws {
        let bailed = [CompletionRecord(sessionID: "s1", isFinished: false)]
        let next = try #require(ProgramEngine.nextSession(program: program, completions: bailed))
        #expect(next.session.id == "s1")
    }

    @Test func returnsProgramOrderNotCompletionOrder() throws {
        let done = [CompletionRecord(sessionID: "s2", isFinished: true)]
        let next = try #require(ProgramEngine.nextSession(program: program, completions: done))
        #expect(next.session.id == "s1", "the first unfinished session in program order")
    }

    @Test func nilWhenEverythingIsFinished() {
        let done = ["s1", "s2", "s3"].map { CompletionRecord(sessionID: $0, isFinished: true) }
        #expect(ProgramEngine.nextSession(program: program, completions: done) == nil)
        #expect(ProgramEngine.isComplete(program: program, completions: done))
    }

    @Test func progressCountsFinishedSessionsOnly() {
        let mixed = [
            CompletionRecord(sessionID: "s1", isFinished: true),
            CompletionRecord(sessionID: "s2", isFinished: false)
        ]
        let result = ProgramEngine.progress(program: program, completions: mixed)
        #expect(result.completed == 1)
        #expect(result.total == 3)
    }

    @Test func ignoresRecordsForSessionsNotInThisProgram() {
        let stale = [
            CompletionRecord(sessionID: "removed-in-a-content-update", isFinished: true),
            CompletionRecord(sessionID: "s1", isFinished: true)
        ]
        let result = ProgramEngine.progress(program: program, completions: stale)
        #expect(result.completed == 1)
        #expect(result.total == 3)
        #expect(ProgramEngine.isComplete(program: program, completions: stale) == false)
    }

    @Test func countsADuplicatedSessionIDOnce() {
        let dupes = [
            CompletionRecord(sessionID: "s1", isFinished: true),
            CompletionRecord(sessionID: "s1", isFinished: true)
        ]
        #expect(ProgramEngine.progress(program: program, completions: dupes).completed == 1)
    }

    @Test func emptyProgramIsCompleteAndHasNoNextSession() {
        let empty = makeProgram(sessions: [])
        #expect(ProgramEngine.nextSession(program: empty, completions: []) == nil)
        #expect(ProgramEngine.isComplete(program: empty, completions: []))
    }
}
