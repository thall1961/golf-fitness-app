import Foundation
import Testing
@testable import FairwayFit

@Suite struct ReminderSchedulerTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")!
        return formatter.date(from: iso)!
    }

    @Test func noFireDatesWhenDisabled() {
        let preference = ReminderPreference(weekdays: [2, 4, 6], hour: 18, minute: 0, enabled: false)
        #expect(ReminderScheduler.nextFireDates(preference: preference,
                                                after: date("2026-09-07T09:00:00Z"),
                                                calendar: calendar,
                                                limit: 5).isEmpty)
    }

    @Test func noFireDatesWithoutWeekdays() {
        let preference = ReminderPreference(weekdays: [], hour: 18, minute: 0, enabled: true)
        #expect(ReminderScheduler.nextFireDates(preference: preference,
                                                after: date("2026-09-07T09:00:00Z"),
                                                calendar: calendar,
                                                limit: 5).isEmpty)
    }

    @Test func firesOnTheChosenWeekdaysInOrder() {
        // Weekdays 2/4/6 = Monday, Wednesday, Friday. Now is Monday 07 Sep 09:00.
        let preference = ReminderPreference(weekdays: [2, 4, 6], hour: 18, minute: 0, enabled: true)
        let dates = ReminderScheduler.nextFireDates(preference: preference,
                                                    after: date("2026-09-07T09:00:00Z"),
                                                    calendar: calendar,
                                                    limit: 4)
        #expect(dates == [date("2026-09-07T18:00:00Z"),
                          date("2026-09-09T18:00:00Z"),
                          date("2026-09-11T18:00:00Z"),
                          date("2026-09-14T18:00:00Z")])
    }

    @Test func skipsTodayOnceTheTimeHasPassed() {
        let preference = ReminderPreference(weekdays: [2], hour: 18, minute: 0, enabled: true)
        let dates = ReminderScheduler.nextFireDates(preference: preference,
                                                    after: date("2026-09-07T19:00:00Z"),
                                                    calendar: calendar,
                                                    limit: 1)
        #expect(dates == [date("2026-09-14T18:00:00Z")])
    }

    @Test func bodyNamesTheSessionThatIsActuallyNext() {
        let body = ReminderScheduler.body(sessionNumber: 9, total: 24,
                                          sessionName: "Rotational Power B", minutes: 38)
        #expect(body == "Session 9 of 24: Rotational Power B — 38 min")
    }
}
