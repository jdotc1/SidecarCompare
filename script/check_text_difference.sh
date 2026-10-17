#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$(mktemp -d "$ROOT/dist/text-difference-check.XXXXXX")"
trap 'rm -rf "$CHECK"' EXIT
cat > "$CHECK/Check.swift" <<'SWIFT'
import Foundation
import SidecarCore
@main struct Check {
    static func main() throws {
        assert(tryResult("same", "same") == nil)
        let addition = try StringDifferenceSummary.compare(a: "abef", b: "abCDef")!
        assert(addition.kind == "Added text in B" && addition.a.changedScalarCount == 0 && addition.b.changed == "CD")
        assert(addition.sharedPrefixScalars == 2 && addition.sharedSuffixScalars == 2)
        let removal = try StringDifferenceSummary.compare(a: "abCDef", b: "abef")!
        assert(removal.kind == "Removed text from A" && removal.b.changedScalarCount == 0)
        let empty = try StringDifferenceSummary.compare(a: "", b: "x")!
        assert(empty.a.valueIsEmpty && empty.a.changed.isEmpty && empty.b.changed == "x")
        let emptyB = try StringDifferenceSummary.compare(a: "x", b: "")!
        assert(emptyB.b.valueIsEmpty && emptyB.kind == "Removed text from A")
        let unicode = try StringDifferenceSummary.compare(a: "caf\u{e9}", b: "cafe\u{301}")!
        assert(unicode.a.changed == #"\u00E9"# && unicode.b.changed == #"e\u0301"#)
        assert(unicode.a.changedScalarCount == 1 && unicode.b.changedScalarCount == 2)
        let emoji = try StringDifferenceSummary.compare(a: "😀", b: "😃")!
        assert(emoji.a.changed == #"\uD83D\uDE00"# && emoji.b.changed == #"\uD83D\uDE03"#)
        assert(emoji.a.changedScalarCount == 1)
        let control = try StringDifferenceSummary.compare(a: "\"\\\nA", b: "\"\\\nB")!
        assert(control.a.before.contains(#"\u000A"#) && control.a.before.contains(#"\""#) && control.a.before.contains(#"\\"#))
        let edits = try StringDifferenceSummary.compare(a: "a1b2c", b: "aXbYc")!
        assert(edits.a.changed == "1b2" && edits.b.changed == "XbY")
        let long = try StringDifferenceSummary.compare(a: String(repeating: "x", count: 9000) + "OLD" + String(repeating: "y", count: 9000), b: String(repeating: "x", count: 9000) + "NEW" + String(repeating: "y", count: 9000))!
        assert(long.sharedPrefixScalars == 9000 && long.sharedSuffixScalars == 9000)
        assert(long.a.changed == "OLD" && long.b.changed == "NEW" && !long.a.truncated)
        assert(long.a.before == "…" + String(repeating: "x", count: 40) && long.a.after == String(repeating: "y", count: 40) + "…")
        let bounded = try StringDifferenceSummary.compare(a: String(repeating: "a", count: 1000), b: String(repeating: "b", count: 1000))!
        assert(bounded.a.changedScalarCount == 1000 && bounded.a.changed.count == 80 && bounded.a.truncated)
        print("Text difference passed: equality, additions/removals, empty sides, canonical Unicode distinctions, surrogate pairs, escaped controls/quotes, honest multi-edit span, beyond-preview context and bounded truncation.")
    }
    static func tryResult(_ a: String, _ b: String) -> StringDifferenceSummary? {
        do { return try StringDifferenceSummary.compare(a: a, b: b) }
        catch { assertionFailure("Unexpected failure"); return nil }
    }
}
SWIFT
swiftc -target "$(uname -m)-apple-macosx15.0" -warnings-as-errors -parse-as-library -I "$ROOT/.build/out/Products/Debug" "$ROOT/.build/out/Products/Debug/SidecarCore.o" "$CHECK/Check.swift" -o "$CHECK/check"
"$CHECK/check"
