//
// Created by Maarten Billemont on 2019-11-09.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

protocol Describable {
    var describe: String { get }
}

private let swiftTypePattern = (try? NSRegularExpression( pattern: "^_T[^0-9]*" ))!

func describe(_ type: AnyClass?, short: Bool = false, _: Void = ()) -> String? {
    type.flatMap { describe( $0, short: short ) }
}

func describe(_ type: AnyClass, short: Bool = false) -> String {
    var className = NSStringFromClass( type )

    // Get the last inner class name.
    className = className.lastIndex( of: "." ).flatMap { String( className.suffix( from: className.index( after: $0 ) ) ) } ?? className

    // Decode the swift class name.
    if let swiftType = swiftTypePattern.firstMatch( in: className, range: NSRange( location: 0, length: className.count ) )?.range,
       swiftType.location != NSNotFound && swiftType.length > 0 {
        let decoding = String( className.suffix( swiftType.location + swiftType.length ) )
        var decoded  = [ String ]()
        var index    = decoding.startIndex
        while index < decoding.endIndex {
            guard let length = Int( decoding.suffix( from: index ) ), length > 0
            else { break }

            let lengthLength = Int( log10( Double( length ) ) + 1 )
            let from         = decoding.index( index, offsetBy: lengthLength )
            let to           = decoding.index( index, offsetBy: lengthLength + length )
            decoded.append( String( decoding[from..<to] ) )
            index = to
        }
        className = decoded.last ?? decoding
    }

    if short {
        return className.components( separatedBy: CharacterSet.uppercaseLetters.inverted ).joined()
    }

    return className
}

func describe(_ type: UIView?, short: Bool = false, _: Void = ()) -> String? {
    type.flatMap { describe( $0, short: short ) }
}

func describe(_ view: UIView, short: Bool = false) -> String {
    let owner = view.owner

    if short {
        if view == (owner?.0 as? UIViewController)?.viewIfLoaded {
            return "view"
        }

        if let index = view.superview?.subviews.firstIndex( of: view ) {
            return "[\(index)] \(describe( type( of: view ) ))"
        }

        return describe( type( of: view ) )
    }

    //let identifier : String = (inAccessibilityIdentifier ? nil: view.accessibilityIdentifier)< ??
    let identifier: String = view.accessibilityIdentifier< ??
            (owner?.1).flatMap { "\(describe( type( of: view ), short: true )) \($0)" } ?? describe( type( of: view ) )
    if let nextResponder = owner?.0 {
        return "\(identifier) \(describe( type( of: nextResponder ), short: true ))"
    }

    return identifier
}
