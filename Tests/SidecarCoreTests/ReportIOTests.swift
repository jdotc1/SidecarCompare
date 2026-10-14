import Foundation
import XCTest
@testable import SidecarCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class ReportTests: XCTestCase {
    func comparison() throws -> Comparison {
        try Comparator.compare(a: JSONParser.parse(Data(#"{"PatientName":"SYNTHETIC_SECRET","EchoTime":0.08,"huge":9007199254740993}"#.utf8)), b: JSONParser.parse(Data(#"{"PatientName":"SYNTHETIC_CHANGED","EchoTime":0.09,"missing":null}"#.utf8)))
    }
    func testSummaryContainsNoInputNamesOrValues() throws {
        for text in [ReportRenderer.json(try comparison(), detail: .summary), ReportRenderer.text(try comparison(), detail: .summary)] {
            for forbidden in ["PatientName", "SYNTHETIC", "EchoTime", "9007199254740993"] {
                XCTAssertFalse(text.contains(forbidden), forbidden)
            }
        }
    }
    func testDetailedReportPreservesTypesPrecisionAndMissingness() throws {
        let text = ReportRenderer.json(try comparison(), detail: .full)
        XCTAssertTrue(text.contains("9007199254740993"))
        XCTAssertTrue(text.contains("SYNTHETIC_SECRET"))
        let root = try JSONParser.parse(Data(text.utf8))
        guard case .object(let object) = root, case .array(let rows) = object["rows"] else { return XCTFail("rows required") }
        XCTAssertEqual(rows.count, 4)
        guard case .object(let row) = rows.last, case .object(let a) = row["a"] else { return XCTFail("typed missingness required") }
        XCTAssertEqual(a["present"], .bool(false))
        XCTAssertNil(a["value"])
    }
    func testEmbeddedPathsRemainInFullReportButNotSummary() throws {
        let raw = #"{"SourceFile":"/SYNTHETIC_PATIENT/path/image.dcm","IntendedFor":["sub-synthetic/anat/image.nii.gz"]}"#
        let value = try JSONParser.parse(Data(raw.utf8))
        let result = try Comparator.compare(a: value, b: value)
        for text in [ReportRenderer.json(result, detail: .full), ReportRenderer.text(result, detail: .full)] {
            XCTAssertTrue(text.contains("/SYNTHETIC_PATIENT/path/image.dcm"))
        }
        for text in [ReportRenderer.json(result, detail: .summary), ReportRenderer.text(result, detail: .summary)] {
            XCTAssertFalse(text.contains("SYNTHETIC_PATIENT"))
            XCTAssertFalse(text.contains("SourceFile"))
        }
        XCTAssertTrue(ReportRenderer.privacyNote.contains("embedded filenames and paths"))
    }
    func testTextReportIncludesVersionedComparisonRule() throws {
        let text = ReportRenderer.text(try comparison(), detail: .summary)
        XCTAssertTrue(text.contains("Catalog revision: " + FieldCatalog.revision))
        XCTAssertTrue(text.contains("abs(B-A) <= r * max(abs(A), abs(B))"))
        XCTAssertTrue(text.contains("curated MRI quantities only"))
    }
    func testReportsDeterministicAndNotFilterDependent() throws {
        let result = try comparison()
        _ = result.filtered(search: "doesnotexist", differencesOnly: true, category: nil)
        XCTAssertEqual(ReportRenderer.json(result, detail: .full), ReportRenderer.json(result, detail: .full))
        XCTAssertTrue(ReportRenderer.json(result, detail: .full).contains("PatientName"))
    }
}

final class IOTests: XCTestCase {
    func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
    func testBoundedReadAndWrite() throws {
        try withDirectory { directory in
            let input = directory.appendingPathComponent("a file.json")
            let data = Data(#"{"EchoTime":0.085}"#.utf8)
            try data.write(to: input)
            let document = try SidecarReader.read(input)
            XCTAssertEqual(document.value, try JSONParser.parse(data))
            let report = directory.appendingPathComponent("report.json")
            try ReportWriter.write(Data("{}".utf8), to: report, protecting: [document])
            XCTAssertEqual(try Data(contentsOf: input), data)
            XCTAssertEqual(try Data(contentsOf: report), Data("{}".utf8))
        }
    }
    func testRejectsInputOverwriteSymlinkAndHardlink() throws {
        try withDirectory { directory in
            let input = directory.appendingPathComponent("input.json")
            let data = Data(#"{"x":1}"#.utf8)
            try data.write(to: input)
            let document = try SidecarReader.read(input)
            let symbolic = directory.appendingPathComponent("symbolic.json")
            let hard = directory.appendingPathComponent("hard.json")
            try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: input)
            try FileManager.default.linkItem(at: input, to: hard)
            for target in [input, symbolic, hard] {
                XCTAssertThrowsError(try ReportWriter.write(Data("{}".utf8), to: target, protecting: [document]))
            }
            XCTAssertEqual(try Data(contentsOf: input), data)
        }
    }
    func testRejectsUnrelatedAndDanglingDestinationSymlinks() throws {
        try withDirectory { directory in
            let victim = directory.appendingPathComponent("unrelated.json")
            let original = Data("original".utf8)
            try original.write(to: victim)
            for name in ["unrelated.json", "missing.json"] {
                let link = directory.appendingPathComponent("link-" + name)
                let destination = directory.appendingPathComponent(name)
                try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
                XCTAssertThrowsError(try ReportWriter.write(Data("report".utf8), to: link, protecting: []))
            }
            XCTAssertEqual(try Data(contentsOf: victim), original)
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("missing.json").path))
        }
    }
    func testRejectsDirectoriesLargeFilesAndNonLocalURLs() throws {
        try withDirectory { directory in
            XCTAssertThrowsError(try SidecarReader.read(directory))
            let large = directory.appendingPathComponent("large.json")
            try Data(repeating: 32, count: JSONLimits.maxBytes + 1).write(to: large)
            XCTAssertThrowsError(try SidecarReader.read(large))
            XCTAssertThrowsError(try SidecarReader.read(URL(string: "https://example.invalid/file.json")!))
        }
    }
    func testFIFOIsRejectedWithoutBlocking() throws {
        try withDirectory { directory in
            let fifo = directory.appendingPathComponent("pipe.json")
            XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
            XCTAssertThrowsError(try SidecarReader.read(fifo))
        }
    }
    func testErrorsDoNotContainSelectedPathOrJSONData() throws {
        try withDirectory { directory in
            let input = directory.appendingPathComponent("SYNTHETIC_PATIENT.json")
            try Data(#"{"SECRET": bad}"#.utf8).write(to: input)
            do { _ = try SidecarReader.read(input); XCTFail("must fail") }
            catch { XCTAssertFalse(error.localizedDescription.contains("SYNTHETIC")); XCTAssertFalse(error.localizedDescription.contains("SECRET")) }
        }
    }
}
