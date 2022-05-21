// =============================================================================
// Created by Maarten Billemont on 2020-07-31.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

public enum IconStyle: CaseIterable {
    case duotone, brands, regular, solid, light, system, emoji

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
            case .system:
                return UIFont.systemFont(ofSize: UIFont.systemFontSize).fontName
            case .emoji:
                return "AppleColorEmoji"
        }
    }

    func fontDescriptor(withSize size: CGFloat? = nil) -> UIFontDescriptor {
        UIFontDescriptor( name: self.fontName, size: size ?? 24 )
    }

    func font(withSize size: CGFloat? = nil) -> UIFont {
        UIFont( descriptor: self.fontDescriptor( withSize: size ), size: 0 )
    }
}

private let fontAwesomeUnicode: [String: String?] =
        Bundle.main.url( forResource: "Font Awesome 6", withExtension: "json" )
              .flatMap { try? Data( contentsOf: $0 ) }
              .flatMap {
                  try? JSONDecoder().decode( [ String: String ].self, from: $0 ).mapValues {
                      var unicode: UInt64 = 0
                      return Scanner( string: $0 ).scanHexInt64( &unicode )
                             ? Unicode.Scalar( UInt32( unicode ) ).flatMap { String( Character( $0 ) ) } : nil
                  }
              } ?? .init()

extension NSAttributedString {
    public static func icon(_ icon: String?, withSize size: CGFloat? = nil, style: IconStyle? = nil, invert: Bool = false)
            -> NSAttributedString? {
        guard let icon = icon.flatMap( { fontAwesomeUnicode[$0] } ) ?? icon,
              let style = style ?? {
                  let glyphs = UnsafeMutablePointer<CGGlyph>.allocate( capacity: icon.utf16.count )
                  defer {
                      glyphs.deinitialize( count: icon.utf16.count )
                  }
                  return IconStyle.allCases.first( where: {
                      CTFontGetGlyphsForCharacters( $0.font() as CTFont, [ UniChar ]( icon.utf16 ), glyphs, icon.utf16.count )
                  } )
              }()
        else { return nil }

        let font           = style.font( withSize: size )
        let attributedIcon = NSMutableAttributedString()
        if case .duotone = style, let icon = icon.unicodeScalars.first {
            let tone1 = String( String.UnicodeScalarView( [ icon, Unicode.Scalar( Int( 0xfe01 ) )! ] ) )
            let tone2 = String( String.UnicodeScalarView( [ icon, Unicode.Scalar( Int( 0xfe02 ) )! ] ) )
            attributedIcon.append( NSAttributedString( string: tone2, attributes: [
                .foregroundColor: UIColor.black.with( alpha: invert ? .on : .short ),
                .font: font, .kern: -1000,
            ] ) )
            attributedIcon.append( NSAttributedString( string: tone1, attributes: [
                .foregroundColor: UIColor.black.with( alpha: invert ? .short : .on ),
                .font: font,
            ] ) )
        }
        else {
            attributedIcon.append( NSAttributedString( string: icon, attributes: [
                .foregroundColor: UIColor.black,
                .font: font,
            ] ) )
        }

        return attributedIcon
    }
}

extension UIImage {
    public static func icon(_ icon: String?, withSize size: CGFloat? = nil, style: IconStyle? = nil, invert: Bool = false) -> UIImage? {
        .icon( NSAttributedString.icon( icon, withSize: size, style: style, invert: invert ) )
    }

    public static func icon(_ icon: NSAttributedString?) -> UIImage? {
        guard let icon = icon
        else { return nil }

        let size = icon.size()
        UIGraphicsBeginImageContextWithOptions( size, false, 0 )
        defer { UIGraphicsEndImageContext() }
        icon.draw( in: CGRect( origin: .zero, size: size ) )

        var image = UIGraphicsGetImageFromCurrentImageContext()
        if IconStyle.emoji.fontName != (icon.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.fontName {
            image = image?.withRenderingMode( .alwaysTemplate )
        }

        return image
    }
}
