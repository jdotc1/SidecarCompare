import XCTest
@testable import SidecarCore

final class RelativeChangeTests: XCTestCase {
    private func percent(_ a: String, _ b: String) throws -> String? {
        try DecimalNumber(token: b).relativeChangePercentage(from: DecimalNumber(token: a))
    }
    func testSignZeroAndRepeatingRatios() throws {
        XCTAssertEqual(try percent("8", "9"), "12.5")
        XCTAssertEqual(try percent("3", "4"), "33.333333")
        XCTAssertEqual(try percent("3", "2"), "-33.333333")
        XCTAssertEqual(try percent("-8", "-7"), "12.5")
        XCTAssertEqual(try percent("-8", "8"), "200")
        XCTAssertEqual(try percent("1", "1.0"), "0")
        XCTAssertNil(try percent("-0", "1"))
        XCTAssertNil(try percent("0", "0"))
    }
    func testRoundingAndExactLargeIntegers() throws {
        XCTAssertEqual(try percent("200000000", "200000001"), "0.000001")
        XCTAssertEqual(try percent("200000000", "199999999"), "-0.000001")
        XCTAssertEqual(try percent("1000000000", "1000000001"), "0")
        XCTAssertEqual(try percent("9007199254740992", "18014398509481984"), "100")
        XCTAssertEqual(try percent("9007199254740992", "9007199254740993"), "0")
    }
    func testExponentExtremes() throws {
        XCTAssertEqual(try percent("1e-400", "2e-400"), "100")
        XCTAssertEqual(try percent("1e400", "0"), "-100")
        XCTAssertEqual(try percent("1e400", "1e-400"), "-100")
        XCTAssertEqual(try percent("1e-400", "1e400"), String(repeating: "9", count: 800) + "e2")
    }
}
