import Foundation

/// A single differing span, not a minimal edit script. Unicode scalars are never normalized.
public struct StringDifferenceSummary: Sendable {
    public struct Excerpt: Sendable {
        public let before: String
        public let changed: String
        public let after: String
        public let changedScalarCount: Int
        public let truncated: Bool
        public let valueIsEmpty: Bool
    }
    public let a: Excerpt
    public let b: Excerpt
    public let sharedPrefixScalars: Int
    public let sharedSuffixScalars: Int
    public var kind: String {
        if a.changedScalarCount == 0 { return "Added text in B" }
        if b.changedScalarCount == 0 { return "Removed text from A" }
        return "Changed text"
    }

    public static func compare(a: String, b: String) throws -> Self? {
        try Task.checkCancellation()
        let left = Array(a.unicodeScalars), right = Array(b.unicodeScalars)
        let shortest = min(left.count, right.count)
        var prefix = 0
        while prefix < shortest && left[prefix].value == right[prefix].value {
            if prefix % 4096 == 0 { try Task.checkCancellation() }
            prefix += 1
        }
        if prefix == left.count && prefix == right.count { return nil }
        var suffix = 0
        while suffix < shortest - prefix && left[left.count - suffix - 1].value == right[right.count - suffix - 1].value {
            if suffix % 4096 == 0 { try Task.checkCancellation() }
            suffix += 1
        }
        try Task.checkCancellation()
        return Self(a: excerpt(left, prefix: prefix, suffix: suffix),
                    b: excerpt(right, prefix: prefix, suffix: suffix),
                    sharedPrefixScalars: prefix, sharedSuffixScalars: suffix)
    }

    private static func excerpt(_ scalars: [Unicode.Scalar], prefix: Int, suffix: Int) -> Excerpt {
        let end = scalars.count - suffix
        let changeEnd = min(end, prefix + 80)
        let beforeStart = max(0, prefix - 40), afterEnd = min(scalars.count, end + 40)
        return Excerpt(before: (beforeStart > 0 ? "…" : "") + escaped(scalars[beforeStart..<prefix]),
                       changed: escaped(scalars[prefix..<changeEnd]),
                       after: escaped(scalars[end..<afterEnd]) + (afterEnd < scalars.count ? "…" : ""),
                       changedScalarCount: end - prefix, truncated: changeEnd < end, valueIsEmpty: scalars.isEmpty)
    }
    private static func escaped(_ scalars: ArraySlice<Unicode.Scalar>) -> String {
        var text = ""
        for scalar in scalars {
            let value = scalar.value
            if value > 0xFFFF {
                let remainder = value - 0x10000
                text += String(format: "\\u%04X\\u%04X", 0xD800 + (remainder >> 10), 0xDC00 + (remainder & 0x3FF))
            } else if value > 0x7E || value < 0x20 {
                text += String(format: "\\u%04X", value)
            } else {
                let quoted = JSONValue.quote(String(scalar))
                text += quoted.dropFirst().dropLast()
            }
        }
        return text
    }
}
