import SwiftUI
import SidecarCore

@MainActor
struct RowInspector: View {
    let row: ComparisonRow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let row {
                    Text("Field details").font(.title3.weight(.semibold))
                    Text(row.visiblePath).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Label(row.status.rawValue, systemImage: row.status.symbol)
                    Text(row.category.rawValue).font(.caption).foregroundStyle(.secondary)
                    Divider()
                    valueBlock("A · Reference", row.a)
                    valueBlock("B · Comparison", row.b)
                    if let delta = row.delta {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Exact raw delta · B − A").font(.headline)
                            Text(delta.canonicalString).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Text(row.unit.map { "Canonical unit: \($0)" } ?? "Unit unspecified; no physical interpretation inferred.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    Text("Interpretation").font(.headline)
                    if row.notes.isEmpty {
                        Text("Raw JSON comparison. Unrecognized fields and counters use exact comparison, without inferred units.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(Array(row.notes.enumerated()), id: \.offset) { _, note in
                        Text(note).font(.callout).foregroundStyle(.secondary)
                    }
                    if row.status == .withinTolerance {
                        Text("The values differ. They satisfy the selected numeric rule; this is not evidence of scan equivalence.")
                            .font(.callout)
                    }
                    Text("Raw JSON is shown above even when the table displays milliseconds. Values are not de-identified.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Select a row", systemImage: "sidebar.right", description: Text("Inspect raw values, types, units, and the exact numeric delta."))
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
        .inspectorColumnWidth(min: 270, ideal: 315, max: 500)
    }
    private func valueBlock(_ title: String, _ value: JSONValue?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title + " · " + (value?.typeName ?? "missing")).font(.headline)
            let raw = value?.serialized() ?? "<missing>"
            Text(String(raw.prefix(8192))).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if raw.count > 8192 {
                Text("Preview truncated at 8,192 characters. Detailed export retains the complete value.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
