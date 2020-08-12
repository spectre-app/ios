//
// Created by Maarten Billemont on 2020-08-11.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

extension NSAttributedString {
    public static func +(lhs: NSAttributedString, rhs: NSAttributedString) -> NSAttributedString {
        let attributedString = lhs as? NSMutableAttributedString ?? NSMutableAttributedString( attributedString: lhs )
        attributedString.append( rhs )
        return attributedString
    }

    public static func str(_ string: String, font: UIFont? = nil, textColor: UIColor? = nil, secondaryColor: UIColor? = nil,
                           _ attributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
        var mergedAttributes = attributes
        if let font = font {
            mergedAttributes[.font] = font
        }
        if let textColor = textColor {
            mergedAttributes[.foregroundColor] = textColor
        }
        if let secondaryColor = secondaryColor {
            mergedAttributes[.strokeColor] = secondaryColor
        }

        return NSAttributedString( string: string, attributes: mergedAttributes )
    }
}
