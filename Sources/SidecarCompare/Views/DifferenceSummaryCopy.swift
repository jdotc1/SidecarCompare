import Foundation
import SidecarCore

enum DifferenceSummaryCopy {
    static let byteLimit = 64 * 1024

    static func text(row: ComparisonRow, policy: ComparisonPolicy, limit: Int = byteLimit) throws -> String {
        try Task.checkCancellation()
        var lines = ["Difference summary · not a complete field comparison",
                     "May contain identifying metadata; not de-identified.",
                     "JSON Pointer (JSON string): " + JSONValue.quote(row.path),
                     "Status: " + row.status.rawValue, "Rule: " + policy.label,
                     "A type: " + type(row.a), "B type: " + type(row.b)]
        if case .number(let a) = row.a, case .number(let b) = row.b {
            let delta = b.subtracting(a)
            lines += ["", "A · Original JSON number: " + a.token,
                      "B · Original JSON number: " + b.token,
                      "Exact raw delta · B − A: " + delta.canonicalString,
                      "Absolute delta: " + delta.magnitude.canonicalString,
                      row.unit.map { "Canonical unit: " + $0 } ?? "Unit unspecified.",
                      b.relativeChangePercentage(from: a).map { "Relative change from A: " + $0 + "%" }
                        ?? "Relative change unavailable: A is zero.",
                      "(B − A) / |A| × 100%; rounded to 6 decimal places, ties away from zero. Tolerance classification uses max(|A|, |B|) instead."]
        } else if case .string(let a) = row.a, case .string(let b) = row.b {
            if let summary = try StringDifferenceSummary.compare(a: a, b: b) {
                lines += ["", summary.kind,
                          "Shared prefix: \(summary.sharedPrefixScalars) Unicode scalars; shared suffix: \(summary.sharedSuffixScalars) Unicode scalars.",
                          "One differing span, not a minimal edit-by-edit diff.",
                          "Bounded escaped decoded-text excerpts, not complete original JSON values."]
                for (side, excerpt) in [("A", summary.a), ("B", summary.b)] {
                    lines += ["", "\(side) · \(excerpt.changedScalarCount) differing Unicode scalars" + (excerpt.valueIsEmpty ? " · empty string" : ""),
                              "Before: " + excerpt.before,
                              "Changed: " + (excerpt.changedScalarCount == 0 ? "[empty span]" : excerpt.changed) + (excerpt.truncated ? "… [span truncated]" : ""),
                              "After: " + excerpt.after]
                }
            } else { lines += ["", "Identical Unicode scalar sequences."] }
        } else {
            lines += ["", "No numeric or text difference summary applies. Use Copy Field Comparison for complete original values."]
        }
        let text = lines.joined(separator: "\n")
        guard text.utf8.count <= limit else {
            throw SidecarError("Difference summary exceeds the 64 KiB clipboard limit. Clipboard unchanged.")
        }
        return text
    }

    private static func type(_ value: JSONValue?) -> String {
        guard let value else { return "missing — field absent" }
        switch value {
        case .null: return "null"
        case .bool: return "boolean"
        case .number: return "number"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        }
    }
}
