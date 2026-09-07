import Foundation
import SwiftData
import Testing
@testable import FairwayFit

@Suite @MainActor struct PlayerModelTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema([Profile.self, Enrollment.self, SessionCompletion.self, SetLog.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private let session = makeSession(id: "s1", blocks: [
        Block(kind: .warmup, prescriptions: [makePrescription(exerciseID: "cat-cow", sets: 1)]),
        Block(kind: .main, prescriptions: [
            makePrescription(exerciseID: "push-up", sets: 3),
            makePrescription(exerciseID: "band-row", sets: 2)
        ])
    ])

    @Test func flattensBlocksIntoStepsInOrder() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: session, enrollment: enrollment, context: context)

        #expect(model.steps.map(\.exerciseID) == ["cat-cow", "push-up", "band-row"])
        #expect(model.steps[0].blockKind == .warmup)
        #expect(model.steps[1].blockKind == .main)
    }

    @Test func startingCreatesOneUnfinishedCompletion() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        _ = PlayerModel(session: session, enrollment: enrollment, context: context)

        let completions = try context.fetch(FetchDescriptor<SessionCompletion>())
        #expect(completions.count == 1)
        #expect(completions[0].sessionID == "s1")
        #expect(completions[0].isFinished == false)
    }

    @Test func resumesAnExistingUnfinishedCompletion() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let existing = SessionCompletion(sessionID: "s1", startedAt: .now)
        existing.enrollment = enrollment
        context.insert(existing)
        try context.save()

        _ = PlayerModel(session: session, enrollment: enrollment, context: context)

        #expect(try context.fetch(FetchDescriptor<SessionCompletion>()).count == 1)
    }

    @Test func recordingASetWritesOneLog() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: session, enrollment: enrollment, context: context)

        model.record(setNumber: 1, value: 12, bandLevel: nil)
        model.advance()
        model.record(setNumber: 1, value: 10, bandLevel: .medium)

        let logs = try context.fetch(FetchDescriptor<SetLog>())
        #expect(logs.count == 2)
        #expect(logs.contains { $0.exerciseID == "cat-cow" && $0.actualReps == 12 })
        #expect(logs.contains { $0.exerciseID == "push-up" && $0.bandLevel == .medium })
    }

    @Test func rerecordingTheSameSetOverwritesRatherThanDuplicates() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: session, enrollment: enrollment, context: context)

        model.record(setNumber: 1, value: 8, bandLevel: nil)
        model.record(setNumber: 1, value: 12, bandLevel: nil)

        let logs = try context.fetch(FetchDescriptor<SetLog>())
        #expect(logs.count == 1)
        #expect(logs[0].actualReps == 12)
    }

    @Test func timedTargetsWriteSecondsNotReps() throws {
        let timed = makeSession(id: "t1", blocks: [Block(kind: .main, prescriptions: [
            makePrescription(exerciseID: "side-plank", sets: 1,
                             target: Target(kind: .secondsPerSide, value: 30))
        ])])
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: timed, enrollment: enrollment, context: context)

        model.record(setNumber: 1, value: 35, bandLevel: nil)

        let log = try #require(try context.fetch(FetchDescriptor<SetLog>()).first)
        #expect(log.actualSeconds == 35)
        #expect(log.actualReps == nil)
    }

    @Test func finishingStampsTheCompletion() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: session, enrollment: enrollment, context: context)

        model.finish(rpe: 7)

        let completion = try #require(try context.fetch(FetchDescriptor<SessionCompletion>()).first)
        #expect(completion.isFinished)
        #expect(completion.rpe == 7)
    }

    @Test func abandoningKeepsLogsAndLeavesTheSessionUnfinished() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)
        let model = PlayerModel(session: session, enrollment: enrollment, context: context)

        model.record(setNumber: 1, value: 12, bandLevel: nil)
        model.abandon()

        let completion = try #require(try context.fetch(FetchDescriptor<SessionCompletion>()).first)
        #expect(completion.isFinished == false)
        #expect(completion.setLogs.count == 1)
    }
}
