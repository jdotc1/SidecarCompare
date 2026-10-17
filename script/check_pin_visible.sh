#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/pin-visible-check.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedFields.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
var pins = PinnedFields()
pins.toggle("existing-hidden")
pins.add(["visible-A", "visible-B", "visible-A"])
assert(pins.ids == ["existing-hidden", "visible-A", "visible-B"])
pins.add(["visible-A", "visible-B"])
assert(pins.ids.count == 3)
pins.add([])
assert(pins.ids == ["existing-hidden", "visible-A", "visible-B"])
print("Pin Visible checks passed: additive union retains hidden pins, deduplicates, is idempotent and handles empty visibility.")
SWIFT
swift "$CHECK"
