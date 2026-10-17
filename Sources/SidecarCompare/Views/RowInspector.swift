import SwiftUI
import SidecarCore

@MainActor
struct RowInspector: View {
    let canBack: Bool
    let canForward: Bool
    let back: () -> Void
    let forward: () -> Void
    let canResetWidth: Bool
    let resetWidth: () -> Void
    let row: ComparisonRow?
    let revision: [UUID?]
    let milliseconds: Bool
    let position: String
    let canPrevious: Bool
    let canNext: Bool
    let previous: () -> Void
    let next: () -> Void
    let canShowInTable: Bool
    let showInTable: () -> Void
    let copyMatchContext: (String) -> Void
    let canCopy: Bool
    let copyMessage: String?
    let copy: (ComparisonRow, RowCopyTarget) -> Void
    @Bindable var review: InspectorReviewState

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button("Back", action: back).disabled(!canBack)
                    Button("Forward", action: forward).disabled(!canForward)
                    Text("Review history").font(.caption).foregroundStyle(.secondary)
                }.controlSize(.small)
                Button("Reset Inspector Width", action: resetWidth)
                    .controlSize(.small).disabled(!canResetWidth)
                Text("Drag the left divider to resize.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        navigationButtons
                        Text(position).font(.caption).foregroundStyle(.secondary).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        navigationButtons
                        Text(position).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button("Show in Table", action: showInTable)
                    .controlSize(.small).disabled(!canShowInTable)
                if let row {
                    Menu("Copy") { RowCopyMenu(row: row, enabled: canCopy, copy: copy) }
                        .disabled(!canCopy)
                    Text(copyMessage ?? "Value copy includes complete original JSON, which may identify people.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if (row.a?.serialized().count ?? 0) > 512 {
                            Button(review.expandedA ? "A · Show less" : "A · Show more") { review.expandedA.toggle() }
                        }
                        if (row.b?.serialized().count ?? 0) > 512 {
                            Button(review.expandedB ? "B · Show less" : "B · Show more") { review.expandedB.toggle() }
                        }
                    }.controlSize(.small)
                    InspectorValueSearch(row: row, revision: revision, canCopy: canCopy, copyContext: copyMatchContext, review: review)
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
                    InspectorValueCard(title: "A · Reference", value: row.a, expanded: review.expandedA).id(row.id + ":A")
                    InspectorValueCard(title: "B · Comparison", value: row.b, expanded: review.expandedB).id(row.id + ":B")
                    if let delta = row.delta {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Numeric difference").font(.headline)
                            Text("Absolute delta · |B − A|").font(.subheadline)
                            Text(delta.magnitude.scaled(byPowerOfTen: row.unit == "s" && milliseconds ? 3 : 0).canonicalString
                                 + (row.unit.map { " " + ($0 == "s" && milliseconds ? "ms" : $0) } ?? ""))
                                .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            if case .number(let a) = row.a, case .number(let b) = row.b {
                                RelativeChangeSummary(a: a, b: b)
                                Text("(B − A) / |A| × 100%; rounded to 6 decimal places, ties away from zero. Tolerance classification uses max(|A|, |B|) instead.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("Exact raw delta · B − A").font(.subheadline)
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
            review.resetField()
            proxy.scrollTo("inspector-top", anchor: .top)
        }
        }
        }
    }
    private var navigationButtons: some View {
        HStack {
            Button(action: previous) { Label("Previous", systemImage: "chevron.up") }
                .disabled(!canPrevious)
            Button(action: next) { Label("Next", systemImage: "chevron.down") }
                .disabled(!canNext)
        }
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

@MainActor
private struct RelativeChangeSummary: View {
    let a: DecimalNumber
    let b: DecimalNumber
    @State private var text = "Calculating relative change…"
    var body: some View {
        Text(text).font(.callout).textSelection(.enabled)
            .task(id: [a.token, b.token]) {
                text = "Calculating relative change…"
                let a = a, b = b
                let result = await Task.detached(priority: .userInitiated) {
                    b.relativeChangePercentage(from: a)
                }.value
                guard !Task.isCancelled else { return }
                text = result.map { "Relative change from A: " + $0 + "%" }
                    ?? "Relative change unavailable: A is zero."
            }
    }
}
