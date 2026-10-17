#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/changed-span-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
@main struct Check {
    @MainActor static func main() throws {
        let prefix = String(repeating: "x", count: 9000) + "😀\n\"\\"
        let left = prefix + "éOLD" + String(repeating: "y", count: 100)
        let right = prefix + "e\u{301}NEW" + String(repeating: "y", count: 100)
        let summary = try StringDifferenceSummary.compare(a: left, b: right)!
        let a = try ChangedSpanExcerpt.make(value: left, prefix: summary.sharedPrefixScalars, suffix: summary.sharedSuffixScalars)
        let b = try ChangedSpanExcerpt.make(value: right, prefix: summary.sharedPrefixScalars, suffix: summary.sharedSuffixScalars)
        assert(a.bytePosition == JSONValue.quote(prefix).utf8.count && a.bytePosition > 8192)
        let raw = Array(JSONValue.string(left).serialized().utf8)
        assert(String(decoding: raw[(a.bytePosition-1)..<(a.bytePosition-1+a.changed.utf8.count)], as: UTF8.self) == a.changed)
        assert(Data(a.changed.utf8) == Data("éOLD".utf8) && Data(b.changed.utf8) == Data("e\u{301}NEW".utf8))
        let empty = try ChangedSpanExcerpt.make(value: "", prefix: 0, suffix: 0)
        assert(empty.scalarCount == 0 && empty.bytePosition == 2 && empty.before == "\"" && empty.after == "\"")
        let boundary = try ChangedSpanExcerpt.make(value: "ab", prefix: 1, suffix: 1)
        assert(boundary.scalarCount == 0 && boundary.bytePosition == 3 && boundary.before == "\"a" && boundary.after == "b\"")
        let long = try ChangedSpanExcerpt.make(value: String(repeating: "😀", count: 100), prefix: 0, suffix: 0)
        assert(long.truncated && long.scalarCount == 100 && long.changed.unicodeScalars.count == 80)
        do { _ = try ChangedSpanExcerpt.make(value: "x", prefix: 2, suffix: 0); fatalError("Invalid range accepted") } catch is SidecarError { }
        let review = InspectorReviewState(), revision: [UUID?] = [UUID(), UUID()]
        review.query = "needle"; review.scope = .b; review.followMatch = true
        let identity = SearchIdentity(rowID: "field", revision: revision, queryBytes: Data(review.query.utf8))
        review.outcome = SearchOutcome(identity: identity, a: try JSONValueSearch.find(.string("needle"), query: "needle"), b: try JSONValueSearch.find(.string("needle needle"), query: "needle"))
        review.currentMatch = 2
        review.expandedA = true; review.expandedB = false; review.collapsedA = true; review.collapsedB = true
        review.collapsedTextSummary = true; review.collapsedNumericSummary = true
        review.showCurrentMatch(rowID: "field", revision: revision)
        review.collapsedB = true
        let request = review.valueRevealRequest
        review.showChangedSpan(rowID: "field", revision: revision, side: "A", excerpt: a)
        assert(review.valueRevealRequest != request && !review.collapsedA && review.collapsedB)
        assert(review.query == "needle" && review.currentMatch == 2 && review.scope == .b && review.followMatch)
        assert(review.expandedA && !review.expandedB && review.collapsedTextSummary && review.collapsedNumericSummary)
        assert(review.revealedValueMatch(rowID: "field", revision: revision, side: "B") != nil)
        assert(review.revealedValueSide(rowID: "field", revision: revision) == "A")
        assert(review.changedSpan(rowID: "field", revision: [UUID()], side: "A") == nil)
        assert(review.changedSpan(rowID: "other", revision: revision, side: "A") == nil)
        review.showFind = false; review.showFind = true
        assert(review.changedSpan(rowID: "field", revision: revision, side: "A")?.bytePosition == a.bytePosition)
        review.showCurrentMatch(rowID: "field", revision: revision)
        assert(review.changedSpan(rowID: "field", revision: revision, side: "A") == nil)
        review.showChangedSpan(rowID: "field", revision: revision, side: "B", excerpt: b)
        review.resetField()
        assert(review.changedSpan(rowID: "field", revision: revision, side: "B") == nil && review.query == "needle")
        print("PASS: raw JSON byte mapping beyond8192 with escaped prefix/emoji/exact Unicode, empty boundaries, bounded span, invalid range; independent reveal preserves Find/query/scope/match/follow/expansion/disclosures and opposite collapse; revision/row/reset guards and explicit Find handoff")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
