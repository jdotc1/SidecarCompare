import Foundation

public enum Comparator {
    #if DEBUG
    /// Local native acceptance checkpoint; nil in ordinary sessions, absent in release.
    @TaskLocal public static var acceptanceCheckpoint: (@Sendable () -> Void)?
    #endif
    public static func compare(a: JSONValue, b: JSONValue, policy: ComparisonPolicy = .exact) throws -> Comparison {
        guard case .object(let left) = a, case .object(let right) = b else {
            throw SidecarError("Comparison requires two JSON objects.")
        }
        var rows = [ComparisonRow]()
        var totalPathBytes = 0
        for key in Set(left.keys).union(right.keys).sorted() {
            let info = FieldCatalog.info(forTopLevelKey: key.rawValue)
            let validShape = (info?.accepts(left[key]) ?? true) && (info?.accepts(right[key]) ?? true)
            try visit(a: left[key], b: right[key], path: "/" + escape(key.rawValue),
                      info: info, validShape: validShape, depth: 0, policy: policy, rows: &rows, totalPathBytes: &totalPathBytes)
        }
        return Comparison(rows: rows, policy: policy)
    }

    private static func visit(a: JSONValue?, b: JSONValue?, path: String,
                              info: FieldInfo?, validShape: Bool, depth: Int,
                              policy: ComparisonPolicy, rows: inout [ComparisonRow], totalPathBytes: inout Int) throws {
        #if DEBUG
        acceptanceCheckpoint?()
        #endif
        try Task.checkCancellation()
        let pathBytes = path.utf8.count
        guard pathBytes <= ComparisonLimits.maxPathBytes else {
            throw SidecarError("An expanded JSON Pointer exceeds the 2,048-byte comparison limit. No partial result was returned.")
        }
        if case .object(let left) = a, case .object(let right) = b, !left.isEmpty || !right.isEmpty {
            for key in Set(left.keys).union(right.keys).sorted() {
                try visit(a: left[key], b: right[key], path: path + "/" + escape(key.rawValue),
                          info: info, validShape: false, depth: depth + 1, policy: policy, rows: &rows, totalPathBytes: &totalPathBytes)
            }
            return
        }
        if case .array(let left) = a, case .array(let right) = b, !left.isEmpty || !right.isEmpty {
            for i in 0..<max(left.count, right.count) {
                try visit(a: i < left.count ? left[i] : nil, b: i < right.count ? right[i] : nil,
                          path: path + "/\(i)", info: info, validShape: validShape,
                          depth: depth + 1, policy: policy, rows: &rows, totalPathBytes: &totalPathBytes)
            }
            return
        }
        guard rows.count < ComparisonLimits.maxRows else {
            throw SidecarError("The comparison exceeds 20,000 rows. No partial result was returned.")
        }
        guard totalPathBytes + pathBytes <= ComparisonLimits.maxTotalPathBytes else {
            throw SidecarError("Expanded JSON Pointers exceed the 2 MiB comparison budget. No partial result was returned.")
        }
        totalPathBytes += pathBytes
        let unit = validShape && depth <= 1 ? info?.unit : nil
        var notes = [String]()
        if let info {
            if !validShape && info.unit != nil {
                notes.append("The top-level field has an unsupported value shape. Compared as raw JSON without units or tolerance.")
            } else if let unit {
                notes.append("\(info.source) interpretation: \(info.key) uses \(unit). No unit guessing or metadata correction.")
            }
            if !info.explanation.isEmpty { notes.append(info.explanation) }
        }
        let delta: DecimalNumber?
        if case .number(let left) = a, case .number(let right) = b { delta = right.subtracting(left) }
        else { delta = nil }
        let status: DifferenceStatus
        switch (a, b) {
        case (nil, _): status = .bOnly
        case (_, nil): status = .aOnly
        case (.some(let left), .some(let right)):
            if left.typeName != right.typeName { status = .typeChanged }
            else if left == right { status = .equal }
            else if unit != nil, info?.allowsTolerance == true,
                    case .number(let x) = left, case .number(let y) = right,
                    x.isWithinRelativeTolerance(of: y, tolerance: policy.relativeTolerance) {
                status = .withinTolerance
            } else { status = .changed }
        }
        rows.append(ComparisonRow(path: path, a: a, b: b, status: status,
                                  category: info?.category ?? .other, unit: unit, notes: notes, delta: delta))
    }

    private static func escape(_ name: String) -> String {
        name.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }
}
