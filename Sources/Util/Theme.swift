//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

infix operator =>: MultiplicationPrecedence

private var propertyPaths = [ Identity: AnyObject ]()

public func =><E: NSObject, V>(target: E, keyPath: KeyPath<E, V>)
                -> PropertyPath<E, V> {
    find( propertyPath: PropertyPath( target: target, nonnullKeyPath: keyPath, nullableKeyPath: nil, attribute: nil ),
          identity: target, keyPath )
}

public func =><E: NSObject, V>(target: E, keyPath: KeyPath<E, V?>)
                -> PropertyPath<E, V> {
    find( propertyPath: PropertyPath( target: target, nonnullKeyPath: nil, nullableKeyPath: keyPath, attribute: nil ),
          identity: target, keyPath )
}

public func =><E: NSObject>(propertyPath: PropertyPath<E, NSAttributedString>, attribute: NSAttributedString.Key)
                -> PropertyPath<E, NSAttributedString> {
    find( propertyPath: PropertyPath( target: propertyPath.target, nonnullKeyPath: propertyPath.nonnullKeyPath,
                                      nullableKeyPath: propertyPath.nullableKeyPath, attribute: attribute ),
          identity: propertyPath.target, propertyPath.nonnullKeyPath ?? propertyPath.nullableKeyPath, attribute )
}

private func find<E, V>(propertyPath: @autoclosure () -> PropertyPath<E, V>, identity members: AnyHashable?...)
                -> PropertyPath<E, V> {
    let identity = Identity( members )
    if let propertyPath = propertyPaths[identity] as? PropertyPath<E, V> {
        return propertyPath
    }

    let propertyPath = propertyPath()
    propertyPaths[identity] = propertyPath
    return propertyPath
}

public func =><E, V>(propertyPath: PropertyPath<E, V>, property: Property<V>?) {
    if let property = property {
        property.bind( propertyPath: propertyPath )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

public func =><E>(propertyPath: PropertyPath<E, CGColor>, property: Property<UIColor>?) {
    if let property = property {
        property.bind( propertyPath: propertyPath )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

public func =><E, V>(propertyPath: PropertyPath<E, NSAttributedString>, property: Property<V>?) {
    if let property = property {
        property.bind( propertyPath: propertyPath )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

class Identity: Equatable, Hashable {
    let members: [WeakBox<AnyHashable?>]
    let hash:    Int

    init(_ members: AnyHashable?...) {
        var hasher = Hasher()
        self.members = members.map {
            hasher.combine( $0 )
            return WeakBox( $0 )
        }
        self.hash = hasher.finalize()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.hash )
    }

    static func ==(lhs: Identity, rhs: Identity) -> Bool {
        lhs.hash == rhs.hash && lhs.members == rhs.members
    }
}

public protocol _PropertyPath: class {
    func assign(value: @autoclosure () -> Any?)
}

public class PropertyPath<E, V>: _PropertyPath, CustomStringConvertible where E: AnyObject {

    weak var target: E?
    let nonnullKeyPath:  KeyPath<E, V>?
    let nullableKeyPath: KeyPath<E, V?>?
    let attribute:       NSAttributedString.Key?
    var property:        AnyProperty? {
        willSet {
            if let property = self.property {
                property.unbind( propertyPath: self )
            }
        }
    }

    fileprivate init(target: E?, nonnullKeyPath: KeyPath<E, V>?, nullableKeyPath: KeyPath<E, V?>?, attribute: NSAttributedString.Key?) {
        self.target = target
        self.nonnullKeyPath = nonnullKeyPath
        self.nullableKeyPath = nullableKeyPath
        self.attribute = attribute
    }

    public var description: String {
        if let attribute = self.attribute {
            return "\(self.propertyDescription) => \(attribute)"
        }
        else {
            return self.propertyDescription
        }
    }

    var propertyDescription: String {
        let targetDescription: String
        if let target = self.target {
            targetDescription = "\(type( of: target )): \(ObjectIdentifier( target ))"
        }
        else {
            targetDescription = "\(type( of: E.self )): gone)"
        }
        if let keyPath = self.nullableKeyPath {
            return "\(targetDescription) => \(NSExpression( forKeyPath: keyPath ).keyPath)"
        }
        else if let keyPath = self.nonnullKeyPath {
            return "\(targetDescription) => \(NSExpression( forKeyPath: keyPath ).keyPath)"
        }
        else {
            return "\(self.target == nil ? String( reflecting: E.self ): String( reflecting: self.target! ))"
        }
    }

    public func assign(value: @autoclosure () -> Any?) {
        guard let target = self.target
        else { return }

        var value = value()
        trc( "[assign] %@ => %@", self, value )

        if let attribute = self.attribute, let string = target[keyPath: self.nullableKeyPath!] as? NSAttributedString {
            let string = string as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: string )

            if let value = value {
                if let secondaryColor = value as? UIColor, attribute == .strokeColor {
                    string.enumerateAttribute( .strokeColor, in: NSRange( location: 0, length: string.length ) ) { value, range, stop in
                        if value != nil,
                           (string.attribute( .strokeWidth, at: range.location, effectiveRange: nil ) as? NSNumber)?.intValue ?? 0 == 0 {
                            string.addAttribute( .foregroundColor, value: secondaryColor, range: range )
                        }
                    }
                }
                else {
                    string.addAttribute( attribute, value: value, range: NSRange( location: 0, length: string.length ) )
                }
            }
            else {
                string.removeAttribute( attribute, range: NSRange( location: 0, length: string.length ) )
            }

            value = string
        }

        if self.nonnullKeyPath == \UIButton.currentTitleColor,
           let target = target as? UIButton, let value = value as? UIColor {
            target.setTitleColor( value, for: .normal )
        }
        else if self.nullableKeyPath == \UIButton.currentTitleShadowColor,
                let target = target as? UIButton, let value = value as? UIColor {
            target.setTitleShadowColor( value, for: .normal )
        }
        else if self.nullableKeyPath == \UIButton.currentAttributedTitle,
                let target = target as? UIButton, let value = value as? NSAttributedString {
            target.setAttributedTitle( value, for: .normal )
        }
        else if self.nullableKeyPath == \UIButton.currentBackgroundImage,
                let target = target as? UIButton, let value = value as? UIImage {
            target.setBackgroundImage( value, for: .normal )
        }
        else if self.nullableKeyPath == \UIButton.currentImage,
                let target = target as? UIButton, let value = value as? UIImage {
            target.setImage( value, for: .normal )
        }
        else if let propertyKeyPath = self.nullableKeyPath as? ReferenceWritableKeyPath<E, V?> {
            target[keyPath: propertyKeyPath] = value as? V
        }
        else if let propertyKeyPath = self.nonnullKeyPath as? ReferenceWritableKeyPath<E, V>, let value = value as? V {
            target[keyPath: propertyKeyPath] = value
        }
    }
}

public struct ThemePattern {
    static let dream   = ThemePattern(
            dark: .hex( "385359" ),
            dusk: .hex( "4C6C73" ),
            flat: .hex( "64858C" ),
            dawn: .hex( "AAB9BF" ),
            pale: .hex( "F2F2F2" ) )
    static let aged    = ThemePattern(
            dark: .hex( "07090D" ),
            dusk: .hex( "1E2626" ),
            flat: .hex( "6C7365" ),
            dawn: .hex( "A3A68D" ),
            pale: .hex( "BBBF9F" ) )
    static let pale    = ThemePattern(
            dark: .hex( "09090D" ),
            dusk: .hex( "1F1E26" ),
            flat: .hex( "3E5159" ),
            dawn: .hex( "5E848C" ),
            pale: .hex( "B0CDD9" ) )
    static let lush    = ThemePattern(
            dark: .hex( "141F26" ),
            dusk: .hex( "213A40" ),
            flat: .hex( "4C6C73" ),
            dawn: .hex( "5D878C" ),
            pale: .hex( "F0F1F2" ) )
    static let oak     = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "262523" ),
            flat: .hex( "595958" ),
            dawn: .hex( "A68877" ),
            pale: .hex( "D9C9BA" ) )
    static let spring  = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "2E5955" ),
            flat: .hex( "618C8C" ),
            dawn: .hex( "99BFBF" ),
            pale: .hex( "F2F2F2" ) )
    static let fuzzy   = ThemePattern(
            dark: .hex( "000F08" ),
            dusk: .hex( "004A4F" ),
            flat: .hex( "3E8989" ),
            dawn: .hex( "9AD5CA" ),
            pale: .hex( "CCE3DE" ) )
    static let premium = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "313A40" ),
            flat: .hex( "593825" ),
            dawn: .hex( "BFB7A8" ),
            pale: .hex( "F2D5BB" ) )
    static let deep    = ThemePattern(
            dark: .hex( "1A2A40" ),
            dusk: .hex( "3F4859" ),
            flat: .hex( "877B8C" ),
            dawn: .hex( "B6A8BF" ),
            pale: .hex( "BFCDD9" ) )
    static let sand    = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "736656" ),
            flat: .hex( "A69880" ),
            dawn: .hex( "D9CDBF" ),
            pale: .hex( "F2EEEB" ) )

    let dark: UIColor?
    let dusk: UIColor?
    let flat: UIColor?
    let dawn: UIColor?
    let pale: UIColor?
}

extension UIFont {
    static func custom(family: String, weight: UIFont.Weight, asTextStyle textStyle: UIFont.TextStyle) -> UIFont? {
        self.custom( family: family, weight: weight, asFontStyle: UIFontDescriptor.preferredFontDescriptor( withTextStyle: textStyle ) )
    }

    static func custom(family: String, weight: UIFont.Weight, asFontStyle fontStyle: UIFont) -> UIFont? {
        self.custom( family: family, weight: weight, asFontStyle: fontStyle.fontDescriptor )
    }

    static func custom(family: String, weight: UIFont.Weight, asFontStyle styleDescriptor: UIFontDescriptor) -> UIFont? {
        var customDescriptor = UIFontDescriptor( fontAttributes: [
            .family: family, .size: styleDescriptor.pointSize,
            .traits: [ UIFontDescriptor.TraitKey.weight: weight ],
        ] )
        if let axes = CTFontCopyVariationAxes( UIFont( descriptor: customDescriptor, size: 0 ) ) as? [[String: Any]],
           let weightAxis = axes.first( where: { $0[kCTFontVariationAxisNameKey as String] as? String == "Weight" } ),
           let weightIdentifier = weightAxis[kCTFontVariationAxisIdentifierKey as String] as? NSNumber {
            customDescriptor = CTFontDescriptorCreateCopyWithVariation( customDescriptor, weightIdentifier, weight.dimension )
        }
        return UIFont( descriptor: customDescriptor, size: 0 )
    }

    static func poppins(_ weight: UIFont.Weight, asTextStyle textStyle: UIFont.TextStyle) -> UIFont? {
        self.custom( family: "Poppins VF", weight: weight, asTextStyle: textStyle )
    }

    static func sourceCodePro(_ weight: UIFont.Weight, ofSize size: CGFloat) -> UIFont? {
        self.custom( family: "Source Code Pro", weight: weight, asFontStyle: .monospacedDigitSystemFont( ofSize: size, weight: weight ) )
    }
}

extension UIFont.Weight {
    var dimension: CGFloat {
        let myScale = self.rawValue, blackScale = UIFont.Weight.black.rawValue, ultraLightScale = UIFont.Weight.ultraLight.rawValue
        let regular = CGFloat( 400 ), black = CGFloat( 900 ), ultraLight = CGFloat( 100 )

        return myScale >= 0 ? regular + myScale / blackScale * (black - regular):
                regular - myScale / ultraLightScale * (regular - ultraLight)
    }
}

public class Theme: Hashable, CustomStringConvertible, Observable, Updatable {
    private static var byPath    = [ String: Theme ]()
    private static let base      = Theme()

    // Register all theme objects
    public static let  allCases  = [ Theme.base,
                                     Theme( path: ".dream", pattern: .dream,
                                            mood: "This weather is for dreaming." ),
                                     Theme( path: ".aged", pattern: .aged,
                                            mood: "Whiff of a Victorian manuscript." ),
                                     Theme( path: ".pale", pattern: .pale,
                                            mood: "Weathered stone foundation standing tall." ),
                                     Theme( path: ".lush", pattern: .lush,
                                            mood: "A clean and modest kind of lush." ),
                                     Theme( path: ".oak", pattern: .oak,
                                            mood: "The cabin below deck on my yacht." ),
                                     Theme( path: ".spring", pattern: .spring,
                                            mood: "Bright morning fog in spring-time." ),
                                     Theme( path: ".fuzzy", pattern: .fuzzy,
                                            mood: "Soft and just a touch fuzzy." ),
                                     Theme( path: ".premium", pattern: .premium,
                                            mood: "The kind of wealthy you don't advertise." ),
                                     Theme( path: ".deep", pattern: .deep,
                                            mood: "I am my past and I am beautiful." ),
                                     Theme( path: ".sand", pattern: .sand,
                                            mood: "Sandstone cabin by the beech." ),
    ]
    public static let  current   = Theme( path: "current" )

    // SPECTRE:
    public static let  `default` = allCases[1]

    public class func with(path: String?) -> Theme? {
        self.allCases.first { $0.path == path } ?? path<.flatMap { Theme.byPath[$0] } ?? .base
    }

    public let observers = Observers<ThemeObserver>()
    public let font      = Fonts()
    public let color     = Colors()

    public struct Fonts {
        public let largeTitle  = FontProperty()
        public let title1      = FontProperty()
        public let title2      = FontProperty()
        public let title3      = FontProperty()
        public let headline    = FontProperty()
        public let subheadline = FontProperty()
        public let body        = FontProperty()
        public let callout     = FontProperty()
        public let caption1    = FontProperty()
        public let caption2    = FontProperty()
        public let footnote    = FontProperty()
        public let password    = FontProperty()
        public let mono        = FontProperty()
    }

    public struct Colors {
        public let body        = AppearanceProperty<UIColor>() //! Text body
        public let secondary   = AppearanceProperty<UIColor>() //! Text accents / Captions
        public let placeholder = AppearanceProperty<UIColor>() //! Field hints
        public let backdrop    = AppearanceProperty<UIColor>() //! Main content background
        public let panel       = AppearanceProperty<UIColor>() //! Detail content background
        public let shade       = AppearanceProperty<UIColor>() //! Detail dimming background
        public let shadow      = AppearanceProperty<UIColor>() //! Text contrast
        public let mute        = AppearanceProperty<UIColor>() //! Dim content hinting
        public let selection   = AppearanceProperty<UIColor>() //! Selected content background
        public let tint        = AppearanceProperty<UIColor>() //! Control accents
    }

    // MARK: --- Life ---

    public var  parent:      Theme? {
        didSet {
            self.font.largeTitle.parent = self.parent?.font.largeTitle
            self.font.title1.parent = self.parent?.font.title1
            self.font.title2.parent = self.parent?.font.title2
            self.font.title3.parent = self.parent?.font.title3
            self.font.headline.parent = self.parent?.font.headline
            self.font.subheadline.parent = self.parent?.font.subheadline
            self.font.body.parent = self.parent?.font.body
            self.font.callout.parent = self.parent?.font.callout
            self.font.caption1.parent = self.parent?.font.caption1
            self.font.caption2.parent = self.parent?.font.caption2
            self.font.footnote.parent = self.parent?.font.footnote
            self.font.password.parent = self.parent?.font.password
            self.font.mono.parent = self.parent?.font.mono
            self.color.body.parent = self.parent?.color.body
            self.color.secondary.parent = self.parent?.color.secondary
            self.color.placeholder.parent = self.parent?.color.placeholder
            self.color.backdrop.parent = self.parent?.color.backdrop
            self.color.panel.parent = self.parent?.color.panel
            self.color.shade.parent = self.parent?.color.shade
            self.color.shadow.parent = self.parent?.color.shadow
            self.color.mute.parent = self.parent?.color.mute
            self.color.selection.parent = self.parent?.color.selection
            self.color.tint.parent = self.parent?.color.tint

            self.update()
        }
    }
    private let name:        String
    public var  path:        String {
        if let parent = parent {
            return "\(parent.path).\(self.name)"
        }
        else {
            return self.name
        }
    }
    public var  mood:        String?
    public var  description: String {
        self.mood ?? self.parent?.description ?? self.path
    }

    // MPTheme.base
    private init() {
        self.name = ""

        // Global default style
        self.font.largeTitle.set( UIFont.poppins( .light, asTextStyle: .largeTitle ), withTextStyle: .largeTitle )
        self.font.title1.set( UIFont.poppins( .regular, asTextStyle: .title1 ), withTextStyle: .title1 )
        self.font.title2.set( UIFont.poppins( .medium, asTextStyle: .title2 ), withTextStyle: .title2 )
        self.font.title3.set( UIFont.poppins( .regular, asTextStyle: .title3 ), withTextStyle: .title3 )
        self.font.headline.set( UIFont.poppins( .medium, asTextStyle: .headline ), withTextStyle: .headline )
        self.font.subheadline.set( UIFont.poppins( .bold, asTextStyle: .subheadline ), withTextStyle: .subheadline )
        self.font.body.set( UIFont.poppins( .light, asTextStyle: .body ), withTextStyle: .body )
        self.font.callout.set( UIFont.poppins( .regular, asTextStyle: .callout ), withTextStyle: .callout )
        self.font.caption1.set( UIFont.poppins( .light, asTextStyle: .caption1 ), withTextStyle: .caption1 )
        self.font.caption2.set( UIFont.poppins( .regular, asTextStyle: .caption2 ), withTextStyle: .caption2 )
        self.font.footnote.set( UIFont.poppins( .medium, asTextStyle: .footnote ), withTextStyle: .footnote )
        self.font.password.set( UIFont.sourceCodePro( .bold, ofSize: 20 ), withTextStyle: .largeTitle )
        self.font.mono.set( UIFont.sourceCodePro( .thin, ofSize: UIFont.systemFontSize ), withTextStyle: .body )
        self.color.body.set( UIColor.darkText )
        self.color.secondary.set( UIColor.darkGray.with( alpha: .long ) )
        self.color.placeholder.set( UIColor.darkGray.with( alpha: .short ) )
        self.color.backdrop.set( UIColor.groupTableViewBackground )
        self.color.panel.set( UIColor.white )
        self.color.shade.set( UIColor.lightText )
        self.color.shadow.set( UIColor.gray.with( alpha: .short ) )
        self.color.mute.set( UIColor.darkGray.with( alpha: .short ) )
        self.color.selection.set( UIColor.gray.with( alpha: .short ) )
        self.color.tint.set( UIColor.systemBlue )

        if #available( iOS 13, * ) {
            self.font.mono.set( .monospacedSystemFont( ofSize: UIFont.labelFontSize, weight: .thin ) )
            self.color.body.set( UIColor.label )
            self.color.secondary.set( UIColor.secondaryLabel )
            self.color.placeholder.set( UIColor.placeholderText )
            self.color.backdrop.set( UIColor.systemBackground )
            self.color.panel.set( UIColor.secondarySystemBackground )
            self.color.shade.set( UIColor.systemFill )
            self.color.shadow.set( UIColor.secondarySystemFill )
            self.color.mute.set( UIColor.separator )
            self.color.selection.set( UIColor.tertiarySystemFill )
            self.color.tint.set( UIColor.link )
        }

        Theme.byPath[""] = self
    }

    private init(path: String, pattern: ThemePattern? = nil, mood: String? = nil, override: ((Theme) -> ())? = nil) {
        self.mood = mood

        var parent: Theme?
        if let lastDot = path.lastIndex( of: "." ) {
            self.name = String( path[path.index( after: lastDot )..<path.endIndex] )
            parent = String( path[path.startIndex..<lastDot] )<.flatMap { Theme.byPath[$0] } ?? .base
        }
        else {
            self.name = path
        }

        Theme.byPath[path] = self
        if let pattern = pattern {
            self.color.body.set( light: pattern.dark, dark: pattern.pale )
            self.color.secondary.set( light: pattern.dusk?.with( alpha: .long ), dark: pattern.dawn?.with( alpha: .long ) )
            self.color.placeholder.set( light: pattern.dusk?.with( alpha: .short ), dark: pattern.dawn?.with( alpha: .short ) )
            self.color.backdrop.set( light: pattern.pale, dark: pattern.dark )
            self.color.panel.set( light: pattern.dawn, dark: pattern.dusk )
            self.color.shade.set( light: pattern.pale?.with( alpha: .long ), dark: pattern.dark?.with( alpha: .long ) )
            self.color.shadow.set( light: pattern.flat?.with( alpha: .short ), dark: pattern.flat?.with( alpha: .short ) )
            self.color.mute.set( light: pattern.dusk?.with( alpha: .short ), dark: pattern.dawn?.with( alpha: .short ) )
            self.color.selection.set( light: pattern.flat?.with( alpha: .short ), dark: pattern.flat?.with( alpha: .short ) )
            self.color.tint.set( light: pattern.dusk, dark: pattern.dawn )
        }
        override?( self )

        defer {
            self.parent = parent
        }
    }

    public func update() {
        self.font.largeTitle.update()
        self.font.title1.update()
        self.font.title2.update()
        self.font.title3.update()
        self.font.headline.update()
        self.font.subheadline.update()
        self.font.body.update()
        self.font.callout.update()
        self.font.caption1.update()
        self.font.caption2.update()
        self.font.footnote.update()
        self.font.password.update()
        self.font.mono.update()
        self.color.body.update()
        self.color.secondary.update()
        self.color.placeholder.update()
        self.color.backdrop.update()
        self.color.panel.update()
        self.color.shade.update()
        self.color.shadow.update()
        self.color.mute.update()
        self.color.selection.update()
        self.color.tint.update()

        self.observers.notify( event: { $0.didChangeTheme() } )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine( self.path )
    }

    public static func ==(lhs: Theme, rhs: Theme) -> Bool {
        lhs.path == rhs.path
    }
}

public protocol ThemeObserver {
    func didChangeTheme()
}

public protocol Updatable: class {
    var updatesPostponed: Bool { get }
    var updatesRejected:  Bool { get }

    func update()
}

public extension Updatable {
    var updatesPostponed: Bool {
        false
    }
    var updatesRejected:  Bool {
        false
    }
}

public protocol _Property {
    associatedtype V

    func get() -> V?
    func unbind(propertyPath: _PropertyPath)
}

public class AnyProperty: _Property {
    let _get:    () -> Any
    let _unbind: (_PropertyPath) -> ()

    public init<P: _Property>(_ property: P) {
        self._get = property.get
        self._unbind = { property.unbind( propertyPath: $0 ) }
    }

    public func get() -> Any? {
        self._get()
    }

    public func unbind(propertyPath: _PropertyPath) {
        self._unbind( propertyPath )
    }
}

public class Property<V>: _Property, Updatable, CustomStringConvertible {
    var parent: Property<V>? {
        didSet {
            self.update()
        }
    }
    var dependants = [ Updatable ]()

    init(parent: Property<V>? = nil) {
        self.parent = parent
    }

    public func get() -> V? {
        self.parent?.get()
    }

    public func transform<T>(_ function: @escaping (V?) -> T?) -> Property<T> {
        let transform = TransformProperty( self, function: function )
        self.dependants.append( transform )

        return transform
    }

    func bind<E>(propertyPath: PropertyPath<E, V>) {
        let updater = PropertyUpdater( value: self.get, propertyPath: propertyPath )
        propertyPath.property = AnyProperty( self )
        self.dependants.append( updater )
        updater.update()
    }

    func bind<E>(propertyPath: PropertyPath<E, NSAttributedString>) {
        let updater = AnyPropertyUpdater( value: self.get, propertyPath: propertyPath )
        propertyPath.property = AnyProperty( self )
        self.dependants.append( updater )
        updater.update()
    }

    public func unbind(propertyPath: _PropertyPath) {
        self.dependants.removeAll { ($0 as? AnyPropertyUpdater)?.has( propertyPath ) ?? false }
    }

    public func update() {
        self.dependants.forEach { $0.update() }
    }

    public var description: String {
        if let parent = self.parent {
            return "parent[ \(parent) ]"
        }
        else {
            return "parent[]"
        }
    }
}

private class AnyPropertyUpdater: Updatable {
    private let propertyPath:  _PropertyPath
    private let valueFunction: () -> Any?

    init(value valueFunction: @escaping () -> Any?, propertyPath: _PropertyPath) {
        self.valueFunction = valueFunction
        self.propertyPath = propertyPath
    }

    func has(_ propertyPath: _PropertyPath) -> Bool {
        self.propertyPath === propertyPath
    }

    func update() {
        self.propertyPath.assign( value: self.valueFunction() )
    }
}

private class PropertyUpdater: AnyPropertyUpdater {
    init<E: AnyObject, V>(value valueFunction: @escaping () -> V?, propertyPath: PropertyPath<E, V>) {
        super.init( value: valueFunction, propertyPath: propertyPath )
    }
}

public class ValueProperty<V>: Property<V> {
    private var value: V?
    var properties = [ (Any, KeyPath<Any, V?>) ]()

    init(_ value: V? = nil, parent: Property<V>? = nil) {
        super.init( parent: parent )
        self.value = value
    }

    public override func get() -> V? {
        self.value ?? super.get()
    }

    func set(_ value: V?) {
        self.value = value
        self.update()
    }

    func clear() {
        self.set( nil )
    }

    public override var description: String {
        if let value = self.value {
            return "value[ \(type( of: value )) ]"
        }
        else {
            return super.description
        }
    }
}

public class FontProperty: ValueProperty<UIFont> {
    private var textStyle: UIFont.TextStyle?

    init(_ value: UIFont? = nil, withTextStyle textStyle: UIFont.TextStyle? = nil, parent: Property<UIFont>? = nil) {
        self.textStyle = textStyle
        super.init( value, parent: parent )
    }

    public override func get() -> UIFont? {
        guard let value = super.get()
        else { return nil }

        guard let textStyle = self.textStyle
        else { return value }

        return UIFontMetrics( forTextStyle: textStyle ).scaledFont( for: value )
    }

    func set(_ value: UIFont?, withTextStyle textStyle: UIFont.TextStyle? = nil) {
        self.textStyle = textStyle
        super.set( value )
    }

    override func clear() {
        self.textStyle = nil
        super.clear()
    }

    public override var description: String {
        if let textStyle = self.textStyle {
            return "\(super.description), textStyle(\(textStyle)) ]"
        }
        else {
            return super.description
        }
    }
}

public class AppearanceProperty<V>: Property<V> {
    private var value: (light: V?, dark: V?)

    init(_ value: (light: V?, dark: V?) = (light: nil, dark: nil), parent: Property<V>? = nil) {
        self.value = value
        super.init( parent: parent )
    }

    public override func get() -> V? {
        if #available( iOS 13, * ) {
            return (UITraitCollection.current.userInterfaceStyle == .dark ? self.value.dark: self.value.light) ?? super.get()
        }
        else {
            return self.value.light ?? super.get()
        }
    }

    func set(light lightValue: V?, dark darkValue: V?) {
        self.value = (light: lightValue, dark: darkValue)
    }

    func set(_ value: V?) {
        self.set( light: value, dark: value )
    }

    public override var description: String {
        if #available( iOS 13, * ) {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                if let value = self.value.dark {
                    return "dark[ \(type( of: value )) ]"
                }
                else {
                    return super.description
                }
            }
            else {
                if let value = self.value.light {
                    return "light[ \(type( of: value )) ]"
                }
                else {
                    return super.description
                }
            }
        }
        else {
            if let value = self.value.light {
                return "light[ \(type( of: value )) ]"
            }
            else {
                return super.description
            }
        }
    }
}

public class TransformProperty<F, T>: Property<T> {
    let from:     Property<F>
    let function: (F?) -> T?

    init(_ from: Property<F>, function: @escaping (F?) -> T?) {
        self.from = from
        self.function = function
        super.init( parent: nil )
    }

    public override func get() -> T? {
        self.function( self.from.get() )
    }

    public override var description: String {
        "transform[ \(self.from) ]"
    }
}

public extension Property where V == UIFont {
    func get(size: CGFloat? = nil, traits: UIFontDescriptor.SymbolicTraits? = nil) -> UIFont? {
        var font = self.get()

        if let traits = traits {
            font = font?.withSymbolicTraits( traits )
        }
        if let size = size {
            font = font?.withSize( size )
        }

        return font
    }
}

public extension Property where V == UIColor {
    func get(tint: UIColor? = nil, alpha: CGFloat? = nil) -> UIColor? {
        var color: UIColor? = self.get()

        if let tint = tint {
            color = color?.with( hue: tint.hue )
        }
        if let alpha = alpha {
            color = color?.with( alpha: alpha )
        }

        return color
    }

    func get(x: Void = ()) -> CGColor? {
        self.get()?.cgColor
    }

    func bind<E>(propertyPath: PropertyPath<E, CGColor>) {
        let updater = PropertyUpdater( value: { self.get() }, propertyPath: propertyPath )
        propertyPath.property = AnyProperty( self )
        self.dependants.append( updater )
        updater.update()
    }
}
