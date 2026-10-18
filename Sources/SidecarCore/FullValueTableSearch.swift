import Foundation

public enum FullValueSearchSide: String, CaseIterable, Sendable {
    case both = "Both", a = "A only", b = "B only"
    public var valueLabel: String { self == .a ? "A" : self == .b ? "B" : "A/B" }
}

/// Complete literal raw-JSON membership; publishes only the finished set.
public enum FullValueTableSearch {
    public static func matchingIDs(rows: [ComparisonRow], query: String, side: FullValueSearchSide = .both) throws -> Set<String> {
        try Task.checkCancellation()
        guard !query.isEmpty else { return Set(rows.map(\.id)) }
        let length = query.utf8.count
        var result = Set<String>()
        for row in rows {
            try Task.checkCancellation()
            let values = side == .a ? [row.a] : side == .b ? [row.b] : [row.a, row.b]
            for value in values.compactMap({ $0 }) {
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
