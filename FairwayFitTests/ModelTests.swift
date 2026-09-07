import Foundation
import SwiftData
import Testing
@testable import FairwayFit

@Suite struct ModelTests {

    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema([Profile.self, Enrollment.self, SessionCompletion.self, SetLog.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func persistsAnEnrollmentWithCompletionsAndLogs() throws {
        let context = try inMemoryContext()

        let enrollment = Enrollment(programID: "mobility-foundations", startedAt: .now)
        context.insert(enrollment)

        let completion = SessionCompletion(sessionID: "mf-w1d1", startedAt: .now)
        completion.enrollment = enrollment
        context.insert(completion)

        let log = SetLog(exerciseID: "push-up", setNumber: 1, actualReps: 12)
        log.completion = completion
        context.insert(log)

        try context.save()

        let saved = try context.fetch(FetchDescriptor<Enrollment>())
        #expect(saved.count == 1)
        #expect(saved[0].completions.count == 1)
        #expect(saved[0].completions[0].setLogs[0].actualReps == 12)
    }

    @Test func mapsCompletionsToEngineRecords() throws {
        let context = try inMemoryContext()
        let enrollment = Enrollment(programID: "p", startedAt: .now)
        context.insert(enrollment)

        let finished = SessionCompletion(sessionID: "s1", startedAt: .now)
        finished.finishedAt = .now
        finished.enrollment = enrollment
        context.insert(finished)

        let bailed = SessionCompletion(sessionID: "s2", startedAt: .now)
        bailed.enrollment = enrollment
        context.insert(bailed)

        try context.save()

        let records = enrollment.completionRecords.sorted { $0.sessionID < $1.sessionID }
        #expect(records == [CompletionRecord(sessionID: "s1", isFinished: true),
                            CompletionRecord(sessionID: "s2", isFinished: false)])
    }

    @Test func profileDefaultsToRemindersOff() throws {
        let context = try inMemoryContext()
        let profile = Profile()
        context.insert(profile)
        try context.save()

        #expect(profile.remindersEnabled == false)
        #expect(profile.reminderWeekdays.isEmpty)
        #expect(profile.reminderHour == 18)
        #expect(profile.reminderMinute == 0)
    }
}
