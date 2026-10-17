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
