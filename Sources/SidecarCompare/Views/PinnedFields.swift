/// Session-only IDs; callers admit only rows in the bounded current comparison.
struct PinnedFields {
    private(set) var ids: Set<String> = []
    private var clearedIDs: Set<String>?
    private(set) var removedVisibleCount = 0
    var clearedCount: Int { removedVisibleCount == 0 ? clearedIDs?.count ?? 0 : 0 }
    var undoCount: Int { removedVisibleCount > 0 ? removedVisibleCount : clearedCount }
    mutating func invalidateUndo() { clearedIDs = nil; removedVisibleCount = 0 }
    mutating func clearForUndo() {
        guard !ids.isEmpty else { return }
        clearedIDs = ids
        removedVisibleCount = 0
        ids.removeAll()
    }
    mutating func removeVisibleForUndo(_ visibleIDs: [String]) {
        let removing = ids.intersection(visibleIDs)
        guard !removing.isEmpty else { return }
        clearedIDs = ids
        removedVisibleCount = removing.count
        ids.subtract(removing)
    }
    mutating func undoClear() {
        guard let clearedIDs else { return }
        ids = clearedIDs
        invalidateUndo()
    }
    func contains(_ id: String) -> Bool { ids.contains(id) }
    mutating func toggle(_ id: String) {
        invalidateUndo()
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
    mutating func add(_ visibleIDs: [String]) { invalidateUndo(); ids.formUnion(visibleIDs) }
    mutating func retain(_ valid: Set<String>) { invalidateUndo(); ids.formIntersection(valid) }
}
