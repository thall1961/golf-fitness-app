import SwiftData
import SwiftUI

@main
struct FairwayFitApp: App {
    @State private var appState: AppState?

    private let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Schema([Profile.self, Enrollment.self, SessionCompletion.self, SetLog.self])
            )
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let appState {
                RootTabView()
                    .environment(appState)
                    .modelContainer(container)
            } else {
                ProgressView()
                    .task {
                        do {
                            let state = try await AppState.live()
                            state.refreshContentInBackground()
                            appState = state
                        } catch {
                            fatalError("Bundled content is unusable: \(error)")
                        }
                    }
            }
        }
    }
}
