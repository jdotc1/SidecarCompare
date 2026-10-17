#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/inspector-section-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
@main struct Check {
    @MainActor static func main() throws {
        let review = InspectorReviewState()
        let revision: [UUID?] = [UUID(), UUID()]
        review.query = "needle"
        let identity = SearchIdentity(rowID: "field", revision: revision, queryBytes: Data(review.query.utf8))
        review.outcome = SearchOutcome(identity: identity,
            a: try JSONValueSearch.find(.string("needle"), query: review.query),
            b: try JSONValueSearch.find(.string(String(repeating: "x", count: 9000) + "needle"), query: review.query))
        review.currentMatch = 1
        review.collapsedA = true; review.collapsedB = true
        review.expandedA = true; review.expandedB = false
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(review.collapsedA && !review.collapsedB && review.expandedA && !review.expandedB)
        assert(review.query == "needle" && review.currentMatch == 1)
        assert(review.revealedValueMatch(rowID: "field", revision: revision, side: "B")?.bytePosition == 9002)
        assert(review.revealedValueMatch(rowID: "field", revision: revision, side: "A") == nil)
        assert(review.revealedValueSide(rowID: "field", revision: [UUID()]) == nil)
        review.currentMatch = 0
        assert(review.revealedValueSide(rowID: "field", revision: revision) == nil)
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(!review.collapsedA && !review.collapsedB && review.expandedA)
        review.query = "missing"
        assert(review.revealedValueSide(rowID: "field", revision: revision) == nil)
        review.collapsedA = true
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(review.collapsedA)
        review.resetField()
        assert(review.revealedMatch == nil && review.query == "missing")
        print("Show Match passed: full-value byte 9002, independent side reveal, unchanged query/match/expansion, query/index/revision invalidation and reset.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/debug" -L "$ROOT/.build/debug" -lSidecarCore "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
