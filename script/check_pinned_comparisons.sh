#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/pinned-comparison-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/main.swift" <<'SWIFT'
import Foundation
import SidecarCore
let long = String(repeating: "é", count: 9001)
let a = "{\"a/b~c\":9007199254740993e+0,\"missing\":null,\"z\":" + JSONValue.quote(long) + "}"
let b = #"{"a/b~c":true,"z":"short","unselected":2}"#
let result = try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8)))
let rows = result.rows.filter { $0.path != "/unselected" }
let ids = Set(rows.map(\.id))
let content = try PinnedComparisonCopy.content(rows: Array(result.rows.reversed()), pinnedIDs: ids, policy: result.policy)
assert(content.count == 3)
let expected = "Pinned field comparisons · original metadata\nContains complete original metadata; not de-identified.\nFields: 3" + rows.sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }.map { "\n\n—\n" + FieldComparisonCopy.text(row: $0, policy: result.policy) }.joined()
assert(Array(content.text.utf8) == Array(expected.utf8))
assert(content.text.contains("9007199254740993e+0") && content.text.contains(long))
assert(content.text.contains("[missing — field absent]") && content.text.contains("\nnull\n"))
let exact = try PinnedComparisonCopy.content(rows: rows, pinnedIDs: ids, policy: result.policy, limit: content.text.utf8.count)
assert(exact.text == content.text)
do {
    _ = try PinnedComparisonCopy.content(rows: rows, pinnedIDs: ids, policy: result.policy, limit: content.text.utf8.count - 1)
    assertionFailure("Oversize result must throw without returning partial output")
} catch is PinnedComparisonCopy.SizeLimitExceeded {}
let empty = try PinnedComparisonCopy.content(rows: rows, pinnedIDs: [], policy: result.policy)
assert(empty.count == 0 && empty.text.isEmpty)
print("Pinned comparisons passed: exact single-field composition/order/membership, raw long Unicode/numeric values, missing/null, exact UTF8 byte boundary, oversize rejects whole result, empty pins.")
SWIFT
swiftc -warnings-as-errors -I "$ROOT/.build/debug" -L "$ROOT/.build/debug" -lSidecarCore "$ROOT/Sources/SidecarCompare/Views/FieldComparisonCopy.swift" "$ROOT/Sources/SidecarCompare/Views/PinnedComparisonCopy.swift" "$CHECK/main.swift" -o "$CHECK/check"
"$CHECK/check"
