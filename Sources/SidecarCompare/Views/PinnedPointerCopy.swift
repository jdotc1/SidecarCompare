import SidecarCore

/// Formats original RFC 6901 pointers without display escaping or Unicode normalization.
enum PinnedPointerCopy {
    static func content(fields: [(id: String, pointer: String)], pinnedIDs: Set<String>) -> (text: String, count: Int) {
        let pointers = fields.filter { pinnedIDs.contains($0.id) }.map(\.pointer)
            .sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        return (pointers.joined(separator: "\n"), pointers.count)
    }

    static let includedByteLimit = 1024 * 1024
    static func includedContent(fields: [(id: String, pointer: String)], includedIDs: Set<String>,
                                limit: Int = includedByteLimit) throws -> (text: String, count: Int) {
        let result = content(fields: fields, pinnedIDs: includedIDs)
        guard result.count > 0 else { throw SidecarError("No included JSON Pointers to copy. Clipboard unchanged.") }
        guard result.text.utf8.count <= limit else {
            throw SidecarError("Included JSON Pointers exceed the 1 MiB clipboard limit. Nothing was copied; clipboard unchanged.")
        }
        return result
    }

}
