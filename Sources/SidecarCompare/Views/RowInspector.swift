import SwiftUI
import SidecarCore

@MainActor
struct RowInspector: View {
    let row: ComparisonRow?
    let canPrevious: Bool
    let canNext: Bool
    let previous: () -> Void
    let next: () -> Void
    let canCopy: Bool
    let copyMessage: String?
    let copy: (ComparisonRow, RowCopyTarget) -> Void
    @State private var expandedA = false
    @State private var expandedB = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: previous) { Label("Previous", systemImage: "chevron.up") }
                        .disabled(!canPrevious)
                    Button(action: next) { Label("Next", systemImage: "chevron.down") }
                        .disabled(!canNext)
                    Spacer(minLength: 0)
                }
                if let row {
                    Menu("Copy") { RowCopyMenu(row: row, enabled: canCopy, copy: copy) }
                        .disabled(!canCopy)
                    Text(copyMessage ?? "Value copy includes complete original JSON, which may identify people.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if (row.a?.serialized().count ?? 0) > 512 {
                            Button(expandedA ? "A · Show less" : "A · Show more") { expandedA.toggle() }
                        }
                        if (row.b?.serialized().count ?? 0) > 512 {
                            Button(expandedB ? "B · Show less" : "B · Show more") { expandedB.toggle() }
                        }
                    }.controlSize(.small)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            Divider()
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let row {
                    Text("Field details").font(.title3.weight(.semibold))
                    Text(row.visiblePath).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(row.status.rawValue, systemImage: row.status.symbol)
                    Text(row.category.rawValue).font(.caption).foregroundStyle(.secondary)
                    if row.status == .typeChanged {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Type change · A → B").font(.headline)
                            Text("\(row.a?.typeName ?? "missing") → \(row.b?.typeName ?? "missing")")
                                .font(.system(.body, design: .monospaced))
                            Text("Compare the raw values below; types are preserved without conversion.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    InspectorValueCard(title: "A · Reference", value: row.a, expanded: expandedA).id(row.id + ":A")
                    InspectorValueCard(title: "B · Comparison", value: row.b, expanded: expandedB).id(row.id + ":B")
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
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).id("inspector-top")
        }
        .onChange(of: row?.id) { _, _ in
            expandedA = false; expandedB = false
            proxy.scrollTo("inspector-top", anchor: .top)
        }
        }
        }
        .inspectorColumnWidth(min: 270, ideal: 315, max: 500)
    }
}

@MainActor
private struct InspectorValueCard: View {
    let title: String
    let value: JSONValue?
    let expanded: Bool

    var body: some View {
        let raw = value?.serialized() ?? "<missing>"
        let limit = expanded ? 8192 : 512
        let shown = String(raw.prefix(limit))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Text(value?.typeName ?? "missing")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Divider()
            if value == nil {
                Text("Field absent from this sidecar.").font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Raw JSON").font(.caption).foregroundStyle(.secondary)
                Text(verbatim: shown)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if raw.count > 512 {
                    Text("Showing \(shown.count.formatted()) of \(raw.count.formatted()) characters.")
                        .font(.caption).foregroundStyle(.secondary)
                    if expanded && raw.count > 8192 {
                        Text("Preview limited to 8,192 characters. Detailed export retains the complete value.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.2)))
    }
}
