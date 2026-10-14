import Foundation
import XCTest
@testable import SidecarCore

final class ComparisonTests: XCTestCase {
    func compare(_ a: String, _ b: String, tolerance: String = "0") throws -> Comparison {
        try Comparator.compare(a: JSONParser.parse(Data(a.utf8)), b: JSONParser.parse(Data(b.utf8)), policy: ComparisonPolicy(relativeTolerance: tolerance))
    }
    func testOrderDoesNotMatterAndPathsAreEscaped() throws {
        let result = try compare(#"{"a/b":1,"a~b":2}"#, #"{"a~b":2.0,"a/b":1}"#)
        XCTAssertEqual(result.rows.map(\.path), ["/a~1b", "/a~0b"])
        XCTAssertTrue(result.rows.allSatisfy { $0.status == .equal })
    }
    func testMissingNullAndEmptyContainersRemainDistinct() throws {
        let result = try compare(#"{"null":null,"array":[],"object":{},"sub":{"x":1}}"#, #"{"array":[],"object":{},"extra":null}"#)
        XCTAssertEqual(result.rows.first { $0.path == "/null" }?.status, .aOnly)
        XCTAssertEqual(result.rows.first { $0.path == "/sub" }?.status, .aOnly)
        XCTAssertEqual(result.rows.first { $0.path == "/array" }?.status, .equal)
        XCTAssertEqual(result.rows.first { $0.path == "/extra" }?.status, .bOnly)
    }
    func testArraysArePositionalAndContainerTypesAreNotCoerced() throws {
        let result = try compare(#"{"x":[1,2],"y":{"z":1},"z":true}"#, #"{"x":[2,1,3],"y":[1],"z":1}"#)
        XCTAssertEqual(result.rows.map(\.status), [.changed, .changed, .bOnly, .typeChanged, .typeChanged])
        XCTAssertEqual(result.rows[3].path, "/y")
    }
    func testKnownQuantitiesOnlyUseTolerance() throws {
        let result = try compare(#"{"EchoTime":0.1,"EchoNumber":100,"vendor":{"EchoTime":0.1}}"#, #"{"EchoTime":0.1001,"EchoNumber":101,"vendor":{"EchoTime":0.1001}}"#, tolerance: "0.01")
        XCTAssertEqual(result.rows.first { $0.path == "/EchoTime" }?.status, .withinTolerance)
        XCTAssertEqual(result.rows.first { $0.path == "/EchoNumber" }?.status, .changed)
        XCTAssertEqual(result.rows.first { $0.path == "/vendor/EchoTime" }?.status, .changed)
        XCTAssertNil(result.rows.first { $0.path == "/vendor/EchoTime" }?.unit)
    }
    func testExactToleranceBoundaryAndPrecision() throws {
        let boundary = try compare(#"{"EchoTime":9}"#, #"{"EchoTime":10}"#, tolerance: "0.1")
        XCTAssertEqual(boundary.rows[0].status, .withinTolerance)
        let outside = try compare(#"{"EchoTime":8.999999999999999999999999999999999}"#, #"{"EchoTime":10}"#, tolerance: "0.1")
        XCTAssertEqual(outside.rows[0].status, .changed)
        let big = try compare(#"{"EchoTime":9007199254740992}"#, #"{"EchoTime":9007199254740993}"#)
        XCTAssertEqual(big.rows[0].status, .changed)
        XCTAssertEqual(big.rows[0].delta?.canonicalString, "1")
    }
    func testTinyNumbersAndZero() throws {
        XCTAssertEqual(try compare(#"{"EchoTime":1e-400}"#, #"{"EchoTime":2e-400}"#, tolerance: "0.1").rows[0].status, .changed)
        XCTAssertEqual(try compare(#"{"EchoTime":0}"#, #"{"EchoTime":0.00001}"#, tolerance: "0.01").rows[0].status, .changed)
    }
    func testInvalidKnownShapesStayRaw() throws {
        let result = try compare(#"{"EchoTime":[0.1,"bad"]}"#, #"{"EchoTime":[0.1001,"bad"]}"#, tolerance: "0.01")
        XCTAssertEqual(result.rows[0].status, .changed)
        XCTAssertNil(result.rows[0].unit)
        XCTAssertFalse(result.rows[0].notes.isEmpty)
    }
    func testValidTimingArrayHasUnitsAndPerElementDeltas() throws {
        let result = try compare(#"{"SliceTiming":[0,0.2]}"#, #"{"SliceTiming":[0,0.201]}"#, tolerance: "0.01")
        XCTAssertEqual(result.rows[1].unit, "s")
        XCTAssertEqual(result.rows[1].status, .withinTolerance)
        XCTAssertEqual(result.rows[1].displayValue(side: .b, milliseconds: true), "201 ms")
        XCTAssertEqual(result.rows[1].delta?.canonicalString, "0.001")
    }
    func testPreparationRepetitionTimeAllowsArrayAndScalar() throws {
        let array = try compare(#"{"RepetitionTimePreparation":[1,2]}"#, #"{"RepetitionTimePreparation":[1,2.001]}"#, tolerance: "0.01")
        XCTAssertEqual(array.rows[1].unit, "s")
        XCTAssertEqual(array.rows[1].status, .withinTolerance)
        XCTAssertFalse(array.rows[1].notes.contains { $0.contains("unsupported value shape") })
        let scalar = try compare(#"{"RepetitionTimePreparation":2}"#, #"{"RepetitionTimePreparation":2.001}"#, tolerance: "0.01")
        XCTAssertEqual(scalar.rows[0].unit, "s")
        XCTAssertEqual(scalar.rows[0].status, .withinTolerance)
    }
    func testInvalidPoliciesRejected() {
        for token in ["-1", "1.01", "NaN", "Infinity", "", "0,\"injected\":1"] {
            XCTAssertThrowsError(try ComparisonPolicy(relativeTolerance: token))
        }
    }
    func testUnicodeDistinctKeysAcrossDocumentsDoNotMerge() throws {
        let result = try compare(#"{"é":1}"#, #"{"e\u0301":1}"#)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(Set(result.rows.map(\.id)).count, 2)
    }
    func testEmptyDocumentsAndDifferenceFilter() throws {
        XCTAssertEqual(try compare("{}", "{}").rows.count, 0)
        let result = try compare(#"{"EchoTime":1,"x":2}"#, #"{"EchoTime":1.001,"x":2}"#, tolerance: "0.01")
        XCTAssertEqual(result.filtered(search: "", differencesOnly: true, category: nil).count, 1)
        XCTAssertEqual(result.differenceCount, 1)
    }
    func testNoImplicitMillisecondsGuessOrGlobalUnitsOverride() throws {
        let result = try compare(#"{"EchoTime":0.08,"Units":"ms"}"#, #"{"EchoTime":80,"Units":"ms"}"#)
        XCTAssertEqual(result.rows[0].status, .changed)
        XCTAssertEqual(result.rows[0].unit, "s")
    }
}

final class DecimalTests: XCTestCase {
    func n(_ s: String) throws -> DecimalNumber { try DecimalNumber(token: s) }
    func testSignedArithmeticAndPowers() throws {
        for (a, b, expected) in [("1", "2", "-1"), ("-1", "2", "-3"), ("1", "-2", "3"), ("-1", "-2", "1"), ("0", "0", "0"), ("0.01", "10", "-9.99"), ("100", "99.9", "0.1")] {
            XCTAssertEqual(try n(a).subtracting(n(b)), try n(expected))
        }
        XCTAssertEqual(try n("0.085").scaled(byPowerOfTen: 3).canonicalString, "85")
        XCTAssertEqual(try n("-12.3").multiplied(by: n("0.1")), try n("-1.23"))
    }
}
