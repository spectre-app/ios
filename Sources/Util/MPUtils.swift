//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import os

let productName = PearlInfoPlist.get().cfBundleDisplayName ?? "paX"

let resultTypes = [
    MPResultType.templateMaximum, MPResultType.templateLong, MPResultType.templateMedium, MPResultType.templateShort,
    MPResultType.templateBasic, MPResultType.templatePIN, MPResultType.templateName, MPResultType.templatePhrase,
    MPResultType.statefulPersonal, MPResultType.statefulDevice, MPResultType.deriveKey
]

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

func withVaStrings<R>(_ strings: [String], terminate: Bool = true, body: (CVaListPointer) -> R) -> R {
    var va: [CVarArg] = strings.map { mpw_strdup( $0 ) }
    if terminate {
        va.append( Int( bitPattern: nil ) )
    }
    defer {
        va.forEach { free( $0 as? UnsafeMutablePointer<Int8> ) }
    }

    return withVaList( va, body )
}

extension MPKeyPurpose {
    var result: String {
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

extension MPResultType {
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

        return String( safeUTF8: mpw_identicon_encode( self ) )
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
        shadow.shadowColor = appConfig.theme.color.shadow.get()
        shadow.shadowOffset = CGSize( width: 0, height: 1 )
        return stra( self.text(), [
            NSAttributedString.Key.foregroundColor: self.color.ui(),
            NSAttributedString.Key.shadow: shadow,
        ] )
    }
}

extension MPIdenticonColor {
    public func ui() -> UIColor {
        switch self {
            case .black:
                return .black
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
            case .white:
                return .white
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
        String( safeUTF8: mpw_format_name( self ) )
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
                return "v1 (mpsites)"
            case .JSON:
                return "v2 (mpjson)"
            default:
                fatalError( "Unsupported format: \(self.rawValue)" )
        }
    }
}

public enum MPError: LocalizedError {
    case `issue`(_ error: Error, title: String)
    case `issue`(_ error: Error, title: String, details: String)
    case `issue`(title: String, details: String)
    case `internal`(details: String)
    case `state`(details: String)
    case `marshal`(MPMarshalError, title: String)
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

    public func mpw_get(path: String...) -> Bool? {
        withVaStrings( path ) { mpw_marshal_data_vget_bool( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: String...) -> Double? {
        withVaStrings( path ) { mpw_marshal_data_vget_num( self.pointee.data, $0 ) }
    }

    public func mpw_get(path: String...) -> String? {
        withVaStrings( path ) { String( safeUTF8: mpw_marshal_data_vget_str( self.pointee.data, $0 ) ) }
    }

    public func mpw_set(_ value: Bool, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_bool( value, self.pointee.data, $0 ) }
    }

    public func mpw_set(_ value: Double, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_num( value, self.pointee.data, $0 ) }
    }

    public func mpw_set(_ value: String?, path: String...) -> Bool {
        withVaStrings( path ) { mpw_marshal_data_vset_str( value, self.pointee.data, $0 ) }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: String, prePadToLength length: Int) {
        appendLiteral( String( repeating: " ", count: max( 0, length - value.count ) ).appending( value ) )
    }

    mutating func appendInterpolation(_ value: String, postPadToLength length: Int) {
        appendLiteral( value.appending( String( repeating: " ", count: max( 0, length - value.count ) ) ) )
    }

    mutating func appendInterpolation(_ value: Any?, sign: Bool) {
        let formatter = NumberFormatter()
        if sign {
            formatter.positivePrefix = formatter.plusSign
        }
        if let string = formatter.string( for: value ) {
            appendLiteral( string )
        }
    }

    mutating func appendInterpolation(_ value: Any?, numeric format: String) {
        let formatter = NumberFormatter()
        formatter.positiveFormat = format
        formatter.negativeFormat = format
        if let string = formatter.string( for: value ) {
            appendLiteral( string )
        }
    }

    mutating func appendInterpolation(amount value: Decimal) {
        if value >= 1000000000000 {
            appendLiteral( "\(value / 1000000000000, numeric: "#,##0")T" )
        }
        else if value >= 1000000000 {
            appendLiteral( "\(value / 1000000000, numeric: "#,##0")B" )
        }
        else if value >= 1000000 {
            appendLiteral( "\(value / 1000000, numeric: "#,##0")M" )
        }
        else if value >= 1000 {
            appendLiteral( "\(value / 1000, numeric: "#,##0")k" )
        }
        else {
            appendLiteral( "\(value, numeric: "#,##0")" )
        }
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters( in: .whitespacesAndNewlines )
        hexSanitized = hexSanitized.replacingOccurrences( of: "#", with: "" )
        var rgb: UInt32  = 0
        var r:   CGFloat = 0.0
        var g:   CGFloat = 0.0
        var b:   CGFloat = 0.0
        var a:   CGFloat = 1.0
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
            a = CGFloat( rgb & 0x000000FF ) / 255.0
        }
        else {
            return nil
        }
        self.init( red: r, green: g, blue: b, alpha: a )
    }

    // Determine how common a color is in a list of colors.
    // Compares the color to the other colors only by average hue distance.
    func similarityOfHue(in colors: [UIColor]) -> CGFloat {
        let swatchHue = self.hue()

        var commonality: CGFloat = 0
        for color in colors {
            let colorHue = color.hue()
            commonality += abs( colorHue - swatchHue )
        }

        return commonality / CGFloat( colors.count )
    }

    func hue() -> CGFloat {
        var hue: CGFloat = 0
        self.getHue( &hue, saturation: nil, brightness: nil, alpha: nil )

        return hue;
    }

    func saturation() -> CGFloat {
        var saturation: CGFloat = 0
        self.getHue( nil, saturation: &saturation, brightness: nil, alpha: nil )

        return saturation;
    }

    func brightness() -> CGFloat {
        var brightness: CGFloat = 0
        self.getHue( nil, saturation: nil, brightness: &brightness, alpha: nil )

        return brightness;
    }

    func withHueComponent(_ newHue: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: newHue ?? hue, saturation: saturation, brightness: brightness, alpha: alpha );
    }

    func withHue(_ color: UIColor?) -> UIColor {
        self.withHueComponent( color?.hue() );
    }

    func withSaturationComponent(_ newSaturation: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: newSaturation ?? saturation, brightness: brightness, alpha: alpha );
    }

    func withSaturation(_ color: UIColor?) -> UIColor {
        self.withSaturationComponent( color?.saturation() );
    }

    func withBrightnessComponent(_ newBrightness: CGFloat?) -> UIColor {
        var hue:        CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha:      CGFloat = 0
        self.getHue( &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha )

        return UIColor( hue: hue, saturation: saturation, brightness: newBrightness ?? brightness, alpha: alpha );
    }

    func withBrightness(_ color: UIColor?) -> UIColor {
        self.withBrightnessComponent( color?.brightness() );
    }
}

extension UIFont {
    func withSymbolicTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if let descriptor = self.fontDescriptor.withSymbolicTraits( symbolicTraits ) {
            return UIFont( descriptor: descriptor, size: self.pointSize )
        }

        return self;
    }
}

extension CGSize {
    public static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize( width: lhs.width + rhs.width, height: lhs.height + rhs.height )
    }

    public static func +=(lhs: inout CGSize, rhs: CGSize) {
        lhs.width += rhs.width
        lhs.height += rhs.height
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

extension UIEdgeInsets {
    var width:  CGFloat {
        self.left + self.right
    }
    var height: CGFloat {
        self.top + self.bottom
    }
    var size:   CGSize {
        CGSize( width: self.width, height: self.height )
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
}

extension Data {
    func sha256() -> [UInt8] {
        self.withUnsafeBytes {
            var hash = [ UInt8 ]( repeating: 0, count: Int( CC_SHA256_DIGEST_LENGTH ) )
            _ = CC_SHA256( $0.baseAddress, CC_LONG( self.count ), &hash )
            return hash
        }
    }

    func hexEncodedString() -> String {
        let hex = NSMutableString( capacity: self.count * 2 )
        self.forEach { hex.appendFormat( "%02hhX", $0 ) }

        return hex as String
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

public func trc(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .trace, format, args );
}

public func dbg(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .debug, format, args );
}

public func inf(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .info, format, args );
}

public func wrn(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .warning, format, args );
}

public func err(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .error, format, args );
}

public func ftl(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                _ format: StaticString, _ args: Any?...) {
    log( file: file, line: line, function: function, dso: dso, level: .fatal, format, args );
}

public func log(file: String = #file, line: Int32 = #line, function: String = #function, dso: UnsafeRawPointer = #dsohandle,
                level: LogLevel, _ format: StaticString, _ args: [Any?]) {

    if mpw_verbosity < level {
        return
    }

    let message = String( format: format.description, arguments: args.map { arg in
        guard let arg = arg
        else { return Int( bitPattern: nil ) }

        return arg as? CVarArg ?? String( describing: arg )
    } )

    if #available( iOS 10.0, * ) {
        let source = file.lastIndex( of: "/" ).flatMap { String( file.suffix( from: file.index( after: $0 ) ) ) } ?? file
        switch level {
            case .trace, .debug:
                os_log( "%30@:%-3ld %-3@ | %@", dso: dso, type: .debug, source, line, level.description, message )
            case .info:
                os_log( "%30@:%-3ld %-3@ | %@", dso: dso, type: .info, source, line, level.description, message )
            case .warning:
                os_log( "%30@:%-3ld %-3@ | %@", dso: dso, type: .default, source, line, level.description, message )
            case .error:
                os_log( "%30@:%-3ld %-3@ | %@", dso: dso, type: .error, source, line, level.description, message )
            case .fatal:
                os_log( "%30@:%-3ld %-3@ | %@", dso: dso, type: .fault, source, line, level.description, message )
            @unknown default: ()
        }
    }

    mpw_log_ssink( level, file, line, function, message )
}
