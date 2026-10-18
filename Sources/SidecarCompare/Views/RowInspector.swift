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
    let tableSearchQuery: String?
    let milliseconds: Bool
    let position: String
    let canPrevious: Bool
    let canNext: Bool
    let previous: () -> Void
    let next: () -> Void
    let canShowInTable: Bool
    let showInTable: () -> Void
    let isPinned: Bool
    let canPin: Bool
    let togglePin: () -> Void
    let copyMatchContext: (String) -> Void
    let canCopy: Bool
    let copyMessage: String?
    let copy: (ComparisonRow, RowCopyTarget) -> Void
    @Bindable var review: InspectorReviewState
    @State private var textChangeLocations: StringDifferenceLocations?
    @State private var textSummaryRequest = UUID()
    @State private var tableMatchLocations: TableMatchLocations?
    @State private var tableMatchFailed = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let row {
                    Text(verbatim: row.visiblePath)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(2).truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(row.visiblePath)
                    Label(row.status.rawValue, systemImage: row.status.symbol)
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No field selected").font(.callout).foregroundStyle(.secondary)
                }
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
                    Button(isPinned ? "Unpin Field" : "Pin Field", action: togglePin)
                        .controlSize(.small).disabled(!canPin)
                    HStack(spacing: 8) {
                        Menu("Copy") { RowCopyMenu(row: row, enabled: canCopy, copy: copy, includeDifferenceSummary: true) }
                            .disabled(!canCopy)
                        if let identity = textChangeIdentity {
                            Menu("Text Change") {
                                Button("Show A Change") { revealTextChange(side: "A", identity: identity) }
                                    .disabled(textChangeLocations?.identity != identity)
                                Button("Show B Change") { revealTextChange(side: "B", identity: identity) }
                                    .disabled(textChangeLocations?.identity != identity)
                                Divider()
                                Button("Return to Text Summary") { textSummaryRequest = UUID() }
                            }.disabled(!canShowInTable)
                        }
                    }
                    if let identity = tableMatchIdentity {
                        Menu("Show Table Match") {
                            Button("Show A Match") { revealTableMatch(side: "A", identity: identity) }
                                .disabled(tableMatchLocations?.identity != identity || tableMatchLocations?.a == nil)
                            Button("Show B Match") { revealTableMatch(side: "B", identity: identity) }
                                .disabled(tableMatchLocations?.identity != identity || tableMatchLocations?.b == nil)
                            Text("Choose the first match on either side; inspector Find stays unchanged.")
                        }.controlSize(.small).disabled(!canShowInTable)
                        if let locations = tableMatchLocations, locations.identity == identity {
                            let index = review.tableMatchIndex(identity: identity)
                            HStack(spacing: 8) {
                                Button("Previous Table Match") { review.moveTableMatch(locations, offset: -1) }
                                    .disabled(!canShowInTable || locations.total == 0 || index == 0)
                                Button("Next Table Match") { review.moveTableMatch(locations, offset: 1) }
                                    .disabled(!canShowInTable || locations.total == 0 || index == locations.total - 1)
                            }.controlSize(.small)
                            Button("Copy Table Match Context") {
                                guard canCopy, tableMatchIdentity == identity,
                                      let text = review.tableMatchContext(row: row, locations: locations) else { return }
                                copyMatchContext(text)
                            }.controlSize(.small)
                                .disabled(!canCopy || !canShowInTable || review.tableMatchContext(row: row, locations: locations) == nil)
                            Text(index.map { "Table match \($0 + 1) of \(locations.total) · \($0 < locations.countA ? "A" : "B") · A: \(locations.countA) · B: \(locations.countB)" }
                                 ?? "Table matches · A: \(locations.countA) · B: \(locations.countB)")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if tableMatchFailed {
                            Text("Table match unavailable. Change the table query to try again.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(copyMessage ?? "Value copy includes complete original JSON, which may identify people.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button(review.collapsedA ? "A · Expand section" : "A · Collapse section") { review.collapsedA.toggle() }
                        Button(review.collapsedB ? "B · Expand section" : "B · Collapse section") { review.collapsedB.toggle() }
                    }.controlSize(.small)
                    HStack(spacing: 8) {
                        if (row.a?.serialized().count ?? 0) > 512 {
                            Button(review.expandedA ? "A · Show less" : "A · Show more") { review.expandedA.toggle() }
                        }
                        if (row.b?.serialized().count ?? 0) > 512 {
                            Button(review.expandedB ? "B · Show less" : "B · Show more") { review.expandedB.toggle() }
                        }
                    }.controlSize(.small)
                    InspectorValueSearch(row: row, revision: revision, canReveal: canShowInTable, canCopy: canCopy, copyContext: copyMatchContext, review: review)
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
                    if row.status != .equal, case .string(let a) = row.a, case .string(let b) = row.b {
                        StringDifferenceSection(a: a, b: b, identity: StringDifferenceIdentity(rowID: row.id, revision: revision), collapsed: $review.collapsedTextSummary, canReveal: canShowInTable, reveal: { side, excerpt in
                            guard canShowInTable else { return }
                            review.showChangedSpan(rowID: row.id, revision: revision, side: side, excerpt: excerpt)
                        }, prepared: { textChangeLocations = $0 })
                        .id(row.id + ":text-summary")
                    }
                    InspectorValueCard(title: "A · Reference", value: row.a, expanded: review.expandedA, collapsed: review.collapsedA, match: review.revealedValueMatch(rowID: row.id, revision: revision, side: "A"), change: review.changedSpan(rowID: row.id, revision: revision, side: "A"), tableMatch: review.tableMatch(identity: tableMatchIdentity, side: "A")).id(row.id + ":A")
                    InspectorValueCard(title: "B · Comparison", value: row.b, expanded: review.expandedB, collapsed: review.collapsedB, match: review.revealedValueMatch(rowID: row.id, revision: revision, side: "B"), change: review.changedSpan(rowID: row.id, revision: revision, side: "B"), tableMatch: review.tableMatch(identity: tableMatchIdentity, side: "B")).id(row.id + ":B")
                    if let delta = row.delta {
                        DisclosureGroup(isExpanded: Binding(get: { !review.collapsedNumericSummary }, set: { review.collapsedNumericSummary = !$0 })) {
                        VStack(alignment: .leading, spacing: 5) {
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
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Numeric difference").font(.headline)
                                if review.collapsedNumericSummary {
                                    Text("|B − A|: " + delta.magnitude.scaled(byPowerOfTen: row.unit == "s" && milliseconds ? 3 : 0).canonicalString
                                         + (row.unit.map { " " + ($0 == "s" && milliseconds ? "ms" : $0) } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
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
        .onChange(of: review.valueRevealRequest) { _, _ in
            if let row, let side = review.revealedValueSide(rowID: row.id, revision: revision) {
                proxy.scrollTo(row.id + ":" + side, anchor: .top)
            }
        }
        .onChange(of: textSummaryRequest) { _, _ in
            if let identity = textChangeIdentity {
                proxy.scrollTo(identity.rowID + ":text-summary", anchor: .top)
            }
        }
        .onChange(of: row?.id) { _, _ in
            proxy.scrollTo("inspector-top", anchor: .top)
        }
        }
        }
        .task(id: tableMatchIdentity) {
            guard !Task.isCancelled else { return }
            let identity = tableMatchIdentity
            review.invalidateTableMatch(expecting: identity)
            tableMatchLocations = nil; tableMatchFailed = false
            guard let identity, let row else { return }
            let worker = Task.detached(priority: .userInitiated) { try TableMatchLocations.prepare(row: row, identity: identity) }
            do {
                let locations = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard !Task.isCancelled else { return }
                tableMatchLocations = locations
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; tableMatchFailed = true }
        }
    }
    private var tableMatchIdentity: TableMatchIdentity? {
        guard let row, let tableSearchQuery, !tableSearchQuery.isEmpty else { return nil }
        return TableMatchIdentity(rowID: row.id, revision: revision, query: Data(tableSearchQuery.utf8))
    }
    private func revealTableMatch(side: String, identity: TableMatchIdentity) {
        guard canShowInTable, tableMatchIdentity == identity,
              let locations = tableMatchLocations, locations.identity == identity else { return }
        review.showTableMatch(locations, side: side)
    }
    private var textChangeIdentity: StringDifferenceIdentity? {
        guard let row, row.status != .equal, case .string = row.a, case .string = row.b else { return nil }
        return StringDifferenceIdentity(rowID: row.id, revision: revision)
    }
    private func revealTextChange(side: String, identity: StringDifferenceIdentity) {
        guard canShowInTable, identity == textChangeIdentity,
              let locations = textChangeLocations, locations.identity == identity else { return }
        review.showChangedSpan(rowID: identity.rowID, revision: identity.revision, side: side,
                               excerpt: side == "A" ? locations.a : locations.b)
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
    let collapsed: Bool
    let match: JSONSearchExcerpt?
    let change: ChangedSpanExcerpt?
    let tableMatch: JSONSearchExcerpt?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Text(value?.typeName ?? "missing")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Text(value?.inspectorSummary ?? "Field absent")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if collapsed {
                Text("Section collapsed").font(.caption).foregroundStyle(.secondary)
            } else {
                let raw = value?.serialized() ?? "<missing>"
                let limit = expanded ? 8192 : 512
                let shown = String(raw.prefix(limit))
                Divider()
                if value == nil {
                    Text("Field absent from this sidecar.").font(.callout).foregroundStyle(.secondary)
                } else {
                    if let tableMatch {
                        Text("Table search match · raw JSON byte \(tableMatch.bytePosition)")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        (Text(verbatim: tableMatch.before) + Text(verbatim: tableMatch.match).bold().underline()
                         + Text(verbatim: (tableMatch.matchTruncated ? "…" : "") + tableMatch.after))
                            .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Table-query occurrence · bounded raw JSON excerpt; inspector Find is unchanged.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                    } else if let change {
                        Text("Changed span · raw JSON byte \(change.bytePosition)")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                        Text("\(change.scalarCount) differing Unicode scalars" + (change.scalarCount == 0 ? " · Empty span / insertion or deletion boundary" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        (Text(verbatim: change.before)
                         + Text(verbatim: change.scalarCount == 0 ? "[empty span]" : change.changed).bold().underline()
                         + Text(verbatim: (change.truncated ? "…" : "") + change.after))
                            .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(change.truncated ? "Bounded raw JSON excerpt; differing span truncated after 80 Unicode scalars." : "Bounded raw JSON excerpt; underlined text is the differing span.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                    } else if let match {
                        Text("Value around current match · byte \(match.bytePosition)")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        (Text(verbatim: match.before) + Text(verbatim: match.match).bold().underline()
                         + Text(verbatim: (match.matchTruncated ? "…" : "") + match.after))
                            .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(match.matchTruncated ? "Bounded raw JSON excerpt; long match truncated." : "Bounded raw JSON excerpt; underlined text is the match.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                    }
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
