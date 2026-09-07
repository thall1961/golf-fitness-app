import Foundation
import Testing
@testable import FairwayFit

/// A stub `URLProtocol` that lets tests drive `URLSessionContentFetcher`
/// without touching the network. It streams a configurable number of
/// fixed-size chunks with a short pause between each, so a test can observe
/// whether the fetcher aborted the transfer early rather than waiting for it
/// to finish.
final class StubStreamingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var chunkSize = 0
    nonisolated(unsafe) static var totalChunks = 0
    nonisolated(unsafe) static var chunksSent = 0
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var declaredContentLength: Int64 = -1
    nonisolated(unsafe) static var responseURL: URL?
    nonisolated(unsafe) static var startDelay: TimeInterval = 0.05

    private let lock = NSLock()
    private var isCancelled = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = Self.responseURL ?? request.url!
        let headers: [String: String]? = Self.declaredContentLength >= 0
            ? ["Content-Length": String(Self.declaredContentLength)]
            : nil
        let response = HTTPURLResponse(url: url, statusCode: Self.statusCode,
                                       httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            Thread.sleep(forTimeInterval: Self.startDelay)
            let chunk = Data(repeating: 0x41, count: Self.chunkSize)
            for index in 0..<Self.totalChunks {
                if self.currentlyCancelled { break }
                self.client?.urlProtocol(self, didLoad: chunk)
                Self.chunksSent = index + 1
                Thread.sleep(forTimeInterval: 0.01)
            }
            if !self.currentlyCancelled {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    private var currentlyCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }

    static func reset() {
        chunkSize = 0
        totalChunks = 0
        chunksSent = 0
        statusCode = 200
        declaredContentLength = -1
        responseURL = nil
        startDelay = 0.05
    }
}

@Suite struct ContentFetchingTests {

    private let url = URL(string: "https://example.com/content.json")!

    private func stubbedFetcher() -> URLSessionContentFetcher {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubStreamingURLProtocol.self]
        return URLSessionContentFetcher(session: URLSession(configuration: config))
    }

    // NOTE on what these two tests can and cannot prove: `URLProtocol`-backed
    // mocking of `URLSession.bytes(for:)` buffers the mock's entire body
    // before handing anything to the `AsyncBytes` consumer — confirmed
    // empirically (the stub's producer-side chunk count reached its total
    // before `fetch` ever read a byte, even with a generous artificial delay
    // before the first chunk). So a producer-side "did it stop early" signal
    // is not observable through this harness; real incremental abortion over
    // a live socket is not exercised here. What *is* provable, and what these
    // tests assert, is the outcome that matters for correctness: an oversized
    // response — whether declared via `Content-Length` or discovered only by
    // counting streamed bytes — is rejected rather than accepted. The
    // `bytes.task.cancel()` call in `ContentFetching.swift` is exercised by
    // these tests but its early-abort effect on the wire is not asserted.
    @Test func rejectsWhenTheDeclaredContentLengthExceedsTheCap() async throws {
        StubStreamingURLProtocol.reset()
        StubStreamingURLProtocol.chunkSize = 1024
        StubStreamingURLProtocol.totalChunks = 1
        StubStreamingURLProtocol.declaredContentLength = Int64(ContentDecoder.maximumBytes) + 1
        StubStreamingURLProtocol.responseURL = url
        StubStreamingURLProtocol.startDelay = 0

        let fetcher = stubbedFetcher()
        await #expect(throws: URLSessionContentFetcher.ResponseTooLarge.self) {
            _ = try await fetcher.fetch(from: url)
        }
    }

    @Test func rejectsAnOversizedStreamedBodyDiscoveredOnlyByCountingBytes() async throws {
        StubStreamingURLProtocol.reset()
        StubStreamingURLProtocol.chunkSize = 1024 * 1024
        StubStreamingURLProtocol.totalChunks = 6 // 6 MB total; cap is 5 MB
        StubStreamingURLProtocol.declaredContentLength = -1 // no Content-Length header, as with chunked transfer
        StubStreamingURLProtocol.responseURL = url
        StubStreamingURLProtocol.startDelay = 0

        let fetcher = stubbedFetcher()
        await #expect(throws: URLSessionContentFetcher.ResponseTooLarge.self) {
            _ = try await fetcher.fetch(from: url)
        }
    }

    @Test func rejectsWhenTheFinalURLIsNotHTTPS() async throws {
        StubStreamingURLProtocol.reset()
        StubStreamingURLProtocol.chunkSize = 16
        StubStreamingURLProtocol.totalChunks = 1
        StubStreamingURLProtocol.startDelay = 0
        StubStreamingURLProtocol.responseURL = URL(string: "http://redirected.example.com/content.json")!

        let fetcher = stubbedFetcher()
        await #expect(throws: URLSessionContentFetcher.BadResponse.self) {
            _ = try await fetcher.fetch(from: url)
        }
    }

    @Test func fetchesSuccessfullyWhenTheResponseIsSmallAndStaysOnHTTPS() async throws {
        StubStreamingURLProtocol.reset()
        StubStreamingURLProtocol.chunkSize = 16
        StubStreamingURLProtocol.totalChunks = 2
        StubStreamingURLProtocol.startDelay = 0
        StubStreamingURLProtocol.responseURL = url

        let fetcher = stubbedFetcher()
        let data = try await fetcher.fetch(from: url)
        #expect(data.count == 32)
    }
}
