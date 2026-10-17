import Foundation

/// Bounded arbitrary-precision decimal. Exact comparison/tolerance never uses binary floating point.
public struct DecimalNumber: Sendable, Equatable {
    public let token: String
    let negative: Bool
    let digits: [UInt8] // Most significant first; canonical coefficient, no trailing zeros.
    let exponent: Int

    public init(token: String) throws {
        let bytes = Array(token.utf8)
        guard !bytes.isEmpty, bytes.count <= JSONLimits.maxNumberBytes else {
            throw SidecarError("Number exceeds the supported token length.")
        }
        var index = 0
        if bytes[index] == 45 { index += 1 }
        guard index < bytes.count else { throw SidecarError("Invalid JSON number.") }
        if bytes[index] == 48 {
            index += 1
        } else {
            guard (49...57).contains(bytes[index]) else { throw SidecarError("Invalid JSON number.") }
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
        }
        if index < bytes.count && bytes[index] == 46 {
            index += 1
            let start = index
            while index < bytes.count && (48...57).contains(bytes[index]) { index += 1 }
            guard index > start else { throw SidecarError("Invalid number fraction.") }
        }
        var explicitExponent = 0
        if index < bytes.count && (bytes[index] == 69 || bytes[index] == 101) {
            index += 1
            var sign = 1
            if index < bytes.count && (bytes[index] == 43 || bytes[index] == 45) {
                if bytes[index] == 45 { sign = -1 }
                index += 1
            }
            let start = index
            while index < bytes.count && (48...57).contains(bytes[index]) {
                explicitExponent = explicitExponent * 10 + Int(bytes[index] - 48)
                guard explicitExponent <= JSONLimits.maxExponent else {
                    throw SidecarError("Number exponent magnitude exceeds 400.")
                }
                index += 1
            }
            guard index > start else { throw SidecarError("Invalid number exponent.") }
            explicitExponent *= sign
        }
        guard index == bytes.count else { throw SidecarError("Invalid JSON number.") }
        let mantissa = token.split(whereSeparator: { $0 == "e" || $0 == "E" })[0]
        let fractionCount = mantissa.firstIndex(of: ".").map { mantissa.distance(from: $0, to: mantissa.endIndex) - 1 } ?? 0
        let coefficient = mantissa.utf8.filter { (48...57).contains($0) }.map { $0 - 48 }
        let normalized = Self.normalize(coefficient, exponent: explicitExponent - fractionCount)
        self.token = token
        self.digits = normalized.0
        self.exponent = normalized.1
        self.negative = bytes[0] == 45 && normalized.0 != [0]
    }

    private init(negative: Bool, digits: [UInt8], exponent: Int) {
        let normalized = Self.normalize(digits, exponent: exponent)
        self.negative = negative && normalized.0 != [0]
        self.digits = normalized.0
        self.exponent = normalized.1
        self.token = Self.format(negative: self.negative, digits: normalized.0, exponent: normalized.1)
    }

    private static func normalize(_ raw: [UInt8], exponent: Int) -> ([UInt8], Int) {
        var value = Array(raw.drop(while: { $0 == 0 }))
        if value.isEmpty { return ([0], 0) }
        var power = exponent
        while value.last == 0 { value.removeLast(); power += 1 }
        return (value, power)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.negative == rhs.negative && lhs.digits == rhs.digits && lhs.exponent == rhs.exponent
    }
    public var isZero: Bool { digits == [0] }
    public var isNegative: Bool { negative }
    public var canonicalString: String { Self.format(negative: negative, digits: digits, exponent: exponent) }
    public func scaled(byPowerOfTen power: Int) -> Self {
        Self(negative: negative, digits: digits, exponent: exponent + power)
    }
    public var magnitude: Self { Self(negative: false, digits: digits, exponent: exponent) }

    public func magnitudeLessThanOrEqual(to other: Self) -> Bool { compareMagnitude(other) <= 0 }

    private func compareMagnitude(_ other: Self) -> Int {
        if isZero { return other.isZero ? 0 : -1 }
        if other.isZero { return 1 }
        let order = digits.count + exponent
        let otherOrder = other.digits.count + other.exponent
        if order != otherOrder { return order < otherOrder ? -1 : 1 }
        for i in 0..<max(digits.count, other.digits.count) {
            let a = i < digits.count ? digits[i] : 0
            let b = i < other.digits.count ? other.digits[i] : 0
            if a != b { return a < b ? -1 : 1 }
        }
        return 0
    }

    public func multiplied(by other: Self) -> Self {
        if isZero || other.isZero { return Self(negative: false, digits: [0], exponent: 0) }
        let a = Array(digits.reversed()), b = Array(other.digits.reversed())
        var out = [Int](repeating: 0, count: a.count + b.count)
        for i in a.indices { for j in b.indices { out[i + j] += Int(a[i]) * Int(b[j]) } }
        for i in 0..<(out.count - 1) { out[i + 1] += out[i] / 10; out[i] %= 10 }
        return Self(negative: negative != other.negative, digits: out.reversed().map(UInt8.init), exponent: exponent + other.exponent)
    }

    /// Signed `self - other`, including values below Double's underflow threshold.
    public func subtracting(_ other: Self) -> Self {
        let power = min(exponent, other.exponent)
        let a = Array((digits + [UInt8](repeating: 0, count: exponent - power)).reversed())
        let b = Array((other.digits + [UInt8](repeating: 0, count: other.exponent - power)).reversed())
        if negative != other.negative {
            var out = [UInt8](), carry = 0
            for i in 0..<max(a.count, b.count) {
                let value = (i < a.count ? Int(a[i]) : 0) + (i < b.count ? Int(b[i]) : 0) + carry
                out.append(UInt8(value % 10)); carry = value / 10
            }
            if carry > 0 { out.append(UInt8(carry)) }
            return Self(negative: negative, digits: out.reversed(), exponent: power)
        }
        let order = compareMagnitude(other)
        let larger = order >= 0 ? a : b, smaller = order >= 0 ? b : a
        var out = [UInt8](), borrow = 0
        for i in larger.indices {
            var value = Int(larger[i]) - (i < smaller.count ? Int(smaller[i]) : 0) - borrow
            borrow = value < 0 ? 1 : 0
            if value < 0 { value += 10 }
            out.append(UInt8(value))
        }
        return Self(negative: order >= 0 ? negative : !negative, digits: out.reversed(), exponent: power)
    }

    public func isWithinRelativeTolerance(of other: Self, tolerance: Self) -> Bool {
        if self == other { return true }
        if tolerance.isZero { return false }
        let scale = compareMagnitude(other) >= 0 ? magnitude : other.magnitude
        return subtracting(other).magnitudeLessThanOrEqual(to: scale.multiplied(by: tolerance))
    }

    private static func format(negative: Bool, digits: [UInt8], exponent: Int) -> String {
        let sign = negative ? "-" : ""
        let coefficient = String(bytes: digits.map { $0 + 48 }, encoding: .utf8)!
        if digits == [0] { return "0" }
        if exponent >= 0 && coefficient.count + exponent <= 24 {
            return sign + coefficient + String(repeating: "0", count: exponent)
        }
        let position = digits.count + exponent
        if exponent < 0 && position > 0 {
            let split = coefficient.index(coefficient.startIndex, offsetBy: position)
            return sign + coefficient[..<split] + "." + coefficient[split...]
        }
        if position <= 0 && position >= -6 {
            return sign + "0." + String(repeating: "0", count: -position) + coefficient
        }
        return sign + coefficient + "e" + String(exponent)
    }
}

extension DecimalNumber {
    /// `(self - reference) / abs(reference) * 100`, rounded to six decimal
    /// places using decimal integer division, ties away from zero. Display only.
    public func relativeChangePercentage(from reference: Self) -> String? {
        guard !reference.isZero else { return nil }
        let delta = subtracting(reference)
        if delta.isZero { return "0" }
        let power = delta.exponent + 8 - reference.exponent
        let numerator = delta.digits + [UInt8](repeating: 0, count: max(0, power))
        let denominator = Self(negative: false, digits: reference.digits
            + [UInt8](repeating: 0, count: max(0, -power)), exponent: 0)
        var remainder = Self(negative: false, digits: [0], exponent: 0)
        var quotient: [UInt8] = []
        for digit in numerator {
            let shifted = remainder.scaled(byPowerOfTen: 1)
            remainder = shifted.subtracting(Self(negative: true, digits: [digit], exponent: 0))
            var next: UInt8 = 0
            while denominator.magnitudeLessThanOrEqual(to: remainder) {
                remainder = remainder.subtracting(denominator)
                next += 1
            }
            quotient.append(next)
        }
        let two = Self(negative: false, digits: [2], exponent: 0)
        if denominator.magnitudeLessThanOrEqual(to: remainder.multiplied(by: two)) {
            var index = quotient.count - 1
            while index > 0 && quotient[index] == 9 { quotient[index] = 0; index -= 1 }
            if quotient[index] == 9 { quotient[index] = 0; quotient.insert(1, at: 0) }
            else { quotient[index] += 1 }
        }
        return Self(negative: delta.negative, digits: quotient, exponent: -6).canonicalString
    }
}
