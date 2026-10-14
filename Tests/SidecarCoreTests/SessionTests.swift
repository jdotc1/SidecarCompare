import Foundation
import XCTest
@testable import SidecarCore

private actor ControlledLoader {
    var pending: [String: CheckedContinuation<SidecarDocument, Error>] = [:]
    func load(_ url: URL) async throws -> SidecarDocument {
        try await withCheckedThrowingContinuation { pending[url.lastPathComponent] = $0 }
    }
    func has(_ key: String) -> Bool { pending[key] != nil }
    func resolve(_ key: String, document: SidecarDocument) { pending.removeValue(forKey: key)?.resume(returning: document) }
}

@MainActor
final class SessionTests: XCTestCase {
    func document(_ name: String, _ value: String = "1") throws -> SidecarDocument {
        SidecarDocument(value: try JSONParser.parse(Data("{\"EchoTime\":\(value)}".utf8)), displayName: name)
    }
    func wait(_ predicate: @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await predicate()) {
            if ContinuousClock.now > deadline { XCTFail("Timed out waiting for state"); throw SidecarError("Test timeout") }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    func testSupersededLoaderCannotPublish() async throws {
        let loader = ControlledLoader()
        let session = ComparisonSession(loader: { try await loader.load($0) })
        session.load(URL(fileURLWithPath: "/old"), into: .a)
        try await wait { await loader.has("old") }
        session.load(URL(fileURLWithPath: "/new"), into: .a)
        try await wait { await loader.has("new") }
        await loader.resolve("new", document: try document("new"))
        try await wait { !session.isLoading(.a) }
        await loader.resolve("old", document: try document("old"))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(session.a?.displayName, "new")
    }
    func testClearInvalidatesInFlightLoadAndResetsPolicy() async throws {
        let loader = ControlledLoader()
        let session = ComparisonSession(loader: { try await loader.load($0) })
        session.setPolicy(try ComparisonPolicy(relativeTolerance: "0.1"))
        session.load(URL(fileURLWithPath: "/old"), into: .a)
        try await wait { await loader.has("old") }
        session.clear()
        await loader.resolve("old", document: try document("old"))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(session.a); XCTAssertNil(session.comparison)
        XCTAssertFalse(session.isBusy)
        XCTAssertEqual(session.policy, .exact)
    }
    func testComparisonSwapAndCurrentPolicy() async throws {
        let a = try document("A", "1"), b = try document("B", "1.001")
        let session = ComparisonSession()
        session.replace(a: a, b: b)
        try await wait { session.comparison != nil }
        XCTAssertEqual(session.comparison?.rows[0].status, .changed)
        session.setPolicy(try ComparisonPolicy(relativeTolerance: "0.01"))
        try await wait { session.comparison?.policy.relativeTolerance.token == "0.01" }
        XCTAssertEqual(session.comparison?.rows[0].status, .withinTolerance)
        session.swap()
        try await wait { session.comparison != nil }
        XCTAssertEqual(session.a?.displayName, "B")
        XCTAssertEqual(session.comparison?.rows[0].delta?.canonicalString, "-0.001")
    }
    func testFailedReplacementCannotLeaveOldComparisonVisible() async throws {
        let session = ComparisonSession(loader: { _ in throw CocoaError(.fileReadNoSuchFile) })
        session.replace(a: try document("A"), b: try document("B"))
        try await wait { session.comparison != nil }
        session.load(URL(fileURLWithPath: "/SYNTHETIC_SECRET"), into: .a)
        XCTAssertNil(session.a); XCTAssertNil(session.comparison)
        try await wait { !session.isLoading(.a) }
        XCTAssertNotNil(session.error(for: .a))
        XCTAssertFalse(session.error(for: .a)?.contains("SYNTHETIC_SECRET") ?? true)
    }
    func testRapidPolicyChangesAndClearNeverPublishStaleComparison() async throws {
        let session = ComparisonSession()
        session.replace(a: try document("A"), b: try document("B", "1.001"))
        for _ in 0..<25 {
            session.setPolicy(try ComparisonPolicy(relativeTolerance: "0.1"))
            session.setPolicy(.exact)
        }
        try await wait { session.comparison != nil }
        XCTAssertEqual(session.comparison?.policy, .exact)
        session.setPolicy(try ComparisonPolicy(relativeTolerance: "0.1"))
        session.clear()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(session.comparison); XCTAssertFalse(session.isBusy)
    }
    func testCancelSlotAndSwapGuardDuringLoading() async throws {
        let loader = ControlledLoader()
        let session = ComparisonSession(loader: { try await loader.load($0) })
        session.replace(a: try document("A"), b: try document("B"))
        session.load(URL(fileURLWithPath: "/pending"), into: .a)
        try await wait { await loader.has("pending") }
        session.swap()
        XCTAssertEqual(session.b?.displayName, "B")
        session.cancel(.a)
        await loader.resolve("pending", document: try document("pending"))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(session.a); XCTAssertFalse(session.isLoading(.a))
    }
    func testSameSourceIncludesHardlinksButNotEqualContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.json")
        let alias = directory.appendingPathComponent("alias.json")
        let copy = directory.appendingPathComponent("copy.json")
        let bytes = Data(#"{"EchoTime":0.1}"#.utf8)
        try bytes.write(to: original); try bytes.write(to: copy)
        try FileManager.default.linkItem(at: original, to: alias)
        let session = ComparisonSession()
        session.replace(a: try SidecarReader.read(original), b: try SidecarReader.read(alias))
        XCTAssertTrue(session.sameSource)
        session.replace(a: try SidecarReader.read(original), b: try SidecarReader.read(original))
        XCTAssertTrue(session.sameSource)
        session.replace(a: try SidecarReader.read(original), b: try SidecarReader.read(copy))
        XCTAssertFalse(session.sameSource)
        session.replace(a: try document("same name"), b: try document("same name"))
        XCTAssertFalse(session.sameSource)
        session.clear()
        XCTAssertFalse(session.sameSource)
    }

}
