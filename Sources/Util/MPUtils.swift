//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

let productName    = Bundle.main.object( forInfoDictionaryKey: "CFBundleDisplayName" ) as? String ?? "Spectre"
let productVersion = Bundle.main.object( forInfoDictionaryKey: "CFBundleShortVersionString" ) as? String ?? "0"
let productBuild   = Bundle.main.object( forInfoDictionaryKey: "CFBundleVersion" ) as? String ?? "0"

postfix operator <

postfix public func <(a: Any?) -> Any? {
    (a as? String)< ?? (a as? Int)< ?? (a as? Int64)<
}

postfix public func <(s: String?) -> String? {
    (s?.isEmpty ?? true) ? nil: s
}

postfix public func <(i: Int?) -> Int? {
    i ?? 0 == 0 ? nil: i
}

postfix public func <(i: Int64?) -> Int64? {
    i ?? 0 == 0 ? nil: i
}

func ratio(of value: UInt8, from: Double, to: Double) -> Double {
    from + (to - from) * (Double( value ) / Double( UInt8.max ))
}

prefix public func -(a: UIEdgeInsets) -> UIEdgeInsets {
    UIEdgeInsets( top: -a.top, left: -a.left, bottom: -a.bottom, right: -a.right )
}

// Map a 0-max value such that it mirrors around a center point.
// 0 -> 0, center -> max, max -> 0
func mirror(ratio: Int, center: Int, max: Int) -> Int {
    if ratio < center {
        return max * ratio / center
    }
    else {
        return max - max * (ratio - center) / (max - center)
    }
}

func withVaStrings<R>(_ strings: [StaticString], terminate: Bool = true, body: (CVaListPointer) -> R) -> R {
    var va: [CVarArg] = strings.map { $0.utf8Start }
    if terminate {
        va.append( Int( bitPattern: nil ) )
    }
    defer {
        va.forEach { free( $0 as? UnsafeMutablePointer<Int8> ) }
    }

    return withVaList( va, body )
}

extension MPKeyPurpose: CustomStringConvertible {
    public var description: String {
        switch self {
            case .authentication:
                return "password"
            case .identification:
                return "user name"
            case .recovery:
                return "security answer"
            @unknown default:
                return ""
        }
    }
}

extension MPResultType: CustomStringConvertible, CaseIterable {
    public static let allCases: [MPResultType] = [
        .templateMaximum, .templateLong, .templateMedium, .templateShort,
        .templateBasic, .templatePIN, .templateName, .templatePhrase,
        .statefulPersonal, .statefulDevice, .deriveKey,
    ]
    static let recommendedTypes: [MPKeyPurpose: [MPResultType]] = [
        .authentication: [ .templateMaximum, .templatePhrase, .templateLong, .templateBasic, .templatePIN ],
        .identification: [ .templateName, .templateBasic, .templateShort ],
        .recovery: [ .templatePhrase ],
    ]

    public var description:          String {
        String( validate: mpw_type_short_name( self ) ) ?? "?"
    }
    public var localizedDescription: String {
        String( validate: mpw_type_long_name( self ) ) ?? "?"
    }

    func `in`(class c: MPResultTypeClass) -> Bool {
        self.rawValue & UInt32( c.rawValue ) == UInt32( c.rawValue )
    }

    func has(feature f: MPSiteFeature) -> Bool {
        self.rawValue & UInt32( f.rawValue ) == UInt32( f.rawValue )
    }
}

extension MPIdenticon: Equatable {
    public static func ==(lhs: MPIdenticon, rhs: MPIdenticon) -> Bool {
        lhs.leftArm == rhs.leftArm && lhs.body == rhs.body && lhs.rightArm == rhs.rightArm &&
                lhs.accessory == rhs.accessory && lhs.color == rhs.color
    }

    public func encoded() -> String? {
        if self.color == .unset {
            return nil
        }

        return String( validate: mpw_identicon_encode( self ) )
    }

    public func text() -> String? {
        if self.color == .unset {
            return nil
        }

        return [ String( cString: self.leftArm ),
                 String( cString: self.body ),
                 String( cString: self.rightArm ),
                 String( cString: self.accessory ) ].joined()
    }

    public func attributedText() -> NSAttributedString? {
        if self.color == .unset {
            return nil
        }

        let shadow = NSShadow()
        shadow.shadowColor = Theme.current.color.shadow.get() // TODO: Update on theme change.
        shadow.shadowOffset = CGSize( width: 0, height: 1 )
        return self.text().flatMap {
            NSAttributedString( string: $0, attributes: [
                .foregroundColor: self.color.ui(),
                .shadow: shadow,
            ] )
        }
    }
}

extension MPIdenticonColor {
    public func ui() -> UIColor {
        switch self {
            case .unset:
                return .clear
            case .red:
                return .red
            case .green:
                return .green
            case .yellow:
                return .yellow
            case .blue:
                return .blue
            case .magenta:
                return .magenta
            case .cyan:
                return .cyan
            case .mono:
                if #available( iOS 13, * ) {
                    return .label
                }
                else {
                    return .lightText
                }
            default:
                fatalError( "Unsupported color: \(self)" )
        }
    }
}

extension MPAlgorithmVersion: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ MPAlgorithmVersion ]( (.first)...(.last) )

    public func distance(to other: MPAlgorithmVersion) -> Int32 {
        Int32( other.rawValue ) - Int32( self.rawValue )
    }

    public func advanced(by n: Int32) -> MPAlgorithmVersion {
        MPAlgorithmVersion( rawValue: UInt32( Int32( self.rawValue ) + n ) )!
    }

    public var description: String {
        "v\(self.rawValue)"
    }
}

extension MPMarshalFormat: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ MPMarshalFormat ]( (.first)...(.last) )

    public func distance(to other: MPMarshalFormat) -> Int32 {
        Int32( other.rawValue ) - Int32( self.rawValue )
    }

    public func advanced(by n: Int32) -> MPMarshalFormat {
        MPMarshalFormat( rawValue: UInt32( Int32( self.rawValue ) + n ) )!
    }

    public var name: String? {
        String( validate: mpw_format_name( self ) )
    }

    public var uti:         String? {
        switch self {
            case .none:
                return nil
            case .flat:
                return "com.lyndir.masterpassword.sites"
            case .JSON:
                return "com.lyndir.masterpassword.json"
            default:
                fatalError( "Unsupported format: \(self)" )
        }
    }
    public var description: String {
        switch self {
            case .none:
                return "No Output"
            case .flat:
                return "v1 (sites)"
            case .JSON:
                return "v2 (json)"
            default:
                fatalError( "Unsupported format: \(self.rawValue)" )
        }
    }
}

public enum MPError: LocalizedError {
    case `issue`(_ error: Error? = nil, title: String, details: String? = nil)
    case `internal`(details: String)
    case `state`(details: String)
    case `marshal`(MPMarshalError, title: String)

    public var errorDescription: String? {
        switch self {
            case .issue(_, title: let title, _):
                return title
            case .internal( _ ):
                return "An internal error occurred."
            case .state( _ ):
                return "Not ready."
            case .marshal(_, let title):
                return title
        }
    }
    public var failureReason: String? {
        switch self {
            case .issue(let error, _, let details):
                return [ details, error?.localizedDescription, (error as NSError?)?.localizedFailureReason ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
            case .internal(let details):
                return details
            case .state(let details):
                return details
            case .marshal(let error, _):
                return [ error.localizedDescription, (error as NSError).localizedFailureReason ]
                        .compactMap( { $0 } ).joined( separator: "\n" )
        }
    }
    public var recoverySuggestion: String? {
        switch self {
            case .issue(let error, _, _):
                return (error as NSError?)?.localizedRecoverySuggestion
            case .marshal(let error, _):
                return (error as NSError).localizedRecoverySuggestion
            default:
                return nil
        }
    }
}

extension OperationQueue {
    convenience init(named name: String) {
        self.init()

        self.name = name
    }

    convenience init(queue: DispatchQueue) {
        self.init()

        self.name = queue.label
        self.underlyingQueue = queue
    }
}

extension NSTextAlignment {
    static var inverse: NSTextAlignment {
        UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .left: .right
    }
}

extension UnsafeMutablePointer where Pointee == MPMarshalledFile {

    public func mpw_get(path: StaticString...) -> Bool? {
        withVaStrings( path ) { mpw_marshal_data_vget_bool( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: StaticString...) -> Double? {
        withVaStrings( path ) { mpw_marshal_data_vget_num( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: StaticString...) -> String? {
        withVaStrings( path ) { String( validate: mpw_marshal_data_vget_str( self.pointee.data, $0 ) ) }
    }

    public func mpw_set(_ value: Bool, path: StaticString...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_bool( value, self.pointee.data, $0 ) }
    }

    public func mpw_set(_ value: Double, path: StaticString...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_num( value, self.pointee.data, $0 ) }
    }

    public func mpw_set(_ value: String?, path: StaticString...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_str( value, self.pointee.data, $0 ) }
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

extension Locale {
    public static let C = Locale( identifier: "en_US_POSIX" )
}

extension Double {
    public static let φ     = 1.618 // Golden Ratio
    public static let long  = 1 / φ
    public static let short = (1 - long)
}

extension CGFloat {
    public static let φ     = CGFloat( Double.φ ) // Golden Ratio
    public static let long  = 1 / φ
    public static let short = (1 - long)
}

extension Float {
    public static let φ     = Float( Double.φ ) // Golden Ratio
    public static let long  = 1 / φ
    public static let short = (1 - long)
}

extension UITraitCollection {
    @available(iOS 13.0, *)
    func resolveAsCurrent<R>(_ perform: () -> R) -> R {
        var result: R!
        self.performAsCurrent { result = perform() }

        return result
    }
}

extension UIColor {

    // Extended sRGB, hex, RRGGBB / RRGGBBAA
    class func hex(_ hex: String, alpha: CGFloat = 1) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters( in: .whitespacesAndNewlines )
        hexSanitized = hexSanitized.replacingOccurrences( of: "#", with: "" )
        var rgb: UInt32  = 0
        var r:   CGFloat = 0.0
        var g:   CGFloat = 0.0
        var b:   CGFloat = 0.0
        var a:   CGFloat = alpha
        guard Scanner( string: hexSanitized ).scanHexInt32( &rgb )
        else { return nil }
        if hexSanitized.count == 6 {
            r = CGFloat( (rgb & 0xFF0000) >> 16 ) / 255.0
            g = CGFloat( (rgb & 0x00FF00) >> 8 ) / 255.0
            b = CGFloat( rgb & 0x0000FF ) / 255.0
        }
        else if hexSanitized.count == 8 {
            r = CGFloat( (rgb & 0xFF000000) >> 24 ) / 255.0
            g = CGFloat( (rgb & 0x00FF0000) >> 16 ) / 255.0
            b = CGFloat( (rgb & 0x0000FF00) >> 8 ) / 255.0
            a *= CGFloat( rgb & 0x000000FF ) / 255.0
        }
        else {
            return nil
        }

        return UIColor( red: r, green: g, blue: b, alpha: a )
    }

    var hex: String {
        var r = CGFloat( 0 ), g = CGFloat( 0 ), b = CGFloat( 0 ), a = CGFloat( 0 )
        self.getRed( &r, green: &g, blue: &b, alpha: &a )

        return String( format: "%0.2lX%0.2lX%0.2lX,%0.2lX", Int( r * 255 ), Int( g * 255 ), Int( b * 255 ), Int( a * 255 ) )
    }

    // Determine how common a color is in a list of colors.
    // Compares the color to the other colors only by average hue distance.
    func similarityOfHue(in colors: [UIColor]) -> CGFloat {
        let swatchHue = self.hue

        var commonality: CGFloat = 0
        for color in colors {
            let colorHue = color.hue
            commonality += abs( colorHue - swatchHue )
        }

        return commonality / CGFloat( colors.count )
    }

    var hue: CGFloat {
        var hue: CGFloat = 0
        self.getHue( &hue, saturation: nil, brightness: nil, alpha: nil )

        return hue
    }

    var saturation: CGFloat {
        var saturation: CGFloat = 0
        self.getHue( nil, saturation: &saturation, brightness: nil, alpha: nil )

        return saturation
    }

    var brightness: CGFloat {
        var brightness: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: &brightness, alpha: nil )

        return brightness
    }

    var alpha: CGFloat {
        var alpha: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: nil, alpha: &alpha )

        return alpha
    }

    func with(alpha newAlpha: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: saturation, brightness: brightness, alpha: newAlpha ?? alpha )
    }

    func with(hue newHue: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: newHue ?? hue, saturation: saturation, brightness: brightness, alpha: alpha )
    }

    func with(saturation newSaturation: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: newSaturation ?? saturation, brightness: brightness, alpha: alpha )
    }

    func with(brightness newBrightness: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: saturation, brightness: newBrightness ?? brightness, alpha: alpha )
    }
}

extension UIFont {
    func withSymbolicTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = self.fontDescriptor.withSymbolicTraits( symbolicTraits ) {
            return UIFont( descriptor: descriptor, size: self.pointSize )
        }

        return self
    }
}

extension String {
    public var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}

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

extension CGSize {
    public static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width + rhs.width, height: lhs.height + rhs.height )
    }

    public static func -(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width - rhs.width, height: lhs.height - rhs.height )
    }

    public static func +=(lhs: inout CGSize, rhs: CGSize) {
        lhs.width += rhs.width
        lhs.height += rhs.height
    }

    public static func -=(lhs: inout CGSize, rhs: CGSize) {
        lhs.width -= rhs.width
        lhs.height -= rhs.height
    }

    init(_ point: CGPoint) {
        self.init( width: point.x, height: point.y )
    }

    func union(_ size: CGSize) -> CGSize {
        size.width <= self.width && size.height <= self.height ? self:
                size.width >= self.width && size.height >= self.height ? size:
                CGSize( width: max( self.width, size.width ), height: max( self.height, size.height ) )
    }

    func grow(width: CGFloat = 0, height: CGFloat = 0, size: CGSize = .zero, point: CGPoint = .zero) -> CGSize {
        let width  = width + size.width + point.x
        let height = height + size.height + point.y
        return width == 0 && height == 0 ? self:
                CGSize( width: self.width + width, height: self.height + height )
    }
}

extension CGPoint {
    public static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x + rhs.x, y: lhs.y + rhs.y )
    }

    public static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint( x: lhs.x - rhs.x, y: lhs.y - rhs.y )
    }

    public static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    public static func -=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
}

extension UIEdgeInsets {
    public static func +(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: max( lhs.top, rhs.top ), left: max( lhs.left, rhs.left ),
                      bottom: max( lhs.bottom, rhs.bottom ), right: max( lhs.right, rhs.right ) )
    }

    public static func -(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets( top: min( lhs.top, rhs.top ), left: min( lhs.left, rhs.left ),
                      bottom: min( lhs.bottom, rhs.bottom ), right: min( lhs.right, rhs.right ) )
    }

    public static func +=(lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top = max( lhs.top, rhs.top )
        lhs.left = max( lhs.left, rhs.left )
        lhs.bottom = max( lhs.bottom, rhs.bottom )
        lhs.right = max( lhs.right, rhs.right )
    }

    public static func -=(lhs: inout UIEdgeInsets, rhs: UIEdgeInsets) {
        lhs.top = min( lhs.top, rhs.top )
        lhs.left = min( lhs.left, rhs.left )
        lhs.bottom = min( lhs.bottom, rhs.bottom )
        lhs.right = min( lhs.right, rhs.right )
    }

    var width:  CGFloat {
        self.left + self.right
    }
    var height: CGFloat {
        self.top + self.bottom
    }
    var size:   CGSize {
        CGSize( width: self.width, height: self.height )
    }

    init(in insetRect: CGRect, subtracting subtractRect: CGRect) {
        if !insetRect.intersects( subtractRect ) {
            self = .zero
        }
        else {
            let topLeftBounds     = insetRect.topLeft
            let bottomRightBounds = insetRect.bottomRight
            let topLeftFrom       = subtractRect.topLeft
            let bottomRightFrom   = subtractRect.bottomRight
            let topLeftInset      = bottomRightFrom - topLeftBounds
            let bottomRightInset  = bottomRightBounds - topLeftFrom

            let top    = topLeftFrom.y <= topLeftBounds.y && bottomRightFrom.y < bottomRightBounds.y ? max( 0, topLeftInset.y ): 0
            let left   = topLeftFrom.x <= topLeftBounds.x && bottomRightFrom.x < bottomRightBounds.x ? max( 0, topLeftInset.x ): 0
            let bottom = topLeftFrom.y > topLeftBounds.y && bottomRightFrom.y >= bottomRightBounds.y ? max( 0, bottomRightInset.y ): 0
            let right  = topLeftFrom.x > topLeftBounds.x && bottomRightFrom.x >= bottomRightBounds.x ? max( 0, bottomRightInset.x ): 0

            self.init( top: top, left: left, bottom: bottom, right: right )
        }
    }
}

extension CGRect {
    var center:      CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var top:         CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY )
    }
    var topLeft:     CGPoint {
        CGPoint( x: self.minX, y: self.minY )
    }
    var topRight:    CGPoint {
        CGPoint( x: self.maxX, y: self.minY )
    }
    var left:        CGPoint {
        CGPoint( x: self.minX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var right:       CGPoint {
        CGPoint( x: self.maxX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var bottom:      CGPoint {
        CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.maxY )
    }
    var bottomLeft:  CGPoint {
        CGPoint( x: self.minX, y: self.maxY )
    }
    var bottomRight: CGPoint {
        CGPoint( x: self.maxX, y: self.maxY )
    }

    init(center: CGPoint, radius: CGFloat) {
        self.init( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 )
    }

    init(center: CGPoint, size: CGSize) {
        self.init( x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height )
    }
}

extension CGPath {
    static func between(_ fromRect: CGRect, _ toRect: CGRect) -> CGPath {
        let path = CGMutablePath()

        if abs( fromRect.minX - toRect.minX ) < abs( fromRect.maxX - toRect.maxX ) {
            let p1 = fromRect.left, p2 = toRect.topLeft
            path.move( to: p1 )
            path.addLine( to: CGPoint( x: p2.x, y: p1.y ) )
            path.addLine( to: p2 )
            path.addLine( to: toRect.bottomLeft )
        }
        else {
            let p1 = fromRect.right, p2 = toRect.topRight
            path.move( to: p1 )
            path.addLine( to: CGPoint( x: p2.x, y: p1.y ) )
            path.addLine( to: p2 )
            path.addLine( to: toRect.bottomRight )
        }

        return path
    }
}

extension Data {
    func sha256() -> [UInt8] {
        self.withUnsafeBytes {
            var hash = [ UInt8 ]( repeating: 0, count: Int( CC_SHA256_DIGEST_LENGTH ) )
            _ = CC_SHA256( $0.baseAddress, CC_LONG( self.count ), &hash )
            return hash
        }
    }

    var hex: String {
        let hex = NSMutableString( capacity: self.count * 2 )
        self.forEach { hex.appendFormat( "%02hhX", $0 ) }

        return hex as String
    }
}

extension Decimal {
    static let e = Decimal( string: "2.7182818284590452353602874713526624977572470936999595749669676277240766303535475945713821785251664" )!

    func log(base: Decimal) -> Decimal {
        self.ln() / base.ln()
    }

    func ln() -> Decimal {
        // https://en.wikipedia.org/wiki/Logarithm#Power_series -- "More efficient series"

        // To speed convergence, using ln(z) = y + ln(A), A = z / e^y approximation for values larger than 1.5
        let approximateInput = Double( truncating: self as NSNumber )
        if approximateInput > 1.5 {
            let y       = Int( ceil( Darwin.log( approximateInput ) ) )
            // Using integer because of more precise powers for integers
            let smaller = self / pow( Decimal.e, y )
            return Decimal( y ) + smaller.ln()
        }
        if approximateInput < 0.4 {
            let y       = Int( floor( Darwin.log( approximateInput ) ) )
            // Using integer because of more precise powers for integers
            let smaller = self / pow( Decimal.e, y )
            return Decimal( y ) + smaller.ln()
        }

        let seriesConstant       = (self - 1) / (self + 1)
        var currentConstantValue = seriesConstant, final = seriesConstant
        for i in stride( from: 3, through: 93, by: 2 ) {
            currentConstantValue *= seriesConstant

            // For some reason, underflow never triggers an error on NSDecimalMultiply, so you need to check for when values get too small and abort convergence manually at that point
            var rounded: Decimal = 0
            NSDecimalRound( &rounded, &currentConstantValue, 80, .bankers )
            if rounded == 0 {
                break
            }

            currentConstantValue *= seriesConstant
            NSDecimalRound( &rounded, &currentConstantValue, 80, .bankers )
            if rounded == 0 {
                break
            }

            var currentFactor = currentConstantValue / Decimal( i )
            NSDecimalRound( &rounded, &currentFactor, 80, .bankers )
            if rounded == 0 {
                break
            }

            final += currentFactor
        }

        return 2 * final
    }
}

extension String {
    func sha256() -> [UInt8] {
        self.data( using: .utf8 )?.sha256() ?? []
    }

    func color() -> UIColor? {
        let sha        = self.sha256()
        let hue        = CGFloat( ratio( of: sha[0], from: 0, to: 1 ) )
        let saturation = CGFloat( ratio( of: sha[1], from: 0.3, to: 1 ) )
        let brightness = CGFloat( ratio( of: sha[2], from: 0.5, to: 0.7 ) )

        return UIColor( hue: hue, saturation: saturation, brightness: brightness, alpha: 1 )
    }
}

extension NSOrderedSet {
    func seq<E>(_ type: E.Type) -> [E] {
        self.array as! [E]
    }
}

extension Date {
    func format(date dateStyle: DateFormatter.Style = .medium, time timeStyle: DateFormatter.Style = .medium)
                    -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = dateStyle
        dateFormatter.timeStyle = timeStyle
        return dateFormatter.string( from: self )
    }
}

extension LogLevel: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ LogLevel ]( (.fatal)...(.trace) )

    public func distance(to other: LogLevel) -> Int32 {
        other.rawValue - self.rawValue
    }

    public func advanced(by n: Int32) -> LogLevel {
        LogLevel( rawValue: self.rawValue + n )!
    }

    public var description: String {
        switch self {
            case .trace:
                return "TRC"
            case .debug:
                return "DBG"
            case .info:
                return "INF"
            case .warning:
                return "WRN"
            case .error:
                return "ERR"
            case .fatal:
                return "FTL"
            @unknown default:
                fatalError( "Unsupported log level: \(self.rawValue)" )
        }
    }
}

public func pii(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: appConfig.isDebug ? .debug: .trace, format, args )
}

public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .trace, format, args )
}

public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .debug, format, args )
}

public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .info, format, args )
}

public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .warning, format, args )
}

public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .error, format, args )
}

public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .fatal, format, args )
}

public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: LogLevel, _ format: StaticString, _ args: [Any?]) {

    if mpw_verbosity < level {
        return
    }

    let message = String( format: format.description, arguments: args.map { arg in
        if let error = arg as? LocalizedError {
            return [ error.failureReason, error.errorDescription ].compactMap { $0 }.joined( separator: ": " )
        }

        guard let arg = arg
        else { return Int( bitPattern: nil ) }

        return arg as? CVarArg ?? String( reflecting: arg )
    } )

    mpw_log_ssink( level, file, line, function, message )
}

func decrypt(secret secretBase64: String?) -> String? {
    guard let secretBase64 = secretBase64
    else { return nil }

    var secretLength = mpw_base64_decode_max( secretBase64 ), keyLength = 0
    guard secretLength > 0
    else { return nil }

    guard let key = mpw_unhex( appSecret, &keyLength )
    else { return nil }
    defer { key.deallocate() }

    var secretData = [ UInt8 ]( repeating: 0, count: secretLength )
    secretLength = mpw_base64_decode( secretBase64, &secretData )

    return String( decode: mpw_aes_decrypt( key, keyLength, &secretData, &secretLength ),
                   length: secretLength, deallocate: true )
}

func digest(value: String?) -> String? {
    guard let value = value, let appSalt = decrypt( secret: appSalt ),
          let digest = mpw_hash_hmac_sha256( appSalt, appSalt.lengthOfBytes( using: .utf8 ),
                                             value, value.lengthOfBytes( using: .utf8 ) )
    else { return nil }
    defer { digest.deallocate() }

    return String( validate: mpw_hex( digest, 32 ) )
}
