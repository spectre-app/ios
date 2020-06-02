//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

infix operator =>: MultiplicationPrecedence

public func =><E, V>(target: E, keyPath: ReferenceWritableKeyPath<E, V?>) -> (E, ReferenceWritableKeyPath<E, V?>) {
    (target, keyPath)
}

public func =><E>(property: (E, ReferenceWritableKeyPath<E, NSAttributedString?>), attribute: NSAttributedString.Key)
                -> (E, ReferenceWritableKeyPath<E, NSAttributedString?>, NSAttributedString.Key) {
    (property.0, property.1, attribute)
}

public func =><E, V>(objectProperty: (E, ReferenceWritableKeyPath<E, V?>), themeProperty: Property<V>?) {
    if let themeProperty = themeProperty {
        themeProperty.apply( to: objectProperty.0, at: objectProperty.1 )
    }
    else {
        objectProperty.0[keyPath: objectProperty.1] = nil
    }
}

public func =><E>(objectProperty: (E, ReferenceWritableKeyPath<E, CGColor?>), themeProperty: Property<UIColor>?) {
    if let themeProperty = themeProperty {
        themeProperty.apply( to: objectProperty.0, at: objectProperty.1 )
    }
    else {
        objectProperty.0[keyPath: objectProperty.1] = nil
    }
}

public func =><E, V>(attributedProperty: (E, ReferenceWritableKeyPath<E, NSAttributedString?>, NSAttributedString.Key), themeProperty: Property<V>?) {
    if let themeProperty = themeProperty {
        themeProperty.apply( to: attributedProperty.0, at: attributedProperty.1, attribute: attributedProperty.2 )
    }
    else if let attributedString = attributedProperty.0[keyPath: attributedProperty.1] {
        let attributedString = attributedString as? NSMutableAttributedString ?? .init( attributedString: attributedString )
        attributedString.removeAttribute( attributedProperty.2, range: NSRange( location: 0, length: attributedString.length ) )
        attributedProperty.0[keyPath: attributedProperty.1] = attributedString
    }
}

public class Theme: Hashable, CustomStringConvertible, Observable, Updatable {
    private static var byPath = [ String: Theme ]()
    private static let base   = Theme()

    public static let all     = [ Theme.default, Theme.base ] // Register all theme objects
    public static let current = Theme( path: "current" )

    // VOLTO:
    // 000F08 004A4F 3E8989 9AD5CA CCE3DE
    public static let `default` = Theme( path: ".volto" ) {
        $0.color.body.set( light: UIColor( hex: "000F08" ), dark: UIColor( hex: "CCE3DE" ) )
        $0.color.secondary.set( light: UIColor( hex: "3E8989" ), dark: UIColor( hex: "3E8989" ) )
        $0.color.placeholder.set( light: UIColor( hex: "004A4F", alpha: 0.382 ), dark: UIColor( hex: "9AD5CA", alpha: 0.382 ) )
        $0.color.backdrop.set( light: UIColor( hex: "CCE3DE" ), dark: UIColor( hex: "000F08" ) )
        $0.color.panel.set( light: UIColor( hex: "9AD5CA" ), dark: UIColor( hex: "004A4F" ) )
        $0.color.shade.set( light: UIColor( hex: "9AD5CA", alpha: 0.618 ), dark: UIColor( hex: "004A4F", alpha: 0.618 ) )
        $0.color.shadow.set( light: UIColor( hex: "9AD5CA", alpha: 0.382 ), dark: UIColor( hex: "004A4F", alpha: 0.382 ) )
        $0.color.mute.set( light: UIColor( hex: "004A4F", alpha: 0.382 ), dark: UIColor( hex: "9AD5CA", alpha: 0.382 ) )
        $0.color.selection.set( light: UIColor( hex: "9AD5CA", alpha: 0.382 ), dark: UIColor( hex: "004A4F", alpha: 0.382 ) )
        $0.color.tint.set( light: UIColor( hex: "9AD5CA" ), dark: UIColor( hex: "004A4F" ) )
    }

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
    public var  description: String {
        self.path
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
        self.color.body.set( UIColor.white )
        self.color.secondary.set( UIColor.lightText )
        self.color.placeholder.set( UIColor.lightText.withAlphaComponent( 0.382 ) )
        self.color.backdrop.set( UIColor.darkGray )
        self.color.panel.set( UIColor.black )
        self.color.shade.set( UIColor.black.withAlphaComponent( 0.618 ) )
        self.color.shadow.set( UIColor.black.withAlphaComponent( 0.382 ) )
        self.color.mute.set( UIColor.white.withAlphaComponent( 0.382 ) )
        self.color.selection.set( UIColor.lightGray )
        self.color.tint.set( UIColor( hex: "00A99C" ) )

        if #available( iOS 13, * ) {
            self.font.mono.set( .monospacedSystemFont( ofSize: UIFont.labelFontSize, weight: .thin ) )

            self.color.body.set( UIColor.label )
            self.color.secondary.set( UIColor.secondaryLabel )
            self.color.placeholder.set( UIColor.placeholderText )
            self.color.backdrop.set( UIColor.systemBackground )
            self.color.panel.set( UIColor.secondarySystemBackground )
            self.color.shadow.set( UIColor.secondarySystemFill )
            self.color.mute.set( UIColor.systemFill )
            self.color.selection.set( UIColor.link )
        }

        Theme.byPath[""] = self
    }

    private init(path: String, override: ((Theme) -> ())? = nil) {
        var parent: Theme?
        if let lastDot = path.lastIndex( of: "." ) {
            self.name = String( path[path.index( after: lastDot )..<path.endIndex] )
            parent = String( path[path.startIndex..<lastDot] )<.flatMap { Theme.byPath[$0] } ?? .base
        }
        else {
            self.name = path
        }

        Theme.byPath[path] = self
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

    func apply<E>(to target: E?, at keyPath: ReferenceWritableKeyPath<E, V?>) {
        let updater = Updater( {
            if let target = target {
                trc( "%@ => %@ => %@", String( describing: type( of: target ) ), NSExpression( forKeyPath: keyPath ).keyPath, self )

                target[keyPath: keyPath] = self.get()
            }
        } )

        self.dependants.append( updater )
        updater.update()
    }

    func apply<E>(to target: E?, at keyPath: ReferenceWritableKeyPath<E, NSAttributedString?>, attribute: NSAttributedString.Key) {
        let updater = Updater( {
            if let target = target, let string = target[keyPath: keyPath] {
                trc( "%@ => %@ => %@ => %@", String( describing: type( of: target ) ), NSExpression( forKeyPath: keyPath ).keyPath, attribute.rawValue, self )

                let string = string as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: string )
                if let value = self.get() {
                    string.addAttribute( attribute, value: value, range: NSRange( location: 0, length: string.length ) )
                }
                else {
                    string.removeAttribute( attribute, range: NSRange( location: 0, length: string.length ) )
                }
                target[keyPath: keyPath] = string
            }
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
    var properties = [ (Any, ReferenceWritableKeyPath<Any, V?>) ]()

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
            color = color?.withHueComponent( tint.hue() )
        }
        if let alpha = alpha {
            color = color?.withAlphaComponent( alpha )
        }

        return color
    }

    func get(x: Void = ()) -> CGColor? {
        self.parent?.get()?.cgColor
    }

    func apply<E>(to target: E?, at keyPath: ReferenceWritableKeyPath<E, CGColor?>) {
        let updater = Updater( {
            if let target = target {
                trc( "%@ @ %@ = %@", String( describing: type( of: target ) ), NSExpression( forKeyPath: keyPath ).keyPath, self )

                target[keyPath: keyPath] = self.get()
            }
        } )

        self.dependants.append( updater )
        updater.update()
    }
}
