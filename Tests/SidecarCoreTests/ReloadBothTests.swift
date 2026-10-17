import Foundation
import XCTest
@testable import SidecarCore

private actor ReloadPairLoader {
    private var pending: [String: CheckedContinuation<SidecarDocument, Error>] = [:]
    func load(_ url: URL) async throws -> SidecarDocument {
        try await withCheckedThrowingContinuation { pending[url.lastPathComponent] = $0 }
    }
    var ready: Bool { pending.count == 2 }
    func finish(_ key: String, result: Result<SidecarDocument, Error>) {
        pending.removeValue(forKey: key)?.resume(with: result)
    }
}

@MainActor
final class ReloadBothTests: XCTestCase {
    private func document(_ side: String, _ number: String) throws -> SidecarDocument {
        SidecarDocument(value: try JSONParser.parse(Data("{\"EchoTime\":\(number)}".utf8)),
                        displayName: side, sourceURL: URL(fileURLWithPath: "/synthetic/\(side)"))
    }
    private func wait(_ predicate: @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await predicate()) {
            if ContinuousClock.now > deadline { XCTFail("Timed out"); throw SidecarError("Test timeout") }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    private func prepared(_ loader: ReloadPairLoader) async throws -> ComparisonSession {
        let session = ComparisonSession(loader: { try await loader.load($0) })
        session.replace(a: try document("A", "1"), b: try document("B", "2"))
        session.setPolicy(try ComparisonPolicy(relativeTolerance: "0.01"))
        try await wait { !session.isBusy }
        session.reloadBoth()
        try await wait { await loader.ready }
        XCTAssertNil(session.comparison)
        XCTAssertTrue(session.isLoading(.a)); XCTAssertTrue(session.isLoading(.b))
        return session
    }
    func testReloadBothWaitsForNewPairAndKeepsPolicy() async throws {
        let loader = ReloadPairLoader(), session = try await prepared(loader)
        await loader.finish("A", result: .success(try document("A", "3")))
        try await wait { !session.isLoading(.a) }
        XCTAssertNil(session.comparison); XCTAssertTrue(session.isLoading(.b))
        await loader.finish("B", result: .success(try document("B", "7")))
        try await wait { !session.isBusy }
        XCTAssertEqual(session.comparison?.rows.first?.delta?.canonicalString, "4")
        XCTAssertEqual(session.policy.relativeTolerance.token, "0.01")
    }
    func testReloadBothEitherOrBothFailuresKeepNoStaleComparison() async throws {
        for failures in [[FileSlot.a], [.b], [.a, .b]] {
            let loader = ReloadPairLoader(), session = try await prepared(loader)
            for slot in [FileSlot.a, .b] {
                let key = slot == .a ? "A" : "B"
                await loader.finish(key, result: failures.contains(slot)
                    ? .failure(CocoaError(.fileReadNoSuchFile)) : .success(try document(key, "5")))
            }
            try await wait { !session.isBusy }
            XCTAssertNil(session.comparison)
            for slot in [FileSlot.a, .b] {
                XCTAssertEqual(session.document(for: slot) == nil, failures.contains(slot))
                XCTAssertEqual(session.error(for: slot) != nil, failures.contains(slot))
            }
        }
    }
    func testReloadBothClearRejectsLateCompletions() async throws {
        let loader = ReloadPairLoader(), session = try await prepared(loader)
        session.clear()
        await loader.finish("A", result: .success(try document("A", "3")))
        await loader.finish("B", result: .success(try document("B", "7")))
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(session.a); XCTAssertNil(session.b); XCTAssertNil(session.comparison)
        XCTAssertFalse(session.isBusy)
    }
}
