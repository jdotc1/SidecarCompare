import SwiftUI
import SidecarCore

@MainActor
struct ComparisonTable: View {
    let rows: [ComparisonRow]
    let pinnedIDs: Set<String>
    let canPin: Bool
    let togglePin: (ComparisonRow) -> Void
    let revealRequest: UUID
    let milliseconds: Bool
    let canCopy: Bool
    let copy: (ComparisonRow, RowCopyTarget) -> Void
    @Binding var selection: String?

    @Binding var sortOrder: [KeyPathComparator<ComparisonRow>]

    var body: some View {
        ScrollViewReader { proxy in
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Status", value: \.statusSortKey) { row in
                Label(row.status.rawValue, systemImage: row.status.symbol)
                    .font(.callout)
                    .foregroundStyle(row.status == .equal ? Color.secondary : Color.primary)
            }.width(min: 118, ideal: 145, max: 185)
            TableColumn("JSON Pointer", value: \.path) { row in
                Text(row.visiblePath).font(.system(.body, design: .monospaced)).lineLimit(1)
                    .help(row.visiblePath)
            }.width(min: 140, ideal: 250, max: 600)
            TableColumn("A · Reference", value: \.aSortKey) { row in
                Text(row.displayValue(side: .a, milliseconds: milliseconds))
                    .font(.system(.body, design: .monospaced)).lineLimit(1)
            }.width(min: 100, ideal: 180, max: 700)
            TableColumn("B · Comparison", value: \.bSortKey) { row in
                Text(row.displayValue(side: .b, milliseconds: milliseconds))
                    .font(.system(.body, design: .monospaced)).lineLimit(1)
            }.width(min: 100, ideal: 180, max: 700)
            TableColumn("Display unit", value: \.unitSortKey) { row in
                Text(row.unit == "s" && milliseconds ? "ms" : row.unit ?? "—")
                    .foregroundStyle(.secondary)
            }.width(min: 65, ideal: 85, max: 110)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if ids.count == 1, let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                Button(pinnedIDs.contains(row.id) ? "Unpin Field" : "Pin Field") { togglePin(row) }
                    .disabled(!canPin)
                Divider()
                RowCopyMenu(row: row, enabled: canCopy, copy: copy)
            }
        }
        .accessibilityLabel("Sidecar metadata comparison")
        .onChange(of: revealRequest) { _, _ in
            if let selection, rows.contains(where: { $0.id == selection }) {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
        .onChange(of: selection) { _, selection in
            if let selection { proxy.scrollTo(selection) }
        }
        }
    }
}

// Exact numeric ordering is independent of display units and comparison tolerance.
extension ComparisonRow {
    var statusSortKey: String { status.rawValue }
    var aSortKey: JSONSortValue { JSONSortValue(a) }
    var bSortKey: JSONSortValue { JSONSortValue(b) }
    var unitSortKey: String { unit ?? "" }
}
