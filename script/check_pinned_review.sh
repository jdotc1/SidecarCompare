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
        let fields = snapshot.reviewFields
        assert(fields.count == 2 && fields.map(\.pointer) == ["/a~1b~0c", "/z"])
        assert(fields[0].hidden && !fields[1].hidden)
        assert(fields[0].status == .typeChanged && fields[1].status == .aOnly)
        assert(Set(fields.map(\.id)) == Set(selected.map(\.id)))
        let allHidden = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0,
            pinnedIDs: Set(selected.map(\.id)))
        assert(allHidden.reviewFields.allSatisfy(\.hidden))
        let ordinary = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 3)
        assert(ordinary.reviewFields.isEmpty)
        assert(snapshot.visiblePinnedIDs == [visible.id] && snapshot.reviewFields.count == 2)
        print("Pinned review passed: exact pin membership, stable escaped pointer order, statuses, visible/hidden labels, no ordinary-export list, immutable snapshot.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/PinnedPointerCopy.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
