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

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
    }

    init(stringLiteral value: String) {
        self.attributedString = NSAttributedString( string: value )
    }

    init(stringInterpolation: StringInterpolation) {
        self.attributedString = NSAttributedString( attributedString: stringInterpolation.attributedString )
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
