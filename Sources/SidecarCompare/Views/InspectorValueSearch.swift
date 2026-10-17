import Foundation
import SwiftUI
import SidecarCore

@MainActor
struct InspectorValueSearch: View {
    let row: ComparisonRow
    let revision: [UUID?]
    @State private var query = ""
    @State private var outcome: SearchOutcome?
    @State private var failed: SearchIdentity?
    @State private var currentMatch = 0

    private var identity: SearchIdentity {
        SearchIdentity(rowID: row.id, revision: revision, queryBytes: Data(query.utf8))
    }
    private var currentOutcome: SearchOutcome? { outcome?.identity == identity ? outcome : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TextField("Find in values…", text: $query)
                    .textFieldStyle(.roundedBorder)
                if !query.isEmpty {
                    Button("Clear Find") { query = "" }.controlSize(.small)
                }
            }
            Text("Literal, case-sensitive · complete raw A/B JSON")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !query.isEmpty {
                if let result = currentOutcome {
                    Text("A: \(result.a.count) matches · B: \(result.b.count) matches")
                        .font(.caption).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(failed == identity ? "Value search could not be completed. Edit or clear Find to retry." : "Searching complete A/B values…")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { matchButtons }
                    VStack(alignment: .leading, spacing: 6) { matchButtons }
                }.controlSize(.small)
                if let result = currentOutcome {
                    if result.total == 0 {
                        Text("No matches in either complete value.").font(.caption).foregroundStyle(.secondary)
                    } else if let match = result.excerpt(at: currentMatch) {
                        Text("Match \(currentMatch + 1) of \(result.total) · \(match.side) · byte \(match.excerpt.bytePosition)")
                            .font(.caption).monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        (Text(verbatim: match.excerpt.before) + Text(verbatim: match.excerpt.match).bold().underline()
                         + Text(verbatim: (match.excerpt.matchTruncated ? "…" : "") + match.excerpt.after))
                            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(match.excerpt.matchTruncated
                             ? "Bounded excerpt; this long match is truncated. Complete value searched."
                             : "Bounded excerpt; underlined text is the match. Complete value searched.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .task(id: identity) { await search() }
    }

    @ViewBuilder private var matchButtons: some View {
        Button("Previous Match") { currentMatch -= 1 }
            .disabled(currentOutcome == nil || currentMatch <= 0)
        Button("Next Match") { currentMatch += 1 }
            .disabled(currentOutcome == nil || currentMatch + 1 >= (currentOutcome?.total ?? 0))
    }

    private func search() async {
        let request = identity, query = query, a = row.a, b = row.b
        outcome = nil; failed = nil; currentMatch = 0
        guard !query.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(125))
            let worker = Task.detached(priority: .userInitiated) {
                let left = try JSONValueSearch.find(a, query: query)
                let right = try JSONValueSearch.find(b, query: query)
                return SearchOutcome(identity: request, a: left, b: right)
            }
            let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled, request == identity else { return }
            outcome = result
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, request == identity else { return }
            failed = request
        }
    }
}

private struct SearchIdentity: Hashable, Sendable {
    let rowID: String
    let revision: [UUID?]
    let queryBytes: Data
}
private struct SearchOutcome: Sendable {
    let identity: SearchIdentity
    let a: JSONValueSearch
    let b: JSONValueSearch
    var total: Int { a.count + b.count }
    func excerpt(at index: Int) -> (side: String, excerpt: JSONSearchExcerpt)? {
        if index < a.count { return a.excerpt(at: index).map { ("A", $0) } }
        return b.excerpt(at: index - a.count).map { ("B", $0) }
    }
}
