import Foundation

enum ContentError: Error, Equatable, Sendable {
    case malformed
    case unsupportedSchema(Int)
    case invalid([ContentValidationError])
    case tooLarge
}

/// The one path any content document takes to become usable: size, decode,
/// schema check, then full validation. Rejection is wholesale.
enum ContentDecoder {
    static let maximumBytes = 5 * 1024 * 1024

    static func decode(_ data: Data) throws -> Content {
        guard data.count <= maximumBytes else { throw ContentError.tooLarge }

        let content: Content
        do {
            content = try JSONDecoder().decode(Content.self, from: data)
        } catch {
            throw ContentError.malformed
        }

        guard content.schemaVersion == Content.supportedSchemaVersion else {
            throw ContentError.unsupportedSchema(content.schemaVersion)
        }

        let errors = ContentValidator.validate(content)
        guard errors.isEmpty else { throw ContentError.invalid(errors) }

        return content
    }
}
