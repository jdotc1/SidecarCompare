import Foundation

/// Presentation ordering only. No tolerance, conversion, or floating-point coercion.
public struct JSONSortValue: Comparable, Sendable {
    public let value: JSONValue?
    public init(_ value: JSONValue?) { self.value = value }

    private var rank: Int {
        switch value {
        case nil: 0
        case .null: 1
        case .bool: 2
        case .number: 3
        case .string: 4
        case .array: 5
        case .object: 6
        }
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        switch (lhs.value, rhs.value) {
        case (.number(let a), .number(let b)):
            if a == b { return false }
            if a.isNegative != b.isNegative { return a.isNegative }
            return a.isNegative ? b.magnitudeLessThanOrEqual(to: a) : a.magnitudeLessThanOrEqual(to: b)
        case (.string(let a), .string(let b)):
            return a.utf8.lexicographicallyPrecedes(b.utf8)
        default:
            return (lhs.value?.compactPreview ?? "").utf8.lexicographicallyPrecedes((rhs.value?.compactPreview ?? "").utf8)
        }
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { !(lhs < rhs) && !(rhs < lhs) }
}
