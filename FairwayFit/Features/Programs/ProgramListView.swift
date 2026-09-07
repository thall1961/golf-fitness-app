import SwiftData
import SwiftUI

struct ProgramListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List(appState.content.programs) { program in
                NavigationLink {
                    ProgramDetailView(program: program)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(program.title).font(.headline)
                            if appState.activeEnrollment(in: context)?.programID == program.id {
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
