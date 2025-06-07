//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import OrderedCollections
import Swift
import UIKit

// TODO: Remove when https://www.swift.org/swift-evolution/#?proposal=SE-0418 is released
extension KeyPath: @unchecked @retroactive Sendable {}

// TODO: Remove me when https://github.com/apple/swift/pull/36830 merges.
infix operator ???: NilCoalescingPrecedence
public func ??? <T>(optional: T?, defaultValue: @autoclosure () async throws -> T) async rethrows -> T {
    switch optional {
        case let .some(value):
            value
        case .none:
            try await defaultValue()
    }
}

public func ??? <T>(optional: T?, defaultValue: @autoclosure () async throws -> T?) async rethrows -> T? {
    switch optional {
        case let .some(value):
            value
        case .none:
            try await defaultValue()
    }
}

public func withObservationTracking(_ apply: @Sendable @escaping () -> Void) {
    withObservationTracking(apply, onChange: {
        Task { @MainActor in
            withObservationTracking(apply)
        }
    })
}

extension Optional {
    public func flatMap<E: Error, U: ~Copyable>(_ transform: (Wrapped) async throws(E) -> U?) async throws(E) -> U? {
        guard let value = self
        else { return nil }

        return try await transform(value)
    }
}

extension AnyHashable: @retroactive ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyHashable...) {
        self.init(elements)
    }
}

extension Collection {
    public var nonEmpty: Self? {
        self.isEmpty ? nil : self
    }
}

extension RangeReplaceableCollection {
    public mutating func removedAll(where shouldBeRemoved: (Self.Element) throws -> Bool) rethrows -> DiscontiguousSlice<Self> {
        let toBeRemoved = try self.indices(where: shouldBeRemoved)
        let removed = self[toBeRemoved]
        self.removeSubranges(toBeRemoved)
        return removed
    }
}

extension Array {
    static func joined<E: Equatable>(separator: E? = nil, _ elements: [E]?...) -> [E] {
        if let separator {
            [E](elements.compactMap { $0 }.joined(separator: [separator]))
        }
        else {
            [E](elements.compactMap { $0 }.joined())
        }
    }

    static func joined<E: Equatable>(separator: [E?]? = nil, _ elements: [E?]?...) -> [E?] {
        if let separator {
            [E?](elements.compactMap { $0 }.joined(separator: separator))
        }
        else {
            [E?](elements.compactMap { $0 }.joined())
        }
    }
}

extension Array where Element: Equatable {
    /** Retains only the first of each equal element, filtering out any future occurrences.  Preserves all nil elements. */
    func unique() -> Self {
        var uniqueElements = [Element]()
        return self.filter { element in
            defer { uniqueElements.append(element) }
            return !uniqueElements.contains(element) || String(reflecting: element) == "nil"
        }
    }
}

extension Collection<String> {
    func withCStrings<R>(_cStrings: [UnsafePointer<Int8>] = [], body: ([UnsafePointer<Int8>]) -> R) -> R {
        if let string = self.first {
            string.withCString {
                self.dropFirst().withCStrings(_cStrings: _cStrings + [$0], body: body)
            }
        }
        else {
            body(_cStrings)
        }
    }

    func withCStringVaList<R>(terminate: Bool = true, body: (CVaListPointer) -> R) -> R {
        self.withCStrings {
            withVaList(terminate ? $0 + [Int(bitPattern: nil)] : $0, body)
        }
    }
}

extension Dictionary {
    @inlinable public func merging(_ other: [Key: Value]) -> [Key: Value] {
        self.merging(other, uniquingKeysWith: { $1 })
    }

    subscript(key: Key, default def: @autoclosure () -> Value) -> Value {
        mutating get {
            if let value = self[key] {
                return value
            }
            else {
                let def = def()
                self[key] = def
                return def
            }
        }
        set {
            self[key] = newValue
        }
    }
}

extension Error {
    var details: (description: String, failure: String?, suggestion: String?, underlying: [String]) {
        let error    = self as NSError
        let provider = NSError.userInfoValueProvider(forDomain: error.domain)
        let resolver: (String) -> Any? = { error.userInfo[$0] ?? provider?(self, $0) }

        var underlyingErrors = [NSError]()
        if #available(iOS 14.5, *) {
            underlyingErrors.append(contentsOf: error.underlyingErrors.map { $0 as NSError })
        }
        else if let underlyingError = resolver(NSUnderlyingErrorKey) as? NSError {
            underlyingErrors.append(underlyingError)
        }

        return (
            description: resolver(NSLocalizedDescriptionKey) as? String ?? self.localizedDescription,
            failure: [resolver(NSLocalizedFailureErrorKey) as? String, error.localizedFailureReason]
                .compactMap { $0 }.joined(separator: " ").nonEmpty,
            suggestion: error.localizedRecoverySuggestion,
            underlying: underlyingErrors.compactMap(\.detailsDescription)
        )
    }

    var detailsDescription: String {
        let details = self.details
        return [
            details.description,
            details.failure.flatMap { "Failure: \($0)" },
            details.suggestion.flatMap { "Suggestion: \($0)" },
            details.underlying.joined(separator: "\n\n").nonEmpty
                .flatMap { "Underlying:\n  - \($0.replacingOccurrences(of: "\n", with: "    "))" },
        ].compactMap { $0 }.joined(separator: "\n")
    }
}

extension Double {
    public static let φ     = (1 + sqrt(5)) / 2 // Golden Ratio
    public static let short = (1 - long)
    public static let long  = 1 / φ
    public static let off   = 0.0
    public static let on    = 1.0
}

extension Float {
    public static let φ     = Float(Double.φ) // Golden Ratio
    public static let long  = 1 / φ
    public static let short = (1 - long)
    public static let off   = Float(0.0)
    public static let on    = Float(1.0)
}

extension CGFloat {
    public static let φ     = CGFloat(Double.φ) // Golden Ratio
    public static let short = (1 - long)
    public static let long  = 1 / φ
    public static let off   = CGFloat(0.0)
    public static let on    = CGFloat(1.0)
}

extension ObjectIdentifier {
    var identity: String {
        String(self.debugDescription.split { "()".contains($0) }[1])
    }
}

// Automatic synthesis of Strideable implementation; concrete types still need to explicitly inherit Strideable
extension RawRepresentable where RawValue: Strideable {
    public func distance(to other: Self) -> RawValue.Stride {
        self.rawValue.distance(to: other.rawValue)
    }

    public func advanced(by stride: RawValue.Stride) -> Self {
        Self(rawValue: self.rawValue.advanced(by: stride)) ?? self
    }
}

extension RawRepresentable where Self: CustomStringConvertible, RawValue: LosslessStringConvertible {
    public var description: String {
        String(self.rawValue)
    }
}

extension RawRepresentable where Self: Identifiable, RawValue: Hashable {
    public var id: Self {
        self
    }
}

extension NSObject: @retroactive Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

extension URL: @retroactive Identifiable {
    public var id: Self {
        self
    }
}

extension Result {
    var error:       Failure? {
        guard case let .failure(error) = self
        else { return nil }

        return error
    }

    var isCancelled: Bool {
        self.error is CancellationError
    }

    var name:        String {
        if self.isCancelled {
            return "cancelled"
        }

        switch self {
            case .success:
                return "success"
            case .failure:
                return "failure"
        }
    }
}

let hostNameRegex = #/
    ^
    (?:[^\/]*:\/\/)?
    (?:[^:]*:)?
    (?:[^@]*@)?
    (?<host>[^\/]*)
    (?:\/.*)?
    $
/#

extension String {
    /** Create a String from a signed c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CSignedChar>?, consume: Bool = false) -> String? {
        guard let pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.init(validatingUTF8: pointer)
    }

    /** Create a String from an unsigned c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CUnsignedChar>?, consume: Bool = false) -> String? {
        guard let pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.decodeCString(pointer, as: Unicode.UTF8.self, repairingInvalidCodeUnits: false)?.result
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeRawPointer?, length: Int, consume: Bool = false) -> String? {
        guard let pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.valid(spectre_strndup(pointer.bindMemory(to: CChar.self, capacity: length), length), consume: true)
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeMutableRawPointer?, length: Int, consume: Bool = false) -> String? {
        guard let pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.valid(spectre_strndup(pointer.bindMemory(to: CChar.self, capacity: length), length), consume: true)
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeRawBufferPointer?, consume: Bool = false) -> String? {
        guard let pointer
        else { return nil }
        return self.valid(pointer.baseAddress, length: pointer.count, consume: consume)
    }

    static func unhex(_ hex: String) -> String? {
        var length: Int = .zero
        return self.valid(spectre_unhex(hex, &length), length: length, consume: true)
    }

    public init(dump value: Any) {
        var dumped = ""
        dump(value, to: &dumped)
        self = dumped
    }

    subscript(_ pattern: String) -> [[Substring?]] {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.matches(in: self, range: NSRange(location: .zero, length: self.count)).map { match in
                (0 ..< match.numberOfRanges).map { group in
                    Range(match.range(at: group), in: self).flatMap { self[$0] }
                }
            }
        }
        catch {
            return [[]]
        }
    }

    public var nonEmpty: Self? {
        self.isEmpty ? nil : self
    }

    public func isVersionOutdated(by other: String) -> Bool {
        let selfComponents  = self.components(separatedBy: ".")
        let otherComponents = other.components(separatedBy: ".")
        for c in 0 ..< max(otherComponents.count, selfComponents.count) {
            if c < otherComponents.count, c < selfComponents.count {
                let otherComponent = (otherComponents[c] as NSString).integerValue
                let selfComponent  = (selfComponents[c] as NSString).integerValue
                if otherComponent > selfComponent {
                    // Other version component higher than this, this is outdated.
                    return true
                }
                else if otherComponent < selfComponent {
                    // Other version component lower than this, this is more recent.
                    return false
                }

                // Components match, check next component.
                continue
            }
            else if otherComponents.count > selfComponents.count {
                // Other version has more components than this and prior components were identical, this outdated.
                return true
            }
            else {
                // Build version has more components than other and prior components were identical, this is more recent.
                return false
            }
        }

        // Both versions have identical components, this is up to date.
        return false
    }

    public func name(style: PersonNameComponentsFormatter.Style) -> String {
        let formatter = PersonNameComponentsFormatter()
        formatter.style = style

        if let components = formatter.personNameComponents(from: self) {
            return formatter.string(from: components)
        }

        return self
    }

    public var hostName: String {
        (try? hostNameRegex.firstMatch(in: self)?.output.host).flatMap(String.init) ?? ""
    }

    public var privateName: String {
        let hostname = self.hostName
        for publicSuffix in Resources.shared.publicSuffixes ?? []
            where hostname.hasSuffix(".\(publicSuffix)") {
            var privateDomain = hostname.prefix(upTo: hostname.index(hostname.endIndex, offsetBy: -publicSuffix.count - 1))
            if let lastDot = privateDomain.lastIndex(of: ".") {
                privateDomain = privateDomain.suffix(from: privateDomain.index(after: lastDot))
            }
            return "\(privateDomain).\(publicSuffix)"
        }

        return hostname
    }

    public var variantNames: OrderedSet<String> {
        .init([self.privateName, self.hostName, self.contains("/") ? nil : self].removingNil())
    }

    func color() -> UIColor {
        guard let digest = self.digest()
        else { return .clear }

        let hue        = CGFloat(scale(int: digest[0], into: 0 ..< 1))
        let saturation = CGFloat(scale(int: digest[1], into: 0.3 ..< 1))
        let brightness = CGFloat(scale(int: digest[2], into: 0.5 ..< 0.7))
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: .on)
    }

    func b64Decrypt() -> String? {
        var secretLength = spectre_base64_decode_max(self.lengthOfBytes(using: .utf8)), keyLength: size_t = .zero
        guard secretLength > 0
        else { return nil }

        guard let key = spectre_unhex(secrets.app.secret, &keyLength)
        else { return nil }
        defer { key.deallocate() }

        var secretData = [UInt8](repeating: .zero, count: secretLength)
        secretLength = spectre_base64_decode(self, &secretData)

        return .valid(
            spectre_aes_decrypt(key, keyLength, &secretData, &secretLength),
            length: secretLength, consume: true
        )
    }

    func digest(salt: String? = nil) -> Data? {
        withCString(encodedAs: UTF8.self) {
            UnsafeBufferPointer(start: $0, count: self.lengthOfBytes(using: .utf8)).digest(salt: salt)
        }
    }

    func indent(spaces: Int = 4) -> String {
        if self.isEmpty {
            self
        } else {
            String(repeating: " ", count: spaces)
                + self.replacingOccurrences(of: "\n", with: "\n\(String(repeating: " ", count: spaces))")
        }
    }
}

extension UnsafeBufferPointer where Element == UInt8 {
    func digest(salt: String? = nil) -> Data? {
        guard let salt = salt ?? secrets.app.salt.b64Decrypt()
        else { return nil }

        var digest = [UInt8](repeating: .zero, count: 32)
        guard spectre_hash_hmac_sha256(&digest, salt, salt.lengthOfBytes(using: .utf8), self.baseAddress, self.count)
        else { return nil }

        return Data(digest)
    }
}

extension Numeric {
    public var nonEmpty: Self? {
        self == Self(exactly: Int.zero) ? nil : self
    }

    public func ifEmpty(_ emptyValue: some BinaryInteger) -> Self {
        self == Self(exactly: Int.zero) ? Self(exactly: emptyValue)! : self
    }
}

private let percentFormatter = using(NumberFormatter()) {
    $0.numberStyle = .percent
}

extension StringInterpolationProtocol where StringLiteralType == String {
    mutating func appendInterpolation(if value: Bool, _ then: @autoclosure () -> String, else: @autoclosure () -> String = "") {
        self.appendLiteral(value ? then() : `else`())
    }

    mutating func appendInterpolation<V>(`let` value: V?, _ then: (V) -> String, else: @autoclosure () -> String = "") {
        self.appendLiteral(value.flatMap { then($0) } ?? `else`())
    }

    mutating func appendInterpolation(`let` value: (some Any)?, _ then: String = "{}", else: @autoclosure () -> String = "") {
        self.appendInterpolation(let: value, {
            then.replacingOccurrences(of: "{}", with: ($0 as? CustomStringConvertible)?.description ?? String(dump: $0))
        }, else: `else`())
    }

    mutating func appendInterpolation<N: FixedWidthInteger, S: FormatStyle>(_ number: N, as style: S)
        where S.FormatInput == N, S.FormatOutput == String {
        if number == .max {
            self.appendLiteral("max")
        }
        else if number == .min {
            self.appendLiteral("min")
        }
        else if number == .zero {
            self.appendLiteral("zero")
        }
        else {
            self.appendLiteral(number.formatted(style))
        }
    }

    mutating func appendInterpolation<N: BinaryFloatingPoint, S: FormatStyle>(_ number: N, as style: S)
        where S.FormatInput == N, S.FormatOutput == String {
        if number == .greatestFiniteMagnitude || number == .infinity {
            self.appendLiteral("max")
        }
        else if number == -.greatestFiniteMagnitude || number == -.infinity {
            self.appendLiteral("min")
        }
        else if number.isNaN {
            self.appendLiteral("nan")
        }
        else if number.isZero || number.isSubnormal || number == .ulpOfOne || number == .leastNonzeroMagnitude {
            self.appendLiteral("zero")
        }
        else {
            self.appendLiteral(number.formatted(style))
        }
    }

    mutating func appendInterpolation<S: FormatStyle>(_ number: NSNumber, as style: S)
        where S.FormatInput == Double, S.FormatOutput == String {
        self.appendInterpolation(number.doubleValue, as: style)
    }

    mutating func appendInterpolation<S: FormatStyle>(_ input: S.FormatInput, as style: S)
        where S.FormatOutput == String {
        self.appendLiteral(style.format(input))
    }

    mutating func appendInterpolation(percent ratio: some BinaryFloatingPoint) {
        self.appendLiteral(percentFormatter.string(for: ratio) ?? "")
    }

    mutating func appendInterpolation(_ value: String, prePadToLength length: Int) {
        self.appendLiteral(String(repeating: " ", count: max(0, length - value.count)).appending(value))
    }

    mutating func appendInterpolation(_ value: String, postPadToLength length: Int) {
        self.appendLiteral(value.appending(String(repeating: " ", count: max(0, length - value.count))))
    }

    mutating func appendInterpolation(number value: CGFloat, as format: String? = nil,
                                      decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberFormat...) {
        self.appendInterpolation(
            number: Double(value), as: format,
            decimals: decimals, locale: locale, options.reduce([]) { $0.union($1) }
        )
    }

    mutating func appendInterpolation(number value: Double, as format: String? = nil,
                                      decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberFormat...) {
        self.appendInterpolation(
            number: Decimal(value), as: format,
            decimals: decimals, locale: locale, options.reduce([]) { $0.union($1) }
        )
    }

    mutating func appendInterpolation(number value: Decimal, as format: String? = nil,
                                      decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberFormat...) {
        let formatter = NumberFormatter()
        if let format {
            formatter.positiveFormat = format
        }
        if let locale {
            formatter.locale = locale
        }
        if let decimals {
            formatter.minimumFractionDigits = decimals.lowerBound
            formatter.maximumFractionDigits = decimals.upperBound
        }
        if options.contains(.abbreviated) {
            formatter.usesGroupingSeparator = true
        }
        if options.contains(.signed) {
            formatter.positivePrefix = formatter.plusSign
        }
        if options.contains(.currency) {
            formatter.numberStyle = .currency
        }

        var value = value
        if options.contains(.abbreviated) {
            if value >= 1_000_000_000_000 {
                value /= 1_000_000_000_000
                formatter.positiveSuffix = "T"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1_000_000_000 {
                value /= 1_000_000_000
                formatter.positiveSuffix = options.contains(.currency) ? "B" : "G"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1_000_000 {
                value /= 1_000_000
                formatter.positiveSuffix = "M"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1000 {
                value /= 1000
                formatter.positiveSuffix = options.contains(.currency) ? "K" : "k"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
        }

        if let string = formatter.string(for: value) {
            self.appendLiteral(string)
        }
    }

    mutating func appendInterpolation(measurement: Measurement<Unit>,
                                      options: MeasurementFormatter.UnitOptions = .naturalScale,
                                      style: Formatter.UnitStyle = .short) {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = options
        formatter.unitStyle = style
        self.appendLiteral(formatter.string(from: measurement))
    }

    mutating func appendInterpolation(measurement value: Decimal, _ unit: Unit,
                                      options: MeasurementFormatter.UnitOptions = [.providedUnit, .naturalScale],
                                      style: Formatter.UnitStyle = .short) {
        self.appendInterpolation(
            measurement: Measurement(value: (value as NSDecimalNumber).doubleValue, unit: unit),
            options: options, style: style
        )
    }
}

struct NumberFormat: OptionSet {
    let rawValue: Int

    static let abbreviated = NumberFormat(rawValue: 1 << 0)
    static let currency    = NumberFormat(rawValue: 1 << 1)
    static let signed      = NumberFormat(rawValue: 1 << 2)
}

