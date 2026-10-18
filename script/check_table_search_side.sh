#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/table-match-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorValueSearch.swift" > "$CHECK/Check.swift"
cat >> "$CHECK/Check.swift" <<'SWIFT'
actor Gate {
    var held: [String: CheckedContinuation<Set<String>, Never>] = [:]
    var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    func pause(_ name: String) async -> Set<String> {
        await withCheckedContinuation { continuation in
            held[name] = continuation
            waiters.removeValue(forKey: name)?.resume()
        }
    }
    func started(_ name: String) async {
        if held[name] != nil { return }
        await withCheckedContinuation { waiters[name] = $0 }
    }
    func release(_ name: String, ids: Set<String>) { held.removeValue(forKey: name)!.resume(returning: ids) }
}
@main struct Check {
 @MainActor static func main() async throws {
  let long = String(repeating: "x", count: 9000)
  let comparison = try Comparator.compare(a: JSONParser.parse(Data(("{\"Left\":\"needle\",\"Right\":\"other\",\"Long\":\"" + long + "needle\",\"Null\":null}").utf8)), b: JSONParser.parse(Data("{\"Left\":\"other\",\"Right\":\"needle\",\"Long\":\"NEEDLE\",\"Missing\":\"needle\"}".utf8)))
  func paths(_ side: FullValueSearchSide) throws -> [String] {
   let ids = try FullValueTableSearch.matchingIDs(rows: comparison.rows, query: "needle", side: side)
   return comparison.rows.filter { ids.contains($0.id) }.map(\.path).sorted()
  }
  let aPaths = try paths(.a); assert(aPaths == ["/Left", "/Long"])
  let bPaths = try paths(.b); assert(bPaths == ["/Missing", "/Right"])
  let bothPaths = try paths(.both); assert(bothPaths == ["/Left", "/Long", "/Missing", "/Right"])
  let row = comparison.rows.first { $0.path == "/Left" }!, revisions: [UUID?] = [UUID(), UUID()]
  let aID = TableMatchIdentity(rowID: row.id, revision: revisions, query: Data("needle".utf8), side: .a)
  let bID = TableMatchIdentity(rowID: row.id, revision: revisions, query: aID.query, side: .b)
  let aLocations = try TableMatchLocations.prepare(row: row, identity: aID)
  let bLocations = try TableMatchLocations.prepare(row: row, identity: bID)
  assert(aLocations.countA == 1 && aLocations.countB == 0 && bLocations.total == 0)
  let review = InspectorReviewState(); review.query = "independent Find"; review.expandedA = true
  review.showTableMatch(aLocations, side: "A")
  let saved = review.bookmark(rowID: row.id, revision: revisions)
  review.resetField(); review.restore(saved, rowID: row.id, revision: revisions, tableIdentity: bID)
  assert(review.tableMatchIndex(identity: aID) == nil && review.query == "independent Find" && review.expandedA)
  let state = FullTableSearchState(), gate = Gate()
  let requestA = FullTableSearchRequest(sources: revisions, policy: "0", query: aID.query, enabled: true, side: .a)
  let requestB = FullTableSearchRequest(sources: revisions, policy: "0", query: aID.query, enabled: true, side: .b)
  let old = Task { await state.run(requestA, rows: comparison.rows) { _, _ in await gate.pause("oldA") } }
  await gate.started("oldA")
  assert(state.pending(for: requestB) && state.matches(for: requestB) == nil)
  await state.run(requestB, rows: comparison.rows)
  let bMatches = try FullValueTableSearch.matchingIDs(rows: comparison.rows, query: "needle", side: .b)
  assert(state.matches(for: requestB) == bMatches)
  await gate.release("oldA", ids: [row.id]); await old.value
  assert(state.matches(for: requestB) == bMatches && state.matches(for: requestA) == nil)
  print("PASS: Both/A/B exact complete membership beyond9000, missing-side exclusion; scoped counts/reveal/history identity; Find/expansion preservation; side change while pending rejects stale A and default worker publishes only B membership")
 }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/FullTableSearchState.swift" "$ROOT/Sources/SidecarCompare/Views/ChangedSpanReveal.swift" "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
