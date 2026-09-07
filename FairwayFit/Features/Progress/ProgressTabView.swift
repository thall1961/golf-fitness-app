import SwiftData
import SwiftUI

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(sort: \SessionCompletion.startedAt, order: .reverse)
    private var completions: [SessionCompletion]

    private var finished: [SessionCompletion] { completions.filter(\.isFinished) }

    private var streak: Int {
        ProgressEngine.currentStreak(finishedDates: finished.compactMap(\.finishedAt),
                                     now: .now,
                                     calendar: ProgressEngine.streakCalendar)
    }

    private var benchmarkLogs: [BenchmarkLog] {
        finished.flatMap { completion in
            completion.setLogs.compactMap { log in
                guard let value = log.achievedValue, let date = completion.finishedAt else { return nil }
                return BenchmarkLog(exerciseID: log.exerciseID, date: date, value: value)
            }
        }
    }

    private var benchmarkExercises: [Exercise] {
        appState.content.exercises.filter(\.isBenchmark)
    }

    /// Whether this exercise's logs are seconds or reps, read off what was
    /// actually recorded rather than guessed from the category.
    private func isTimed(_ exercise: Exercise) -> Bool {
        finished.lazy
            .flatMap(\.setLogs)
            .first { $0.exerciseID == exercise.id }?
            .actualSeconds != nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Sessions completed", value: "\(finished.count)")
                    LabeledContent("Streak", value: streak == 1 ? "1 week" : "\(streak) weeks")
                    if let enrollment = appState.activeEnrollment(in: context),
                       let program = appState.program(for: enrollment) {
                        let progress = ProgramEngine.progress(program: program,
                                                              completions: enrollment.completionRecords)
                        LabeledContent(program.title,
                                       value: "\(progress.completed) of \(progress.total)")
                    }
                } footer: {
                    Text("A week counts towards your streak once you finish two sessions in it.")
                }

                Section("Benchmarks") {
                    ForEach(benchmarkExercises) { exercise in
                        BenchmarkChartView(
                            exercise: exercise,
                            points: ProgressEngine.benchmarkSeries(logs: benchmarkLogs,
                                                                   exerciseID: exercise.id,
                                                                   calendar: .current),
                            isTimed: isTimed(exercise)
                        )
                    }
                }

                Section("History") {
                    if completions.isEmpty {
                        Text("Nothing logged yet.").foregroundStyle(.secondary)
                    }
                    ForEach(completions) { completion in
                        NavigationLink {
                            HistoryDetailView(completion: completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(completion.isFinished
                                     ? "\(completion.setLogs.count) sets logged"
                                     : "Unfinished")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}
