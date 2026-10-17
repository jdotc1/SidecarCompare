import XCTest
@testable import SidecarCore

final class JSONValueSummaryTests: XCTestCase {
    func testDecodedStringsAndScalarDistinctions() throws {
        XCTAssertEqual(JSONValue.string("").inspectorSummary, "Empty string")
        XCTAssertEqual(JSONValue.string("e\u{301}").inspectorSummary, "1 decoded character")
        XCTAssertEqual(JSONValue.string("👨‍👩‍👧‍👦x").inspectorSummary, "2 decoded characters")
        XCTAssertEqual(JSONValue.string("\n").inspectorSummary, "1 decoded character")
        XCTAssertEqual(JSONValue.number(try DecimalNumber(token: "9007199254740993e+0")).inspectorSummary, "Exact JSON number")
        XCTAssertEqual(JSONValue.null.inspectorSummary, "JSON null")
        XCTAssertEqual(JSONValue.bool(false).inspectorSummary, "JSON boolean")
    }
    func testImmediateContainerCounts() {
        XCTAssertEqual(JSONValue.array([]).inspectorSummary, "0 items")
        XCTAssertEqual(JSONValue.array([.array([.null, .null])]).inspectorSummary, "1 item")
        XCTAssertEqual(JSONValue.array([.null, .bool(true)]).inspectorSummary, "2 items")
        XCTAssertEqual(JSONValue.object([:]).inspectorSummary, "0 members")
        XCTAssertEqual(JSONValue.object(["a": .array([.null])]).inspectorSummary, "1 member")
        XCTAssertEqual(JSONValue.object(["a": .null, "b": .null]).inspectorSummary, "2 members")
    }
}
