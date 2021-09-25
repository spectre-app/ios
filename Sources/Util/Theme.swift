// =============================================================================
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

//
// An object O has a key path K with value V. A property P can bind to O's K to sync its V with the property's own value.
//

infix operator =>: MultiplicationPrecedence

// Level 1: Obtain a property path to object O's key path K.

func => <E: NSObject, V>(target: E, keyPath: KeyPath<E, V>)
                -> PropertyPath<E, V> {
    find( propertyPath: PropertyPath( target: target, nonnullKeyPath: keyPath, nullableKeyPath: nil, attribute: nil ),
          identity: target, keyPath )
}

func => <E: NSObject, V>(target: E, keyPath: KeyPath<E, V?>)
                -> PropertyPath<E, V> {
    find( propertyPath: PropertyPath( target: target, nonnullKeyPath: nil, nullableKeyPath: keyPath, attribute: nil ),
          identity: target, keyPath )
}

func => <E: NSObject>(propertyPath: PropertyPath<E, NSAttributedString>, attribute: NSAttributedString.Key)
                -> PropertyPath<E, NSAttributedString> {
    find( propertyPath: PropertyPath( target: propertyPath.target!, nonnullKeyPath: propertyPath.nonnullKeyPath,
                                      nullableKeyPath: propertyPath.nullableKeyPath, attribute: attribute ),
          identity: propertyPath.target, propertyPath.nonnullKeyPath ?? propertyPath.nullableKeyPath, attribute.rawValue as NSString )
}

private var cachedPropertyPaths = NSCache<Identity, AnyPropertyPath>()
private var activePropertyPaths = [ Identity: WeakBox<AnyPropertyPath> ]()

private func find<E, V>(propertyPath: @autoclosure () -> PropertyPath<E, V>, identity members: AnyObject?...)
                -> PropertyPath<E, V> {
    let identity = Identity( members )
    //dbg( "[properties] finding identity(%x) with members: %@", identity.hashValue, members )
    if let propertyPath = activePropertyPaths[identity]?.value as? PropertyPath<E, V>, propertyPath.target != nil {
        //dbg( "[properties] found existing property path with identity(%x): %@", identity.hashValue, propertyPath )
        return propertyPath
    }

    let propertyPath = propertyPath()
    //dbg( "[properties] no existing property paths with identity(%x), creating: %@", identity.hashValue, propertyPath )
    cachedPropertyPaths.setObject( propertyPath, forKey: identity )
    activePropertyPaths[identity] = WeakBox( propertyPath )
    return propertyPath
}

private class Identity: Equatable, Hashable {
    let members: [ObjectIdentifier]

    init(_ members: [AnyObject?]) {
        self.members = members.map { $0.flatMap { ObjectIdentifier( $0 ) } ?? ObjectIdentifier( NSNull.self ) }
    }

    func hash(into hasher: inout Hasher) {
        self.members.hash( into: &hasher )
    }

    static func == (lhs: Identity, rhs: Identity) -> Bool {
        lhs.members.elementsEqual( rhs.members )
    }
}

// Level 2: Bind the property path to a property P.

func => <E, V>(propertyPath: PropertyPath<E, V>, property: Property<V>?) {
    if let property = property {
        propertyPath.bind( property: property )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

func => <E>(propertyPath: PropertyPath<E, CGColor>, property: Property<UIColor>?) {
    if let property = property {
        propertyPath.bind( property: property )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

func => <E, V>(propertyPath: PropertyPath<E, NSAttributedString>, property: Property<V>?) {
    if let property = property {
        propertyPath.bind( property: property )
    }
    else {
        propertyPath.assign( value: nil )
    }
}

class AnyPropertyPath: CustomDebugStringConvertible {
    var debugDescription: String {
        "-"
    }

    func assign(value: @autoclosure () -> Any?) {
    }
}

class PropertyPath<E, V>: AnyPropertyPath where E: AnyObject {

    let nonnullKeyPath:  KeyPath<E, V>?
    let nullableKeyPath: KeyPath<E, V?>?
    let attribute:       NSAttributedString.Key?

    internal weak var target: E?
    private var property: AnyProperty? {
        didSet {
            if oldValue !== self.property {
                if let oldProperty = oldValue, let binding = self.binding {
                    oldProperty.unbind( binding: binding )
                }
                if let newProperty = self.property {
                    self.binding = newProperty.bind( propertyPath: self )
                }
            } else {
                self.binding?.doUpdate()
            }
        }
    }
    private var binding:  Updates?

    override var debugDescription: String {
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
            return "\(targetDescription) => \(keyPath._kvcKeyPathString ?? String( describing: keyPath ))"
        }
        else if let keyPath = self.nonnullKeyPath {
            return "\(targetDescription) => \(keyPath._kvcKeyPathString ?? String( describing: keyPath ))"
        }
        else {
            return "\(self.target == nil ? String( reflecting: E.self ): String( reflecting: self.target! ))"
        }
    }

    fileprivate init(target: E, nonnullKeyPath: KeyPath<E, V>?, nullableKeyPath: KeyPath<E, V?>?, attribute: NSAttributedString.Key?) {
        self.target = target
        self.nonnullKeyPath = nonnullKeyPath
        self.nullableKeyPath = nullableKeyPath
        self.attribute = attribute
    }

    func bind(property: AnyProperty) {
        if self.property == nil, let target = self.target {
            let cleaners = objc_getAssociatedObject( target, #function ) as? NSMutableArray ?? .init()
            //dbg( "[properties] creating property path cleaner: %@", self )
            cleaners.add( PropertyPathCleaner( target: target, propertyPath: self ) )
            objc_setAssociatedObject( target, #function, cleaners, .OBJC_ASSOCIATION_RETAIN )
        }

        //dbg( "[properties] bind property path: %@ to %@", self, property )
        self.property = property
    }

    func unbind() {
        if self.property != nil {
            //dbg( "[properties] unbind property path: %@", self )
        }
        self.property = nil
    }

    override func assign(value: @autoclosure () -> Any?) {
        guard let target = self.target
        else { return }

        var value = value()

        if let color = (value as? UIColor)?.cgColor as? V {
            value = color
        }

        if let attribute = self.attribute, let string = target[keyPath: self.nullableKeyPath!] as? NSAttributedString {
            let oldString   = NSAttributedString( attributedString: string )
            let string      = string as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: string )
            let stringRange = NSRange( location: 0, length: string.length )

            if let value = value {
                // Retain existing foregroundColor alpha (eg. duotone).
                if attribute == .foregroundColor, let primaryColor = value as? UIColor {
                    string.enumerateAttribute( .foregroundColor, in: stringRange ) { value, range, _ in
                        if let currentColor = value as? UIColor {
                            string.addAttribute( .foregroundColor, value: primaryColor.with( alpha: currentColor.alpha ), range: range )
                        }
                    }
                }
                // strokeColor without strokeWidth overrides foregroundColor with an alternative color.
                else if attribute == .strokeColor, let secondaryColor = value as? UIColor {
                    string.enumerateAttribute( .strokeColor, in: stringRange ) { value, range, _ in
                        if value != nil,
                           (string.attribute( .strokeWidth, at: range.location, effectiveRange: nil ) as? NSNumber)?.intValue ?? 0 == 0 {
                            string.addAttribute( .foregroundColor, value: secondaryColor, range: range )
                        }
                    }
                }
                // Update attribute without any special handling.
                else {
                    string.addAttribute( attribute, value: value, range: stringRange )
                }
            }
            // Remove attribute without any special handling.
            else {
                string.removeAttribute( attribute, range: stringRange )
            }

            // Restore Font Awesome elements after updating fonts.
            if attribute == .font, let font = value as? UIFont, !font.familyName.contains( "Font Awesome" ) {
                oldString.enumerateAttribute( .font, in: stringRange ) { value, range, _ in
                    if let oldFont = value as? UIFont, oldFont.familyName.contains( "Font Awesome" ) {
                        string.addAttribute( .font, value: oldFont.withSize( font.pointSize ), range: range )
                    }
                }
            }

            value = string
        }

        //dbg( "[properties] assign => path %@, value: %@", self, value )
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

class PropertyPathCleaner<E, V> where E: AnyObject {
    weak var target: E?
    let propertyPath: PropertyPath<E, V>

    init(target: E?, propertyPath: PropertyPath<E, V>) {
        self.target = target
        self.propertyPath = propertyPath
    }

    deinit {
        //dbg( "[properties] deinit property path cleaner for: %@", self.propertyPath )
        if self.propertyPath.target === self.target {
            self.propertyPath.unbind()
        }
    }
}

struct ThemePattern {
    static let spectre = ThemePattern(
            dark: .hex( "0E3345" ),
            dusk: .hex( "173D50" ),
            flat: .hex( "41A0A0" ),
            dawn: .hex( "F1F9FC" ),
            pale: .hex( "FFFFFF" ) )
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

public enum AppIcon: String, CaseIterable {
    case iconLight = "Light Icon", logoLight = "Light Logo", iconDark = "Dark Icon", logoDark = "Dark Logo"

    static let primary = AppIcon.iconLight
    static var current: AppIcon {
        #if TARGET_APP
        self.allCases.first( where: { $0.rawValue == UIApplication.shared.alternateIconName } ) ?? .primary
        #else
        AppConfig.shared.appIcon
        #endif
    }

    var image: UIImage? {
        UIImage( named: self.rawValue + " Image" )
    }

    #if TARGET_APP
    func activate() {
        DispatchQueue.main.perform {
            UIApplication.shared.setAlternateIconName( self == .primary ? nil: self.rawValue ) { error in
                if let error = error {
                    mperror( title: "Couldn't change app icon.", error: error )
                }
                else {
                    AppConfig.shared.appIcon = self
                }
            }
        }
    }
    #endif
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

class Theme: Hashable, CustomStringConvertible, Observable, Updatable {
    private static var byPath = [ String: Theme ]()
    private static let base   = Theme()

    // Register all theme objects
    static let allCases  = [ Theme.base,
                             Theme( path: ".spectre", pattern: .spectre,
                                    mood: "It's just a mental reflection." ),
                             Theme( path: ".dream", pattern: .dream,
                                    mood: "This weather is for dreaming." ),
                             Theme( path: ".deep", pattern: .deep,
                                    mood: "I am my past and I am beautiful." ),
                             Theme( path: ".sand", pattern: .sand,
                                    mood: "Sandstone cabin by the beech." ),
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
                             Theme( path: ".pale", pattern: .pale,
                                    mood: "Weathered stone foundation standing tall." ),
                             Theme( path: ".aged", pattern: .aged,
                                    mood: "Whiff of a Victorian manuscript." ),
    ]
    static let current   = Theme( path: "current" )

    // SPECTRE:
    static let `default` = allCases[1]

    class func with(path: String?) -> Theme? {
        self.allCases.first { $0.path == path } ?? path?.nonEmpty.flatMap { Theme.byPath[$0] } ?? .base
    }

    let observers = Observers<ThemeObserver>()
    let font      = Fonts()
    let color     = Colors()

    struct Fonts {
        let largeTitle  = FontProperty()
        let title1      = FontProperty()
        let title2      = FontProperty()
        let title3      = FontProperty()
        let headline    = FontProperty()
        let subheadline = FontProperty()
        let body        = FontProperty()
        let callout     = FontProperty()
        let caption1    = FontProperty()
        let caption2    = FontProperty()
        let footnote    = FontProperty()
        let password    = FontProperty()
        let mono        = FontProperty()
    }

    struct Colors {
        let body        = AppearanceProperty<UIColor>() //! Text body
        let secondary   = AppearanceProperty<UIColor>() //! Text accents / Captions
        let placeholder = AppearanceProperty<UIColor>() //! Field hints
        let backdrop    = AppearanceProperty<UIColor>() //! Main content background
        let panel       = AppearanceProperty<UIColor>() //! Detail content background
        let shade       = AppearanceProperty<UIColor>() //! Detail dimming background
        let shadow      = AppearanceProperty<UIColor>() //! Text contrast
        let mute        = AppearanceProperty<UIColor>() //! Dim content hinting
        let selection   = AppearanceProperty<UIColor>() //! Selected content background
        let tint        = AppearanceProperty<UIColor>() //! Control accents
    }

    // MARK: - Life

    var parent: Theme? {
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

            self.updateTask.request()
        }
    }
    private let name: String
    var path:        String {
        if let parent = parent {
            return "\(parent.path).\(self.name)"
        }
        else {
            return self.name
        }
    }
    var mood:        String?
    var description: String {
        self.mood ?? self.parent?.description ?? self.path
    }

    // Theme.base
    private init() {
        self.name = ""
        self.mood = "Device native colour scheme."

        // Global default style
        self.font.largeTitle.set( UIFont.poppins( .light, asTextStyle: .largeTitle ), withTextStyle: .largeTitle )
        self.font.title1.set( UIFont.poppins( .regular, asTextStyle: .title1 ), withTextStyle: .title1 )
        self.font.title2.set( UIFont.poppins( .medium, asTextStyle: .title2 ), withTextStyle: .title2 )
        self.font.title3.set( UIFont.poppins( .regular, asTextStyle: .title3 ), withTextStyle: .title3 )
        self.font.headline.set( UIFont.poppins( .medium, asTextStyle: .headline ), withTextStyle: .headline )
        self.font.subheadline.set( UIFont.poppins( .regular, asTextStyle: .subheadline ), withTextStyle: .subheadline )
        self.font.body.set( UIFont.poppins( .light, asTextStyle: .body ), withTextStyle: .body )
        self.font.callout.set( UIFont.poppins( .regular, asTextStyle: .callout ), withTextStyle: .callout )
        self.font.caption1.set( UIFont.poppins( .regular, asTextStyle: .caption1 ), withTextStyle: .caption1 )
        self.font.caption2.set( UIFont.poppins( .medium, asTextStyle: .caption2 ), withTextStyle: .caption2 )
        self.font.footnote.set( UIFont.poppins( .medium, asTextStyle: .footnote ), withTextStyle: .footnote )
        self.font.password.set( UIFont.sourceCodePro( .semibold, ofSize: 16 ), withTextStyle: .largeTitle )
        self.font.mono.set( UIFont.sourceCodePro( .thin, ofSize: UIFont.systemFontSize ), withTextStyle: .body )
        self.color.body.set( UIColor.darkText )
        self.color.secondary.set( UIColor.darkGray.with( alpha: .long ) )
        self.color.placeholder.set( UIColor.darkGray.with( alpha: .short ) )
        self.color.backdrop.set( UIColor.white )
        self.color.panel.set( UIColor.groupTableViewBackground )
        self.color.shade.set( UIColor.lightText )
        self.color.shadow.set( UIColor.white.with( alpha: .long ) )
        self.color.mute.set( UIColor.darkGray.with( alpha: .short * .short ) )
        self.color.selection.set( .hex( "41A0A0" )?.with( alpha: .short ) )
        self.color.tint.set( .hex( "41A0A0" ) )

        if #available( iOS 13, * ) {
            self.font.mono.set( .monospacedSystemFont( ofSize: UIFont.labelFontSize, weight: .thin ) )
            self.color.body.set( UIColor.label )
            self.color.secondary.set( UIColor.secondaryLabel )
            self.color.placeholder.set( UIColor.placeholderText )
            self.color.backdrop.set( UIColor.systemBackground )
            self.color.panel.set( UIColor.secondarySystemBackground )
            self.color.shade.set( UIColor.systemFill )
            self.color.shadow.set( UIColor.systemBackground.with( alpha: .long ) )
            self.color.mute.set( UIColor.separator )
        }

        Theme.byPath[""] = self
    }

    private init(path: String, pattern: ThemePattern? = nil, mood: String? = nil, override: ((Theme) -> Void)? = nil) {
        self.mood = mood

        var parent: Theme?
        if let lastDot = path.lastIndex( of: "." ) {
            self.name = String( path[path.index( after: lastDot )..<path.endIndex] )
            parent = String( path[path.startIndex..<lastDot] ).nonEmpty.flatMap { Theme.byPath[$0] } ?? .base
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
            self.color.shadow.set( light: pattern.pale?.with( alpha: .long ), dark: pattern.dark?.with( alpha: .long ) )
            self.color.mute.set( light: pattern.dusk?.with( alpha: .short * .short ), dark: pattern.dawn?.with( alpha: .short * .short ) )
            self.color.selection.set( light: pattern.flat?.with( alpha: .short ), dark: pattern.flat?.with( alpha: .short ) )
            self.color.tint.set( light: pattern.flat, dark: pattern.flat )
        }
        override?( self )

        defer {
            self.parent = parent
        }
    }

    lazy var updateTask = DispatchTask.update( self ) { [weak self] in
        guard let self = self
        else { return }

        self.font.largeTitle.doUpdate()
        self.font.title1.doUpdate()
        self.font.title2.doUpdate()
        self.font.title3.doUpdate()
        self.font.headline.doUpdate()
        self.font.subheadline.doUpdate()
        self.font.body.doUpdate()
        self.font.callout.doUpdate()
        self.font.caption1.doUpdate()
        self.font.caption2.doUpdate()
        self.font.footnote.doUpdate()
        self.font.password.doUpdate()
        self.font.mono.doUpdate()
        self.color.body.doUpdate()
        self.color.secondary.doUpdate()
        self.color.placeholder.doUpdate()
        self.color.backdrop.doUpdate()
        self.color.panel.doUpdate()
        self.color.shade.doUpdate()
        self.color.shadow.doUpdate()
        self.color.mute.doUpdate()
        self.color.selection.doUpdate()
        self.color.tint.doUpdate()

        self.observers.notify( event: { $0.didChange( theme: self ) } )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.path )
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.path == rhs.path
    }
}

protocol ThemeObserver {
    func didChange(theme: Theme)
}

class AnyProperty: Updates {
    var updates = [ WeakBox<Updates> ]()

    func getAny() -> Any? {
        nil
    }

    func bind(propertyPath: AnyPropertyPath) -> Updates {
        let updater = PropertyUpdater( property: self, propertyPath: propertyPath )
        self.updates.append( WeakBox( updater ) )
        updater.doUpdate()
        //dbg( "[properties] bind => property %@, bound to: %@", self, self.updates )

        return updater
    }

    func unbind(binding: Updates) {
        self.updates.removeAll { $0.value === binding }
        //dbg( "[properties] unbind => property %@, bound to: %@", self, self.updates )
    }

    func doUpdate() {
        self.updates.forEach { $0.value?.doUpdate() }
    }
}

private class PropertyUpdater: Updates, CustomDebugStringConvertible {
    private weak var propertyPath: AnyPropertyPath?
    private let property: AnyProperty

    var debugDescription: String {
        "update[\(self.propertyPath?.debugDescription ?? "gone"), from: \(self.property)]"
    }

    init(property: AnyProperty, propertyPath: AnyPropertyPath) {
        self.property = property
        self.propertyPath = propertyPath
    }

    func doUpdate() {
        self.propertyPath?.assign( value: self.property.getAny() )
    }
}

class Property<V>: AnyProperty, CustomDebugStringConvertible {
    weak var parent: Property<V>? {
        didSet {
            self.doUpdate()
        }
    }

    var debugDescription: String {
        if let property = property( of: Theme.current.color, withValue: self ) {
            return "Theme.color.\(property)"
        }
        else if let property = property( of: Theme.current.font, withValue: self ) {
            return "Theme.font.\(property)"
        }
        else {
            return self.valueDescription
        }
    }

    var valueDescription: String {
        if let parent = self.parent {
            return "child-of[ \(parent) ]"
        }
        else {
            return "child-of[]"
        }
    }

    init(parent: Property<V>? = nil) {
        self.parent = parent
    }

    override func getAny() -> Any? {
        self.get()
    }

    func get() -> V? {
        self.parent?.get()
    }

    func transform<T>(_ function: @escaping (V?) -> T?) -> Property<T> {
        let updater = TransformProperty( self, function: function )
        self.updates.append( WeakBox( updater ) )
        //dbg( "[properties] transform => property %@, bound to: %@", self, self.updates )

        return updater
    }
}

class ValueProperty<V>: Property<V> {
    private var value: V?
    var properties = [ (Any, KeyPath<Any, V?>) ]()

    init(_ value: V? = nil, parent: Property<V>? = nil) {
        super.init( parent: parent )
        self.value = value
    }

    override func get() -> V? {
        self.value ?? super.get()
    }

    func set(_ value: V?) {
        self.value = value
        self.doUpdate()
    }

    func clear() {
        self.set( nil )
    }

    override var valueDescription: String {
        if let value = self.value {
            return "value[ \(type( of: value )) ]"
        }
        else {
            return super.valueDescription
        }
    }
}

class FontProperty: ValueProperty<UIFont> {
    private var textStyle: UIFont.TextStyle?

    init(_ value: UIFont? = nil, withTextStyle textStyle: UIFont.TextStyle? = nil, parent: Property<UIFont>? = nil) {
        self.textStyle = textStyle
        super.init( value, parent: parent )
    }

    override func get() -> UIFont? {
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

    override var valueDescription: String {
        if let textStyle = self.textStyle {
            return "\(super.valueDescription), textStyle(\(textStyle)) ]"
        }
        else {
            return super.valueDescription
        }
    }
}

class AppearanceProperty<V>: Property<V> {
    private var value: (light: V?, dark: V?)

    init(_ value: (light: V?, dark: V?) = (light: nil, dark: nil), parent: Property<V>? = nil) {
        self.value = value
        super.init( parent: parent )
    }

    override func get() -> V? {
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

    override var valueDescription: String {
        if #available( iOS 13, * ) {
            if UITraitCollection.current.userInterfaceStyle == .dark {
                if let value = self.value.dark {
                    return "dark[ \(type( of: value )) ]"
                }
                else {
                    return super.valueDescription
                }
            }
            else {
                if let value = self.value.light {
                    return "light[ \(type( of: value )) ]"
                }
                else {
                    return super.valueDescription
                }
            }
        }
        else {
            if let value = self.value.light {
                return "light[ \(type( of: value )) ]"
            }
            else {
                return super.valueDescription
            }
        }
    }
}

class TransformProperty<F, T>: Property<T> {
    let from:     Property<F>
    let function: (F?) -> T?

    init(_ from: Property<F>, function: @escaping (F?) -> T?) {
        self.from = from
        self.function = function
        super.init( parent: nil )
    }

    override func get() -> T? {
        self.function( self.from.get() )
    }

    override var valueDescription: String {
        "transform[ \(self.from) ]"
    }
}
