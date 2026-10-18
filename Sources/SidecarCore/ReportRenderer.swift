import Foundation

public enum ReportDetail: String, Sendable, CaseIterable { case summary, full }

public enum ReportScope: Sendable {
    case all
    case pinned(Set<String>)
    case visible(Set<String>)

    fileprivate func select(_ comparison: Comparison) -> Comparison {
        let ids: Set<String>
        switch self {
        case .all: return comparison
        case .pinned(let selected), .visible(let selected): ids = selected
        }
        return Comparison(rows: comparison.rows.filter { ids.contains($0.id) }
            .sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }, policy: comparison.policy)
    }
    fileprivate var selectionNote: String? {
        switch self {
        case .all: return nil
        case .pinned: return "Pinned fields only, including pins hidden by table filters"
        case .visible: return "Visible fields only (snapshot of table filters)"
        }
    }
    fileprivate var isVisible: Bool { if case .visible = self { return true }; return false }
}

public enum ReportRenderer {
    public static let appVersion = "0.1.0"
    public static let toleranceRule = "abs(B-A) <= r * max(abs(A), abs(B)); curated MRI quantities only"
    public static let scopeNote = "Selected JSON files only. No BIDS inheritance, image inspection, de-identification, or clinical validation."
    public static let privacyNote = "Full reports retain original metadata, including embedded filenames and paths, which may identify people. The app does not add selected-file names or paths. Review before sharing."

    public static func json(_ comparison: Comparison, detail: ReportDetail, scope: ReportScope = .all) -> String {
        let totalRowCount = comparison.rows.count
        let comparison = scope.select(comparison)
        var report: [JSONKey: JSONValue] = [
            "schemaVersion": .number(integer(1)),
            "application": .string("SidecarCompare"),
            "applicationVersion": .string(appVersion),
            "catalogRevision": .string(FieldCatalog.revision),
            "scope": .string(scopeNote),
            "detail": .string(detail.rawValue),
            "relativeTolerance": .number(comparison.policy.relativeTolerance),
            "toleranceRule": .string(toleranceRule),
            "units": .string("Canonical sidecar units; display-unit choices do not change this report"),
            "rowCount": .number(integer(comparison.rows.count)),
            "differenceCount": .number(integer(comparison.differenceCount)),
            "counts": .object(Dictionary(uniqueKeysWithValues: DifferenceStatus.allCases.map { (JSONKey($0.rawValue), .number(integer(comparison.counts[$0] ?? 0))) }))
        ]
        if let selection = scope.selectionNote { report["selection"] = .string(selection) }
        if scope.isVisible { report["totalRowCount"] = .number(integer(totalRowCount)) }
        if detail == .full {
            report["privacyWarning"] = .string(privacyNote)
            report["rows"] = .array(comparison.rows.map { row in
                var value: [JSONKey: JSONValue] = [
                    "path": .string(row.path), "status": .string(row.status.rawValue),
                    "category": .string(row.category.rawValue), "a": presence(row.a), "b": presence(row.b),
                    "notes": .array(row.notes.map(JSONValue.string))
                ]
                if let unit = row.unit { value["unit"] = .string(unit) }
                if let delta = row.delta { value["deltaBMinusA"] = .number(delta) }
                return .object(value)
            })
        }
        return JSONValue.object(report).serialized() + "\n"
    }

    public static func text(_ comparison: Comparison, detail: ReportDetail, scope: ReportScope = .all) -> String {
        let totalRowCount = comparison.rows.count
        let comparison = scope.select(comparison)
        var lines = ["SidecarCompare \(appVersion)", "Report schema: 1; Catalog revision: \(FieldCatalog.revision)", scopeNote,
                     comparison.policy.label, "Relative tolerance fraction: \(comparison.policy.relativeTolerance.token)", toleranceRule,
                     "Rows: \(comparison.rows.count); differences: \(comparison.differenceCount)",
                     "Within-tolerance changes remain differences, not exact equality."]
        if let selection = scope.selectionNote { lines.append("Selection: " + selection) }
        if scope.isVisible { lines.append("Total comparison rows: \(totalRowCount)") }
        for status in DifferenceStatus.allCases { lines.append("\(status.rawValue): \(comparison.counts[status] ?? 0)") }
        if detail == .full {
            lines.append(privacyNote)
            for row in comparison.rows {
                lines += ["", "\(row.visiblePath) — \(row.status.rawValue)",
                          "A (\(row.a?.typeName ?? "missing")): \(row.a?.serialized() ?? "<missing>")",
                          "B (\(row.b?.typeName ?? "missing")): \(row.b?.serialized() ?? "<missing>")"]
                if let unit = row.unit { lines.append("Canonical unit: \(unit)") }
                if let delta = row.delta { lines.append("Delta B−A: \(delta.canonicalString)") }
                lines += row.notes
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func presence(_ value: JSONValue?) -> JSONValue {
        guard let value else { return .object(["present": .bool(false), "type": .string("missing")]) }
        return .object(["present": .bool(true), "type": .string(value.typeName), "value": value])
    }
    private static func integer(_ value: Int) -> DecimalNumber { try! DecimalNumber(token: String(value)) }
}
