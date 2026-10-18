#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/change-history-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
@main struct Check {
    @MainActor static func main() throws {
        let review = InspectorReviewState(), revisions: [UUID?] = [UUID(), UUID()]
        // Already bounded excerpt fixture: span-location math has its own accepted receipt.
        let a = ChangedSpanExcerpt(before: "…prefix", changed: "OLD", after: "suffix…", bytePosition: 9005, scalarCount: 3, truncated: false)
        let b = ChangedSpanExcerpt(before: "\"", changed: "", after: "\"", bytePosition: 2, scalarCount: 0, truncated: false)
        review.query = "needle"; review.scope = .b; review.followMatch = true; review.showFind = false
        let identity = SearchIdentity(rowID: "long", revision: revisions, queryBytes: Data(review.query.utf8))
        review.outcome = SearchOutcome(identity: identity, a: try JSONValueSearch.find(nil, query: "needle"), b: try JSONValueSearch.find(.string("needle needle"), query: "needle"))
        review.currentMatch = 1
        review.showChangedSpan(rowID: "long", revision: revisions, side: "A", excerpt: a)
        review.expandedA = true; review.collapsedA = true; review.collapsedB = true; review.collapsedTextSummary = true
        var history = InspectorHistory(); history.visit("long")
        history.save(review.bookmark(rowID: "long", revision: revisions), for: "long")
        history.visit("empty"); review.resetField()
        review.showChangedSpan(rowID: "empty", revision: revisions, side: "B", excerpt: b)
        history.save(review.bookmark(rowID: "empty", revision: revisions), for: "empty")
        history.move(to: history.back!); review.resetField()
        let before = review.valueRevealRequest
        review.restore(history.review(for: "long")!, rowID: "long", revision: revisions)
        assert(review.changedSpan(rowID: "long", revision: revisions, side: "A")?.bytePosition == 9005)
        assert(review.valueRevealRequest == before && review.collapsedA && review.collapsedB && review.expandedA && review.collapsedTextSummary)
        assert(review.query == "needle" && review.scope == .b && review.followMatch && !review.showFind)
        assert(review.bookmark(rowID: "long", revision: revisions).match == 1)
        history.move(to: history.forward!); review.resetField()
        review.restore(history.review(for: "empty")!, rowID: "empty", revision: revisions)
        assert(review.changedSpan(rowID: "empty", revision: revisions, side: "B")?.scalarCount == 0)
        review.resetField(); review.query = "new query"
        review.restore(history.review(for: "long")!, rowID: "long", revision: revisions)
        assert(review.query == "new query" && review.currentMatch == 0)
        assert(review.changedSpan(rowID: "long", revision: revisions, side: "A") != nil)
        review.resetField(); review.restore(history.review(for: "long")!, rowID: "long", revision: [UUID(), UUID()])
        assert(review.changedSpan(rowID: "long", revision: revisions, side: "A") == nil)
        review.restore(history.review(for: "long")!, rowID: "other", revision: revisions)
        assert(review.changedSpan(rowID: "other", revision: revisions, side: "A") == nil)
        review.restore(history.review(for: "long")!, rowID: "long", revision: revisions)
        assert(review.bookmark(rowID: "other", revision: revisions).revealedChange == nil)
        review.query = "needle"; review.outcome = SearchOutcome(identity: identity, a: try JSONValueSearch.find(nil, query: "needle"), b: try JSONValueSearch.find(.string("needle needle"), query: "needle"))
        review.currentMatch = 1; review.showCurrentMatch(rowID: "long", revision: revisions)
        let findChoice = review.bookmark(rowID: "long", revision: revisions)
        assert(findChoice.revealedChange == nil)
        review.resetField(); review.restore(findChoice, rowID: "long", revision: revisions)
        assert(review.changedSpan(rowID: "long", revision: revisions, side: "A") == nil)
        history.clearReviews(); assert(history.review(for: "long") == nil)
        print("PASS: Back/Forward restore independent A/B excerpts and empty boundaries; Find/query/scope/match/follow/presentation preserved; no reveal-scroll request or forced disclosure; changed query stays current; row/revision validation; explicit Find choice and history invalidation")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
