import Foundation
import UserNotifications

struct ReminderPreference: Hashable, Sendable {
    /// Calendar weekday numbers, 1 = Sunday.
    let weekdays: [Int]
    let hour: Int
    let minute: Int
    let enabled: Bool
}

/// Reminders are a nudge preference, not a schedule the program is bound to.
/// Nothing here knows or cares whether a session was "missed".
enum ReminderScheduler {

    static func body(sessionNumber: Int, total: Int, sessionName: String, minutes: Int) -> String {
        "Session \(sessionNumber) of \(total): \(sessionName) — \(minutes) min"
    }

    static func nextFireDates(preference: ReminderPreference,
                              after now: Date,
                              calendar: Calendar,
                              limit: Int) -> [Date] {
        guard preference.enabled, !preference.weekdays.isEmpty, limit > 0 else { return [] }

        // Each weekday is walked forward independently, then the streams are
        // merged — otherwise three weekdays would only ever yield three dates.
        var dates: [Date] = []
        for weekday in Set(preference.weekdays).sorted() {
            var components = DateComponents()
            components.hour = preference.hour
            components.minute = preference.minute
            components.weekday = weekday

            var cursor = now
            for _ in 0..<limit {
                guard let next = calendar.nextDate(after: cursor,
                                                   matching: components,
                                                   matchingPolicy: .nextTime) else { break }
                dates.append(next)
                cursor = next
            }
        }
        return Array(dates.sorted().prefix(limit))
    }

    /// One repeating weekly trigger per chosen weekday.
    static func triggers(for preference: ReminderPreference) -> [UNCalendarNotificationTrigger] {
        guard preference.enabled else { return [] }
        return Set(preference.weekdays).sorted().map { weekday in
            var components = DateComponents()
            components.weekday = weekday
            components.hour = preference.hour
            components.minute = preference.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }
}
