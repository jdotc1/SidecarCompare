import Foundation

extension JSONValue {
    /// Shape of the parsed value, independent of serialized preview length.
    public var inspectorSummary: String {
        switch self {
        case .string(let value):
            if value.isEmpty { return "Empty string" }
            let count = value.count
            return "\(count.formatted()) decoded \(count == 1 ? "character" : "characters")"
        case .array(let values):
            return "\(values.count.formatted()) \(values.count == 1 ? "item" : "items")"
        case .object(let values):
            return "\(values.count.formatted()) \(values.count == 1 ? "member" : "members")"
        case .number: return "Exact JSON number"
        case .bool: return "JSON boolean"
        case .null: return "JSON null"
        }
    }
}
