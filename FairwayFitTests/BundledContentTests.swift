import Foundation
import Testing
@testable import FairwayFit

/// The CI half of the content safety net: the repo's own content.json must
/// pass the exact rules ContentStore applies to anything it fetches.
@Suite struct BundledContentTests {

    private func bundledData() throws -> Data {
        // Bundle.main is the host app bundle for a host-application unit test,
        // which is where the Content build phase copies content.json.
        let url = try #require(
            Bundle.main.url(forResource: "content", withExtension: "json"),
            "content.json is missing from the app bundle"
        )
        return try Data(contentsOf: url)
    }

    @Test func bundledContentPassesValidation() throws {
        let content = try ContentDecoder.decode(try bundledData())
        #expect(content.schemaVersion == Content.supportedSchemaVersion)
        #expect(content.version > 0)
    }

    @Test func libraryHasTheExpectedShape() throws {
        let content = try ContentDecoder.decode(try bundledData())
        #expect(content.exercises.count >= 45)
        #expect(content.exercises.filter(\.isBenchmark).count >= 5)
        #expect(ExerciseCategory.allCases.allSatisfy { category in
            content.exercises.contains { $0.category == category }
        })
    }

    @Test func mobilityFoundationsIsComplete() throws {
        let content = try ContentDecoder.decode(try bundledData())
        let program = try #require(content.program(id: "mobility-foundations"))
        #expect(program.sessions.count == 12)
        #expect(program.isRepeatable == false)
        #expect(program.sessions.allSatisfy { $0.blocks.contains { $0.kind == .warmup } })
    }

    @Test func everyExerciseDemoIsAUniqueHTTPSLink() throws {
        let content = try ContentDecoder.decode(try bundledData())
        let links = content.exercises.map(\.demoURL.absoluteString)
        #expect(links.allSatisfy { $0.hasPrefix("https://") })
        #expect(Set(links).count == links.count, "two exercises share a demo link")
    }
}
