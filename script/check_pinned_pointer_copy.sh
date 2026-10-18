#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/dist"
CHECK="$(mktemp "$ROOT/dist/pointer-copy-check.XXXXXX.swift")"
trap 'rm -f "$CHECK" "${CHECK}.bin"' EXIT
cat "$ROOT/Sources/SidecarCompare/Views/PinnedPointerCopy.swift" > "$CHECK"
cat >> "$CHECK" <<'SWIFT'
let fields = [(id: "hidden", pointer: "/z"), (id: "escaped", pointer: "/a~1b~0c"),
              (id: "unselected", pointer: "/ignored"), (id: "decomposed", pointer: "/e\u{301}"),
              (id: "composed", pointer: "/é"), (id: "empty-key", pointer: "/")]
let content = PinnedPointerCopy.content(fields: fields, pinnedIDs: ["hidden", "escaped", "decomposed", "composed", "empty-key", "stale"])
assert(content.count == 5)
assert(Array(content.text.utf8) == Array("/\n/a~1b~0c\n/e\u{301}\n/z\n/é".utf8))
let empty = PinnedPointerCopy.content(fields: fields, pinnedIDs: [])
assert(empty.count == 0 && empty.text.isEmpty)
print("Pinned pointer copy passed: full membership, escaped/empty keys, exact Unicode bytes, deterministic ordering, stale IDs and empty pins.")
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$CHECK" -o "${CHECK}.bin"
"${CHECK}.bin"
