//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

public class MPTheme: Hashable, CustomStringConvertible {
    private static var byPath = [ String: MPTheme ]()

    public static let all = [ MPTheme.default, MPTheme.dark ] // Register all theme objects

    public static let base = MPTheme()

    // VOLTO:
    // 000F08 004A4F 3E8989 9AD5CA CCE3DE
    public static let `default` = MPTheme( path: ".volto" ) {
        $0.color.backdrop.set( UIColor( hex: "CCE3DE" ) )
        $0.color.panel.set( UIColor( hex: "CCE3DE" ) )
        $0.color.selection.set( UIColor( hex: "9AD5CA", alpha: 0.382 ) )
        $0.color.tint.set( UIColor( hex: "9AD5CA" ) )
        $0.color.body.set( UIColor( hex: "000F08" ) )
    }
    public static let dark = MPTheme( path: ".volto.dark" ) {
        $0.color.backdrop.set( UIColor( hex: "004A4F" ) )
        $0.color.panel.set( UIColor( hex: "3E8989" ) )
        $0.color.selection.set( UIColor( hex: "9AD5CA", alpha: 0.382 ) )
        $0.color.tint.set( UIColor( hex: "3E8989" ) )
        $0.color.body.set( UIColor( hex: "CCE3DE" ) )
    }

    public class func with(path: String?) -> MPTheme? {
        self.all.first { $0.path == path } ?? path<.flatMap { MPTheme.byPath[$0] } ?? .base
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
        public let body:        Value<UIColor>
        public let secondary:   Value<UIColor>
        public let placeholder: Value<UIColor>
        public let backdrop:    Value<UIColor>
        public let panel:       Value<UIColor>
        public let shade:       Value<UIColor>
        public let shadow:      Value<UIColor>
        public let mute:        Value<UIColor>
        public let selection:   Value<UIColor>
        public let tint:        Value<UIColor>
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
                largeTitle: Value( UIFont.preferredFont( forTextStyle: .largeTitle ) ),
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
                password: Value( .monospacedDigitSystemFont( ofSize: 22, weight: .bold ) ),
                mono: Value( .monospacedDigitSystemFont( ofSize: UIFont.systemFontSize, weight: .thin ) ) )
        self.color = Colors(
                body: Value( UIColor.white ),
                secondary: Value( UIColor.lightText ),
                placeholder: Value( UIColor.lightText.withAlphaComponent( 0.382 ) ),
                backdrop: Value( UIColor.darkGray ),
                panel: Value( UIColor.black ),
                shade: Value( UIColor.black.withAlphaComponent( 0.618 ) ),
                shadow: Value( UIColor.black.withAlphaComponent( 0.382 ) ),
                mute: Value( UIColor.white.withAlphaComponent( 0.382 ) ),
                selection: Value( UIColor.lightGray ),
                tint: Value( UIColor( hex: "00A99C" ) ) )

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

        MPTheme.byPath[""] = self
    }

    private init(path: String, override: (MPTheme) -> ()) {
        if let lastDot = path.lastIndex( of: "." ) {
            self.parent = String( path[path.startIndex..<lastDot] )<.flatMap { MPTheme.byPath[$0] } ?? .base
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
                             placeholder: Value( parent: self.parent?.color.placeholder ),
                             backdrop: Value( parent: self.parent?.color.backdrop ),
                             panel: Value( parent: self.parent?.color.panel ),
                             shade: Value( parent: self.parent?.color.shade ),
                             shadow: Value( parent: self.parent?.color.shadow ),
                             mute: Value( parent: self.parent?.color.mute ),
                             selection: Value( parent: self.parent?.color.selection ),
                             tint: Value( parent: self.parent?.color.tint ) )

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
