import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func replaceReminders(title: String, body: String, preference: ReminderPreference) async
}

struct NotificationCenterClient: NotificationScheduling {
    private static let identifierPrefix = "fairway-fit-reminder-"

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func replaceReminders(title: String, body: String, preference: ReminderPreference) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        for (index, trigger) in ReminderScheduler.triggers(for: preference).enumerated() {
            let request = UNNotificationRequest(identifier: "\(Self.identifierPrefix)\(index)",
                                                content: content,
                                                trigger: trigger)
            try? await center.add(request)
        }
    }
}
