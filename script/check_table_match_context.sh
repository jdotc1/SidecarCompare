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
  let comparison = try Comparator.compare(a: JSONParser.parse(Data(("{\"a/b~\":\"" + prefix + "needle café needle\"}").utf8)), b: JSONParser.parse(Data("{\"a/b~\":\"needle\"}".utf8)))
  let row = comparison.rows[0], revision: [UUID?] = [UUID(), UUID()]
  let id = TableMatchIdentity(rowID: row.id, revision: revision, query: Data("needle".utf8))
  let locations = try TableMatchLocations.prepare(row: row, identity: id)
  let review = InspectorReviewState(); review.query = "Find"; review.currentMatch = 4
  review.expandedA = true; review.collapsedB = true; review.collapsedTextSummary = true
  assert(review.tableMatchContext(row: row, locations: locations) == nil)
  review.showTableMatch(locations, side: "A"); review.moveTableMatch(locations, offset: 1)
  let request = review.valueRevealRequest, bookmark = review.bookmark(rowID: row.id, revision: revision)
  let text = review.tableMatchContext(row: row, locations: locations)!
  assert(text.contains("A · match 2 of 3 · raw JSON byte 9015"))
  assert(text.contains("JSON Pointer (JSON string): \"/a~1b~0\""))
  assert(text.contains("café needle") && text.contains("Bounded raw JSON excerpt; not a complete JSON value."))
  assert(review.valueRevealRequest == request && review.currentMatch == 4 && review.query == "Find")
  assert(review.expandedA && review.collapsedB && review.collapsedTextSummary)
  assert(review.bookmark(rowID: row.id, revision: revision).revealedTableMatch?.index == bookmark.revealedTableMatch?.index)
  let stale = try TableMatchLocations.prepare(row: row, identity: TableMatchIdentity(rowID: row.id, revision: [UUID()], query: id.query))
  assert(review.tableMatchContext(row: row, locations: stale) == nil)
  let changedQuery = try TableMatchLocations.prepare(row: row, identity: TableMatchIdentity(rowID: row.id, revision: revision, query: Data("café".utf8)))
  assert(review.tableMatchContext(row: row, locations: changedQuery) == nil)
  review.showTableMatch(locations, side: "B")
  assert(review.tableMatchContext(row: row, locations: locations)!.contains("B · match 3 of 3 · raw JSON byte 2"))
  let longID = TableMatchIdentity(rowID: row.id, revision: revision, query: Data(String(repeating: "x", count: 100).utf8))
  let long = try TableMatchLocations.prepare(row: row, identity: longID)
  review.showTableMatch(long, side: "A")
  let truncated = review.tableMatchContext(row: row, locations: long)!
  assert(truncated.contains("Match text is truncated.") && truncated.contains("…"))
  review.invalidateTableMatch(expecting: nil)
  assert(review.tableMatchContext(row: row, locations: long) == nil)
  print("PASS: exact escaped pointer, Unicode context, A/B global position and raw byte beyond9000; bounded/truncated labels; absent/query/source invalidation; copy preparation preserves Find/index/expansion/collapse/summary/history and reveal request")
 }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
