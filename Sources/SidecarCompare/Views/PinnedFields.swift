/// Session-only IDs; callers admit only rows in the bounded current comparison.
struct PinnedFields {
    private(set) var ids: Set<String> = []
    func contains(_ id: String) -> Bool { ids.contains(id) }
    mutating func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }
    mutating func add(_ visibleIDs: [String]) { ids.formUnion(visibleIDs) }
    mutating func retain(_ valid: Set<String>) { ids.formIntersection(valid) }
}
