import Foundation
import Testing
@testable import FairwayFit

private struct StubFetcher: ContentFetching {
    let result: Result<Data, any Error>
    func fetch(from url: URL) async throws -> Data { try result.get() }
}

private struct FetchFailure: Error {}

@Suite struct ContentStoreTests {

    private let contentURL = URL(string: "https://example.com/content.json")!

    private func data(version: Int, schemaVersion: Int = 1) throws -> Data {
        try JSONEncoder().encode(makeContent(schemaVersion: schemaVersion, version: version,
                                             exercises: [makeExercise(isBenchmark: true)]))
    }

    private func temporaryCacheURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("content.json")
    }

    @Test func loadsBundledContentOnFirstLaunch() async throws {
        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: temporaryCacheURL(),
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .failure(FetchFailure())))
        #expect(await store.content.version == 2)
        #expect(await store.source == .bundled)
    }

    @Test func aSuccessfulFetchWritesTheCacheWithoutChangingLoadedContent() async throws {
        let cacheURL = temporaryCacheURL()
        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .success(try data(version: 7))))

        let didCache = await store.refresh()

        #expect(didCache)
        #expect(await store.content.version == 2, "promotion happens at next launch, not mid-run")
        let cached = try Data(contentsOf: cacheURL)
        #expect(try ContentDecoder.decode(cached).version == 7)
    }

    @Test func theCachedDocumentIsUsedOnTheNextLaunch() async throws {
        let cacheURL = temporaryCacheURL()
        let first = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .success(try data(version: 7))))
        _ = await first.refresh()

        let second = try ContentStore(bundledData: try data(version: 2),
                                      cacheURL: cacheURL,
                                      contentURL: contentURL,
                                      fetcher: StubFetcher(result: .failure(FetchFailure())))
        #expect(await second.content.version == 7)
        #expect(await second.source == .cached)
    }

    @Test func ignoresAFetchThatIsNotNewer() async throws {
        let cacheURL = temporaryCacheURL()
        let store = try ContentStore(bundledData: try data(version: 7),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .success(try data(version: 7))))
        #expect(await store.refresh() == false)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
    }

    @Test func ignoresAMalformedFetch() async throws {
        let cacheURL = temporaryCacheURL()
        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .success(Data("{ nope".utf8))))
        #expect(await store.refresh() == false)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
    }

    @Test func ignoresAFetchWithAnUnknownSchema() async throws {
        let cacheURL = temporaryCacheURL()
        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .success(try data(version: 90, schemaVersion: 99))))
        #expect(await store.refresh() == false)
    }

    @Test func ignoresANetworkFailure() async throws {
        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: temporaryCacheURL(),
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .failure(FetchFailure())))
        #expect(await store.refresh() == false)
        #expect(await store.content.version == 2)
    }

    @Test func discardsACorruptCacheOnLaunch() async throws {
        let cacheURL = temporaryCacheURL()
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("{ corrupt".utf8).write(to: cacheURL)

        let store = try ContentStore(bundledData: try data(version: 2),
                                     cacheURL: cacheURL,
                                     contentURL: contentURL,
                                     fetcher: StubFetcher(result: .failure(FetchFailure())))
        #expect(await store.content.version == 2)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
    }
}
