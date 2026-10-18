#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/visible-inspector-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        let comparison = try Comparator.compare(a: JSONParser.parse(Data(#"{"selected":1,"outside":0}"#.utf8)), b: JSONParser.parse(Data(#"{"selected":2,"outside":1}"#.utf8)))
        let target = comparison.rows.first { $0.path == "/selected" }!
        let outside = comparison.rows.first { $0.path == "/outside" }!
        let snapshot = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 1, visibleIDs: [target.id])
        let request = snapshot.inspectorRequest(for: target.id)!
        assert(request.id == target.id && !request.requiresPin && !request.clearFilters)
        assert(request.isValid(currentSourceIDs: [], currentRowIDs: [target.id, outside.id], pins: []))
        assert(snapshot.inspectorRequest(for: outside.id) == nil && snapshot.inspectorRequest(for: "stale") == nil)
        assert(!request.isValid(currentSourceIDs: [UUID()], currentRowIDs: [target.id], pins: []))
        assert(!request.isValid(currentSourceIDs: [], currentRowIDs: [outside.id], pins: []))
        let source = UUID()
        let bound = ExportInspectorRequest(id: target.id, clearFilters: false, requiresPin: false, sourceIDs: [source])
        assert(bound.isValid(currentSourceIDs: [source], currentRowIDs: [target.id], pins: []))
        assert(!bound.isValid(currentSourceIDs: [UUID()], currentRowIDs: [target.id], pins: []))
        let invalid = ExportInspectorRequest(id: target.id, clearFilters: true, requiresPin: false, sourceIDs: [])
        assert(!invalid.isValid(currentSourceIDs: [], currentRowIDs: [target.id], pins: []))
        let pinned = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 0, pinnedIDs: [target.id])
        let pinRequest = pinned.inspectorRequest(for: target.id)!
        assert(pinRequest.requiresPin && pinRequest.clearFilters)
        assert(!pinRequest.isValid(currentSourceIDs: [], currentRowIDs: [target.id], pins: []))
        assert(pinRequest.isValid(currentSourceIDs: [], currentRowIDs: [target.id], pins: [target.id]))
        assert(snapshot.reviewFields(matching: "no-match").isEmpty && snapshot.inspectorRequest(for: target.id) != nil)
        assert(snapshot.visibleIDs == [target.id] && snapshot.selectedCount == 1)
        let ordinary = ExportSnapshot(comparison: comparison, documents: [], visibleRowCount: 2)
        assert(ordinary.inspectorRequest(for: target.id) == nil)
        print("PASS: visible captured/unpinned target direct request, outside/stale target rejection, source identity/current comparison validation, no visible-filter clearing, pinned authorization retained, review search independent of membership, ordinary export has no review request")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Services/NativeReportSave.swift" "$ROOT/Sources/SidecarCompare/Views/ExportSheet.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
