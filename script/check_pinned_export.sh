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
        let a = #"{"z":null,"a/b~c":9007199254740993e+0,"unselected":"private-marker"}"#
        let b = #"{"a/b~c":true,"unselected":2}"#
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8)))
        let ids = Set(comparison.rows.filter { $0.path != "/unselected" }.map(\.id))
        let snapshot = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0, pinnedIDs: ids)
        assert(snapshot.selectedCount == 2 && snapshot.visibleRowCount == 0)
        let summary = try snapshot.render(detail: .summary, json: true)
        assert(summary.contains("\"rowCount\":2") && summary.contains("Pinned fields only"))
        assert(!summary.contains("9007199254740993") && !summary.contains("a~1b~0c") && !summary.contains("private-marker"))
        let full = try snapshot.render(detail: .full, json: true)
        assert(full.contains("9007199254740993e+0") && full.contains("\"value\":null"))
        assert(full.contains("\"present\":false") && !full.contains("private-marker") && !full.contains("/unselected"))
        assert(full.range(of: "/a~1b~0c")!.lowerBound < full.range(of: "/z")!.lowerBound)
        let text = try snapshot.render(detail: .full, json: false)
        assert(text.contains("Pinned fields only") && text.contains("9007199254740993e+0") && text.contains("<missing>"))
        let exact = try snapshot.render(detail: .full, json: true, limit: full.utf8.count)
        assert(exact == full)
        do {
            _ = try snapshot.render(detail: .full, json: true, limit: full.utf8.count - 1)
            assertionFailure("Oversize pinned report returned output")
        } catch is SidecarError {}
        let all = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0)
        let ordinary = try all.render(detail: .full, json: true)
        assert(ordinary == ReportRenderer.json(comparison, detail: .full))
        print("Pinned export passed: hidden pins, scoped summary privacy/counts, stable pointer order, raw exact numeric/null/missing full JSON and text, exact UTF8 budget and whole-output rejection, ordinary export parity.")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
