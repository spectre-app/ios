// =============================================================================
// Created by Maarten Billemont on 2021-03-06.
// Copyright (c) 2021 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

struct Text: CustomStringConvertible, ExpressibleByStringInterpolation {
    var description: String {
        self.attributedString.string
    }

    let attributedString: NSAttributedString

    // MARK: - Life

    init(_ attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    init(_ string: String, _ attributes: [NSAttributedString.Key: Any] = [:]) {
        self.init( NSAttributedString( string: string, attributes ) )
    }

    init(stringLiteral string: String) {
        self.init( NSAttributedString( string: string ) )
    }

    init(stringInterpolation: StringInterpolation) {
        self.init( stringInterpolation.attributedString )
    }

    // MARK: - Interface

    func attributedString(textColor: UIColor? = nil, textSize: CGFloat? = nil) -> NSAttributedString {
        let attributedString = NSMutableAttributedString( attributedString: self.attributedString )
        attributedString.enumerateAttributes(
                in: NSRange( location: 0, length: attributedString.length ) ) { attributes, range, _ in
            var fixedAttributes = attributes, fixed = false
            if let font = attributes[.font] as? UIFont, let textSize = textSize,
               font.pointSize != textSize {
                fixedAttributes[.font] = font.withSize( textSize )
                fixed = true
            }
            if let color = attributes[.foregroundColor] as? UIColor, let textColor = textColor?.with( alpha: color.alpha ),
               color != textColor {
                fixedAttributes[.foregroundColor] = textColor
                fixed = true
            }
            if fixed {
                attributedString.setAttributes( fixedAttributes, range: range )
            }
        }

        return NSAttributedString( attributedString: attributedString )
    }

    // MARK: - Types

    struct StringInterpolation: StringInterpolationProtocol {
        var attributedString: NSMutableAttributedString

        init(literalCapacity: Int, interpolationCount: Int) {
            self.attributedString = NSMutableAttributedString()
        }

        mutating func appendLiteral(_ literal: String) {
            self.attributedString.append( NSAttributedString( string: literal ) )
        }

        mutating func appendInterpolation(_ string: NSAttributedString?) {
            string.flatMap { self.attributedString.append( $0 ) }
        }

        mutating func appendInterpolation(_ string: CustomStringConvertible?, _ attributes: [NSAttributedString.Key: Any] = [:]) {
            string.flatMap { self.attributedString.append( NSAttributedString( string: $0.description, attributes: attributes ) ) }
        }
    }
}

extension UILabel {
    func applyText(_ text: Text?) {
        self.attributedText = text?.attributedString( textColor: self.textColor, textSize: self.font.pointSize )
    }
}

extension UITextField {
    func applyText(_ text: Text?) {
        self.attributedText = text?.attributedString( textColor: self.textColor, textSize: self.font?.pointSize )
    }
}

extension UIButton {
    func applyText(_ text: Text?) {
        self.setAttributedTitle(
                text?.attributedString( textColor: self.currentTitleColor, textSize: self.titleLabel?.font.pointSize ),
                for: .normal )
    }
}
