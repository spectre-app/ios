//
// Created by Maarten Billemont on 2020-07-31.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

public enum IconStyle {
    case brands, duotone, solid, light, regular

    var fontName: String {
        switch self {
            case .brands:
                return "FontAwesome6Brands-Regular"
            case .duotone:
                return "FontAwesome6Duotone-Solid"
            case .solid:
                return "FontAwesome6Pro-Solid"
            case .light:
                return "FontAwesome6Pro-Light"
            case .regular:
                return "FontAwesome6Pro-Regular"
        }
    }

    func fontDescriptor(withSize size: CGFloat? = nil) -> UIFontDescriptor {
        UIFontDescriptor( name: self.fontName, size: size ?? 24 )
    }

    func font(withSize size: CGFloat? = nil) -> UIFont {
        UIFont( descriptor: self.fontDescriptor( withSize: size ), size: 0 )
    }
}

extension NSAttributedString {
    public static func icon(_ icon: String?, withSize size: CGFloat? = nil, invert: Bool = false) -> NSAttributedString? {
        guard let icon = icon
        else { return nil }

        var duotone = true
        var font    = IconStyle.duotone.font( withSize: size )
        var glyphs  = [ CGGlyph ]( repeating: kCGFontIndexInvalid, count: icon.utf16.count )
        if !CTFontGetGlyphsForCharacters( font as CTFont, [ UniChar ]( icon.utf16 ), &glyphs, icon.utf16.count ) {
            duotone = false
            font = IconStyle.brands.font( withSize: size )
        }

        let attributedIcon = NSMutableAttributedString( string: icon, attributes: [
            NSAttributedString.Key.kern: duotone ? -1000: 0,
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: UIColor.black.with( alpha: invert ? .short: .on ),
        ] )

        if duotone {
            let toneScalars = icon.unicodeScalars.compactMap { Unicode.Scalar( 0x100000 + $0.value ) }
            attributedIcon.append( NSAttributedString( string: String( String.UnicodeScalarView( toneScalars ) ), attributes: [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: UIColor.black.with( alpha: invert ? .on: .short ),
            ] ) )
        }

        return attributedIcon
    }
}

extension UIImage {
    public static func icon(_ icon: String?, withSize size: CGFloat? = nil, invert: Bool = false) -> UIImage? {
        guard let attributedIcon = NSAttributedString.icon( icon, withSize: size, invert: invert )
        else { return nil }

        let size = attributedIcon.size()
        UIGraphicsBeginImageContextWithOptions( size, false, 0 )
        defer { UIGraphicsEndImageContext() }
        attributedIcon.draw( in: CGRect( origin: .zero, size: size ) )

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode( .alwaysTemplate )
    }
}
