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
            a: try JSONValueSearch.find(.string("needle needle"), query: review.query),
            b: try JSONValueSearch.find(.string(String(repeating: "x", count: 9000) + "needle needle"), query: review.query))
        assert(!review.followMatch)
        review.expandedA = true; review.collapsedA = true; review.collapsedB = true
        review.moveMatch(by: 1, rowID: "field", revision: revision, canReveal: true)
        assert(review.currentMatch == 1 && review.collapsedA && review.revealedMatch == nil)
        review.followMatch = true
        review.followCurrentMatch(rowID: "field", revision: revision)
        assert(!review.collapsedA && review.collapsedB && review.expandedA)
        review.collapsedA = true
        review.moveMatch(by: 1, rowID: "field", revision: revision, canReveal: true)
        assert(review.currentMatch == 2 && review.collapsedA && !review.collapsedB)
        assert(review.revealedValueMatch(rowID: "field", revision: revision, side: "B")?.bytePosition == 9002)
        assert(review.query == "needle" && review.expandedA && !review.expandedB)
        let request = review.valueRevealRequest
        review.moveMatch(by: -1, rowID: "field", revision: [UUID()], canReveal: true)
        assert(review.currentMatch == 2 && request == review.valueRevealRequest)
        review.moveMatch(by: 1, rowID: "field", revision: revision, canReveal: false)
        assert(review.currentMatch == 3 && review.revealedMatch == nil)
        review.followMatch = false
        review.moveMatch(by: -1, rowID: "field", revision: revision, canReveal: true)
        assert(review.currentMatch == 2 && review.revealedMatch == nil)
        review.followMatch = true; review.scope = .a
        review.followCurrentMatch(rowID: "field", revision: revision)
        assert(review.currentMatch == 0 && review.revealedValueSide(rowID: "field", revision: revision) == "A")
        review.outcome = SearchOutcome(identity: identity, a: try JSONValueSearch.find(nil, query: review.query), b: try JSONValueSearch.find(nil, query: review.query))
        review.revealedMatch = nil
        review.followCurrentMatch(rowID: "field", revision: revision)
        assert(review.followMatch && review.revealedMatch == nil)
        review.showFind = false; review.resetField()
        assert(review.followMatch && review.query == "needle")
        review.resetAll(); assert(!review.followMatch)
        print("Follow Match passed: default off/manual navigation, enabled A/B transition at byte9002, other-side collapse and expansion/query preserved, stale revision and unavailable reveal guarded, scope/empty/reset handling.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/debug" -L "$ROOT/.build/debug" -lSidecarCore "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
