import SwiftUI
import SidecarCore

enum RowCopyTarget: Sendable { case pointer, a, b, comparison, differenceSummary }

@MainActor
struct RowCopyMenu: View {
    let row: ComparisonRow
    let enabled: Bool
    let copy: (ComparisonRow, RowCopyTarget) -> Void

    var includeDifferenceSummary = false

    var body: some View {
        Button("Copy JSON Pointer") { copy(row, .pointer) }.disabled(!enabled)
        Button("Copy Field Comparison · Original JSON") { copy(row, .comparison) }.disabled(!enabled)
        if includeDifferenceSummary {
            Button("Copy Difference Summary") { copy(row, .differenceSummary) }.disabled(!enabled)
        }
        Divider()
        Button("Copy A Value · Original JSON") { copy(row, .a) }.disabled(!enabled || row.a == nil)
        Button("Copy B Value · Original JSON") { copy(row, .b) }.disabled(!enabled || row.b == nil)
    }
}
