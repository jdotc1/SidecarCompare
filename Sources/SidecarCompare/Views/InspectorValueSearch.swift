import Foundation
import SwiftUI
import Observation
import SidecarCore

@MainActor
struct InspectorValueSearch: View {
    let row: ComparisonRow
    let revision: [UUID?]
    let canReveal: Bool
    let canCopy: Bool
    let copyContext: (String) -> Void
    @Bindable var review: InspectorReviewState

    private var identity: SearchIdentity {
        SearchIdentity(rowID: row.id, revision: revision, queryBytes: Data(review.query.utf8))
    }
    private var currentOutcome: SearchOutcome? { review.outcome?.identity == identity ? review.outcome : nil }

    private var matchRange: Range<Int> { currentOutcome?.range(for: review.scope) ?? 0..<0 }
    private var currentExcerpt: (side: String, excerpt: JSONSearchExcerpt)? {
        guard matchRange.contains(review.currentMatch) else { return nil }
        return currentOutcome?.excerpt(at: review.currentMatch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button(review.showFind ? "Hide Find" : "Show Find") { review.showFind.toggle() }
                    .controlSize(.small)
                if review.showFind {
                    Picker("Find in", selection: $review.scope) {
                        ForEach(InspectorFindScope.allCases) { scope in Text(scope.rawValue).tag(scope) }
                    }.pickerStyle(.menu).controlSize(.small)
                } else {
                    Text(collapsedSummary).font(.caption).foregroundStyle(.secondary)
                        .monospacedDigit().fixedSize(horizontal: false, vertical: true)
                }
            }
            if review.showFind {
            HStack(spacing: 6) {
                TextField("Find in values…", text: $review.query)
                    .textFieldStyle(.roundedBorder)
                if !review.query.isEmpty {
                    Button("Clear Find") { review.query = "" }.controlSize(.small)
                }
            }
            Toggle("Follow match in value", isOn: $review.followMatch)
                .toggleStyle(.checkbox).controlSize(.small)
                .help("Reveal and scroll to the current occurrence when navigating matches.")
            Text("Literal, case-sensitive · complete raw A/B JSON")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !review.query.isEmpty {
                if let result = currentOutcome {
                    Text("\(matchRange.count) matches in \(review.scope.rawValue) · A: \(result.a.count) · B: \(result.b.count)")
                        .font(.caption).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(review.failed == identity ? "Value search could not be completed. Edit or clear Find to retry." : "Searching complete A/B values…")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        matchButtons
                        matchPosition.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) { matchButtons }
                        matchPosition
                    }
                }.controlSize(.small)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { matchActions }
                    VStack(alignment: .leading, spacing: 6) { matchActions }
                }.controlSize(.small)
                if currentOutcome != nil {
                    if matchRange.isEmpty {
                        Text(review.scope == .both ? "No matches in either complete value." : "No matches in \(review.scope == .a ? "A" : "B").").font(.caption).foregroundStyle(.secondary)
                    } else if let match = currentExcerpt {
                        Text("Raw JSON · byte \(match.excerpt.bytePosition)")
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
        }
        .onChange(of: Data(review.query.utf8)) { _, _ in review.pendingMatch = nil }
        .onChange(of: review.followMatch) { _, _ in
            if canReveal { review.followCurrentMatch(rowID: row.id, revision: revision) }
        }
        .onChange(of: review.scope) { _, _ in
            if canReveal { review.followCurrentMatch(rowID: row.id, revision: revision) }
        }
        .task(id: identity) { await search() }
    }

    private var collapsedSummary: String {
        guard !review.query.isEmpty else { return "\(review.scope.rawValue) · No query" }
        guard currentOutcome != nil else {
            return "\(review.scope.rawValue) · " + (review.failed == identity ? "Search unavailable" : "Searching…")
        }
        guard !matchRange.isEmpty, let match = currentExcerpt else { return "\(review.scope.rawValue) · No matches" }
        return "\(review.scope.rawValue) · \(match.side) · Match \(review.currentMatch - matchRange.lowerBound + 1) of \(matchRange.count)"
    }

    @ViewBuilder private var matchPosition: some View {
        if let match = currentExcerpt {
            Text("\(match.side) · Match \(review.currentMatch - matchRange.lowerBound + 1) of \(matchRange.count)")
                .font(.caption).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var matchActions: some View {
        Button("Show Match in Value") { review.showCurrentMatch(rowID: row.id, revision: revision) }
            .disabled(!canReveal || currentExcerpt == nil)
        Button("Copy Match Context", action: copyMatchContext)
            .disabled(!canCopy || currentExcerpt == nil)
    }

    @ViewBuilder private var matchButtons: some View {
        Button("Previous Match") { review.moveMatch(by: -1, rowID: row.id, revision: revision, canReveal: canReveal) }
            .disabled(currentOutcome == nil || review.currentMatch <= matchRange.lowerBound)
        Button("Next Match") { review.moveMatch(by: 1, rowID: row.id, revision: revision, canReveal: canReveal) }
            .disabled(currentOutcome == nil || review.currentMatch + 1 >= matchRange.upperBound)
    }

    private func copyMatchContext() {
        guard canCopy, let match = currentExcerpt else { return }
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
            review.currentMatch = restoredMatch ?? 0
            review.normalizeMatch()
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
    func range(for scope: InspectorFindScope) -> Range<Int> {
        switch scope {
        case .both: return 0..<total
        case .a: return 0..<a.count
        case .b: return a.count..<total
        }
    }
    func excerpt(at index: Int) -> (side: String, excerpt: JSONSearchExcerpt)? {
        if index < a.count { return a.excerpt(at: index).map { ("A", $0) } }
        return b.excerpt(at: index - a.count).map { ("B", $0) }
    }
}

/// Session-local review state survives presentation changes, never source replacement.
@Observable @MainActor
final class InspectorReviewState {
    var query = "" { didSet { if Data(query.utf8) != Data(oldValue.utf8) { revealedMatch = nil } } }
    var scope: InspectorFindScope = .both { didSet { if scope != oldValue { normalizeMatch() } } }
    var followMatch = false
    var showFind = true
    var expandedA = false
    var expandedB = false
    var collapsedA = false
    var collapsedB = false
    var currentMatch = 0 { didSet { if currentMatch != oldValue { revealedMatch = nil } } }
    var valueRevealRequest = UUID()
    fileprivate var revealedMatch: PendingMatch?
    fileprivate var outcome: SearchOutcome?
    fileprivate var failed: SearchIdentity?
    fileprivate var pendingMatch: PendingMatch?

    func normalizeMatch() {
        guard let outcome, outcome.identity.queryBytes == Data(query.utf8) else { return }
        let range = outcome.range(for: scope)
        if !range.contains(currentMatch) { currentMatch = range.lowerBound }
    }

    func moveMatch(by offset: Int, rowID: String, revision: [UUID?], canReveal: Bool) {
        let identity = SearchIdentity(rowID: rowID, revision: revision, queryBytes: Data(query.utf8))
        guard let outcome, outcome.identity == identity, [-1, 1].contains(offset),
              outcome.range(for: scope).contains(currentMatch + offset) else { return }
        currentMatch += offset
        if canReveal { followCurrentMatch(rowID: rowID, revision: revision) }
    }
    func followCurrentMatch(rowID: String, revision: [UUID?]) {
        guard followMatch else { return }
        showCurrentMatch(rowID: rowID, revision: revision)
    }

    func showCurrentMatch(rowID: String, revision: [UUID?]) {
        let identity = SearchIdentity(rowID: rowID, revision: revision, queryBytes: Data(query.utf8))
        guard outcome?.identity == identity, outcome?.range(for: scope).contains(currentMatch) == true,
              let match = outcome?.excerpt(at: currentMatch) else { return }
        if match.side == "A" { collapsedA = false } else { collapsedB = false }
        revealedMatch = PendingMatch(identity: identity, index: currentMatch)
        valueRevealRequest = UUID()
    }
    func revealedValueMatch(rowID: String, revision: [UUID?], side: String) -> JSONSearchExcerpt? {
        let identity = SearchIdentity(rowID: rowID, revision: revision, queryBytes: Data(query.utf8))
        guard revealedMatch?.identity == identity, revealedMatch?.index == currentMatch,
              outcome?.identity == identity, outcome?.range(for: scope).contains(currentMatch) == true,
              let match = outcome?.excerpt(at: currentMatch), match.side == side else { return nil }
        return match.excerpt
    }
    func revealedValueSide(rowID: String, revision: [UUID?]) -> String? {
        for side in ["A", "B"] where revealedValueMatch(rowID: rowID, revision: revision, side: side) != nil { return side }
        return nil
    }

    func bookmark(rowID: String, revision: [UUID?]) -> InspectorReviewBookmark {
        let identity = SearchIdentity(rowID: rowID, revision: revision, queryBytes: Data(query.utf8))
        let match = outcome?.identity == identity ? currentMatch : (pendingMatch?.identity == identity ? pendingMatch?.index ?? 0 : 0)
        return InspectorReviewBookmark(query: Data(query.utf8), revision: revision,
                                       expandedA: expandedA, expandedB: expandedB, collapsedA: collapsedA, collapsedB: collapsedB, match: match, scope: scope)
    }
    func restore(_ bookmark: InspectorReviewBookmark, rowID: String, revision: [UUID?]) {
        guard bookmark.query == Data(query.utf8), bookmark.revision == revision else { return }
        expandedA = bookmark.expandedA; expandedB = bookmark.expandedB
        collapsedA = bookmark.collapsedA; collapsedB = bookmark.collapsedB
        scope = bookmark.scope
        pendingMatch = PendingMatch(identity: SearchIdentity(rowID: rowID, revision: revision, queryBytes: bookmark.query), index: bookmark.match)
    }
    func resetField() {
        pendingMatch = nil; revealedMatch = nil
        expandedA = false; expandedB = false
        collapsedA = false; collapsedB = false
        currentMatch = 0; outcome = nil; failed = nil
    }
    func resetAll() {
        followMatch = false
        showFind = true
        scope = .both
        query = ""
        resetField()
    }
}
