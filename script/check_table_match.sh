#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/table-match-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
@main struct Check {
    @MainActor static func main() throws {
        let prefix = String(repeating: "x", count: 9000)
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(("{\"Long\":\"" + prefix + "needle A review needle\"}").utf8)), b: JSONParser.parse(Data(("{\"Long\":\"" + prefix + "needle B review\"}").utf8)))
        let row = comparison.rows[0], revision: [UUID?] = [UUID(), UUID()]
        let identity = TableMatchIdentity(rowID: row.id, revision: revision, query: Data("needle".utf8))
        let locations = try TableMatchLocations.prepare(row: row, identity: identity)
        assert(locations.a?.bytePosition == 9002 && locations.b?.bytePosition == 9002)
        assert(locations.a?.match == "needle" && locations.b?.match == "needle")
        assert(locations.countA == 2 && locations.countB == 1 && locations.total == 3)
        assert(locations.match(at: -1) == nil && locations.match(at: 3) == nil)
        let traversal = InspectorReviewState()
        traversal.query = "independent"; traversal.expandedA = true; traversal.collapsedB = true
        traversal.moveTableMatch(locations, offset: 1)
        assert(traversal.tableMatchIndex(identity: identity) == 0 && traversal.collapsedB)
        traversal.moveTableMatch(locations, offset: 1)
        assert(traversal.tableMatchIndex(identity: identity) == 1)
        assert(traversal.tableMatch(identity: identity, side: "A")!.bytePosition > 9002)
        traversal.moveTableMatch(locations, offset: 1)
        assert(traversal.tableMatchIndex(identity: identity) == 2 && !traversal.collapsedB)
        let lastRequest = traversal.valueRevealRequest
        traversal.moveTableMatch(locations, offset: 1)
        assert(traversal.valueRevealRequest == lastRequest)
        traversal.moveTableMatch(locations, offset: -1)
        assert(traversal.tableMatchIndex(identity: identity) == 1)
        assert(traversal.query == "independent" && traversal.expandedA)
        traversal.invalidateTableMatch(expecting: nil)
        traversal.moveTableMatch(locations, offset: -1)
        assert(traversal.tableMatchIndex(identity: identity) == 2)
        let onlyB = TableMatchIdentity(rowID: row.id, revision: revision, query: Data("B review".utf8))
        let onlyBLocations = try TableMatchLocations.prepare(row: row, identity: onlyB)
        assert(onlyBLocations.a == nil && onlyBLocations.b != nil)
        assert(TableMatchIdentity(rowID: row.id, revision: revision, query: Data("é".utf8)) != TableMatchIdentity(rowID: row.id, revision: revision, query: Data("e\u{301}".utf8)))
        let review = InspectorReviewState()
        review.query = "review"; review.scope = .b; review.followMatch = true; review.showFind = false
        let findID = SearchIdentity(rowID: row.id, revision: revision, queryBytes: Data(review.query.utf8))
        review.outcome = SearchOutcome(identity: findID, a: try JSONValueSearch.find(row.a, query: "review"), b: try JSONValueSearch.find(row.b, query: "review"))
        review.currentMatch = 1; review.showCurrentMatch(rowID: row.id, revision: revision)
        let previousChange = ChangedSpanExcerpt(before: "", changed: "A", after: "", bytePosition: 9009, scalarCount: 1, truncated: false)
        review.showChangedSpan(rowID: row.id, revision: revision, side: "A", excerpt: previousChange)
        review.expandedA = true; review.expandedB = false; review.collapsedA = true; review.collapsedB = true
        review.collapsedTextSummary = true; review.collapsedNumericSummary = true
        review.showTableMatch(locations, side: "A")
        assert(!review.collapsedA && review.collapsedB && review.expandedA && !review.expandedB)
        assert(review.query == "review" && review.currentMatch == 1 && review.scope == .b && review.followMatch && !review.showFind)
        assert(review.collapsedTextSummary && review.collapsedNumericSummary)
        assert(review.bookmark(rowID: row.id, revision: revision).revealedChange != nil)
        assert(review.revealedValueMatch(rowID: row.id, revision: revision, side: "B") != nil)
        assert(review.tableMatch(identity: identity, side: "A")?.bytePosition == 9002)
        assert(review.revealedValueSide(rowID: row.id, revision: revision) == "A")
        assert(review.tableMatch(identity: onlyB, side: "A") == nil)
        assert(review.tableMatch(identity: TableMatchIdentity(rowID: row.id, revision: [UUID()], query: identity.query), side: "A") == nil)
        review.showTableMatch(locations, side: "B")
        assert(review.tableMatch(identity: identity, side: "B") != nil && !review.collapsedB && review.expandedA)
        review.invalidateTableMatch(expecting: onlyB)
        assert(review.tableMatch(identity: identity, side: "B") == nil && review.query == "review")
        review.collapsedA = true; let before = review.valueRevealRequest
        review.showTableMatch(onlyBLocations, side: "A")
        assert(review.collapsedA && review.valueRevealRequest == before)
        review.showTableMatch(onlyBLocations, side: "B")
        review.showCurrentMatch(rowID: row.id, revision: revision)
        assert(review.tableMatch(identity: onlyB, side: "B") == nil && review.query == "review" && review.currentMatch == 1)
        review.showTableMatch(locations, side: "A"); review.invalidateTableMatch(expecting: nil)
        assert(review.tableMatch(identity: identity, side: "A") == nil)
        review.showTableMatch(locations, side: "B"); review.resetField()
        assert(review.tableMatch(identity: identity, side: "B") == nil && review.query == "review")
        do { _ = try TableMatchLocations.prepare(row: row, identity: TableMatchIdentity(rowID: "stale", revision: revision, query: identity.query)); fatalError("Stale row accepted") } catch is SidecarError { }
        print("PASS: selected-field A/B counts and bounded bidirectional traversal beyond9000, side availability, byte-preserving identity; table reveal preserves independent Find/query/scope/current match/follow/visibility, expansion/opposite collapse and summary/change state; query/source/scope/row invalidation, no-match no-op, explicit Find handoff and reset")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
