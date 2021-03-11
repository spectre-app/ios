//
// Created by Maarten Billemont on 2021-03-06.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import Foundation

struct Text: CustomStringConvertible, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    var description: String {
        self.attributedString.string
    }

    let attributedString: NSAttributedString

    // MARK: --- Life ---

    init(_ attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    init(_ string: String) {
        self.attributedString = NSAttributedString( string: string )
    }

    init(stringLiteral value: String) {
        self.attributedString = NSAttributedString( string: value )
    }

    init(stringInterpolation: StringInterpolation) {
        self.attributedString = NSAttributedString( attributedString: stringInterpolation.attributedString )
    }

    // MARK: --- Interface ---

    func attributedString(for label: UILabel) -> NSAttributedString {
        self.attributedString( textColor: label.textColor, textSize: label.font.pointSize )
    }

    func attributedString(for field: UITextField) -> NSAttributedString {
        self.attributedString( textColor: field.textColor, textSize: field.font?.pointSize )
    }

    func attributedString(for button: UIButton) -> NSAttributedString {
        self.attributedString( textColor: button.currentTitleColor, textSize: button.titleLabel?.font.pointSize )
    }

    func attributedString(textColor: UIColor? = nil, textSize: CGFloat? = nil) -> NSAttributedString {
        let attributedString = NSMutableAttributedString( attributedString: self.attributedString )
        attributedString.enumerateAttributes( in: NSRange( location: 0, length: attributedString.length ) ) { attributes, range, stop in
            var fixedAttributes = attributes, fixed = false
            if let font = attributes[.font] as? UIFont, let textSize = textSize,
               font.pointSize != textSize {
                fixedAttributes[.font] = font.withSize( textSize )
                fixed = true
            }
            if let color = attributes[.foregroundColor] as? UIColor, let textColor = textColor,
               color != textColor.with( alpha: color.alpha ) {
                fixedAttributes[.foregroundColor] = textColor.with( alpha: color.alpha )
                fixed = true
            }
            if fixed {
                attributedString.setAttributes( fixedAttributes, range: range )
            }
        }

        return NSAttributedString( attributedString: attributedString )
    }

    // MARK: --- Types ---

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

        mutating func appendInterpolation(_ string: CustomStringConvertible, _ attributes: [NSAttributedString.Key: Any] = [:]) {
            self.attributedString.append( NSAttributedString( string: string.description, attributes: attributes ) )
        }
    }
}