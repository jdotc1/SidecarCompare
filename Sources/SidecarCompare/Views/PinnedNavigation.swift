/// Navigation follows the already-filtered and sorted table without changing its view.
struct PinnedNavigation {
    let visibleIDs: [String]
    let pinnedIDs: Set<String>
    let selection: String?

    var visiblePins: [String] { visibleIDs.filter { pinnedIDs.contains($0) } }
    func target(forward: Bool) -> String? {
        let index = visibleIDs.firstIndex { $0 == selection }
        if forward {
            return visibleIDs.dropFirst(index.map { $0 + 1 } ?? 0).first { pinnedIDs.contains($0) }
        }
        return visibleIDs.prefix(index ?? visibleIDs.count).reversed().first { pinnedIDs.contains($0) }
    }
    var position: String {
        let pins = visiblePins
        if let index = pins.firstIndex(where: { $0 == selection }) {
            return "Pinned field \(index + 1) of \(pins.count) in this view"
        }
        return "\(pins.count) pinned field\(pins.count == 1 ? "" : "s") in this view · select a pin"
    }
}
