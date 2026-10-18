import Foundation
import Observation
import SidecarCore

struct FullTableSearchRequest: Hashable, Sendable {
    let sources: [UUID?]
    let policy: String
    let query: Data
    let enabled: Bool
    var side: FullValueSearchSide = .both
    var needsSearch: Bool { enabled && !query.isEmpty }
}

@Observable @MainActor
final class FullTableSearchState {
    private var request: FullTableSearchRequest?
    private var generation = UUID()
    private var ids: Set<String>?
    private var error: String?

    func matches(for expected: FullTableSearchRequest) -> Set<String>? {
        request == expected ? ids : nil
    }
    func failure(for expected: FullTableSearchRequest) -> String? {
        request == expected ? error : nil
    }
    func pending(for expected: FullTableSearchRequest) -> Bool {
        expected.needsSearch && matches(for: expected) == nil && failure(for: expected) == nil
    }

    func run(_ expected: FullTableSearchRequest, rows: [ComparisonRow],
             operation: (@Sendable ([ComparisonRow], String) async throws -> Set<String>)? = nil) async {
        guard !Task.isCancelled else { return }
        let token = UUID()
        generation = token; request = expected; ids = nil; error = nil
        guard expected.needsSearch else { return }
        let query = String(decoding: expected.query, as: UTF8.self)
        let worker = Task.detached(priority: .userInitiated) {
            if let operation { return try await operation(rows, query) }
            return try FullValueTableSearch.matchingIDs(rows: rows, query: query, side: expected.side)
        }
        do {
            let found = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled, generation == token, request == expected else { return }
            ids = found
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, generation == token, request == expected else { return }
            self.error = "Full-value search could not be completed. Clear or change the search to try again."
        }
    }
}
