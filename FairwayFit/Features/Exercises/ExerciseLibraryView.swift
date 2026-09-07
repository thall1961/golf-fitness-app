import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var search = ""

    private var grouped: [(category: ExerciseCategory, exercises: [Exercise])] {
        let filtered = search.isEmpty
            ? appState.content.exercises
            : appState.content.exercises.filter {
                $0.name.localizedCaseInsensitiveContains(search)
            }
        return ExerciseCategory.allCases.compactMap { category in
            let matches = filtered.filter { $0.category == category }
                .sorted { $0.name < $1.name }
            return matches.isEmpty ? nil : (category, matches)
        }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.category) { group in
                Section(group.category.rawValue.capitalized) {
                    ForEach(group.exercises) { exercise in
                        NavigationLink(exercise.name) { ExerciseDetailView(exercise: exercise) }
                    }
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Exercises")
    }
}
