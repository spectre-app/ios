//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

infix operator =>: MultiplicationPrecedence

public func =><E, V>(target: E, keyPath: KeyPath<E, V>) -> PropertyPath<E, V> {
    PropertyPath( target: target, nonnullKeyPath: keyPath, nullableKeyPath: nil, attribute: nil )
}

public func =><E, V>(target: E, keyPath: KeyPath<E, V?>) -> PropertyPath<E, V> {
    PropertyPath( target: target, nonnullKeyPath: nil, nullableKeyPath: keyPath, attribute: nil )
}

public func =><E>(propertyPath: PropertyPath<E, NSAttributedString>, attribute: NSAttributedString.Key)
                -> PropertyPath<E, NSAttributedString> {
    PropertyPath( target: propertyPath.target, nonnullKeyPath: propertyPath.nonnullKeyPath, nullableKeyPath: propertyPath.nullableKeyPath,
                  attribute: attribute )
}

public func =><E, V>(propertyPath: PropertyPath<E, V>, property: Property<V>?) {
    if let property = property {
        property.apply( propertyPath: propertyPath )
    }
    else {
        propertyPath.apply( value: nil )
    }
}

public func =><E>(propertyPath: PropertyPath<E, CGColor>, property: Property<UIColor>?) {
    if let property = property {
        property.apply( propertyPath: propertyPath )
    }
    else {
        propertyPath.apply( value: nil )
    }
}

public func =><E, V>(propertyPath: PropertyPath<E, NSAttributedString>, property: Property<V>?) {
    if let property = property {
        property.apply( propertyPath: propertyPath )
    }
    else {
        propertyPath.apply( value: nil )
    }
}

public struct PropertyPath<E, V>: CustomStringConvertible {
    let target:          E
    let nonnullKeyPath:  KeyPath<E, V>?
    let nullableKeyPath: KeyPath<E, V?>?
    let attribute:       NSAttributedString.Key?

    public var description: String {
        if let attribute = self.attribute {
            return "\(self.propertyDescription) => \(attribute)"
        }
        else {
            return self.propertyDescription
        }
    }

    var propertyDescription: String {
        if let keyPath = self.nullableKeyPath {
            return "\(type( of: self.target )) => \(NSExpression( forKeyPath: keyPath ).keyPath)"
        }
        else if let keyPath = self.nonnullKeyPath {
            return "\(type( of: self.target )) => \(NSExpression( forKeyPath: keyPath ).keyPath)"
        }
        else {
            return "\(type( of: self.target ))"
        }
    }

    func apply(value: V?) {
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

        if let propertyKeyPath = self.nullableKeyPath as? ReferenceWritableKeyPath<E, V?> {
            self.target[keyPath: propertyKeyPath] = value
        }
        else if let propertyKeyPath = self.nonnullKeyPath as? ReferenceWritableKeyPath<E, V>, let value = value {
            self.target[keyPath: propertyKeyPath] = value
        }
    }
}

public extension PropertyPath where V == NSAttributedString {
    func apply(value: Any?) {
        if let attribute = self.attribute, let string = self.target[keyPath: self.nullableKeyPath!] {
            let string = string as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: string )
            if let value = value {
                string.addAttribute( attribute, value: value, range: NSRange( location: 0, length: string.length ) )
            }
            else {
                string.removeAttribute( attribute, range: NSRange( location: 0, length: string.length ) )
            }

            self.apply( value: string )
        }
    }
}

public struct ThemePattern {
    static let dream  = ThemePattern(
            dark: .hex( "385359" ),
            dusk: .hex( "4C6C73" ),
            flat: .hex( "64858C" ),
            dawn: .hex( "AAB9BF" ),
            pale: .hex( "F2F2F2" ) )
    static let aged  = ThemePattern(
            dark: .hex( "07090D" ),
            dusk: .hex( "1E2626" ),
            flat: .hex( "6C7365" ),
            dawn: .hex( "A3A68D" ),
            pale: .hex( "BBBF9F" ) )
    static let pale = ThemePattern(
            dark: .hex( "09090D" ),
            dusk: .hex( "1F1E26" ),
            flat: .hex( "3E5159" ),
            dawn: .hex( "5E848C" ),
            pale: .hex( "B0CDD9" ) )
    static let lush = ThemePattern(
            dark: .hex( "141F26" ),
            dusk: .hex( "213A40" ),
            flat: .hex( "4C6C73" ),
            dawn: .hex( "5D878C" ),
            pale: .hex( "F0F1F2" ) )
    static let oak    = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "262523" ),
            flat: .hex( "595958" ),
            dawn: .hex( "A68877" ),
            pale: .hex( "D9C9BA" ) )
    static let spring = ThemePattern(
            dark: .hex( "0D0D0D" ),
            dusk: .hex( "2E5955" ),
            flat: .hex( "618C8C" ),
            dawn: .hex( "99BFBF" ),
            pale: .hex( "F2F2F2" ) )
    static let fuzzy = ThemePattern(
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
    static let deep = ThemePattern(
            dark: .hex( "1A2A40" ),
            dusk: .hex( "3F4859" ),
            flat: .hex( "877B8C" ),
            dawn: .hex( "B6A8BF" ),
            pale: .hex( "BFCDD9" ) )
    static let sand = ThemePattern(
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

public class Theme: Hashable, CustomStringConvertible, Observable, Updatable {
    private static var byPath    = [ String: Theme ]()
    private static let base      = Theme()

    // Register all theme objects
    public static let  all       = [ Theme.base,
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
    public static let  `default` = all[1]

    public class func with(path: String?) -> Theme? {
        self.all.first { $0.path == path } ?? path<.flatMap { Theme.byPath[$0] } ?? .base
    }

    public let observers = Observers<ThemeObserver>()
    public let font      = Fonts()
    public let color     = Colors()

    public struct Fonts {
        public let largeTitle  = ValueProperty<UIFont>()
        public let title1      = ValueProperty<UIFont>()
        public let title2      = ValueProperty<UIFont>()
        public let title3      = ValueProperty<UIFont>()
        public let headline    = ValueProperty<UIFont>()
        public let subheadline = ValueProperty<UIFont>()
        public let body        = ValueProperty<UIFont>()
        public let callout     = ValueProperty<UIFont>()
        public let caption1    = ValueProperty<UIFont>()
        public let caption2    = ValueProperty<UIFont>()
        public let footnote    = ValueProperty<UIFont>()
        public let password    = ValueProperty<UIFont>()
        public let mono        = ValueProperty<UIFont>()
    }

    public struct Colors {
        public let body        = StyleProperty<UIColor>() //! Text body
        public let secondary   = StyleProperty<UIColor>() //! Text accents / Captions
        public let placeholder = StyleProperty<UIColor>() //! Field hints
        public let backdrop    = StyleProperty<UIColor>() //! Main content background
        public let panel       = StyleProperty<UIColor>() //! Detail content background
        public let shade       = StyleProperty<UIColor>() //! Detail dimming background
        public let shadow      = StyleProperty<UIColor>() //! Text contrast
        public let mute        = StyleProperty<UIColor>() //! Dim content hinting
        public let selection   = StyleProperty<UIColor>() //! Selected content background
        public let tint        = StyleProperty<UIColor>() //! Control accents
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
        self.font.largeTitle.set( .preferredFont( forTextStyle: .largeTitle ) )
        self.font.title1.set( .preferredFont( forTextStyle: .title1 ) )
        self.font.title2.set( .preferredFont( forTextStyle: .title2 ) )
        self.font.title3.set( .preferredFont( forTextStyle: .title3 ) )
        self.font.headline.set( .preferredFont( forTextStyle: .headline ) )
        self.font.subheadline.set( .preferredFont( forTextStyle: .subheadline ) )
        self.font.body.set( .preferredFont( forTextStyle: .body ) )
        self.font.callout.set( .preferredFont( forTextStyle: .callout ) )
        self.font.caption1.set( .preferredFont( forTextStyle: .caption1 ) )
        self.font.caption2.set( .preferredFont( forTextStyle: .caption2 ) )
        self.font.footnote.set( .preferredFont( forTextStyle: .footnote ) )
        self.font.password.set( .monospacedDigitSystemFont( ofSize: 22, weight: .bold ) )
        self.font.mono.set( .monospacedDigitSystemFont( ofSize: UIFont.systemFontSize, weight: .thin ) )
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
            self.color.shadow.set( light: pattern.flat?.with( alpha: .long ), dark: pattern.flat?.with( alpha: .long ) )
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

public protocol Updatable {
    func update()
}

public class Updater: Updatable {
    let action: () -> ()

    public init(_ action: @escaping () -> ()) {
        self.action = action
    }

    public func update() {
        self.action()
    }
}

public class Property<V>: Updatable, CustomStringConvertible {
    var parent: Property<V>? {
        didSet {
            self.update()
        }
    }
    var dependants = [ Updatable ]() // TODO: Don't leak references.

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

    func apply<E>(propertyPath: PropertyPath<E, V>) {
        let updater = Updater( {
            trc( "[apply] %@ => %@", propertyPath, self )
            propertyPath.apply( value: self.get() )
        } )

        self.dependants.append( updater )
        updater.update()
    }

    func apply<E>(propertyPath: PropertyPath<E, NSAttributedString>) {
        let updater = Updater( {
            trc( "[apply] %@ => %@", propertyPath, self )
            propertyPath.apply( value: self.get() )
        } )

        self.dependants.append( updater )
        updater.update()
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

public class StyleProperty<V>: Property<V> {
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
        self.parent?.get()?.cgColor
    }

    func apply<E>(propertyPath: PropertyPath<E, CGColor>) {
        let updater = Updater( {
            trc( "[apply] %@ => %@", propertyPath, self )
            propertyPath.apply( value: self.get() )
        } )

        self.dependants.append( updater )
        updater.update()
    }
}
