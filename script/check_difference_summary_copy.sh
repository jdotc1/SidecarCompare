#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/difference-copy-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func row(_ a: String, _ b: String) throws -> ComparisonRow {
        try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8))).rows[0]
    }
    static func main() throws {
        let numeric = try row(#"{"x":9007199254740992e+0}"#, #"{"x":9007199254740993}"#)
        let text = try DifferenceSummaryCopy.text(row: numeric, policy: .exact)
        assert(text.contains("A · Original JSON number: 9007199254740992e+0"))
        assert(text.contains("Exact raw delta · B − A: 1"))
        assert(text.contains("Rule: Exact comparison"))
        let zero = try DifferenceSummaryCopy.text(row: row(#"{"x":0}"#, #"{"x":5}"#), policy: .exact)
        assert(zero.contains("Relative change unavailable: A is zero."))
        let percent = try DifferenceSummaryCopy.text(row: row(#"{"EchoTime":10}"#, #"{"EchoTime":15}"#), policy: .exact)
        assert(percent.contains("Relative change from A: 50%") && percent.contains("Canonical unit: s"))
        let unicode = try DifferenceSummaryCopy.text(row: row(#"{"x":"é"}"#, #"{"x":"e\u0301"}"#), policy: .exact)
        assert(unicode.contains(#"Changed: \u00E9"#) && unicode.contains(#"Changed: e\u0301"#))
        let long = try DifferenceSummaryCopy.text(row: row("{\"x\":\"" + String(repeating: "a", count: 100) + "\"}", "{\"x\":\"" + String(repeating: "b", count: 100) + "\"}"), policy: .exact)
        assert(long.contains("100 differing Unicode scalars") && long.contains("[span truncated]"))
        let missing = try DifferenceSummaryCopy.text(row: row("{}", #"{"x":null}"#), policy: .exact)
        assert(missing.contains("A type: missing — field absent") && missing.contains("B type: null"))
        let boundary = try DifferenceSummaryCopy.text(row: numeric, policy: .exact, limit: text.utf8.count)
        assert(boundary == text)
        do { _ = try DifferenceSummaryCopy.text(row: numeric, policy: .exact, limit: text.utf8.count - 1); fatalError("Accepted excess") }
        catch is SidecarError { }
        print("PASS: exact original numbers/delta/relative/zero/unit, bounded Unicode excerpts, missing/null, policy, all-or-nothing byte boundary")
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$ROOT/Sources/SidecarCompare/Views/DifferenceSummaryCopy.swift" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
