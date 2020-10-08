//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

@objc
public protocol Describable {
    func describe(short: Bool) -> String
}

private let swiftTypePattern = (try? NSRegularExpression( pattern: "^_T[^0-9]*" ))!

func _describe(_ type: AnyClass?, short: Bool = false, _: Void = ()) -> String? {
    type.flatMap { _describe( $0, short: short ) }
}

func _describe(_ type: AnyClass, short: Bool = false) -> String {
    var className = NSStringFromClass( type )

    // Get the last inner class name.
    className = className.lastIndex( of: "." ).flatMap { String( className.suffix( from: className.index( after: $0 ) ) ) } ?? className

    // Decode the swift class name.
    if let swiftType = swiftTypePattern.firstMatch( in: className, range: NSRange( location: 0, length: className.count ) )?.range,
       swiftType.location != NSNotFound && swiftType.length > 0, let range = Range( swiftType, in: className ) {
        let decoding = className[range.upperBound...]
        var decoded  = [ String ]()
        var index    = decoding.startIndex
        while index < decoding.endIndex {
            let length = (decoding[index...] as NSString).integerValue
            guard length > 0
            else { break }

            let lengthLength = Int( log10( Double( length ) ) + 1 )
            let from         = decoding.index( index, offsetBy: lengthLength )
            let to           = decoding.index( index, offsetBy: lengthLength + length )
            decoded.append( String( decoding[from..<to] ) )
            index = to
        }
        className = decoded.last ?? String( decoding )
    }

    if short {
        return className.components( separatedBy: CharacterSet.uppercaseLetters.inverted ).joined()
    }

    return className
}

extension UIView: Describable {
    public func describe(short: Bool = false) -> String {
        let owner = self.owner
        let description: String

        if let identifier = self.accessibilityIdentifier?.nonEmpty {
            description = identifier
        }
        else if let owner = owner {
            description = short ? owner.name: "\(_describe( Self.self, short: true )) \(owner.name) @\(_describe( type( of: owner.host ), short: true ))"
        }
        else if let index = self.superview?.subviews.firstIndex( of: self ) {
            description = short ? "[\(index)]": "[\(index)] \(_describe( Self.self ))"
        }
        else {
            description = _describe( Self.self )
        }

        if !short, let ownerView = owner?.host as? UIView {
            return "\(ownerView.describe( short: false ))/\(description)"
        }
        else {
            return description
        }
    }
}
