import Foundation

struct BenchmarkLog: Hashable, Sendable {
    let exerciseID: String
    let date: Date
    let value: Int
}

struct BenchmarkPoint: Hashable, Sendable, Identifiable {
    var id: Date { date }
    let date: Date
    let best: Int
}

enum ProgressEngine {

    /// Sessions needed in a week for it to count. Fixed across programs so a
    /// streak means the same thing whichever program you are running.
    static let sessionsPerQualifyingWeek = 2

    /// Weeks start Monday regardless of locale, so a Saturday and a Sunday
    /// session count towards the same week rather than straddling two.
    /// The user's timezone is kept — only the first weekday is pinned.
    static var streakCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    /// Consecutive qualifying weeks ending with the current or previous week.
    /// The current week is allowed to be incomplete without breaking a streak
    /// that the previous week already earned.
    static func currentStreak(finishedDates: [Date], now: Date, calendar: Calendar) -> Int {
        guard !finishedDates.isEmpty else { return 0 }

        var countsByWeek: [Date: Int] = [:]
        for date in finishedDates {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            countsByWeek[week, default: 0] += 1
        }

        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        // Start at this week if it qualifies, otherwise at last week.
        var cursor = thisWeek
        if (countsByWeek[thisWeek] ?? 0) < sessionsPerQualifyingWeek {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek) else {
                return 0
            }
            cursor = previous
        }

        var streak = 0
        while (countsByWeek[cursor] ?? 0) >= sessionsPerQualifyingWeek {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// One point per day, taking the best set that day — the trend a golfer
    /// cares about, not every individual set.
    static func benchmarkSeries(logs: [BenchmarkLog],
                                exerciseID: String,
                                calendar: Calendar) -> [BenchmarkPoint] {
        var bestByDay: [Date: Int] = [:]
        for log in logs where log.exerciseID == exerciseID {
            let day = calendar.startOfDay(for: log.date)
            bestByDay[day] = max(bestByDay[day] ?? 0, log.value)
        }
        return bestByDay
            .map { BenchmarkPoint(date: $0.key, best: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
