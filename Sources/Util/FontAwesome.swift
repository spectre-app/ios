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
                return "FontAwesome5Brands-Regular"
            case .duotone:
                return "FontAwesome5Duotone-Solid"
            case .solid:
                return "FontAwesome5Pro-Solid"
            case .light:
                return "FontAwesome5Pro-Light"
            case .regular:
                return "FontAwesome5Pro-Regular"
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
    public static func icon(_ icon: String, withSize size: CGFloat? = nil) -> NSAttributedString? {
        let font           = IconStyle.duotone.font( withSize: size )
        let attributedIcon = NSMutableAttributedString( string: icon, attributes: [
            NSAttributedString.Key.kern: -1000,
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: UIColor.black,
        ] )
        if let iconScalar = icon.unicodeScalars.first, let toneScalar = Unicode.Scalar( 0x100000 + iconScalar.value ) {
            attributedIcon.append( NSAttributedString( string: String( String.UnicodeScalarView( [ toneScalar ] ) ), attributes: [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: UIColor.black.with( alpha: 0.5 ),
            ] ) )
        }

        return attributedIcon
    }
}

extension UIImage {
    public static func icon(_ icon: String, withSize size: CGFloat? = nil) -> UIImage? {
        guard let attributedIcon = NSAttributedString.icon( icon, withSize: size )
        else { return nil }

        let size = attributedIcon.size()
        UIGraphicsBeginImageContextWithOptions( size, false, 0 )
        defer { UIGraphicsEndImageContext() }
        attributedIcon.draw( in: CGRect( origin: .zero, size: size ) )

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode( .alwaysTemplate )
    }
}
