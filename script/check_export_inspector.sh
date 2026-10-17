#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/pinned-export-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        let a = #"{"z":null,"a/b~c":1,"unselected":0}"#
        let b = #"{"a/b~c":true,"unselected":2}"#
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8)))
        let selected = comparison.rows.filter { $0.path != "/unselected" }
        let visible = selected.first { $0.path == "/z" }!
        let snapshot = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 1,
            pinnedIDs: Set(selected.map(\.id)), visiblePinnedIDs: [visible.id])
        let visibleRequest = snapshot.inspectorRequest(for: visible.id)
        assert(visibleRequest?.id == visible.id && visibleRequest?.clearFilters == false)
        let hidden = selected.first { $0.id != visible.id }!
        let hiddenRequest = snapshot.inspectorRequest(for: hidden.id)
        assert(hiddenRequest?.id == hidden.id && hiddenRequest?.clearFilters == true)
        let unpinned = comparison.rows.first { $0.path == "/unselected" }!
        assert(snapshot.inspectorRequest(for: unpinned.id) == nil)
        assert(snapshot.inspectorRequest(for: "stale") == nil)
        assert(snapshot.reviewFields(matching: "no-match").isEmpty)
        assert(snapshot.inspectorRequest(for: hidden.id)?.clearFilters == true)
        assert(snapshot.pinnedIDs == Set(selected.map(\.id)) && snapshot.visiblePinnedIDs == [visible.id])
        print("Export inspector requests passed: visible direct request, hidden recovery request, unpinned/stale rejection, review search independent from membership, immutable pins and visibility snapshot.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
