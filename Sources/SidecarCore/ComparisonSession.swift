import Foundation
#if os(macOS)
import Observation
#endif

/// Main-actor state only. File I/O, parsing and comparisons execute in cancellable worker tasks.
#if os(macOS)
@Observable
#endif
@MainActor
public final class ComparisonSession {
    public private(set) var a: SidecarDocument?
    public private(set) var b: SidecarDocument?
    public private(set) var comparison: Comparison?
    public private(set) var policy: ComparisonPolicy = .exact
    public private(set) var isComparing = false
    public private(set) var comparisonError: String?
    private var loadingA = false
    private var loadingB = false
    private var errorA: String?
    private var errorB: String?
    // An immutable reference is naturally ignored by Observation. Keep task handles
    // outside macro-generated accessors so deinitialization can cancel them safely.
    private let work = SessionWork()
    #if DEBUG
    public var acceptanceComparisonCheckpoint: (@Sendable () -> Void)?
    #endif
    private let loader: @Sendable (URL) async throws -> SidecarDocument

    public init(loader: @escaping @Sendable (URL) async throws -> SidecarDocument = { try await SidecarReader.load($0) }) {
        self.loader = loader
    }
    /// Identity warning only: snapshots of one file may still differ when read at different times.
    public var sameSource: Bool {
        guard let a, let b else { return false }
        if let left = a.sourceIdentity, let right = b.sourceIdentity, left == right { return true }
        if let left = a.sourceURL, let right = b.sourceURL {
            return left.standardizedFileURL == right.standardizedFileURL
        }
        return false
    }
    public var isBusy: Bool { loadingA || loadingB || isComparing }
    public var canSwap: Bool { !loadingA && !loadingB && (a != nil || b != nil) }
    public func isLoading(_ slot: FileSlot) -> Bool { slot == .a ? loadingA : loadingB }
    public func error(for slot: FileSlot) -> String? { slot == .a ? errorA : errorB }
    public func document(for slot: FileSlot) -> SidecarDocument? { slot == .a ? a : b }
    public var sourceDocuments: [SidecarDocument] { [a, b].compactMap { $0 } }

    public func load(_ url: URL, into slot: FileSlot) {
        cancel(slot)
        let generation = UUID()
        work.generations[slot] = generation
        setLoading(true, for: slot)
        let loader = self.loader
        work.loadTasks[slot] = Task { [weak self] in
            do {
                let document = try await loader(url)
                guard let self, self.work.generations[slot] == generation, !Task.isCancelled else { return }
                self.setDocument(document, for: slot)
                self.finishLoad(slot)
                self.recompare()
            } catch {
                guard let self, self.work.generations[slot] == generation else { return }
                if !(error is CancellationError) {
                    self.setError((error as? SidecarError)?.message ?? "The selected file could not be loaded.", for: slot)
                }
                self.finishLoad(slot)
            }
        }
    }
    /// Refresh both selected sources before publishing a comparison of the new pair.
    public func reloadBoth() {
        guard !isBusy, let left = a?.sourceURL, let right = b?.sourceURL else { return }
        load(left, into: .a)
        load(right, into: .b)
    }
    public func cancel(_ slot: FileSlot) {
        work.generations[slot] = UUID()
        work.loadTasks.removeValue(forKey: slot)?.cancel()
        setLoading(false, for: slot)
        setDocument(nil, for: slot)
        setError(nil, for: slot)
        invalidateComparison()
    }
    public func clear() {
        cancel(.a); cancel(.b)
        policy = .exact
    }
    public func replace(a: SidecarDocument, b: SidecarDocument) {
        clear()
        self.a = a; self.b = b
        recompare()
    }
    public func swap() {
        guard canSwap else { return }
        let oldA = a, oldError = errorA
        a = b; b = oldA; errorA = errorB; errorB = oldError
        recompare()
    }
    public func setPolicy(_ policy: ComparisonPolicy) {
        guard self.policy != policy else { return }
        self.policy = policy
        recompare()
    }

    private func recompare() {
        invalidateComparison()
        guard !loadingA, !loadingB, let a, let b else { return }
        let policy = policy, generation = work.comparisonGeneration
        isComparing = true
        #if DEBUG
        let checkpoint = acceptanceComparisonCheckpoint
        #endif
        work.comparisonTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                #if DEBUG
                return try Comparator.$acceptanceCheckpoint.withValue(checkpoint) {
                    try Comparator.compare(a: a.value, b: b.value, policy: policy)
                }
                #else
                return try Comparator.compare(a: a.value, b: b.value, policy: policy)
                #endif
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard let self, self.work.comparisonGeneration == generation, !Task.isCancelled else { return }
                self.comparison = result
                self.isComparing = false
                self.work.comparisonTask = nil
            } catch {
                guard let self, self.work.comparisonGeneration == generation else { return }
                self.isComparing = false
                self.work.comparisonTask = nil
                if !(error is CancellationError) {
                    self.comparisonError = (error as? SidecarError)?.message ?? "The comparison could not be completed."
                }
            }
        }
    }
    private func invalidateComparison() {
        work.comparisonGeneration = UUID()
        work.comparisonTask?.cancel(); work.comparisonTask = nil
        comparison = nil; comparisonError = nil; isComparing = false
    }
    private func finishLoad(_ slot: FileSlot) { setLoading(false, for: slot); work.loadTasks[slot] = nil }
    private func setDocument(_ document: SidecarDocument?, for slot: FileSlot) {
        if slot == .a { a = document } else { b = document }
    }
    private func setLoading(_ value: Bool, for slot: FileSlot) {
        if slot == .a { loadingA = value } else { loadingB = value }
    }
    private func setError(_ value: String?, for slot: FileSlot) {
        if slot == .a { errorA = value } else { errorB = value }
    }
}

/// Auxiliary task bookkeeping is not UI state. Its lifetime is owned by one session.
@MainActor
private final class SessionWork {
    var generations: [FileSlot: UUID] = [:]
    var loadTasks: [FileSlot: Task<Void, Never>] = [:]
    var comparisonGeneration = UUID()
    var comparisonTask: Task<Void, Never>?

    deinit {
        for task in loadTasks.values { task.cancel() }
        comparisonTask?.cancel()
    }
}
