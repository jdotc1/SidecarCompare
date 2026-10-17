#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/inspector-section-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
@main struct Check {
    @MainActor static func main() {
        let review = InspectorReviewState()
        let revision: [UUID?] = [UUID(), UUID()]
        review.query = "needle"
        let original = InspectorReviewBookmark(query: Data("needle".utf8), revision: revision,
            expandedA: true, expandedB: false, collapsedA: true, collapsedB: false, match: 2)
        review.restore(original, rowID: "A", revision: revision)
        assert(review.collapsedA && !review.collapsedB && review.expandedA)
        review.collapsedA.toggle()
        assert(review.expandedA && review.query == "needle")
        review.collapsedA.toggle()
        let saved = review.bookmark(rowID: "A", revision: revision)
        assert(saved.collapsedA && !saved.collapsedB && saved.expandedA && saved.match == 2)
        var history = InspectorHistory()
        history.visit("A"); history.save(saved, for: "A"); history.visit("B")
        review.resetField()
        assert(!review.collapsedA && !review.collapsedB && !review.expandedA && review.query == "needle")
        history.move(to: 0)
        if let bookmark = history.review(for: "A") { review.restore(bookmark, rowID: "A", revision: revision) }
        assert(review.collapsedA && review.expandedA && !review.collapsedB)
        review.resetField(); review.query = "changed"
        review.restore(saved, rowID: "A", revision: revision)
        assert(!review.collapsedA && !review.expandedA && review.query == "changed")
        review.query = "needle"
        review.restore(saved, rowID: "A", revision: [UUID(), UUID()])
        assert(!review.collapsedA)
        review.collapsedB = true; review.resetAll()
        assert(!review.collapsedA && !review.collapsedB && review.query.isEmpty)
        print("Inspector sections passed: independent collapse preserves expansion/query, bookmark/history round trip and pending match, fresh/reset defaults, query/revision guard.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/debug" -L "$ROOT/.build/debug" -lSidecarCore "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
