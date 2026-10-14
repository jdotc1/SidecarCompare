import Foundation

/// JSON names compare by decoded UTF-8, not Swift's Unicode-normalized String equality.
public struct JSONKey: Sendable, Hashable, Comparable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ value: String) { rawValue = value }
    public init(stringLiteral value: String) { rawValue = value }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue.utf8.elementsEqual(rhs.rawValue.utf8) }
    public func hash(into hasher: inout Hasher) { for byte in rawValue.utf8 { hasher.combine(byte) } }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue.utf8.lexicographicallyPrecedes(rhs.rawValue.utf8) }
}

public indirect enum JSONValue: Sendable, Equatable {
    case object([JSONKey: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(DecimalNumber)
    case bool(Bool)
    case null

    public var typeName: String {
        switch self {
        case .object: "object"
        case .array: "array"
        case .string: "string"
        case .number: "number"
        case .bool: "boolean"
        case .null: "null"
        }
    }

    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.object(let a), .object(let b)): a == b
        case (.array(let a), .array(let b)): a == b
        case (.string(let a), .string(let b)): a.utf8.elementsEqual(b.utf8)
        case (.number(let a), .number(let b)): a == b
        case (.bool(let a), .bool(let b)): a == b
        case (.null, .null): true
        default: false
        }
    }

    /// Deterministic valid JSON. Numeric source lexemes are retained without Double conversion.
    public func serialized() -> String {
        switch self {
        case .object(let object):
            return "{" + object.keys.sorted().map { Self.quote($0.rawValue) + ":" + object[$0]!.serialized() }.joined(separator: ",") + "}"
        case .array(let values): return "[" + values.map { $0.serialized() }.joined(separator: ",") + "]"
        case .string(let value): return Self.quote(value)
        case .number(let value): return value.token
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }

    public var compactPreview: String {
        switch self {
        case .object(let value): return "{\(value.count) members}"
        case .array(let value): return "[\(value.count) items]"
        case .string(let value):
            let prefix = String(value.prefix(160))
            return Self.quote(prefix) + (prefix.utf8.count < value.utf8.count ? " …" : "")
        default: return serialized()
        }
    }

    public static func quote(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 8: result += "\\b"
            case 9: result += "\\t"
            case 10: result += "\\n"
            case 12: result += "\\f"
            case 13: result += "\\r"
            case 0...31, 0x2028...0x202E, 0x2066...0x2069:
                result += String(format: "\\u%04X", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}

public enum JSONLimits {
    public static let maxBytes = 2 * 1024 * 1024
    public static let maxValues = 20_000
    public static let maxDepth = 32
    public static let maxStringBytes = 65_536
    public static let maxKeyBytes = 512
    public static let maxNumberBytes = 256
    public static let maxExponent = 400
}

public struct SidecarError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
