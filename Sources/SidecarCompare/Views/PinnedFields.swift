/// Session-only IDs; callers admit only rows in the bounded current comparison.
struct PinnedFields {
    private(set) var ids: Set<String> = []
    private var clearedIDs: Set<String>?
    var clearedCount: Int { clearedIDs?.count ?? 0 }
    mutating func invalidateUndo() { clearedIDs = nil }
    mutating func clearForUndo() {
        guard !ids.isEmpty else { return }
        clearedIDs = ids
        ids.removeAll()
    }
    mutating func undoClear() {
        guard let clearedIDs else { return }
        ids = clearedIDs
        self.clearedIDs = nil
    }
    func contains(_ id: String) -> Bool { ids.contains(id) }
    mutating func toggle(_ id: String) {
        invalidateUndo()
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
    mutating func add(_ visibleIDs: [String]) { invalidateUndo(); ids.formUnion(visibleIDs) }
    mutating func retain(_ valid: Set<String>) { invalidateUndo(); ids.formIntersection(valid) }
}
