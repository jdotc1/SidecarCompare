#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/table-match-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
@main struct Check {
 @MainActor static func main() throws {
  let comparison = try Comparator.compare(a: JSONParser.parse(Data("{\"Field\":\"T T\"}".utf8)), b: JSONParser.parse(Data("{\"Field\":\"T T T\"}".utf8)))
  let row = comparison.rows[0], revision: [UUID?] = [UUID(), UUID()]
  let id = TableMatchIdentity(rowID: row.id, revision: revision, query: Data("T".utf8))
  let locations = try TableMatchLocations.prepare(row: row, identity: id)
  let review = InspectorReviewState(); review.query = "Find"; review.expandedA = true; review.collapsedA = true
  review.collapsedTextSummary = true; review.collapsedNumericSummary = true
  review.showTableMatch(locations, side: "B"); review.moveTableMatch(locations, offset: 1)
  let bookmark = review.bookmark(rowID: row.id, revision: revision)
  var history = InspectorHistory(); history.visit(row.id); history.save(bookmark, for: row.id); history.visit("/Other")
  review.resetField(); review.restore(bookmark, rowID: row.id, revision: revision, tableIdentity: id)
  assert(review.tableMatchIndex(identity: id) == 3)
  assert(review.tableMatch(identity: id, side: "B")?.bytePosition == 4)
  assert(review.query == "Find" && review.expandedA && review.collapsedA && !review.collapsedB)
  assert(review.collapsedTextSummary && review.collapsedNumericSummary)
  review.moveTableMatch(locations, offset: 1); assert(review.tableMatchIndex(identity: id) == 4)
  review.resetField(); review.query = "current Find"
  review.restore(bookmark, rowID: row.id, revision: revision, tableIdentity: id)
  assert(review.query == "current Find" && review.tableMatchIndex(identity: id) == 3)
  for stale in [TableMatchIdentity(rowID: row.id, revision: revision, query: Data("t".utf8)), TableMatchIdentity(rowID: row.id, revision: [UUID()], query: id.query), TableMatchIdentity(rowID: "/Other", revision: revision, query: id.query)] {
   review.resetField(); review.restore(bookmark, rowID: row.id, revision: revision, tableIdentity: stale)
   assert(review.tableMatchIndex(identity: id) == nil)
  }
  review.resetField(); review.restore(bookmark, rowID: row.id, revision: revision)
  assert(review.tableMatchIndex(identity: id) == nil)
  history.clearTableMatches()
  assert(history.review(for: row.id)?.revealedTableMatch == nil)
  assert(history.review(for: row.id)?.expandedA == true)
  review.resetField(); review.restore(history.review(for: row.id)!, rowID: row.id, revision: revision, tableIdentity: id)
  assert(review.tableMatchIndex(identity: id) == nil)
  print("PASS: history restores B second occurrence/index/exact byte and resumes navigation; Find query remains current; matching-query expansion/collapse/summary state restored; query/source/row/disabled-scope guards; clearing saved table matches preserves other review state and prevents revival")
 }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
