#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/pin-check.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedFields.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
var pins = PinnedFields()
assert(pins.ids.isEmpty)
pins.toggle("A"); pins.toggle("B")
assert(pins.contains("A") && pins.ids.count == 2)
pins.toggle("A")
assert(!pins.contains("A") && pins.contains("B"))
pins.toggle("A"); pins.retain(["B", "C"])
assert(pins.ids == ["B"])
pins = PinnedFields()
assert(pins.ids.isEmpty)
print("Pin checks passed: empty, pin/unpin, membership, retained-ID pruning and reset.")
SWIFT
swift "$CHECK"
