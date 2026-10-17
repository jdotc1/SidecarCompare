#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/pin-navigation-check.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedNavigation.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
let ids = ["C", "B", "A"]
let pins: Set<String> = ["C", "A", "hidden"]
let first = PinnedNavigation(visibleIDs: ids, pinnedIDs: pins, selection: "C")
assert(first.target(forward: false) == nil && first.target(forward: true) == "A")
assert(first.position == "Pinned field 1 of 2 in this view")
let last = PinnedNavigation(visibleIDs: ids, pinnedIDs: pins, selection: "A")
assert(last.target(forward: true) == nil && last.target(forward: false) == "C")
assert(last.position == "Pinned field 2 of 2 in this view")
let between = PinnedNavigation(visibleIDs: ids, pinnedIDs: pins, selection: "B")
assert(between.target(forward: false) == "C" && between.target(forward: true) == "A")
let none = PinnedNavigation(visibleIDs: ids, pinnedIDs: pins, selection: nil)
assert(none.target(forward: true) == "C" && none.target(forward: false) == "A")
let hidden = PinnedNavigation(visibleIDs: ["B"], pinnedIDs: pins, selection: "B")
assert(hidden.visiblePins.isEmpty && hidden.target(forward: true) == nil && hidden.target(forward: false) == nil)
let empty = PinnedNavigation(visibleIDs: [], pinnedIDs: [], selection: nil)
assert(empty.visiblePins.isEmpty && empty.target(forward: true) == nil)
print("Pinned navigation passed: current order, endpoints, unpinned selection, no selection, hidden and empty pins, position counts.")
SWIFT
swift "$CHECK"
