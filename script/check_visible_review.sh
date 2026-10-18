#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/visible-review-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(#"{"a/b~c":1,"name":"old","hidden":0}"#.utf8)), b: JSONParser.parse(Data(#"{"a/b~c":true,"name":"new","hidden":1,"new":null}"#.utf8)))
        var ids = Set(comparison.rows.filter { $0.path != "/hidden" }.map(\.id))
        let snapshot = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 3, visibleIDs: ids)
        ids.removeAll()
        let all = snapshot.reviewFields
        assert(all.map(\.pointer) == ["/a~1b~0c", "/name", "/new"])
        assert(all.allSatisfy { !$0.hidden } && snapshot.selectedCount == 3)
        assert(snapshot.reviewCounts[.changed] == 1 && snapshot.reviewCounts[.typeChanged] == 1 && snapshot.reviewCounts[.bOnly] == 1)
        assert(snapshot.reviewFields(matching: "A~1B~0C", status: .typeChanged).map(\.id) == [all[0].id])
        assert(snapshot.reviewFields(matching: "name", status: .typeChanged).isEmpty)
        assert(snapshot.reviewFields(matching: "name", status: .changed).map(\.pointer) == ["/name"])
        assert(snapshot.reviewFields(matching: "new", status: .bOnly).map(\.pointer) == ["/new"])
        assert(snapshot.reviewFields(matching: "no-such-field").isEmpty)
        assert(snapshot.reviewFields(matching: "hidden").isEmpty)
        assert(snapshot.reviewFields(matching: "old").isEmpty)
        assert(snapshot.reviewFields(matching: "Changed").isEmpty)
        assert(snapshot.reviewReminder.contains("all 3 captured fields will be exported"))
        assert(snapshot.visibleIDs == Set(all.map(\.id)) && snapshot.selectedCount == 3)
        assert(snapshot.reviewFields(matching: "").map(\.id) == all.map(\.id))
        assert(snapshot.inspectorRequest(for: all[0].id)?.clearFilters == false)
        let report = try JSONParser.parse(Data(snapshot.render(detail: .summary, json: true).utf8)).serialized()
        assert(report.contains(#""rowCount":3"#) && report.contains(#""totalRowCount":4"#))
        let ordinary = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 3)
        assert(ordinary.reviewFields.isEmpty)
        print("PASS: captured pointer/status list and canonical order, case-insensitive escaped-pointer search/status intersection/empty recovery, no hidden/value/status search leakage, complete-snapshot status counts and membership/reminder retained, summary still exports all captured fields, visible request preserves filters")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
