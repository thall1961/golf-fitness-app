import Foundation
import Testing
@testable import FairwayFit

@Suite struct ProgressEngineTests {

    /// Monday-first, UTC, so week boundaries in these tests are unambiguous.
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

    @Test func noSessionsIsNoStreak() {
        #expect(ProgressEngine.currentStreak(finishedDates: [],
                                             now: date("2026-09-09T12:00:00Z"),
                                             calendar: calendar) == 0)
    }

    @Test func oneSessionThisWeekIsNotYetAStreak() {
        let dates = [date("2026-09-07T09:00:00Z")]
        #expect(ProgressEngine.currentStreak(finishedDates: dates,
                                             now: date("2026-09-09T12:00:00Z"),
                                             calendar: calendar) == 0)
    }

    @Test func twoSessionsThisWeekIsAStreakOfOne() {
        let dates = [date("2026-09-07T09:00:00Z"), date("2026-09-09T09:00:00Z")]
        #expect(ProgressEngine.currentStreak(finishedDates: dates,
                                             now: date("2026-09-09T12:00:00Z"),
                                             calendar: calendar) == 1)
    }

    @Test func consecutiveQualifyingWeeksStack() {
        let dates = [
            date("2026-08-31T09:00:00Z"), date("2026-09-02T09:00:00Z"),  // week of Aug 31
            date("2026-09-07T09:00:00Z"), date("2026-09-09T09:00:00Z")   // week of Sep 7
        ]
        #expect(ProgressEngine.currentStreak(finishedDates: dates,
                                             now: date("2026-09-09T12:00:00Z"),
                                             calendar: calendar) == 2)
    }

    @Test func aGapWeekBreaksTheStreak() {
        let dates = [
            date("2026-08-24T09:00:00Z"), date("2026-08-26T09:00:00Z"),  // qualifying
            // week of Aug 31 skipped entirely
            date("2026-09-07T09:00:00Z"), date("2026-09-09T09:00:00Z")   // qualifying
        ]
        #expect(ProgressEngine.currentStreak(finishedDates: dates,
                                             now: date("2026-09-09T12:00:00Z"),
                                             calendar: calendar) == 1)
    }

    @Test func anIncompleteCurrentWeekDoesNotBreakLastWeeksStreak() {
        let dates = [
            date("2026-08-31T09:00:00Z"), date("2026-09-02T09:00:00Z"),  // last week, qualifying
            date("2026-09-07T09:00:00Z")                                  // this week, only one
        ]
        #expect(ProgressEngine.currentStreak(finishedDates: dates,
                                             now: date("2026-09-08T12:00:00Z"),
                                             calendar: calendar) == 1)
    }

    @Test func benchmarkSeriesTakesTheDailyBest() {
        let logs = [
            BenchmarkLog(exerciseID: "push-up", date: date("2026-09-01T09:00:00Z"), value: 8),
            BenchmarkLog(exerciseID: "push-up", date: date("2026-09-01T09:05:00Z"), value: 11),
            BenchmarkLog(exerciseID: "push-up", date: date("2026-09-08T09:00:00Z"), value: 14),
            BenchmarkLog(exerciseID: "band-row", date: date("2026-09-08T09:00:00Z"), value: 20)
        ]
        let series = ProgressEngine.benchmarkSeries(logs: logs, exerciseID: "push-up", calendar: calendar)
        #expect(series.count == 2)
        #expect(series[0].best == 11)
        #expect(series[1].best == 14)
        #expect(series[0].date < series[1].date)
    }

    @Test func streakCalendarStartsWeeksOnMonday() {
        #expect(ProgressEngine.streakCalendar.firstWeekday == 2)
        #expect(ProgressEngine.streakCalendar.timeZone == Calendar.current.timeZone)
    }

    @Test func benchmarkSeriesIsEmptyForAnUnloggedExercise() {
        #expect(ProgressEngine.benchmarkSeries(logs: [], exerciseID: "push-up",
                                               calendar: calendar).isEmpty)
    }
}
