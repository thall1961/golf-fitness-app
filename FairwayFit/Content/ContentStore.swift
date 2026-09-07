import Foundation
import os

/// Owns the loaded content document and the cache file behind it.
///
/// Launch: resolve bundled vs cached, discarding a cache that is corrupt or
/// has been overtaken. Refresh: fetch, validate wholesale, and write the cache
/// — the in-memory document is never swapped mid-run, so a session in progress
/// cannot change underneath the person doing it.
actor ContentStore {

    // The repository backing this URL (thall1961/golf-fitness-app) is public
    // and this endpoint is live — but it resolves only once `Content/content.json`
    // exists on `main`. Today that file lives on the `fairway-fit-v1` branch,
    // so this request 404s to an unauthenticated client and every `refresh()`
    // fails silently — that failure path is exercised deliberately, and the
    // app runs on its bundled content, which is a fully supported state.
    // Remote updates begin working the moment this branch merges to `main`;
    // no code change is required when that happens.
    static let defaultContentURL = URL(
        string: "https://raw.githubusercontent.com/thall1961/golf-fitness-app/main/Content/content.json"
    )!

    private(set) var content: Content
    private(set) var source: ContentSource

    private let cacheURL: URL
    private let contentURL: URL
    private let fetcher: any ContentFetching
    private let log = Logger(subsystem: "com.thomashall.FairwayFit", category: "content")

    init(bundledData: Data,
         cacheURL: URL,
         contentURL: URL = ContentStore.defaultContentURL,
         fetcher: any ContentFetching = URLSessionContentFetcher()) throws {
        self.cacheURL = cacheURL
        self.contentURL = contentURL
        self.fetcher = fetcher

        let cached = try? Data(contentsOf: cacheURL)
        let resolved = try ContentResolver.resolve(bundled: bundledData, cached: cached)
        self.content = resolved.content
        self.source = resolved.source

        if resolved.shouldDiscardCache {
            try? FileManager.default.removeItem(at: cacheURL)
        }
    }

    /// Convenience for the app: bundled content comes from the app bundle and
    /// the cache lives in Application Support.
    static func live() throws -> ContentStore {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json") else {
            fatalError("content.json is missing from the app bundle — this is a build defect")
        }
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        return try ContentStore(bundledData: try Data(contentsOf: url),
                                cacheURL: support.appendingPathComponent("content.json"))
    }

    /// Returns true when a newer document was validated and cached.
    /// Never throws: every failure is a no-op that leaves the cache as it was.
    @discardableResult
    func refresh() async -> Bool {
        let data: Data
        do {
            data = try await fetcher.fetch(from: contentURL)
        } catch {
            log.debug("content fetch failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        let fetched: Content
        do {
            fetched = try ContentDecoder.decode(data)
        } catch {
            log.error("fetched content rejected: \(String(describing: error), privacy: .public)")
            return false
        }

        guard fetched.version > content.version else { return false }

        do {
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            log.error("caching content failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        log.info("cached content version \(fetched.version); it loads on next launch")
        return true
    }
}
