import Foundation
import SwiftData
import Testing
@testable import FairwayFit

@Suite struct ReenrollmentTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema([Profile.self, Enrollment.self, SessionCompletion.self, SetLog.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func repeatingArchivesTheOldCycleAndStartsACleanOne() throws {
        let context = try context()
        let enrollment = Enrollment(programID: "in-season-maintenance", startedAt: .now)
        context.insert(enrollment)
        let done = SessionCompletion(sessionID: "ism-w1d1", startedAt: .now)
        done.finishedAt = .now
        done.enrollment = enrollment
        context.insert(done)
        try context.save()

        let fresh = enrollment.completeAndRepeat(in: context)

        #expect(enrollment.isActive == false)
        #expect(enrollment.finishedAt != nil)
        #expect(enrollment.completions.count == 1, "the finished cycle keeps its history")
        #expect(fresh.isActive)
        #expect(fresh.programID == "in-season-maintenance")
        #expect(fresh.completions.isEmpty, "a new cycle starts from session one")
    }
}
