import Foundation

/// Bounded session-only history of stable, byte-preserving row IDs.
struct InspectorHistory {
    private(set) var entries: [String] = []
    private(set) var index = -1
    private var reviews: [String: InspectorReviewBookmark] = [:]
    var back: Int? { index > 0 ? index - 1 : nil }
    var forward: Int? { index + 1 < entries.count ? index + 1 : nil }
    mutating func visit(_ id: String) {
        if entries.indices.contains(index), entries[index] == id { return }
        entries = Array(entries.prefix(index + 1))
        entries.append(id)
        if entries.count > 100 { entries.removeFirst(entries.count - 100) }
        index = entries.count - 1
        reviews = reviews.filter { entries.contains($0.key) }
    }
    mutating func move(to target: Int) {
        guard entries.indices.contains(target) else { return }
        index = target
    }
    mutating func retain(_ ids: Set<String>) {
        let prefixCount = entries.prefix(index + 1).filter { ids.contains($0) }.count
        entries.removeAll { !ids.contains($0) }
        index = prefixCount - 1
        reviews = reviews.filter { ids.contains($0.key) }
    }
    mutating func save(_ review: InspectorReviewBookmark, for id: String) {
        guard entries.contains(id) else { return }
        reviews[id] = review
    }
    func review(for id: String) -> InspectorReviewBookmark? { reviews[id] }
    mutating func clearReviews() { reviews.removeAll() }
}

struct InspectorReviewBookmark {
    let query: Data
    let revision: [UUID?]
    let expandedA: Bool
    let expandedB: Bool
    let collapsedA: Bool
    let collapsedB: Bool
    let match: Int
}
