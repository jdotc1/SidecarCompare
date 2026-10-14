import Foundation

/// Strict, bounded UTF-8 JSON parser. Foundation number coercion and duplicate-key loss are avoided.
public struct JSONParser {
    private let bytes: [UInt8]
    private var index = 0
    private var values = 0

    public static func parse(_ data: Data) throws -> JSONValue {
        guard data.count <= JSONLimits.maxBytes else { throw SidecarError("JSON exceeds the 2 MiB input limit.") }
        guard String(data: data, encoding: .utf8) != nil else { throw SidecarError("Input is not valid UTF-8 JSON.") }
        var parser = Self(bytes: Array(data))
        if parser.bytes.starts(with: [0xEF, 0xBB, 0xBF]) { parser.index = 3 }
        let result = try parser.value(depth: 0)
        parser.whitespace()
        guard parser.index == parser.bytes.count else { throw parser.error("Unexpected content after the JSON object") }
        guard case .object = result else { throw SidecarError("A sidecar must have a top-level JSON object.") }
        return result
    }

    private mutating func value(depth: Int) throws -> JSONValue {
        try Task.checkCancellation()
        guard depth <= JSONLimits.maxDepth else { throw error("JSON nesting exceeds 32 levels") }
        values += 1
        guard values <= JSONLimits.maxValues else { throw error("JSON exceeds 20,000 values") }
        whitespace()
        guard let byte = current else { throw error("Unexpected end of JSON") }
        switch byte {
        case 123: return try object(depth: depth)
        case 91: return try array(depth: depth)
        case 34: return .string(try string(limit: JSONLimits.maxStringBytes))
        case 116: try literal("true"); return .bool(true)
        case 102: try literal("false"); return .bool(false)
        case 110: try literal("null"); return .null
        case 45, 48...57: return .number(try number())
        default: throw error("Invalid JSON value")
        }
    }

    private mutating func object(depth: Int) throws -> JSONValue {
        index += 1; whitespace()
        var result = [JSONKey: JSONValue]()
        var canonicalKeys = Set<String>()
        if consume(125) { return .object(result) }
        while true {
            guard current == 34 else { throw error("Expected an object member name") }
            let key = try string(limit: JSONLimits.maxKeyBytes)
            guard canonicalKeys.insert(key).inserted else { throw error("Duplicate or canonically equivalent object member name") }
            whitespace()
            guard consume(58) else { throw error("Expected a colon") }
            result[JSONKey(key)] = try value(depth: depth + 1)
            whitespace()
            if consume(125) { return .object(result) }
            guard consume(44) else { throw error("Expected a comma or closing brace") }
            whitespace()
        }
    }

    private mutating func array(depth: Int) throws -> JSONValue {
        index += 1; whitespace()
        var result = [JSONValue]()
        if consume(93) { return .array(result) }
        while true {
            result.append(try value(depth: depth + 1))
            whitespace()
            if consume(93) { return .array(result) }
            guard consume(44) else { throw error("Expected a comma or closing bracket") }
        }
    }

    private mutating func string(limit: Int) throws -> String {
        index += 1
        var out = [UInt8]()
        while let byte = current {
            index += 1
            if byte == 34 {
                guard let result = String(bytes: out, encoding: .utf8) else { throw error("Invalid UTF-8 string") }
                return result
            }
            guard byte >= 32 else { throw error("Unescaped control character") }
            if byte != 92 { out.append(byte) }
            else {
                guard let escaped = current else { throw error("Incomplete string escape") }
                index += 1
                switch escaped {
                case 34, 92, 47: out.append(escaped)
                case 98: out.append(8)
                case 102: out.append(12)
                case 110: out.append(10)
                case 114: out.append(13)
                case 116: out.append(9)
                case 117:
                    let first = try hexQuad()
                    let scalar: UInt32
                    if (0xD800...0xDBFF).contains(first) {
                        guard consume(92), consume(117) else { throw error("High surrogate lacks a low surrogate") }
                        let second = try hexQuad()
                        guard (0xDC00...0xDFFF).contains(second) else { throw error("Invalid low surrogate") }
                        scalar = 0x10000 + (first - 0xD800) * 1024 + second - 0xDC00
                    } else {
                        guard !(0xDC00...0xDFFF).contains(first) else { throw error("Unpaired low surrogate") }
                        scalar = first
                    }
                    guard let unicode = UnicodeScalar(scalar) else { throw error("Invalid Unicode scalar") }
                    out.append(contentsOf: String(unicode).utf8)
                default: throw error("Invalid string escape")
                }
            }
            guard out.count <= limit else { throw error("String or member name exceeds its supported byte limit") }
        }
        throw error("Unterminated JSON string")
    }

    private mutating func hexQuad() throws -> UInt32 {
        var result: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = current else { throw error("Incomplete Unicode escape") }
            let nibble: UInt32
            switch byte {
            case 48...57: nibble = UInt32(byte - 48)
            case 65...70: nibble = UInt32(byte - 55)
            case 97...102: nibble = UInt32(byte - 87)
            default: throw error("Invalid Unicode escape")
            }
            result = result * 16 + nibble; index += 1
        }
        return result
    }

    private mutating func number() throws -> DecimalNumber {
        let start = index
        while let byte = current, (48...57).contains(byte) || [45, 43, 46, 69, 101].contains(byte) {
            index += 1
            guard index - start <= JSONLimits.maxNumberBytes else { throw error("Number token exceeds 256 bytes") }
        }
        let token = String(decoding: bytes[start..<index], as: UTF8.self)
        do { return try DecimalNumber(token: token) }
        catch let problem as SidecarError { throw error(problem.message) }
    }

    private mutating func literal(_ text: String) throws {
        for byte in text.utf8 {
            guard consume(byte) else { throw error("Invalid JSON literal") }
        }
    }
    private var current: UInt8? { index < bytes.count ? bytes[index] : nil }
    private mutating func consume(_ byte: UInt8) -> Bool {
        guard current == byte else { return false }
        index += 1; return true
    }
    private mutating func whitespace() {
        while let byte = current, [9, 10, 13, 32].contains(byte) { index += 1 }
    }
    private func error(_ message: String) -> SidecarError { SidecarError("\(message) (byte \(index)).") }
}
