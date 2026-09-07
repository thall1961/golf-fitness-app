import SwiftUI

struct HistoryDetailView: View {
    let completion: SessionCompletion

    @Environment(AppState.self) private var appState

    private var sessionName: String {
        for program in appState.content.programs {
            if let session = program.sessions.first(where: { $0.id == completion.sessionID }) {
                return session.name
            }
        }
        return completion.sessionID
    }

    private var groupedLogs: [(exerciseID: String, logs: [SetLog])] {
        Dictionary(grouping: completion.setLogs, by: \.exerciseID)
            .map { (exerciseID: $0.key, logs: $0.value.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.exerciseID < $1.exerciseID }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Started", value: completion.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let finishedAt = completion.finishedAt {
                    LabeledContent("Finished", value: finishedAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    LabeledContent("Status", value: "Unfinished")
                }
                if let rpe = completion.rpe {
                    LabeledContent("Effort", value: "RPE \(rpe)")
                }
            }

            ForEach(groupedLogs, id: \.exerciseID) { group in
                // An exercise removed from content still shows by id — the log
                // records what was done and that claim does not expire.
                Section(appState.content.exercise(id: group.exerciseID)?.name ?? group.exerciseID) {
                    ForEach(group.logs) { log in
                        HStack {
                            Text("Set \(log.setNumber)")
                            Spacer()
                            if let reps = log.actualReps { Text("\(reps) reps") }
                            if let seconds = log.actualSeconds { Text("\(seconds)s") }
                            if let band = log.bandLevel {
                                Text(band.label).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(sessionName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
