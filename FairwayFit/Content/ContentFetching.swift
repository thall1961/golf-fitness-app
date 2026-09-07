import Foundation

protocol ContentFetching: Sendable {
    func fetch(from url: URL) async throws -> Data
}

struct URLSessionContentFetcher: ContentFetching {
    struct BadResponse: Error {}
    struct ResponseTooLarge: Error {}

    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    /// Streams the response body, rejecting anything over the shared 5 MB cap
    /// during transfer rather than after the fact, and only ever following a
    /// chain of redirects that stays on HTTPS. No credentials are attached:
    /// the session is ephemeral and cookies are switched off, because the
    /// content is public and read-only.
    func fetch(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw BadResponse() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BadResponse()
        }
        guard let finalURL = http.url, finalURL.scheme?.lowercased() == "https" else {
            throw BadResponse()
        }

        let cap = ContentDecoder.maximumBytes
        if http.expectedContentLength > 0, http.expectedContentLength > Int64(cap) {
            bytes.task.cancel()
            throw ResponseTooLarge()
        }

        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > cap {
                bytes.task.cancel()
                throw ResponseTooLarge()
            }
        }
        return data
    }
}
