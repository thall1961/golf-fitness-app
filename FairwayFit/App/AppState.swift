import Foundation
import SwiftData

/// Holds the content document for the lifetime of the run and answers the two
/// questions every screen asks: what content is loaded, and which enrollment
/// is active.
@Observable
@MainActor
final class AppState {
    private(set) var content: Content
    let store: ContentStore

    init(store: ContentStore, content: Content) {
        self.store = store
        self.content = content
    }

    static func live() async throws -> AppState {
        let store = try ContentStore.live()
        let content = await store.content
        return AppState(store: store, content: content)
    }

    func refreshContentInBackground() {
        Task { await store.refresh() }
    }

    func activeEnrollment(in context: ModelContext) -> Enrollment? {
        var descriptor = FetchDescriptor<Enrollment>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func program(for enrollment: Enrollment) -> Program? {
        content.program(id: enrollment.programID)
    }
}
