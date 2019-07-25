//
// Created by Maarten Billemont on 2018-04-08.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

func ratio(of value: UInt8, from: Double, to: Double) -> Double {
    return from + (to - from) * (Double( value ) / Double( UInt8.max ))
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

extension MPKeyPurpose {
    func button() -> String {
        switch self {
            case .authentication:
                return "p:"
            case .identification:
                return "u:"
            case .recovery:
                return "a:"
            default:
                fatalError( "Unsupported purpose: \(self)" )
        }
    }

    @discardableResult
    mutating func next() -> MPKeyPurpose {
        switch self {
            case .authentication:
                self = .identification
            case .identification:
                self = .recovery
            case .recovery:
                self = .authentication
            default:
                fatalError( "Unsupported purpose: \(self)" )
        }

        return self
    }
}

extension MPResultType {
    func `in`(class c: MPResultTypeClass) -> Bool {
        return self.rawValue & UInt32( c.rawValue ) == UInt32( c.rawValue )
    }

    func has(feature f: MPSiteFeature) -> Bool {
        return self.rawValue & UInt32( f.rawValue ) == UInt32( f.rawValue )
    }
}

extension MPIdenticon: Equatable {
    public static func ==(lhs: MPIdenticon, rhs: MPIdenticon) -> Bool {
        return lhs.leftArm == rhs.leftArm && lhs.body == rhs.body && lhs.rightArm == rhs.rightArm &&
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
        shadow.shadowColor = MPTheme.global.color.shadow.get()
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

extension MPMarshalFormat: Strideable, CaseIterable, CustomStringConvertible {
    public private(set) static var allCases = [ MPMarshalFormat ]( (.first)...(.last) )

    public func distance(to other: MPMarshalFormat) -> Int32 {
        return Int32( other.rawValue ) - Int32( self.rawValue )
    }

    public func advanced(by n: Int32) -> MPMarshalFormat {
        return MPMarshalFormat( rawValue: UInt32( Int32( self.rawValue ) + n ) )!
    }

    public var name: String? {
        return String( safeUTF8: mpw_format_name( self ) )
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
                fatalError( "Unsupported format: \(self)" )
        }
    }
}

extension MPMarshalError: Error {
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
}

extension UIColor {
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
        return self.withHueComponent( color?.hue() );
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
        return self.withSaturationComponent( color?.saturation() );
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
        return self.withBrightnessComponent( color?.brightness() );
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

extension UIView {
    convenience init(constraining subview: UIView, withMargins margins: Bool = true) {
        self.init()
        self.addSubview( subview )

        LayoutConfiguration( view: subview )
                .constrainToOwner( withMargins: margins )
                .activate()
    }
}

extension CGSize {
    func union(_ size: CGSize) -> CGSize {
        return size.width <= self.width && size.height <= self.height ? self:
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

extension CGRect {
    var center:      CGPoint {
        return CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var top:         CGPoint {
        return CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.minY )
    }
    var topLeft:     CGPoint {
        return CGPoint( x: self.minX, y: self.minY )
    }
    var topRight:    CGPoint {
        return CGPoint( x: self.maxX, y: self.minY )
    }
    var left:        CGPoint {
        return CGPoint( x: self.minX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var right:       CGPoint {
        return CGPoint( x: self.maxX, y: self.minY + (self.maxY - self.minY) / 2 )
    }
    var bottom:      CGPoint {
        return CGPoint( x: self.minX + (self.maxX - self.minX) / 2, y: self.maxY )
    }
    var bottomLeft:  CGPoint {
        return CGPoint( x: self.minX, y: self.maxY )
    }
    var bottomRight: CGPoint {
        return CGPoint( x: self.maxX, y: self.maxY )
    }

    init(center: CGPoint, radius: CGFloat) {
        self.init( x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2 )
    }
}

extension UnsafePointer where Pointee == CChar {
    func toStringAndDeallocate() -> String? {
        defer {
            self.deallocate()
        }
        return String( safeUTF8: self )
    }
}

extension Data {
    func sha256() -> [UInt8] {
        var hash = [ UInt8 ]( repeating: 0, count: Int( CC_SHA256_DIGEST_LENGTH ) )
        self.withUnsafeBytes { _ = CC_SHA256( $0, CC_LONG( self.count ), &hash ) }
        return hash
    }

    func hexEncodedString() -> String {
        let hex = NSMutableString( capacity: self.count * 2 )
        for byte in self {
            hex.appendFormat( "%02hhX", byte )
        }

        return hex as String
    }
}

extension String {
    func sha256() -> [UInt8] {
        return self.data( using: .utf8 )?.sha256() ?? []
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
        return self.array as! [E]
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

// Useful for making Swift Arrays from C arrays (which are imported as tuples).
extension Array {
    init(_ tuple: (Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1 )
    }

    init(_ tuple: (Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2 )
    }

    init(_ tuple: (Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15, tuple.16 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15, tuple.16, tuple.17 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15, tuple.16, tuple.17, tuple.18 )
    }

    init(_ tuple: (Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element, Element)) {
        self.init( arrayLiteral: tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7, tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15, tuple.16, tuple.17, tuple.18, tuple.19 )
    }
}
