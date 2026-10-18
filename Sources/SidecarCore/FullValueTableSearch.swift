import Foundation

/// Complete literal raw-JSON membership; publishes only the finished set.
public enum FullValueTableSearch {
    public static func matchingIDs(rows: [ComparisonRow], query: String) throws -> Set<String> {
        try Task.checkCancellation()
        guard !query.isEmpty else { return Set(rows.map(\.id)) }
        let length = query.utf8.count
        var result = Set<String>()
        for row in rows {
            try Task.checkCancellation()
            for value in [row.a, row.b].compactMap({ $0 }) {
                // Skip impossible lengths before constructing a search prefix table.
                guard value.serialized().utf8.count >= length else { continue }
                if try JSONValueSearch.find(value, query: query).count > 0 {
                    result.insert(row.id)
                    break
                }
            }
        }
        try Task.checkCancellation()
        return result
    }
}
