import Foundation

protocol ContentFetching: Sendable {
    func fetch(from url: URL) async throws -> Data
}

struct URLSessionContentFetcher: ContentFetching {
    struct BadResponse: Error {}

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw BadResponse() }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BadResponse()
        }
        return data
    }
}
