import Foundation

/// Literal UTF-8 search over complete serialized JSON, independent of previews/units.
/// Non-overlapping matches preserve case, escaping and Unicode distinctions.
public struct JSONValueSearch: Sendable {
    private let bytes: [UInt8]
    private let offsets: [Int]
    private let matchLength: Int
    public var count: Int { offsets.count }

    public static func find(_ value: JSONValue?, query: String) throws -> Self {
        try Task.checkCancellation()
        let needle = Array(query.utf8)
        guard let value, !needle.isEmpty else { return Self(bytes: [], offsets: [], matchLength: 0) }
        let bytes = Array(value.serialized().utf8)
        // KMP bounds work linearly even for long repeated strings/queries.
        var prefix = Array(repeating: 0, count: needle.count)
        var matched = 0
        for index in needle.indices.dropFirst() {
            if index % 4096 == 0 { try Task.checkCancellation() }
            while matched > 0 && needle[index] != needle[matched] { matched = prefix[matched - 1] }
            if needle[index] == needle[matched] { matched += 1 }
            prefix[index] = matched
        }
        var offsets: [Int] = []
        matched = 0
        for index in bytes.indices {
            if index % 4096 == 0 { try Task.checkCancellation() }
            while matched > 0 && bytes[index] != needle[matched] { matched = prefix[matched - 1] }
            if bytes[index] == needle[matched] { matched += 1 }
            if matched == needle.count {
                offsets.append(index + 1 - matched)
                matched = 0
            }
        }
        try Task.checkCancellation()
        return Self(bytes: bytes, offsets: offsets, matchLength: needle.count)
    }

    /// Bounded UTF-8 excerpts never split a scalar. The complete match still counts
    /// when its displayed text needs truncation. Positions are one-based byte offsets.
    public func excerpt(at index: Int) -> JSONSearchExcerpt? {
        guard offsets.indices.contains(index) else { return nil }
        let start = offsets[index], end = start + matchLength
        var lower = max(0, start - 40), upper = min(bytes.count, end + 40)
        while lower < start && bytes[lower] & 0xC0 == 0x80 { lower += 1 }
        while upper < bytes.count && upper > end && bytes[upper] & 0xC0 == 0x80 { upper -= 1 }
        var matchEnd = min(end, start + 80)
        while matchEnd < end && matchEnd > start && bytes[matchEnd] & 0xC0 == 0x80 { matchEnd -= 1 }
        return JSONSearchExcerpt(
            before: (lower > 0 ? "…" : "") + String(decoding: bytes[lower..<start], as: UTF8.self),
            match: String(decoding: bytes[start..<matchEnd], as: UTF8.self),
            after: String(decoding: bytes[end..<upper], as: UTF8.self) + (upper < bytes.count ? "…" : ""),
            matchTruncated: matchEnd < end, bytePosition: start + 1)
    }
}

public struct JSONSearchExcerpt: Sendable {
    public let before: String
    public let match: String
    public let after: String
    public let matchTruncated: Bool
    public let bytePosition: Int
}
