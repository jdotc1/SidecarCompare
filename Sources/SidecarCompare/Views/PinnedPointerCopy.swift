/// Formats original RFC 6901 pointers without display escaping or Unicode normalization.
enum PinnedPointerCopy {
    static func content(fields: [(id: String, pointer: String)], pinnedIDs: Set<String>) -> (text: String, count: Int) {
        let pointers = fields.filter { pinnedIDs.contains($0.id) }.map(\.pointer)
            .sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        return (pointers.joined(separator: "\n"), pointers.count)
    }
}
