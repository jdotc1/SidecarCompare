import Foundation
import XCTest
@testable import SidecarCore

final class ReloadURLTests: XCTestCase {
    func testReaderRetainsOriginalSelectedURLForReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("input.json")
        try Data("{}".utf8).write(to: file)
        let selected = URL(fileURLWithPath: directory.path + "/./input.json")
        let document = try SidecarReader.read(selected)
        XCTAssertEqual(document.sourceURL?.absoluteString, selected.absoluteString,
                       "Retain the selected URL; deriving a replacement loses sandbox access metadata.")
    }
}
