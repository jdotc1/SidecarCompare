import Foundation
import XCTest
@testable import SidecarCore

final class ResourceBudgetTests: XCTestCase {
    func parse(_ text: String) throws -> JSONValue { try JSONParser.parse(Data(text.utf8)) }
    func object(prefix: String, count: Int) -> String {
        "{" + (0..<count).map { "\"\(prefix)\($0)\":0" }.joined(separator: ",") + "}"
    }
    func nested(_ object: String, count: Int, keyLength: Int) -> String {
        let opening = "{\"" + String(repeating: "k", count: keyLength) + "\":"
        return String(repeating: opening, count: count) + object + String(repeating: "}", count: count)
    }
    func testCombinedRowBudgetRejectsRatherThanTruncates() throws {
        let a = try parse(object(prefix: "a", count: 10_001))
        let b = try parse(object(prefix: "b", count: 10_001))
        XCTAssertThrowsError(try Comparator.compare(a: a, b: b))
    }
    func testExpandedPathLengthBudget() throws {
        let value = try parse(nested("{\"x\":0}", count: 5, keyLength: 512))
        XCTAssertThrowsError(try Comparator.compare(a: value, b: value))
    }
    func testAggregateExpandedPathBudget() throws {
        let value = try parse(nested(object(prefix: "x", count: 2_000), count: 3, keyLength: 500))
        XCTAssertThrowsError(try Comparator.compare(a: value, b: value))
    }
    func testSupportedComparisonBoundariesAreNotRejected() throws {
        let path = try parse(nested("0", count: 4, keyLength: 511))
        XCTAssertEqual(try Comparator.compare(a: path, b: path).rows[0].path.utf8.count, 2_048)
        let a = try parse(object(prefix: "a", count: 10_000))
        let b = try parse(object(prefix: "b", count: 10_000))
        XCTAssertEqual(try Comparator.compare(a: a, b: b).rows.count, 20_000)
    }
    func testExactByteLimitAndOneOver() throws {
        let maximum = "{}" + String(repeating: " ", count: JSONLimits.maxBytes - 2)
        XCTAssertEqual(try parse(maximum), .object([:]))
        XCTAssertThrowsError(try parse(maximum + " "))
    }
    func testDecodedStringAndKeyLimitsUseUTF8Bytes() throws {
        let string = String(repeating: "é", count: JSONLimits.maxStringBytes / 2)
        XCTAssertNoThrow(try parse("{\"x\":\"" + string + "\"}"))
        XCTAssertThrowsError(try parse("{\"x\":\"" + string + "a\"}"))
        let key = String(repeating: "é", count: JSONLimits.maxKeyBytes / 2)
        XCTAssertNoThrow(try parse("{\"" + key + "\":0}"))
        XCTAssertThrowsError(try parse("{\"" + key + "a\":0}"))
    }
    func testValueLimitCountsRootAndArray() throws {
        let values = Array(repeating: "0", count: JSONLimits.maxValues - 2).joined(separator: ",")
        XCTAssertNoThrow(try parse("{\"x\":[" + values + "]}"))
        XCTAssertThrowsError(try parse("{\"x\":[" + values + ",0]}"))
    }
    func testNumericTokenAndExponentBounds() throws {
        let maximum = String(repeating: "9", count: JSONLimits.maxNumberBytes)
        XCTAssertNoThrow(try parse("{\"x\":" + maximum + "}"))
        XCTAssertThrowsError(try parse("{\"x\":" + maximum + "9}"))
        XCTAssertNoThrow(try parse("{\"x\":1e400,\"y\":1e-400}"))
        XCTAssertThrowsError(try parse("{\"x\":1e-401}"))
    }
    func testDepthBoundaryCountsRootAsZero() throws {
        XCTAssertNoThrow(try parse(nested("0", count: 32, keyLength: 1)))
        XCTAssertThrowsError(try parse(nested("0", count: 33, keyLength: 1)))
    }
}
