import Foundation

enum ContentSource: Equatable, Sendable {
    case bundled, cached
}

struct ResolvedContent: Sendable {
    let content: Content
    let source: ContentSource
    /// True when the cached document is unusable or has been overtaken by the
    /// bundled one, and should be deleted.
    let shouldDiscardCache: Bool
}

enum ContentResolver {

    /// Picks the document to run on. The bundled copy is the floor: it must be
    /// usable, and a throw here is a build defect rather than a runtime state.
    static func resolve(bundled: Data, cached: Data?) throws -> ResolvedContent {
        let bundledContent = try ContentDecoder.decode(bundled)

        guard let cached else {
            return ResolvedContent(content: bundledContent, source: .bundled, shouldDiscardCache: false)
        }

        guard let cachedContent = try? ContentDecoder.decode(cached) else {
            return ResolvedContent(content: bundledContent, source: .bundled, shouldDiscardCache: true)
        }

        if cachedContent.version > bundledContent.version {
            return ResolvedContent(content: cachedContent, source: .cached, shouldDiscardCache: false)
        }
        return ResolvedContent(content: bundledContent, source: .bundled, shouldDiscardCache: true)
    }
}
