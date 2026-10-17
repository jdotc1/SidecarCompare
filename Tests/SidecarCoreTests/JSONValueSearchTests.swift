import Foundation
import XCTest
@testable import SidecarCore

final class JSONValueSearchTests: XCTestCase {
    func testLiteralNonOverlappingSearchPreservesUnicodeAndCase() throws {
        let value = JSONValue.string("banana BANANA é e\u{301} 🙂🙂")
        XCTAssertEqual(try JSONValueSearch.find(value, query: "ana").count, 1)
        XCTAssertEqual(try JSONValueSearch.find(value, query: "BANANA").count, 1)
        XCTAssertEqual(try JSONValueSearch.find(value, query: "é").count, 1)
        XCTAssertEqual(try JSONValueSearch.find(value, query: "e\u{301}").count, 1)
        let emoji = try JSONValueSearch.find(value, query: "🙂")
        XCTAssertEqual(emoji.count, 2)
        XCTAssertEqual(emoji.excerpt(at: 1)?.match, "🙂")
        XCTAssertNil(emoji.excerpt(at: 2))
        XCTAssertEqual(try JSONValueSearch.find(value, query: "").count, 0)
    }
    func testFullValueBeyondPreviewWithBoundedExcerpt() throws {
        let value = JSONValue.string(String(repeating: "x", count: 9000) + "needle" + String(repeating: "y", count: 9000) + "needle")
        let result = try JSONValueSearch.find(value, query: "needle")
        XCTAssertEqual(result.count, 2)
        let excerpt = try XCTUnwrap(result.excerpt(at: 0))
        XCTAssertEqual(excerpt.bytePosition, 9002)
        XCTAssertEqual(excerpt.match, "needle")
        XCTAssertLessThan(excerpt.before.utf8.count + excerpt.after.utf8.count, 90)
        let long = try JSONValueSearch.find(.string(String(repeating: "é", count: 100)), query: String(repeating: "é", count: 100))
        XCTAssertTrue(try XCTUnwrap(long.excerpt(at: 0)).matchTruncated)
        XCTAssertEqual(long.excerpt(at: 0)?.match, String(repeating: "é", count: 40))
    }
    func testRawJSONIncludesEscapesContainersNullAndExactNumbers() throws {
        let value = try JSONParser.parse(Data(#"{"value":"line\nend","n":9007199254740993e0,"null":null}"#.utf8))
        XCTAssertEqual(try JSONValueSearch.find(value, query: #"\n"#).count, 1)
        XCTAssertEqual(try JSONValueSearch.find(value, query: "\n").count, 0)
        XCTAssertEqual(try JSONValueSearch.find(value, query: "9007199254740993e0").count, 1)
        XCTAssertEqual(try JSONValueSearch.find(.null, query: "null").count, 1)
        XCTAssertEqual(try JSONValueSearch.find(nil, query: "missing").count, 0)
        XCTAssertEqual(try JSONValueSearch.find(.array([.bool(true), .null]), query: "null").count, 1)
    }
    func testCancelledSearchDoesNotReturnResults() async throws {
        let task = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return try JSONValueSearch.find(.string("needle"), query: "needle")
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
    }
}
