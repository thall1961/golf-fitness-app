import Foundation
import Testing
@testable import FairwayFit

@Suite struct ContentResolverTests {

    private func data(version: Int, schemaVersion: Int = 1) throws -> Data {
        let content = makeContent(schemaVersion: schemaVersion, version: version,
                                  exercises: [makeExercise(isBenchmark: true)])
        return try JSONEncoder().encode(content)
    }

    @Test func usesBundledWhenThereIsNoCache() throws {
        let resolved = try ContentResolver.resolve(bundled: try data(version: 3), cached: nil)
        #expect(resolved.content.version == 3)
        #expect(resolved.source == .bundled)
        #expect(resolved.shouldDiscardCache == false)
    }

    @Test func prefersTheHigherVersion() throws {
        let resolved = try ContentResolver.resolve(bundled: try data(version: 3),
                                                   cached: try data(version: 9))
        #expect(resolved.content.version == 9)
        #expect(resolved.source == .cached)
    }

    @Test func prefersBundledAfterAnAppUpdateOvertakesTheCache() throws {
        let resolved = try ContentResolver.resolve(bundled: try data(version: 12),
                                                   cached: try data(version: 9))
        #expect(resolved.content.version == 12)
        #expect(resolved.source == .bundled)
        #expect(resolved.shouldDiscardCache, "a stale cache is no longer useful")
    }

    @Test func prefersBundledWhenVersionsTie() throws {
        let resolved = try ContentResolver.resolve(bundled: try data(version: 5),
                                                   cached: try data(version: 5))
        #expect(resolved.source == .bundled)
    }

    @Test func fallsBackToBundledWhenTheCacheIsCorrupt() throws {
        let resolved = try ContentResolver.resolve(bundled: try data(version: 3),
                                                   cached: Data("{ not json".utf8))
        #expect(resolved.content.version == 3)
        #expect(resolved.source == .bundled)
        #expect(resolved.shouldDiscardCache)
    }

    @Test func fallsBackToBundledWhenTheCacheFailsValidation() throws {
        let invalid = try JSONEncoder().encode(
            makeContent(version: 99, exercises: [makeExercise(isBenchmark: false)])
        )
        let resolved = try ContentResolver.resolve(bundled: try data(version: 3), cached: invalid)
        #expect(resolved.source == .bundled)
        #expect(resolved.shouldDiscardCache)
    }

    @Test func fallsBackToBundledWhenTheCacheUsesAnUnknownSchema() throws {
        let future = try data(version: 50, schemaVersion: 99)
        let resolved = try ContentResolver.resolve(bundled: try data(version: 3), cached: future)
        #expect(resolved.content.version == 3)
        #expect(resolved.shouldDiscardCache)
    }

    @Test func throwsWhenBundledContentIsUnusable() {
        #expect(throws: ContentError.malformed) {
            try ContentResolver.resolve(bundled: Data("{ not json".utf8), cached: nil)
        }
    }
}
