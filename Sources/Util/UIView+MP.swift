//
// Created by Maarten Billemont on 2019-11-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

//private var inAccessibilityIdentifier = false

public extension UIView {
    override var accessibilityLabel: String? {
        get {
//            inAccessibilityIdentifier = true
//            defer { inAccessibilityIdentifier = false }
            super.accessibilityLabel ?? describe(self)
        }
        set {
            super.accessibilityLabel = newValue
        }
    }

    var owner : (UIResponder, String)? {
        var nextResponder: UIResponder?
        while let nextResponder_ = nextResponder {
            if let property = nextResponder_.ivarWithValue( self ) {
                return (nextResponder_, property)
            }

            nextResponder = nextResponder_.next
        }

        return nil
    }

//- (NSString *)infoPathName {
//
//    UIResponder *parent = [self nextResponder]
//    if ([parent isKindOfClass:[UIView class]])
//        return strf( @"%@/%@", [(UIView *)parent infoPathName]?: @"", [self infoShortName])
//
//    return strf( @"%@/%@", describe( [parent class] )?: @"", [self infoShortName] )
//}

}
