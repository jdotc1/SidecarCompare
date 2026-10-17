import SidecarCore

/// Plain-text single-field review; value sections contain complete original JSON.
enum FieldComparisonCopy {
    static func text(row: ComparisonRow, policy: ComparisonPolicy) -> String {
        var lines = ["Single-field comparison · original metadata",
                     "Contains original metadata; not de-identified.",
                     "JSON Pointer (JSON string): " + JSONValue.quote(row.path),
                     "Status: " + row.status.rawValue,
                     "Rule: " + policy.label,
                     "", "A · Reference · Original JSON:",
                     row.a?.serialized() ?? "[missing — field absent]",
                     "", "B · Comparison · Original JSON:",
                     row.b?.serialized() ?? "[missing — field absent]"]
        if let delta = row.delta {
            lines += ["", "Exact raw delta · B − A: " + delta.canonicalString,
                      row.unit.map { "Canonical unit: " + $0 } ?? "Unit unspecified."]
        }
        return lines.joined(separator: "\n")
    }
}
