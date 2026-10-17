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
        let result = SearchOutcome(identity: identity,
            a: try JSONValueSearch.find(.string("needle needle"), query: review.query),
            b: try JSONValueSearch.find(.string("needle needle needle"), query: review.query))
        review.outcome = result
        review.currentMatch = 3
        review.collapsedA = true; review.expandedB = true
        review.scope = .b
        assert(review.currentMatch == 3 && result.range(for: review.scope).count == 3)
        review.scope = .both
        assert(review.currentMatch == 3)
        review.scope = .a
        assert(review.currentMatch == 0 && result.range(for: review.scope).count == 2)
        assert(review.query == "needle" && review.collapsedA && review.expandedB)
        review.scope = .b
        assert(review.currentMatch == 2)
        review.currentMatch = 4
        let saved = review.bookmark(rowID: "field", revision: revision)
        assert(saved.scope == .b && saved.match == 4)
        review.resetField()
        assert(review.scope == .b && review.query == "needle")
        review.restore(saved, rowID: "field", revision: revision)
        assert(review.scope == .b && review.pendingMatch?.index == 4 && review.collapsedA && review.expandedB)
        review.outcome = result
        review.currentMatch = review.pendingMatch?.index ?? 0
        review.normalizeMatch()
        assert(review.currentMatch == 4)
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(review.revealedValueSide(rowID: "field", revision: revision) == "B")
        review.scope = .both
        assert(review.currentMatch == 4 && review.revealedValueSide(rowID: "field", revision: revision) == "B")
        review.scope = .a
        assert(review.currentMatch == 0 && review.revealedValueSide(rowID: "field", revision: revision) == nil)
        review.outcome = SearchOutcome(identity: identity, a: result.a, b: try JSONValueSearch.find(nil, query: review.query))
        review.scope = .b
        assert(review.outcome?.range(for: review.scope).isEmpty == true)
        review.collapsedB = true
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(review.collapsedB && review.revealedValueSide(rowID: "field", revision: revision) == nil)
        review.query = "changed"; review.restore(saved, rowID: "field", revision: revision)
        assert(review.query == "changed")
        review.resetAll()
        assert(review.scope == .both && review.query.isEmpty)
        print("Find scope passed: scoped ranges/global occurrence preservation, excluded occurrence recovery, unchanged query/collapse/expansion, bookmark restore, empty-side reveal guard, full reset.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/debug" -L "$ROOT/.build/debug" -lSidecarCore "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
