import XCTest
@testable import SidecarCore

final class JSONSortValueTests: XCTestCase {
    private func number(_ token: String) throws -> JSONSortValue {
        JSONSortValue(.number(try DecimalNumber(token: token)))
    }
    func testExactNumbersAndEquivalentSpellings() throws {
        let tokens = ["10", "2", "9007199254740993", "9007199254740992", "-2", "-10", "0", "-1e-400", "1e-400"]
        let values = try tokens.map(number).sorted()
        let expected = try ["-10", "-2", "-1e-400", "0", "1e-400", "2", "10", "9007199254740992", "9007199254740993"].map(number)
        XCTAssertEqual(values, expected)
        XCTAssertEqual(try number("1.00"), try number("1e0"))
        XCTAssertEqual(try number("-0"), try number("0"))
        XCTAssertEqual(values.sorted(by: >), expected.reversed())
    }
    func testMixedTypesAndStrings() throws {
        let ordered = [JSONSortValue(nil), JSONSortValue(.null), JSONSortValue(.bool(false)),
                       JSONSortValue(.bool(true)), try number("2"), try number("10"),
                       JSONSortValue(.string("10")), JSONSortValue(.string("2")),
                       JSONSortValue(.array([])), JSONSortValue(.object([:]))]
        XCTAssertEqual(ordered.reversed().sorted(), ordered)
        XCTAssertNotEqual(JSONSortValue(.string("é")), JSONSortValue(.string("e\u{301}")))
    }
}
