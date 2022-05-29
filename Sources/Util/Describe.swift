// =============================================================================
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

@objc
public protocol Describable {
    func describe(details: Bool) -> String
}

private let swiftTypePattern = (try? NSRegularExpression( pattern: "^_T[^0-9]*" ))!

func _describe(_ type: AnyClass?, details: Bool = false, abbreviated: Bool = false, _: Void = ()) -> String? {
    type.flatMap { _describe( $0, details: details, abbreviated: abbreviated ) }
}

func _describe(_ type: AnyClass, details: Bool = false, abbreviated: Bool = false) -> String {
    var className = NSStringFromClass( type )

    // Get the last inner class name.
    if !details {
        className = className.lastIndex( of: "." ).flatMap { String( className.suffix( from: className.index( after: $0 ) ) ) } ?? className
    }

    // Decode the swift class name.
    if let swiftType = swiftTypePattern.firstMatch( in: className, range: NSRange( location: 0, length: className.count ) )?.range,
       swiftType.location != NSNotFound && swiftType.length > 0, let range = Range( swiftType, in: className ) {
        let decoding = className[range.upperBound...]
        var decoded  = [ String ]()
        var index    = decoding.startIndex
        while index < decoding.endIndex {
            // FIXME: Sometimes the encoding's length starts with a letter, like: P33_64194F838F350DFFFF7A6F647B1BDC6715PropertyUpdater
            guard let next = decoding[index...].firstIndex(where: { $0.isNumber })
            else { break }
            let prefix = decoding[index..<next]
            let length = (decoding[next...] as NSString).integerValue
            guard length > 0
            else { break }

            let lengthLength = Int( log10( Double( length ) ) + 1 )
            let from         = decoding.index( next, offsetBy: lengthLength )
            let to           = decoding.index( next, offsetBy: lengthLength + length )
            let typeElement  = String( decoding[from..<to] )

            if prefix.isEmpty {
                decoded.append( typeElement )
            } else if details {
                decoded.append( "[\(prefix)]" + typeElement )
            } else if prefix.contains("S") {
                // Probably found a type parameter, don't parse the other parameters if typeDetails is off.
                // TODO: Not 100% correct, since it's possible to have type parameters on a parent type.
                break
            }
            index = to
        }
        className = details ? decoded.joined(separator: ".") : decoded.last ?? String( decoding )
    }

    if abbreviated {
        return className.components( separatedBy: CharacterSet.uppercaseLetters.inverted ).joined()
    }

    return className
}

extension NSObject: Describable {
    public func describe(details: Bool = true) -> String {
        !details ? ObjectIdentifier( self ).identity : "[\(ObjectIdentifier( self ).identity)]: \(_describe( Self.self ))"
    }
}

extension UIView {
    public override func describe(details: Bool = true) -> String {
        Thread.current.threadDictionary["_fromDescribe"] = true
        defer {
            Thread.current.threadDictionary["_fromDescribe"] = nil
        }

        if let identifier = self.accessibilityIdentifier?.nonEmpty {
            return !details ? identifier :
                   "\(identifier): \(_describe( Self.self ))"
        }

        let owner = self.ownership
        if let owner = owner {
            return !details ? owner.property :
                   "\(_describe( type( of: owner.owner ), abbreviated: true )).\(owner.property): \(_describe( Self.self ))"
        }

        if let index = self.superview?.subviews.firstIndex( of: self ) {
            return !details ? "[\(index)]" :
                   "[\(index)]: \(_describe( Self.self ))"
        }

        return super.describe( details: details )
    }
}
