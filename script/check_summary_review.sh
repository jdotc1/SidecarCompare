#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/summary-review-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
@main struct Check {
    @MainActor static func main() {
        let review = InspectorReviewState()
        let revision: [UUID?] = [UUID(), UUID()]
        assert(!review.collapsedTextSummary && !review.collapsedNumericSummary)
        review.query = "needle"
        let text = InspectorReviewBookmark(query: Data("needle".utf8), revision: revision,
            expandedA: true, expandedB: false, collapsedA: true, collapsedB: false, match: 2,
            scope: .b, collapsedTextSummary: true, collapsedNumericSummary: false)
        review.restore(text, rowID: "text", revision: revision)
        let savedText = review.bookmark(rowID: "text", revision: revision)
        assert(savedText.collapsedTextSummary && !savedText.collapsedNumericSummary && savedText.match == 2)
        var history = InspectorHistory()
        history.visit("text"); history.save(savedText, for: "text"); history.visit("number")
        review.resetField()
        assert(!review.collapsedTextSummary && !review.collapsedNumericSummary && review.query == "needle")
        review.collapsedNumericSummary = true
        let savedNumber = review.bookmark(rowID: "number", revision: revision)
        history.save(savedNumber, for: "number")
        history.move(to: 0); review.resetField()
        review.restore(history.review(for: "text")!, rowID: "text", revision: revision)
        assert(review.collapsedTextSummary && !review.collapsedNumericSummary && review.expandedA && review.collapsedA && review.scope == .b)
        review.showFind.toggle(); review.showFind.toggle()
        assert(review.collapsedTextSummary && review.query == "needle")
        history.move(to: 1); review.resetField()
        review.restore(history.review(for: "number")!, rowID: "number", revision: revision)
        assert(!review.collapsedTextSummary && review.collapsedNumericSummary)
        review.resetField(); review.query = "changed"
        review.restore(savedText, rowID: "text", revision: revision)
        assert(!review.collapsedTextSummary && !review.collapsedNumericSummary)
        review.query = "needle"; review.restore(savedText, rowID: "text", revision: [UUID()])
        assert(!review.collapsedTextSummary)
        review.collapsedTextSummary = true; review.collapsedNumericSummary = true; review.resetAll()
        assert(!review.collapsedTextSummary && !review.collapsedNumericSummary)
        print("Summary review passed: expanded defaults, independent per-field bookmarks, history Back/Forward restoration with Find/A-B state, query/revision guards and reset behavior.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
