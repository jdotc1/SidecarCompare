#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/clear-pins-undo.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedFields.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
var pins = PinnedFields()
pins.add(["visible", "hidden"])
pins.clearForUndo()
assert(pins.ids.isEmpty && pins.clearedCount == 2)
pins.undoClear()
assert(pins.ids == ["visible", "hidden"] && pins.clearedCount == 0)
pins.undoClear()
assert(pins.ids == ["visible", "hidden"])
pins.clearForUndo(); pins.toggle("new"); pins.undoClear()
assert(pins.ids == ["new"] && pins.clearedCount == 0)
pins.clearForUndo(); pins.add(["other"]); pins.undoClear()
assert(pins.ids == ["other"] && pins.clearedCount == 0)
pins.clearForUndo(); pins.invalidateUndo(); pins.undoClear()
assert(pins.ids.isEmpty && pins.clearedCount == 0)
pins.add(["old"]); pins.clearForUndo(); pins.retain(["old"]); pins.undoClear()
assert(pins.ids.isEmpty && pins.clearedCount == 0)
pins.add(["replacement"]); pins.clearForUndo(); pins = PinnedFields(); pins.undoClear()
assert(pins.ids.isEmpty && pins.clearedCount == 0)
print("Clear Pins undo passed: hidden/visible snapshot restoration, one-shot undo, edit/add/prune/refresh/reset invalidation.")
SWIFT
swift "$CHECK"
