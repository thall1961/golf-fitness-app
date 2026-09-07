import SwiftData
import SwiftUI

struct ProgramListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    // Same reasoning as TodayView: a real @Query dependency so the "Active"
    // badge re-renders when an enrollment changes anywhere in the app, not
    // just when this view's own manual fetch happens to be re-evaluated.
    @Query(filter: #Predicate<Enrollment> { $0.isActive },
           sort: \Enrollment.startedAt, order: .reverse)
    private var activeEnrollments: [Enrollment]

    private var activeEnrollment: Enrollment? { activeEnrollments.first }

    var body: some View {
        NavigationStack {
            List(appState.content.programs) { program in
                NavigationLink {
                    ProgramDetailView(program: program)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(program.title).font(.headline)
                            if activeEnrollment?.programID == program.id {
                                Text("Active")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(program.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(program.sessions.count) sessions · \(program.sessionsPerWeek)× a week")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Programs")
        }
    }
}
