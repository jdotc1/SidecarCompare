import SwiftUI
import SidecarCore

@MainActor
struct GoToPinnedFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection: String?
    let rows: [ComparisonRow]
    let visibleIDs: Set<String>
    let go: (ComparisonRow, Bool) -> Void

    private var matches: [ComparisonRow] {
        rows.filter { query.isEmpty || $0.visiblePath.localizedCaseInsensitiveContains(query) }
            .sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
    }
    private var selected: ComparisonRow? { matches.first { $0.id == selection } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Pinned Field").font(.headline)
            Text("Search pinned JSON Pointers, including fields hidden by table filters. This search does not change the table search.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Search pinned JSON Pointers", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { navigate() }
            Text("\(matches.count) of \(rows.count) pinned fields")
                .font(.caption).foregroundStyle(.secondary)
            List(matches, selection: $selection) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.visiblePath).font(.system(.body, design: .monospaced))
                        .lineLimit(2).truncationMode(.middle).help(row.visiblePath)
                    Text("\(row.status.rawValue) · \(visibleIDs.contains(row.id) ? "Visible in table" : "Hidden by filters")")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 2)
            }.frame(height: 240)
                .overlay { if matches.isEmpty { Text("No pinned fields match this search.").foregroundStyle(.secondary) } }
            Text(selected.map { visibleIDs.contains($0.id)
                ? "Go selects and reveals this field without changing filters."
                : "Clear filters to reveal this field. Sort order, display settings and Find query stay unchanged."
            } ?? "Select a pinned field to continue.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(selected.map { visibleIDs.contains($0.id) } == false ? "Clear Filters and Go" : "Go", action: navigate)
                    .keyboardShortcut(.defaultAction).disabled(selected == nil)
            }
        }.padding(20).frame(width: 500)
    }
    private func navigate() {
        guard let selected else { return }
        go(selected, !visibleIDs.contains(selected.id))
    }
}
