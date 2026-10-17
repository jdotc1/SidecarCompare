import XCTest
@testable import SidecarCore

final class TableSearchScopeTests: XCTestCase {
    func testScopeSelectsPathsOrEitherPreview() {
        let rows = [
            ComparisonRow(path: "/needle", a: .string("left"), b: .string("right"), status: .changed, category: .other, unit: nil, notes: [], delta: nil),
            ComparisonRow(path: "/A", a: .string("NEEDLE"), b: .string("right"), status: .changed, category: .other, unit: nil, notes: [], delta: nil),
            ComparisonRow(path: "/B", a: nil, b: .string("needle"), status: .bOnly, category: .other, unit: nil, notes: [], delta: nil)]
        let comparison = Comparison(rows: rows, policy: .exact)
        XCTAssertEqual(comparison.filtered(search: "needle", differencesOnly: true, category: nil).map(\.path), ["/needle", "/A", "/B"])
        XCTAssertEqual(comparison.filtered(search: "needle", differencesOnly: true, category: nil, scope: .pointers).map(\.path), ["/needle"])
        XCTAssertEqual(comparison.filtered(search: "needle", differencesOnly: true, category: nil, scope: .previews).map(\.path), ["/A", "/B"])
        for scope in TableSearchScope.allCases {
            XCTAssertEqual(comparison.filtered(search: "", differencesOnly: true, category: nil, scope: scope).count, 3)
        }
    }
    func testPreviewScopeDoesNotSearchBeyondPreview() {
        let row = ComparisonRow(path: "/long", a: .string(String(repeating: "x", count: 1000) + "needle"), b: nil,
                                status: .aOnly, category: .other, unit: nil, notes: [], delta: nil)
        let comparison = Comparison(rows: [row], policy: .exact)
        XCTAssertTrue(comparison.filtered(search: "needle", differencesOnly: true, category: nil, scope: .previews).isEmpty)
    }
}
