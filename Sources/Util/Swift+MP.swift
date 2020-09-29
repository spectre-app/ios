//
// Created by Maarten Billemont on 2020-09-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Swift

extension Array {
    static func joined<E: Equatable>(separator: E? = nil, _ elements: [E]?...) -> Array<E> {
        if let separator = separator {
            return [ E ]( elements.compactMap( { $0 } ).joined( separator: [ separator ] ) )
        }
        else {
            return [ E ]( elements.compactMap( { $0 } ).joined() )
        }
    }

    static func joined<E: Equatable>(separator: [E?]? = nil, _ elements: [E?]?...) -> Array<E?> {
        if let separator = separator {
            return [ E? ]( elements.compactMap( { $0 } ).joined( separator: separator ) )
        }
        else {
            return [ E? ]( elements.compactMap( { $0 } ).joined() )
        }
    }
}

extension Array where Element: Equatable {
    /** Retains only the first of each equal element, filtering out any future occurrences.  Preserves all nil elements. */
    func unique() -> Self {
        var uniqueElements = [ Element ]()
        return self.filter( { element in
            defer { uniqueElements.append( element ) }
            return !uniqueElements.contains( element ) || String( reflecting: element ) == "nil"
        } )
    }
}

extension Dictionary {
    @inlinable public func merging(_ other: [Key: Value]) -> [Key: Value] {
        self.merging( other, uniquingKeysWith: { $1 } )
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

extension Double {
    public static let φ     = (1 + sqrt( 5 )) / 2 // Golden Ratio
    public static let short = (1 - long)
    public static let long  = 1 / φ
    public static let off   = 0.0
    public static let on    = 1.0
}

extension Float {
    public static let φ     = Float( Double.φ ) // Golden Ratio
    public static let long  = 1 / φ
    public static let short = (1 - long)
    public static let off   = Float( 0.0 )
    public static let on    = Float( 1.0 )
}

extension CGFloat {
    public static let φ     = CGFloat( Double.φ ) // Golden Ratio
    public static let short = (1 - long)
    public static let long  = 1 / φ
    public static let off   = CGFloat( 0.0 )
    public static let on    = CGFloat( 1.0 )
}

extension Result {
    var name: String {
        switch self {
            case .success:
                return "success"
            case .failure:
                return "failure"
        }
    }
}

extension String {
    /** Create a String from a signed c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CSignedChar>?, consume: Bool = false) -> String? {
        guard let pointer = pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.init( validatingUTF8: pointer )
    }

    /** Create a String from an unsigned c-string of valid UTF8 bytes. */
    static func valid(_ pointer: UnsafePointer<CUnsignedChar>?, consume: Bool = false) -> String? {
        guard let pointer = pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.decodeCString( pointer, as: Unicode.UTF8.self, repairingInvalidCodeUnits: false )?.result
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeRawPointer?, length: Int, consume: Bool = false) -> String? {
        guard let pointer = pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.valid( mpw_strndup( pointer.bindMemory( to: CChar.self, capacity: length ), length ), consume: true )
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeMutableRawPointer?, length: Int, consume: Bool = false) -> String? {
        guard let pointer = pointer
        else { return nil }
        defer { if consume { pointer.deallocate() } }
        return self.valid( mpw_strndup( pointer.bindMemory( to: CChar.self, capacity: length ), length ), consume: true )
    }

    /** Create a String from a raw buffer of length valid UTF8 bytes. */
    static func valid(_ pointer: UnsafeRawBufferPointer?, consume: Bool = false) -> String? {
        guard let pointer = pointer
        else { return nil }
        return self.valid( pointer.baseAddress, length: pointer.count, consume: consume )
    }

    public var nonEmpty: Self? {
        self.isEmpty ? nil: self
    }

    public func name(style: PersonNameComponentsFormatter.Style) -> String {
        let formatter = PersonNameComponentsFormatter()
        formatter.style = style

        if let components = formatter.personNameComponents( from: self ) {
            return formatter.string( from: components )
        }

        return self
    }

    public var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    func color() -> UIColor? {
        guard let digest = self.digest()
        else { return nil }

        let hue        = CGFloat( ratio( of: digest[0], from: 0, to: 1 ) )
        let saturation = CGFloat( ratio( of: digest[1], from: 0.3, to: 1 ) )
        let brightness = CGFloat( ratio( of: digest[2], from: 0.5, to: 0.7 ) )
        return UIColor( hue: hue, saturation: saturation, brightness: brightness, alpha: 1 )
    }
}

extension String {
    func b64Decrypt() -> String? {
        var secretLength = mpw_base64_decode_max( self ), keyLength = 0
        guard secretLength > 0
        else { return nil }

        guard let key = mpw_unhex( appSecret, &keyLength )
        else { return nil }
        defer { key.deallocate() }

        var secretData = [ UInt8 ]( repeating: 0, count: secretLength )
        secretLength = mpw_base64_decode( self, &secretData )

        return .valid( mpw_aes_decrypt( key, keyLength, &secretData, &secretLength ),
                       length: secretLength, consume: true )
    }

    func digest() -> Data? {
        withUnsafeBytes( of: self.cString( using: .utf8 ) ) { $0.bindMemory( to: UInt8.self ).digest() }
    }
}

extension UnsafeBufferPointer where Element == UInt8 {
    func digest() -> Data? {
        guard let appSalt = appSalt.b64Decrypt()
        else { return nil }

        var digest = [ UInt8 ]( repeating: 0, count: 32 )
        guard mpw_hash_hmac_sha256( &digest, appSalt, appSalt.lengthOfBytes( using: .utf8 ), self.baseAddress, self.count )
        else { return nil }

        return Data( digest )
    }
}

extension Numeric {
    public var nonEmpty: Self? {
        self == Self.init( exactly: 0 ) ? nil: self
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: String, prePadToLength length: Int) {
        self.appendLiteral( String( repeating: " ", count: max( 0, length - value.count ) ).appending( value ) )
    }

    mutating func appendInterpolation(_ value: String, postPadToLength length: Int) {
        self.appendLiteral( value.appending( String( repeating: " ", count: max( 0, length - value.count ) ) ) )
    }

    mutating func appendInterpolation(number value: CGFloat, as format: String? = nil, decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberOptions...) {
        self.appendInterpolation( number: Double( value ), as: format, decimals: decimals, locale: locale, options.reduce( [] ) { $0.union( $1 ) } )
    }

    mutating func appendInterpolation(number value: Double, as format: String? = nil, decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberOptions...) {
        self.appendInterpolation( number: Decimal( value ), as: format, decimals: decimals, locale: locale, options.reduce( [] ) { $0.union( $1 ) } )
    }

    mutating func appendInterpolation(number value: Decimal, as format: String? = nil, decimals: ClosedRange<Int>? = nil, locale: Locale? = nil, _ options: NumberOptions...) {
        let formatter = NumberFormatter()
        if let format = format {
            formatter.positiveFormat = format
        }
        if let locale = locale {
            formatter.locale = locale
        }
        if let decimals = decimals {
            formatter.minimumFractionDigits = decimals.lowerBound
            formatter.maximumFractionDigits = decimals.upperBound
        }
        if options.contains( .abbreviated ) {
            formatter.usesGroupingSeparator = true
        }
        if options.contains( .signed ) {
            formatter.positivePrefix = formatter.plusSign
        }
        if options.contains( .currency ) {
            formatter.numberStyle = .currency
        }

        var value = value
        if options.contains( .abbreviated ) {
            if value >= 1_000_000_000_000 {
                value /= 1_000_000_000_000
                formatter.positiveSuffix = "T"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1_000_000_000 {
                value /= 1_000_000_000
                formatter.positiveSuffix = options.contains( .currency ) ? "B": "G"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1_000_000 {
                value /= 1_000_000
                formatter.positiveSuffix = "M"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
            else if value >= 1_000 {
                value /= 1_000
                formatter.positiveSuffix = options.contains( .currency ) ? "K": "k"
                formatter.negativeSuffix = formatter.positiveSuffix
            }
        }

        if let string = formatter.string( for: value ) {
            self.appendLiteral( string )
        }
    }

    struct NumberOptions: OptionSet {
        let rawValue: Int

        static let abbreviated = NumberOptions( rawValue: 1 << 0 )
        static let currency    = NumberOptions( rawValue: 1 << 1 )
        static let signed      = NumberOptions( rawValue: 1 << 2 )
    }

    mutating func appendInterpolation(measurement: Measurement<Unit>, options: MeasurementFormatter.UnitOptions = .naturalScale, style: Formatter.UnitStyle = .short) {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = options
        formatter.unitStyle = style
        self.appendLiteral( formatter.string( from: measurement ) )
    }

    mutating func appendInterpolation(measurement value: Decimal, _ unit: Unit, options: MeasurementFormatter.UnitOptions = [ .providedUnit, .naturalScale ], style: Formatter.UnitStyle = .short) {
        self.appendInterpolation( measurement: Measurement( value: (value as NSDecimalNumber).doubleValue, unit: unit ), options: options, style: style )
    }
}
