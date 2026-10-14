import Foundation

public enum FileSlot: String, Sendable, CaseIterable { case a = "A", b = "B" }
public enum DifferenceStatus: String, Sendable, CaseIterable {
    case equal = "Equal"
    case withinTolerance = "Within tolerance"
    case changed = "Changed"
    case typeChanged = "Type changed"
    case aOnly = "A only"
    case bOnly = "B only"
    public var symbol: String {
        switch self {
        case .equal: "equal.circle"
        case .withinTolerance: "plusminus.circle"
        case .changed: "arrow.left.arrow.right.circle"
        case .typeChanged: "exclamationmark.circle"
        case .aOnly: "minus.circle"
        case .bOnly: "plus.circle"
        }
    }
}

public struct ComparisonPolicy: Sendable, Equatable {
    public let relativeTolerance: DecimalNumber
    public static let exact = Self(unchecked: "0")
    public init(relativeTolerance: String = "0") throws {
        let number = try DecimalNumber(token: relativeTolerance)
        let one = try DecimalNumber(token: "1")
        guard !number.isNegative, number.magnitudeLessThanOrEqual(to: one) else {
            throw SidecarError("Relative tolerance must be between 0 and 1 (0–100%).")
        }
        self.relativeTolerance = number
    }
    private init(unchecked: String) { relativeTolerance = try! DecimalNumber(token: unchecked) }
    public var label: String {
        relativeTolerance.isZero ? "Exact comparison" : "Relative tolerance: \(relativeTolerance.scaled(byPowerOfTen: 2).canonicalString)%"
    }
}

public struct ComparisonRow: Identifiable, Sendable {
    public let path: String
    public let a: JSONValue?
    public let b: JSONValue?
    public let status: DifferenceStatus
    public let category: FieldCategory
    public let unit: String?
    public let notes: [String]
    public let delta: DecimalNumber?
    // Base64 avoids canonical Unicode collisions in SwiftUI's String identity.
    public var id: String { Data(path.utf8).base64EncodedString() }
    public var visiblePath: String { String(JSONValue.quote(path).dropFirst().dropLast()) }
    public func displayValue(side: FileSlot, milliseconds: Bool) -> String {
        guard let value = side == .a ? a : b else { return "— missing —" }
        if case .number(let number) = value, unit == "s", milliseconds {
            return number.scaled(byPowerOfTen: 3).canonicalString + " ms"
        }
        return value.compactPreview
    }
}

public struct Comparison: Sendable {
    public let rows: [ComparisonRow]
    public let policy: ComparisonPolicy
    public var differenceCount: Int { rows.filter { $0.status != .equal }.count }
    public var counts: [DifferenceStatus: Int] {
        Dictionary(grouping: rows, by: \.status).mapValues(\.count)
    }
    public func filtered(search: String, differencesOnly: Bool, category: FieldCategory?) -> [ComparisonRow] {
        rows.filter { row in
            (!differencesOnly || row.status != .equal) && (category == nil || category == row.category) &&
            (search.isEmpty || row.path.localizedCaseInsensitiveContains(search) ||
             (row.a?.compactPreview.localizedCaseInsensitiveContains(search) ?? false) ||
             (row.b?.compactPreview.localizedCaseInsensitiveContains(search) ?? false))
        }
    }
}

/// Expansion budgets are separate from per-input parser limits. A small nested input
/// can otherwise expand into a very large table/report through repeated path prefixes.
public enum ComparisonLimits {
    public static let maxRows = 20_000
    public static let maxPathBytes = 2_048
    public static let maxTotalPathBytes = 2 * 1024 * 1024
}
