import SwiftData
import SwiftUI

struct ProgramDetailView: View {
    let program: Program

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var isActive: Bool {
        appState.activeEnrollment(in: context)?.programID == program.id
    }

    var body: some View {
        List {
            Section {
                Text(program.whoThisIsFor)
                LabeledContent("Sessions", value: "\(program.sessions.count)")
                LabeledContent("Pace", value: "\(program.sessionsPerWeek)× a week for about \(program.weeks) weeks")
            }

            Section("Sessions") {
                ForEach(Array(program.sessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink {
                        SessionOutlineView(session: session, number: index + 1)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1). \(session.name)")
                            Text("\(session.estimatedMinutes) min · \(session.prescriptions.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button(isActive ? "Currently active" : "Start this program") {
                    enroll()
                    dismiss()
                }
                .disabled(isActive)
            } footer: {
                if !isActive && appState.activeEnrollment(in: context) != nil {
                    Text("Your current program is archived, not deleted. Everything you logged stays in Progress.")
                }
            }
        }
        .navigationTitle(program.title)
    }

    private func enroll() {
        if let current = appState.activeEnrollment(in: context) {
            current.isActive = false
            current.finishedAt = current.finishedAt ?? .now
        }
        context.insert(Enrollment(programID: program.id, startedAt: .now))
        try? context.save()
    }
}

/// Read-only view of what a session contains, reachable before you run it.
struct SessionOutlineView: View {
    let session: Session
    let number: Int
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(session.blocks, id: \.kind) { block in
                Section(block.kind.rawValue.capitalized) {
                    ForEach(block.prescriptions, id: \.exerciseID) { prescription in
                        if let exercise = appState.content.exercise(id: prescription.exerciseID) {
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                PrescriptionRow(exercise: exercise, prescription: prescription)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrescriptionRow: View {
    let exercise: Exercise
    let prescription: Prescription

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
            Text(prescription.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = prescription.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

extension Prescription {
    /// "3 × 12" / "2 × 30s each side"
    var summary: String {
        let amount = switch target.kind {
        case .reps: "\(target.value)"
        case .repsPerSide: "\(target.value) each side"
        case .seconds: "\(target.value)s"
        case .secondsPerSide: "\(target.value)s each side"
        }
        return "\(sets) × \(amount)"
    }
}
