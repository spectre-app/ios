//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

public class MPTheme: Hashable, CustomStringConvertible {
    public static let  all    = [ MPTheme.default, MPTheme.dark ]
    private static var byPath = [ String: MPTheme ]()

    public static let `default` = MPTheme()
    public static let dark = MPTheme( path: ".dark" ) {
        $0.color.brand.set( UIColor( hex: "1C343B" ) )
        $0.color.selection.set( UIColor( hex: "78DDFB" )?.withAlphaComponent( 0.382 ) )
    }

    public class func with(path: String?) -> MPTheme? {
        path.flatMap { MPTheme.byPath[$0] }
    }

    public let font:  Fonts
    public let color: Colors

    public struct Fonts {
        public let largeTitle:  Value<UIFont>
        public let title1:      Value<UIFont>
        public let title2:      Value<UIFont>
        public let title3:      Value<UIFont>
        public let headline:    Value<UIFont>
        public let subheadline: Value<UIFont>
        public let body:        Value<UIFont>
        public let callout:     Value<UIFont>
        public let caption1:    Value<UIFont>
        public let caption2:    Value<UIFont>
        public let footnote:    Value<UIFont>
        public let password:    Value<UIFont>
        public let mono:        Value<UIFont>
    }

    public struct Colors {
        public let body:      Value<UIColor>
        public let secondary: Value<UIColor>
        public let backbody:  Value<UIColor>
        public let backdrop:  Value<UIColor>
        public let panel:     Value<UIColor>
        public let shade:     Value<UIColor>
        public let shadow:    Value<UIColor>
        public let glow:      Value<UIColor>
        public let mute:      Value<UIColor>
        public let selection: Value<UIColor>
        public let brand:     Value<UIColor>
    }

    // MARK: --- Life ---

    private let parent:      MPTheme?
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

    private init() {
        self.name = ""
        self.parent = nil

        // Global default style
        self.font = Fonts(
                largeTitle: {
                    if #available( iOS 11, * ) {
                        return Value( UIFont.preferredFont( forTextStyle: .largeTitle ) )
                    }
                    else {
                        return Value( UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold ) )
                    }
                }(),
                title1: Value( UIFont.preferredFont( forTextStyle: .title1 ) ),
                title2: Value( UIFont.preferredFont( forTextStyle: .title2 ) ),
                title3: Value( UIFont.preferredFont( forTextStyle: .title3 ) ),
                headline: Value( UIFont.preferredFont( forTextStyle: .headline ) ),
                subheadline: Value( UIFont.preferredFont( forTextStyle: .subheadline ) ),
                body: Value( UIFont.preferredFont( forTextStyle: .body ) ),
                callout: Value( UIFont.preferredFont( forTextStyle: .callout ) ),
                caption1: Value( UIFont.preferredFont( forTextStyle: .caption1 ) ),
                caption2: Value( UIFont.preferredFont( forTextStyle: .caption2 ) ),
                footnote: Value( UIFont.preferredFont( forTextStyle: .footnote ) ),
                password: Value( .monospacedDigitSystemFont( ofSize: 22, weight: .black ) ),
                mono: {
                    if #available( iOS 13, * ) {
                        return Value( .monospacedSystemFont( ofSize: UIFont.labelFontSize, weight: .thin ) )
                    }
                    else {
                        return Value( .monospacedDigitSystemFont( ofSize: UIFont.labelFontSize, weight: .thin ) )
                    }
                }() )
        self.color = Colors(
                body: Value( UIColor.white ),
                secondary: Value( UIColor.lightText ),
                backbody: Value( UIColor.darkText ),
                backdrop: Value( UIColor.darkGray ),
                panel: Value( UIColor.black ),
                shade: Value( UIColor.black.withAlphaComponent( 0.618 ) ),
                shadow: Value( UIColor.black.withAlphaComponent( 0.382 ) ),
                glow: Value( UIColor.white ),
                mute: Value( UIColor.white.withAlphaComponent( 0.382 ) ),
                selection: Value( UIColor( red: 0.4, green: 0.8, blue: 1, alpha: 0.382 ) ),
                brand: Value( UIColor( hex: "00A99C" ) ) )

        MPTheme.byPath[""] = self
    }

    private init(path: String, override: (MPTheme) -> ()) {
        if let lastDot = path.lastIndex( of: "." ) {
            self.parent = MPTheme.with( path: String( path[path.startIndex..<lastDot] ) )
            self.name = String( path[path.index( after: lastDot )..<path.endIndex] )
        }
        else {
            self.parent = nil
            self.name = path
        }

        // Parent delegation
        self.font = Fonts( largeTitle: Value( parent: self.parent?.font.largeTitle ),
                           title1: Value( parent: self.parent?.font.title1 ),
                           title2: Value( parent: self.parent?.font.title2 ),
                           title3: Value( parent: self.parent?.font.title3 ),
                           headline: Value( parent: self.parent?.font.headline ),
                           subheadline: Value( parent: self.parent?.font.subheadline ),
                           body: Value( parent: self.parent?.font.body ),
                           callout: Value( parent: self.parent?.font.callout ),
                           caption1: Value( parent: self.parent?.font.caption1 ),
                           caption2: Value( parent: self.parent?.font.caption2 ),
                           footnote: Value( parent: self.parent?.font.footnote ),
                           password: Value( parent: self.parent?.font.password ),
                           mono: Value( parent: self.parent?.font.mono ) )
        self.color = Colors( body: Value( parent: self.parent?.color.body ),
                             secondary: Value( parent: self.parent?.color.secondary ),
                             backbody: Value( parent: self.parent?.color.backbody ),
                             backdrop: Value( parent: self.parent?.color.backdrop ),
                             panel: Value( parent: self.parent?.color.panel ),
                             shade: Value( parent: self.parent?.color.shade ),
                             shadow: Value( parent: self.parent?.color.shadow ),
                             glow: Value( parent: self.parent?.color.glow ),
                             mute: Value( parent: self.parent?.color.mute ),
                             selection: Value( parent: self.parent?.color.selection ),
                             brand: Value( parent: self.parent?.color.brand ) )

        MPTheme.byPath[path] = self

        override( self )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine( self.path )
    }

    public static func ==(lhs: MPTheme, rhs: MPTheme) -> Bool {
        lhs.path == rhs.path
    }

    public class Value<V> {
        var value:  V?
        let parent: Value<V>?

        init(_ value: V? = nil, parent: Value<V>? = nil) {
            self.value = value
            self.parent = parent
        }

        public func get() -> V? {
            self.value ?? self.parent?.get()
        }

        func set(_ value: V?) {
            self.value = value
        }

        func clear() {
            self.value = nil
        }
    }
}

extension MPTheme.Value where V == UIColor {
    func tint(_ color: UIColor?) -> UIColor? {
        get()?.withHue( color )
    }
}
