#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-Debug}"
case "$MODE" in Debug|Release) ;; *) exit 2 ;; esac
CHECK="$(mktemp -d "$ROOT/dist/full-table-search-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
actor Gate {
    var held: [String: CheckedContinuation<Set<String>, Never>] = [:]
    var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    func pause(_ name: String) async -> Set<String> {
        await withCheckedContinuation { continuation in
            held[name] = continuation
            waiters.removeValue(forKey: name)?.resume()
        }
    }
    func started(_ name: String) async {
        if held[name] != nil { return }
        await withCheckedContinuation { waiters[name] = $0 }
    }
    func release(_ name: String, ids: Set<String>) { held.removeValue(forKey: name)!.resume(returning: ids) }
}
@main struct Check {
    @MainActor static func main() async throws {
        func check(_ condition: @autoclosure () throws -> Bool) throws { let passed = try condition(); precondition(passed) }
        let long = String(repeating: "x", count: 9000) + "needle"
        let a = #"{"Long":""# + long + #"","OnlyA":"alpha","Null":null,"Control":"line\nbreak","Unicode":"é"}"#
        let b = #"{"Long":""# + long.replacingOccurrences(of: "needle", with: "NEEDLE") + #"","OnlyB":"beta","Null":null,"Control":"line\nbreak","Unicode":"e\u0301"}"#
        let result = try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8)))
        func ids(_ query: String) throws -> Set<String> { try FullValueTableSearch.matchingIDs(rows: result.rows, query: query) }
        func paths(_ ids: Set<String>) -> [String] { result.rows.filter { ids.contains($0.id) }.map(\.path).sorted() }
        try check(paths(ids("needle")) == ["/Long"])
        try check(paths(ids("NEEDLE")) == ["/Long"])
        try check(ids("Needle").isEmpty)
        try check(paths(ids("alpha")) == ["/OnlyA"] && paths(ids("beta")) == ["/OnlyB"])
        try check(paths(ids("null")) == ["/Null"] && ids("<missing>").isEmpty)
        try check(paths(ids(#"\n"#)) == ["/Control"] && ids("\n").isEmpty)
        try check(paths(ids("é")) == ["/Unicode"] && paths(ids("e\u{301}")) == ["/Unicode"])
        try check(ids("/OnlyA").isEmpty)
        let matches = try ids("needle")
        try check(result.filtered(search: "needle", differencesOnly: false, category: nil, scope: .previews).isEmpty)
        try check(result.filtered(search: "needle", differencesOnly: true, category: nil, scope: .fullValues, fullValueMatches: matches).map(\.path) == ["/Long"])
        try check(result.filtered(search: "needle", differencesOnly: false, category: nil, scope: .fullValues).isEmpty)
        try check(result.filtered(search: "null", differencesOnly: true, category: nil, scope: .fullValues, fullValueMatches: ids("null")).isEmpty)
        let state = FullTableSearchState(), gate = Gate(), source = UUID()
        func request(_ query: String, sources: [UUID?]? = nil, policy: String = "0", enabled: Bool = true) -> FullTableSearchRequest {
            FullTableSearchRequest(sources: sources ?? [source], policy: policy, query: Data(query.utf8), enabled: enabled)
        }
        let firstRequest = request("needle"), secondRequest = request("beta")
        let old = Task { await state.run(firstRequest, rows: result.rows) { _, _ in await gate.pause("old") } }
        await gate.started("old")
        try check(state.pending(for: firstRequest) && state.matches(for: firstRequest) == nil)
        let middle = Task { await state.run(secondRequest, rows: result.rows) { _, _ in await gate.pause("middle") } }
        await gate.started("middle")
        let newest = Task { await state.run(firstRequest, rows: result.rows) { _, _ in await gate.pause("newest") } }
        await gate.started("newest")
        await gate.release("newest", ids: matches); await newest.value
        await gate.release("old", ids: []); await old.value
        await gate.release("middle", ids: []); await middle.value
        try check(state.matches(for: firstRequest) == matches && !state.pending(for: firstRequest))
        try check(state.matches(for: request("needle", sources: [UUID()])) == nil)
        try check(state.pending(for: request("needle", policy: "0.01")))
        let canceled = Task { await state.run(secondRequest, rows: result.rows) { _, _ in await gate.pause("cancel") } }
        await gate.started("cancel"); canceled.cancel()
        await state.run(request("", enabled: false), rows: [])
        await gate.release("cancel", ids: matches); await canceled.value
        try check(state.matches(for: secondRequest) == nil && !state.pending(for: request("", enabled: false)))
        await state.run(firstRequest, rows: result.rows) { _, _ in throw SidecarError("private failure detail") }
        try check(!state.pending(for: firstRequest) && state.failure(for: firstRequest) != nil && state.matches(for: firstRequest) == nil)
        try check(state.failure(for: firstRequest)?.contains("private") == false)
        let coreCancel = Task.detached {
            _ = await gate.pause("coreCancel")
            return try FullValueTableSearch.matchingIDs(rows: result.rows, query: "needle")
        }
        await gate.started("coreCancel"); coreCancel.cancel(); await gate.release("coreCancel", ids: [])
        do { _ = try await coreCancel.value; fatalError("Canceled core search succeeded") } catch is CancellationError { }
        print("PASS: full A/B raw JSON beyond9000, literal case/Unicode/escaping, absent vs null, no pointer matching, existing filters/no partial fallback; deterministic A→B→A stale generation rejection, pending/atomic results, scope/source/policy identities, cancellation, failure/no partials")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/$MODE" "$ROOT/.build/out/Products/$MODE/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/FullTableSearchState.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
