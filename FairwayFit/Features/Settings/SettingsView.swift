import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    @State private var profile: Profile?
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notifications: any NotificationScheduling = NotificationCenterClient()

    private var weekdayNames: [(number: Int, name: String)] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return (1...7).map { ($0, symbols[$0 - 1]) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    form(profile: profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .task {
                if profile == nil { profile = Profile.loadOrCreate(in: context) }
                authorizationStatus = await notifications.authorizationStatus()
            }
        }
    }

    private func form(profile: Profile) -> some View {
        Form {
                Section {
                    Toggle("Training reminders", isOn: Binding(
                        get: { profile.remindersEnabled },
                        set: { newValue in
                            profile.remindersEnabled = newValue
                            try? context.save()
                            Task { await applyReminders(requestingPermission: newValue) }
                        }
                    ))

                    if profile.remindersEnabled {
                        HStack {
                            ForEach(weekdayNames, id: \.number) { day in
                                let isOn = profile.reminderWeekdays.contains(day.number)
                                Button(day.name) { toggle(weekday: day.number) }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                                                in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(isOn ? .white : .primary)
                            }
                        }

                        DatePicker("Time", selection: Binding(
                            get: {
                                Calendar.current.date(from: DateComponents(
                                    hour: profile.reminderHour, minute: profile.reminderMinute)) ?? .now
                            },
                            set: { newValue in
                                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                profile.reminderHour = parts.hour ?? 18
                                profile.reminderMinute = parts.minute ?? 0
                                try? context.save()
                                Task { await applyReminders(requestingPermission: false) }
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if authorizationStatus == .denied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are turned off for Fairway Fit in iOS Settings, so reminders will not appear. Everything else works as normal.")
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    } else {
                        Text("A nudge on the days you choose. Nothing is ever marked missed — the program waits for you.")
                    }
                }

                Section("Reference") {
                    NavigationLink("Exercise library") { ExerciseLibraryView() }
                }

                Section {
                    LabeledContent("Content version", value: "\(appState.content.version)")
                    LabeledContent("Exercises", value: "\(appState.content.exercises.count)")
                    LabeledContent("Programs", value: "\(appState.content.programs.count)")
                } header: {
                    Text("About")
                } footer: {
                    Text("New content is downloaded in the background and starts being used the next time you open the app.")
                }
        }
    }

    private func toggle(weekday: Int) {
        guard let profile else { return }
        if let index = profile.reminderWeekdays.firstIndex(of: weekday) {
            profile.reminderWeekdays.remove(at: index)
        } else {
            profile.reminderWeekdays.append(weekday)
        }
        try? context.save()
        Task { await applyReminders(requestingPermission: false) }
    }

    private func applyReminders(requestingPermission: Bool) async {
        guard let profile else { return }
        if requestingPermission {
            _ = await notifications.requestAuthorization()
        }
        authorizationStatus = await notifications.authorizationStatus()

        let preference = ReminderPreference(weekdays: profile.reminderWeekdays,
                                            hour: profile.reminderHour,
                                            minute: profile.reminderMinute,
                                            enabled: profile.remindersEnabled)

        guard let enrollment = appState.activeEnrollment(in: context),
              let program = appState.program(for: enrollment),
              let next = ProgramEngine.nextSession(program: program,
                                                   completions: enrollment.completionRecords) else {
            await notifications.replaceReminders(title: "Fairway Fit",
                                                 body: "Pick a program and get going.",
                                                 preference: preference)
            return
        }

        let body = ReminderScheduler.body(sessionNumber: next.index + 1,
                                          total: program.sessions.count,
                                          sessionName: next.session.name,
                                          minutes: next.session.estimatedMinutes)
        await notifications.replaceReminders(title: "Fairway Fit", body: body, preference: preference)
    }
}
