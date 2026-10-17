#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/clear-pins-undo.XXXXXX.swift")"
trap 'rm -f "$CHECK"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedFields.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
var pins = PinnedFields()
pins.add(["visibleA", "visibleB", "hidden"])
pins.removeVisibleForUndo(["visibleA", "visibleB", "notPinned", "visibleA"])
assert(pins.ids == ["hidden"] && pins.removedVisibleCount == 2 && pins.undoCount == 2 && pins.clearedCount == 0)
pins.removeVisibleForUndo(["notPinned"])
assert(pins.undoCount == 2)
pins.undoClear()
assert(pins.ids == ["visibleA", "visibleB", "hidden"] && pins.undoCount == 0)
pins.undoClear(); assert(pins.ids.count == 3)
pins.removeVisibleForUndo(["visibleA"]); pins.toggle("new"); pins.undoClear()
assert(pins.ids == ["visibleB", "hidden", "new"] && pins.undoCount == 0)
pins.removeVisibleForUndo(["visibleB"]); pins.add(["added"]); pins.undoClear()
assert(!pins.ids.contains("visibleB") && pins.ids.contains("hidden") && pins.undoCount == 0)
pins.removeVisibleForUndo(["hidden"]); pins.retain(["added"]); pins.undoClear()
assert(pins.ids == ["added"] && pins.undoCount == 0)
pins.removeVisibleForUndo(["added"]); pins.invalidateUndo(); pins.undoClear()
assert(pins.ids.isEmpty && pins.undoCount == 0)
pins.add(["a", "b"]); pins.removeVisibleForUndo(["a"]); pins.clearForUndo()
assert(pins.clearedCount == 1 && pins.removedVisibleCount == 0)
pins.undoClear(); assert(pins.ids == ["b"])
pins.add(["a"]); pins.clearForUndo(); pins.removeVisibleForUndo([]); pins.undoClear()
assert(pins.ids == ["a", "b"])
print("Unpin visible passed: intersection/deduplication, hidden pins retained, exact one-shot snapshot restore, no-op preservation, edit/add/prune/refresh invalidation, replacement by Clear Pins, legacy clear restoration.")
SWIFT
swift "$CHECK"
