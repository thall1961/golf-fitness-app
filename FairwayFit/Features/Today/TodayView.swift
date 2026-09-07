import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    // A real @Query dependency, not a manual context.fetch, so SwiftUI has
    // something to invalidate on: enrolling from another tab (Programs) and
    // switching back to Today must re-render this view, not just a pop from
    // this tab's own navigation stack.
    @Query(filter: #Predicate<Enrollment> { $0.isActive },
           sort: \Enrollment.startedAt, order: .reverse)
    private var activeEnrollments: [Enrollment]

    private var activeEnrollment: Enrollment? { activeEnrollments.first }

    /// What Today has to say right now. Derived, never stored.
    enum State {
        case noEnrollment
        case programUnavailable(id: String)
        case next(index: Int, session: Session, program: Program, enrollment: Enrollment)
        case finished(program: Program, enrollment: Enrollment)
    }

    private var state: State {
        guard let enrollment = activeEnrollment else { return .noEnrollment }
        guard let program = appState.program(for: enrollment) else {
            return .programUnavailable(id: enrollment.programID)
        }
        if let next = ProgramEngine.nextSession(program: program,
                                                completions: enrollment.completionRecords) {
            return .next(index: next.index, session: next.session, program: program, enrollment: enrollment)
        }
        return .finished(program: program, enrollment: enrollment)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .noEnrollment:
                    ContentUnavailableView {
                        Label("No program yet", systemImage: "figure.strengthtraining.functional")
                    } description: {
                        Text("Pick a program and the next session shows up here.")
                    } actions: {
                        NavigationLink("Browse programs") { ProgramPickerList() }
                    }

                case .programUnavailable(let id):
                    ContentUnavailableView {
                        Label("Program unavailable", systemImage: "questionmark.folder")
                    } description: {
                        Text("The program you were following (\(id)) is not in the current content. Your history is safe — pick another program to carry on.")
                    } actions: {
                        NavigationLink("Browse programs") { ProgramPickerList() }
                    }

                case .next(let index, let session, let program, let enrollment):
                    NextSessionCard(index: index, session: session,
                                    program: program, enrollment: enrollment)

                case .finished(let program, let enrollment):
                    ContentUnavailableView {
                        Label("Program complete", systemImage: "checkmark.seal")
                    } description: {
                        Text(program.isRepeatable
                             ? "You finished \(program.title). Run it again, or pick something else."
                             : "You finished \(program.title). Pick what is next.")
                    } actions: {
                        if program.isRepeatable {
                            Button("Run it again") { enrollment.completeAndRepeat(in: context) }
                                .buttonStyle(.borderedProminent)
                        }
                        NavigationLink("Browse programs") { ProgramPickerList() }
                    }
                }
            }
            .navigationTitle("Today")
        }
    }
}

/// The programs list without its own NavigationStack, for pushing from Today.
private struct ProgramPickerList: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(appState.content.programs) { program in
            NavigationLink(program.title) { ProgramDetailView(program: program) }
        }
        .navigationTitle("Programs")
    }
}

struct NextSessionCard: View {
    let index: Int
    let session: Session
    let program: Program
    let enrollment: Enrollment

    @State private var isRunning = false

    private var progress: (completed: Int, total: Int) {
        ProgramEngine.progress(program: program, completions: enrollment.completionRecords)
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(program.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Session \(index + 1) of \(program.sessions.count) · \(session.estimatedMinutes) min")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.blocks, id: \.kind) { block in
                    Label("\(block.kind.rawValue.capitalized) · \(block.prescriptions.count) exercises",
                          systemImage: block.kind == .warmup ? "wind" : block.kind == .main ? "dumbbell" : "flame")
                        .font(.callout)
                }
            }

            Button {
                isRunning = true
            } label: {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
        .fullScreenCover(isPresented: $isRunning) {
            PlayerView(session: session, enrollment: enrollment)
        }
    }
}
