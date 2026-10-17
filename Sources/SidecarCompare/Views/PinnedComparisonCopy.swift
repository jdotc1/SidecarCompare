import SidecarCore

/// Builds a complete bounded snapshot before the caller touches the clipboard.
enum PinnedComparisonCopy {
    static let byteLimit = 4 * 1024 * 1024
    struct SizeLimitExceeded: Error {}

    static func content(rows: [ComparisonRow], pinnedIDs: Set<String>, policy: ComparisonPolicy,
                        limit: Int = byteLimit) throws -> (text: String, count: Int) {
        let selected = rows.filter { pinnedIDs.contains($0.id) }
            .sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
        guard !selected.isEmpty else { return ("", 0) }
        var text = "Pinned field comparisons · original metadata\nContains complete original metadata; not de-identified.\nFields: \(selected.count)"
        var bytes = text.utf8.count
        guard bytes <= limit else { throw SizeLimitExceeded() }
        for row in selected {
            let field = FieldComparisonCopy.text(row: row, policy: policy)
            let separator = "\n\n—\n"
            let added = separator.utf8.count + field.utf8.count
            guard added <= limit - bytes else { throw SizeLimitExceeded() }
            text += separator + field
            bytes += added
        }
        return (text, selected.count)
    }
}
