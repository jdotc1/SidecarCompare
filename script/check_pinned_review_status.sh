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
        let counts = snapshot.reviewCounts
        assert(counts[.typeChanged] == 1 && counts[.aOnly] == 1 && counts[.changed] == nil)
        assert(counts.values.reduce(0, +) == snapshot.selectedCount)
        let all = snapshot.reviewFields(matching: "")
        let typed = snapshot.reviewFields(matching: "A~1B", status: .typeChanged)
        assert(typed.count == 1 && typed[0].hidden && typed[0].status == .typeChanged)
        assert(snapshot.reviewFields(matching: "A~1B", status: .aOnly).isEmpty)
        let searched = snapshot.reviewFields(matching: "A~1B", status: nil)
        assert(searched.map(\.id) == typed.map(\.id))
        let statusOnly = snapshot.reviewFields(matching: "", status: .aOnly)
        assert(statusOnly.count == 1 && statusOnly[0].id == visible.id && !statusOnly[0].hidden)
        assert(snapshot.reviewFields(matching: "", status: nil).map(\.id) == all.map(\.id))
        assert(snapshot.reviewFields(matching: "", status: .withinTolerance).isEmpty)
        assert(snapshot.reviewCounts == counts && snapshot.selectedCount == 2)
        assert(snapshot.pinnedIDs == Set(selected.map(\.id)))
        print("Pinned review status passed: full-pin counts including hidden fields, unpinned exclusion, combined query/status intersection, independent clear semantics, stable order/labels, unchanged counts and export membership.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
