import SwiftUI
import SidecarCore

@MainActor
struct ComparisonTable: View {
    let rows: [ComparisonRow]
    let milliseconds: Bool
    @Binding var selection: String?

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("Status") { row in
                Label(row.status.rawValue, systemImage: row.status.symbol)
                    .font(.callout)
                    .foregroundStyle(row.status == .equal ? Color.secondary : Color.primary)
            }.width(min: 118, ideal: 145, max: 185)
            TableColumn("JSON Pointer") { row in
                Text(row.visiblePath).font(.system(.body, design: .monospaced)).lineLimit(1)
                    .help(row.visiblePath)
            }.width(min: 140, ideal: 250, max: 600)
            TableColumn("A · Reference") { row in
                Text(row.displayValue(side: .a, milliseconds: milliseconds))
                    .font(.system(.body, design: .monospaced)).lineLimit(1)
            }.width(min: 100, ideal: 180, max: 700)
            TableColumn("B · Comparison") { row in
                Text(row.displayValue(side: .b, milliseconds: milliseconds))
                    .font(.system(.body, design: .monospaced)).lineLimit(1)
            }.width(min: 100, ideal: 180, max: 700)
            TableColumn("Display unit") { row in
                Text(row.unit == "s" && milliseconds ? "ms" : row.unit ?? "—")
                    .foregroundStyle(.secondary)
            }.width(min: 65, ideal: 85, max: 110)
        }
        .accessibilityLabel("Sidecar metadata comparison")
    }
}
