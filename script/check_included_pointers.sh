#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/included-pointers-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(#"{"a/b~c":1,"e\u0301":0,"hidden":null,"outside":0}"#.utf8)), b: JSONParser.parse(Data(#"{"a/b~c":true,"é":1,"hidden":null,"outside":1}"#.utf8)))
        let selected = Set(comparison.rows.filter { $0.path != "/outside" }.map(\.id))
        let visible = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 4, visibleIDs: selected)
        assert(visible.reviewFields(matching: "no-match", status: .typeChanged).isEmpty)
        let copy = try visible.includedPointers()
        assert(copy.count == 4)
        let expected = "/a~1b~0c\n/e\u{301}\n/hidden\n/é"
        assert(Data(copy.text.utf8) == Data(expected.utf8))
        let pinned = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0, pinnedIDs: selected)
        assert(pinned.reviewFields.allSatisfy(\.hidden))
        let hiddenCopy = try pinned.includedPointers()
        assert(Data(hiddenCopy.text.utf8) == Data(copy.text.utf8) && hiddenCopy.count == 4)
        let boundary = try visible.includedPointers(limit: copy.text.utf8.count)
        assert(Data(boundary.text.utf8) == Data(copy.text.utf8))
        do { _ = try visible.includedPointers(limit: copy.text.utf8.count - 1); fatalError("Oversize/partial accepted") } catch let error as SidecarError { assert(error.message.contains("Clipboard") || error.message.contains("clipboard")) }
        let empty = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0, visibleIDs: [])
        do { _ = try empty.includedPointers(); fatalError("Empty accepted") } catch is SidecarError { }
        let ordinary = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 4)
        do { _ = try ordinary.includedPointers(); fatalError("Unscoped accepted") } catch is SidecarError { }
        let mixed = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 4, pinnedIDs: selected, visibleIDs: selected)
        do { _ = try mixed.includedPointers(); fatalError("Ambiguous accepted") } catch is SidecarError { }
        assert(visible.visibleIDs == selected && visible.selectedCount == 4 && pinned.pinnedIDs == selected)
        print("PASS: copies complete captured set despite empty review, hidden pins included, raw RFC6901/Unicode preserved in canonical order, exact UTF8 boundary and whole-output rejection, empty/unscoped/ambiguous rejection, membership unchanged")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/PinnedPointerCopy.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
