import Foundation
import SwiftUI
import SidecarCore

@MainActor
struct GoToPointerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pointer = ""
    let rows: [ComparisonRow]
    let visibleIDs: Set<String>
    let go: (ComparisonRow, Bool) -> Void

    private var match: ComparisonRow? {
        let bytes = Data(pointer.utf8)
        return rows.first { Data($0.path.utf8) == bytes }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Go to JSON Pointer").font(.headline)
            Text("Enter the exact RFC 6901 pointer. Use ~1 for / and ~0 for ~ within a key. Text is case-sensitive and is not trimmed.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("JSON Pointer", text: $pointer)
                .textFieldStyle(.roundedBorder)
                .onSubmit { navigate() }
            if let match {
                Text(visibleIDs.contains(match.id)
                     ? "Field is visible in the current view."
                     : "Field hidden by current filters. Clear filters to reveal it; sort order and display settings stay unchanged.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(pointer.isEmpty ? "Enter a pointer to a field listed in this comparison."
                     : "Field not present in this comparison.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(match.map { visibleIDs.contains($0.id) } == false ? "Clear Filters and Go" : "Go", action: navigate)
                    .keyboardShortcut(.defaultAction).disabled(match == nil)
            }
        }.padding(20).frame(width: 460)
    }
    private func navigate() {
        guard let match else { return }
        go(match, !visibleIDs.contains(match.id))
    }
}
