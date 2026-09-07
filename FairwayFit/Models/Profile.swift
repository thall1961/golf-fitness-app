import Foundation
import SwiftData

@Model
final class Profile {
    var name: String
    /// Calendar weekday numbers, 1 = Sunday.
    var reminderWeekdays: [Int]
    var reminderHour: Int
    var reminderMinute: Int
    var remindersEnabled: Bool

    init(name: String = "",
         reminderWeekdays: [Int] = [],
         reminderHour: Int = 18,
         reminderMinute: Int = 0,
         remindersEnabled: Bool = false) {
        self.name = name
        self.reminderWeekdays = reminderWeekdays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.remindersEnabled = remindersEnabled
    }

    /// The single profile row, created on first read. Called from `.task`,
    /// never from a view body — inserting during a body evaluation would
    /// invalidate the `@Query` that triggered it.
    static func loadOrCreate(in context: ModelContext) -> Profile {
        if let existing = try? context.fetch(FetchDescriptor<Profile>()).first {
            return existing
        }
        let fresh = Profile()
        context.insert(fresh)
        try? context.save()
        return fresh
    }
}
