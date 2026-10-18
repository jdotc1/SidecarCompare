#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-Debug}"
case "$MODE" in Debug|Release) ;; *) exit 2 ;; esac
CHECK="$(mktemp -d "$ROOT/dist/visible-export-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        let comparison = try Comparator.compare(
            a: JSONParser.parse(Data(#"{"a":9007199254740992,"b":null,"z":null}"#.utf8)),
            b: JSONParser.parse(Data(#"{"a":9007199254740993,"b":true,"z":null,"q":"kept"}"#.utf8)))
        var ids = Set(comparison.rows.filter { $0.path != "/b" }.map(\.id))
        let snapshot = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 3, visibleIDs: ids)
        ids.removeAll()
        assert(snapshot.selectedCount == 3 && snapshot.visibleIDs?.count == 3)
        let summary = try snapshot.render(detail: .summary, json: true)
        let full = try snapshot.render(detail: .full, json: true)
        let text = try snapshot.render(detail: .full, json: false)
        assert(text.contains("Selection: Visible fields only") && text.contains("Total comparison rows: 4"))
        assert(!text.contains("/b —") && text.contains("9007199254740993"))
        let boundary = try snapshot.render(detail: .full, json: true, limit: full.utf8.count)
        assert(boundary == full)
        do { _ = try snapshot.render(detail: .full, json: true, limit: full.utf8.count - 1); fatalError("Partial/oversize accepted") } catch is SidecarError { }
        let empty = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0, visibleIDs: [])
        let emptyJSON = try JSONParser.parse(Data(empty.render(detail: .summary, json: true).utf8))
        assert(emptyJSON.serialized().contains(#""rowCount":0"#))
        let mixed = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 3, pinnedIDs: [], visibleIDs: snapshot.visibleIDs)
        do { _ = try mixed.render(detail: .summary, json: true); fatalError("Ambiguous scope accepted") } catch is SidecarError { }
        print(summary, terminator: "")
        print(full, terminator: "")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/$MODE" "$ROOT/.build/out/Products/$MODE/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/PinnedPointerCopy.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check" > "$CHECK/output.jsonl"
python3 - "$CHECK/output.jsonl" <<'PY'
import json,sys
from decimal import Decimal
summary,full=[json.loads(line,parse_float=Decimal) for line in open(sys.argv[1])]
assert summary['rowCount']==3 and summary['totalRowCount']==4 and summary['differenceCount']==2
assert summary['selection']=='Visible fields only (snapshot of table filters)' and 'rows' not in summary
assert summary['counts']['Equal']==1 and summary['counts']['Changed']==1 and summary['counts']['B only']==1
assert [r['path'] for r in full['rows']]==['/a','/q','/z']
a,q,z=full['rows']
assert a['a']['value']==9007199254740992 and a['b']['value']==9007199254740993 and a['deltaBMinusA']==1
assert q['a']['present'] is False and q['b']['value']=='kept'
assert z['a']['present'] is True and z['a']['value'] is None
assert 'privacyWarning' in full and full['totalRowCount']==4
print('PASS: fixed visible membership including equal rows, summary counts/privacy, JSON/text scope and total, canonical order, exact original numbers/delta, missing/null, empty snapshot, conflicting scopes, exact UTF8 size boundary and whole-output rejection; independent Python JSON/integer oracle')
PY
