import Foundation
import SidecarCore

/// Raw-JSON location of the first differing decoded scalar, independent of Find.
struct ChangedSpanExcerpt: Sendable {
    let before: String
    let changed: String
    let after: String
    let bytePosition: Int
    let scalarCount: Int
    let truncated: Bool

    static func make(value: String, prefix: Int, suffix: Int) throws -> Self {
        try Task.checkCancellation()
        let scalars = Array(value.unicodeScalars)
        guard prefix >= 0, suffix >= 0, prefix <= scalars.count, suffix <= scalars.count - prefix else {
            throw SidecarError("Changed span is outside the value.")
        }
        let end = scalars.count - suffix, shownEnd = min(end, prefix + 80)
        let lower = max(0, prefix - 40), upper = min(scalars.count, end + 40)
        func text(_ range: Range<Int>) -> String { String(String.UnicodeScalarView(scalars[range])) }
        func escaped(_ range: Range<Int>) -> String { String(JSONValue.quote(text(range)).dropFirst().dropLast()) }
        let position = JSONValue.quote(text(0..<prefix)).utf8.count
        try Task.checkCancellation()
        return Self(before: (lower == 0 ? "\"" : "…") + escaped(lower..<prefix),
                    changed: escaped(prefix..<shownEnd),
                    after: escaped(end..<upper) + (upper == scalars.count ? "\"" : "…"),
                    bytePosition: position, scalarCount: end - prefix, truncated: shownEnd < end)
    }
}

struct ChangedSpanRequest {
    let rowID: String
    let revision: [UUID?]
    let side: String
    let excerpt: ChangedSpanExcerpt
}

struct TableMatchIdentity: Hashable, Sendable {
    let rowID: String
    let revision: [UUID?]
    let query: Data
}

struct TableMatchLocations: Sendable {
    let identity: TableMatchIdentity
    let searchA: JSONValueSearch
    let searchB: JSONValueSearch
    var a: JSONSearchExcerpt? { searchA.excerpt(at: 0) }
    var b: JSONSearchExcerpt? { searchB.excerpt(at: 0) }
    var countA: Int { searchA.count }
    var countB: Int { searchB.count }
    var total: Int { countA + countB }
    func match(at index: Int) -> (side: String, excerpt: JSONSearchExcerpt)? {
        guard index >= 0, index < total else { return nil }
        if index < countA { return searchA.excerpt(at: index).map { ("A", $0) } }
        return searchB.excerpt(at: index - countA).map { ("B", $0) }
    }

    static func prepare(row: ComparisonRow, identity: TableMatchIdentity) throws -> Self {
        try Task.checkCancellation()
        guard row.id == identity.rowID, !identity.query.isEmpty else {
            throw SidecarError("Table match request is no longer available.")
        }
        let query = String(decoding: identity.query, as: UTF8.self)
        return Self(identity: identity,
                    searchA: try JSONValueSearch.find(row.a, query: query),
                    searchB: try JSONValueSearch.find(row.b, query: query))
    }
}

struct TableMatchReveal {
    let identity: TableMatchIdentity
    let side: String
    let index: Int
    let excerpt: JSONSearchExcerpt
}
