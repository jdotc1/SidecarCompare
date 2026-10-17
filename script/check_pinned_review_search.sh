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
        let idsBefore = snapshot.pinnedIDs
        let all = snapshot.reviewFields(matching: "")
        let hidden = snapshot.reviewFields(matching: "A~1B~0C")
        assert(hidden.count == 1 && hidden[0].pointer == "/a~1b~0c" && hidden[0].hidden)
        let shown = snapshot.reviewFields(matching: "/Z")
        assert(shown.count == 1 && shown[0].id == visible.id && !shown[0].hidden)
        assert(snapshot.reviewFields(matching: "Type changed").isEmpty)
        assert(snapshot.reviewFields(matching: "true").isEmpty)
        assert(snapshot.reviewFields(matching: "unselected").isEmpty)
        assert(snapshot.reviewFields(matching: "no-such-field").isEmpty)
        assert(snapshot.reviewFields(matching: "/").map(\.id) == all.map(\.id))
        assert(snapshot.reviewFields(matching: " ").isEmpty)
        assert(snapshot.reviewFields(matching: "").map(\.id) == all.map(\.id))
        assert(snapshot.pinnedIDs == idsBefore && snapshot.selectedCount == 2 && snapshot.visibleRowCount == 1)
        print("Pinned review search passed: case-insensitive escaped-pointer matching, hidden/visible labels retained, statuses/values/unpinned fields excluded, no-match and clear behavior, stable order and unchanged export membership/counts.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
