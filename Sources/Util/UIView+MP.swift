//
// Created by Maarten Billemont on 2019-11-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

//private var inAccessibilityIdentifier = false

public extension UIView {
    private struct Key {
        static var alignmentRectOutsets = 0
    }

    // TODO: Doesn't seem to work
    var alignmentRectInsets: UIEdgeInsets {
        get {
            -self.alignmentRectOutsets
        }
        set {
            self.alignmentRectOutsets = -newValue
        }
    }

    var alignmentRectOutsets: UIEdgeInsets {
        get {
            objc_getAssociatedObject( self, &Key.alignmentRectOutsets ) as? UIEdgeInsets ?? .zero
        }
        set {
            objc_setAssociatedObject( self, &Key.alignmentRectOutsets, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN )
        }
    }

    var alignmentRect: CGRect {
        self.alignmentRect( forFrame: self.frame )
    }

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
