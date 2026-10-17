#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/history-check.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/InspectorHistory.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'

var history = InspectorHistory()
assert(history.back == nil && history.forward == nil)
history.visit("A"); history.visit("B"); history.move(to: 0)
assert(history.entries[history.index] == "A" && history.forward == 1)
history.move(to: 1); history.visit("B")
assert(history.entries == ["A", "B"])
history.move(to: 0); history.visit("C")
assert(history.entries == ["A", "C"] && history.forward == nil)
history.retain(["C"])
assert(history.entries == ["C"] && history.index == 0)
for index in 0..<105 { history.visit(String(index)) }
assert(history.entries.count == 100 && history.entries.first == "5" && history.index == 99)
history.retain([])
assert(history.entries.isEmpty && history.index == -1)
print("History model checks passed: endpoints, traversal, duplicate visits, branching, pruning, 100-entry bound, empty pruning.")
SWIFT
swift "$CHECK"
