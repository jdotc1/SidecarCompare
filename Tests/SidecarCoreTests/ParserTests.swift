import Foundation
import XCTest
@testable import SidecarCore

final class ParserTests: XCTestCase {
    func parse(_ text: String) throws -> JSONValue { try JSONParser.parse(Data(text.utf8)) }
    func testTypedScalars() throws {
        let value = try parse(#"{"a":true,"b":1,"c":null,"d":"1"}"#)
        guard case .object(let object) = value else { return XCTFail("Object required") }
        XCTAssertEqual(object["a"], .bool(true))
        XCTAssertEqual(object["c"], .null)
        XCTAssertNotEqual(object["a"], object["b"])
        XCTAssertNotEqual(object["b"], object["d"])
    }
    func testExactNumbersAndLargeIntegers() throws {
        XCTAssertEqual(try parse(#"{"x":1}"#), try parse(#"{"x":1.0e0}"#))
        XCTAssertEqual(try parse(#"{"x":-0}"#), try parse(#"{"x":0.000}"#))
        XCTAssertNotEqual(try parse(#"{"x":9007199254740992}"#), try parse(#"{"x":9007199254740993}"#))
        XCTAssertNotEqual(try parse(#"{"x":1e-400}"#), try parse(#"{"x":0}"#))
    }
    func testDuplicatesRejectedIncludingEscapesAndCanonicalKeys() {
        for text in [#"{"x":1,"x":2}"#, #"{"x":1,"\u0078":2}"#, #"{"é":1,"e\u0301":2}"#] {
            XCTAssertThrowsError(try parse(text), text)
        }
    }
    func testValidEscapesAndNonNormalizedStrings() throws {
        XCTAssertEqual(try parse(#"{"x":"\ud83d\ude00"}"#), try parse(#"{"x":"😀"}"#))
        XCTAssertNotEqual(try parse(#"{"x":"é"}"#), try parse(#"{"x":"e\u0301"}"#))
    }
    func testRejectsInvalidGrammar() {
        let invalid = ["[]", "true", "null", "", "{}{}", #"{"x":01}"#, #"{"x":+1}"#, #"{"x":1.}"#, #"{"x":.1}"#, #"{"x":1e}"#, #"{"x":NaN}"#, #"{"x":Infinity}"#, #"{"x":1,}"#, #"{"x":[1,]}"#, #"{/* hi */}"#, #"{"x":"\ud800"}"#, #"{"x":"\udc00"}"#, #"{"x":"\q"}"#, "{\"x\":\"\n\"}"]
        for text in invalid { XCTAssertThrowsError(try parse(text), text) }
    }
    func testResourceLimitsAndInvalidUTF8() {
        XCTAssertThrowsError(try JSONParser.parse(Data(repeating: 32, count: JSONLimits.maxBytes + 1)))
        XCTAssertThrowsError(try JSONParser.parse(Data([123, 34, 120, 34, 58, 34, 255, 34, 125])))
        XCTAssertThrowsError(try parse("{\"x\":" + String(repeating: "[", count: 40) + "0" + String(repeating: "]", count: 40) + "}"))
        XCTAssertThrowsError(try parse(#"{"x":1e401}"#))
        XCTAssertThrowsError(try parse("{\"" + String(repeating: "k", count: 513) + "\":0}"))
    }
    func testOptionalBOMAndWhitespace() throws {
        XCTAssertEqual(try parse("\u{feff} \n{}\t"), .object([:]))
    }
    func testRoundTripPreservesNumericToken() throws {
        let value = try parse(#"{"x":1.2300e-3,"a":"line\nnext"}"#)
        XCTAssertTrue(value.serialized().contains("1.2300e-3"))
        XCTAssertEqual(try parse(value.serialized()), value)
    }
}
