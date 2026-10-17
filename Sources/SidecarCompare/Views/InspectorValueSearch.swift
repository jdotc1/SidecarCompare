import Foundation
import SwiftUI
import Observation
import SidecarCore

@MainActor
struct InspectorValueSearch: View {
    let row: ComparisonRow
    let revision: [UUID?]
    let canCopy: Bool
    let copyContext: (String) -> Void
    @Bindable var review: InspectorReviewState

    private var identity: SearchIdentity {
        SearchIdentity(rowID: row.id, revision: revision, queryBytes: Data(review.query.utf8))
    }
    private var currentOutcome: SearchOutcome? { review.outcome?.identity == identity ? review.outcome : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(review.showFind ? "Hide Find" : "Show Find") { review.showFind.toggle() }
                .controlSize(.small)
            if review.showFind {
            HStack(spacing: 6) {
                TextField("Find in values…", text: $review.query)
                    .textFieldStyle(.roundedBorder)
                if !review.query.isEmpty {
                    Button("Clear Find") { review.query = "" }.controlSize(.small)
                }
            }
            Text("Literal, case-sensitive · complete raw A/B JSON")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !review.query.isEmpty {
                if let result = currentOutcome {
                    Text("A: \(result.a.count) matches · B: \(result.b.count) matches")
                        .font(.caption).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(review.failed == identity ? "Value search could not be completed. Edit or clear Find to retry." : "Searching complete A/B values…")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { matchButtons }
                    VStack(alignment: .leading, spacing: 6) { matchButtons }
                }.controlSize(.small)
                Button("Copy Match Context", action: copyMatchContext)
                    .controlSize(.small)
                    .disabled(!canCopy || currentOutcome?.excerpt(at: review.currentMatch) == nil)
                if let result = currentOutcome {
                    if result.total == 0 {
                        Text("No matches in either complete value.").font(.caption).foregroundStyle(.secondary)
                    } else if let match = result.excerpt(at: review.currentMatch) {
                        Text("Match \(review.currentMatch + 1) of \(result.total) · \(match.side) · byte \(match.excerpt.bytePosition)")
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
            } else {
                Text(collapsedSummary).font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit().fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: Data(review.query.utf8)) { _, _ in review.pendingMatch = nil }
        .task(id: identity) { await search() }
    }

    private var collapsedSummary: String {
        guard !review.query.isEmpty else { return "Find: No query" }
        guard let result = currentOutcome else {
            return review.failed == identity ? "Find: Search unavailable" : "Find: Searching…"
        }
        guard result.total > 0, let match = result.excerpt(at: review.currentMatch) else { return "Find: No matches" }
        return "Find: Match \(review.currentMatch + 1) of \(result.total) · \(match.side)"
    }

    @ViewBuilder private var matchButtons: some View {
        Button("Previous Match") { review.currentMatch -= 1 }
            .disabled(currentOutcome == nil || review.currentMatch <= 0)
        Button("Next Match") { review.currentMatch += 1 }
            .disabled(currentOutcome == nil || review.currentMatch + 1 >= (currentOutcome?.total ?? 0))
    }

    private func copyMatchContext() {
        guard canCopy, let match = currentOutcome?.excerpt(at: review.currentMatch) else { return }
        let excerpt = match.excerpt
        let text = "Match context excerpt · \(match.side) · byte \(excerpt.bytePosition)\n"
            + "Bounded raw JSON excerpt; not a complete JSON value."
            + (excerpt.matchTruncated ? " Match text is truncated." : "") + "\n"
            + excerpt.before + excerpt.match + (excerpt.matchTruncated ? "…" : "") + excerpt.after
        copyContext(text)
    }

    private func search() async {
        let request = identity, query = review.query, a = row.a, b = row.b
        guard !Task.isCancelled, review.outcome?.identity != request else { return }
        let restoredMatch = review.pendingMatch?.identity == request ? review.pendingMatch?.index : nil
        review.outcome = nil; review.failed = nil; review.currentMatch = 0
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
            review.outcome = result
            review.currentMatch = min(restoredMatch ?? 0, max(0, result.total - 1))
            if review.pendingMatch?.identity == request { review.pendingMatch = nil }
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, request == identity else { return }
            review.failed = request
        }
    }
}

fileprivate struct SearchIdentity: Hashable, Sendable {
    let rowID: String
    let revision: [UUID?]
    let queryBytes: Data
}
fileprivate struct PendingMatch {
    let identity: SearchIdentity
    let index: Int
}
fileprivate struct SearchOutcome: Sendable {
    let identity: SearchIdentity
    let a: JSONValueSearch
    let b: JSONValueSearch
    var total: Int { a.count + b.count }
    func excerpt(at index: Int) -> (side: String, excerpt: JSONSearchExcerpt)? {
        if index < a.count { return a.excerpt(at: index).map { ("A", $0) } }
        return b.excerpt(at: index - a.count).map { ("B", $0) }
    }
}

/// Session-local review state survives presentation changes, never source replacement.
@Observable @MainActor
final class InspectorReviewState {
    var query = ""
    var showFind = true
    var expandedA = false
    var expandedB = false
    var collapsedA = false
    var collapsedB = false
    var currentMatch = 0
    fileprivate var outcome: SearchOutcome?
    fileprivate var failed: SearchIdentity?
    fileprivate var pendingMatch: PendingMatch?

    func bookmark(rowID: String, revision: [UUID?]) -> InspectorReviewBookmark {
        let identity = SearchIdentity(rowID: rowID, revision: revision, queryBytes: Data(query.utf8))
        let match = outcome?.identity == identity ? currentMatch : (pendingMatch?.identity == identity ? pendingMatch?.index ?? 0 : 0)
        return InspectorReviewBookmark(query: Data(query.utf8), revision: revision,
                                       expandedA: expandedA, expandedB: expandedB, collapsedA: collapsedA, collapsedB: collapsedB, match: match)
    }
    func restore(_ bookmark: InspectorReviewBookmark, rowID: String, revision: [UUID?]) {
        guard bookmark.query == Data(query.utf8), bookmark.revision == revision else { return }
        expandedA = bookmark.expandedA; expandedB = bookmark.expandedB
        collapsedA = bookmark.collapsedA; collapsedB = bookmark.collapsedB
        pendingMatch = PendingMatch(identity: SearchIdentity(rowID: rowID, revision: revision, queryBytes: bookmark.query), index: bookmark.match)
    }
    func resetField() {
        pendingMatch = nil
        expandedA = false; expandedB = false
        collapsedA = false; collapsedB = false
        currentMatch = 0; outcome = nil; failed = nil
    }
    func resetAll() {
        showFind = true
        query = ""
        resetField()
    }
}
