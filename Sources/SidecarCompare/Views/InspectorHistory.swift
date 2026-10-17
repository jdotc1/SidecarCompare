/// Bounded session-only history of stable, byte-preserving row IDs.
struct InspectorHistory {
    private(set) var entries: [String] = []
    private(set) var index = -1
    var back: Int? { index > 0 ? index - 1 : nil }
    var forward: Int? { index + 1 < entries.count ? index + 1 : nil }
    mutating func visit(_ id: String) {
        if entries.indices.contains(index), entries[index] == id { return }
        entries = Array(entries.prefix(index + 1))
        entries.append(id)
        if entries.count > 100 { entries.removeFirst(entries.count - 100) }
        index = entries.count - 1
    }
    mutating func move(to target: Int) {
        guard entries.indices.contains(target) else { return }
        index = target
    }
    mutating func retain(_ ids: Set<String>) {
        let prefixCount = entries.prefix(index + 1).filter { ids.contains($0) }.count
        entries.removeAll { !ids.contains($0) }
        index = prefixCount - 1
    }
}
