// =============================================================================
// Created by Maarten Billemont on 2020-09-13.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

#if DEBUG
var debuggedObjects = [ WeakBox<Any> ]()

@discardableResult
func debugObject<O: AnyObject>(_ object: O, ifDebugging other: AnyObject? = nil) -> O {
    if other == nil || isDebuggingObject( other ) {
        debuggedObjects.append( WeakBox( object ) )
        LeakRegistry.shared.setDebugging( object )
        dbg( ifDebugging: object, "Started debugging: %@: %@", ObjectIdentifier( object ).identity, object )
    }

    return object
}

func isDebuggingObject(_ object: AnyObject?) -> Bool {
    guard let object = object
    else { return false }

    return debuggedObjects.contains( WeakBox( object ) )
}

class WTFLabel: UILabel {
    override init(frame: CGRect) {
        super.init( frame: frame )
        LeakRegistry.shared.register( self )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override var isHidden: Bool {
        get {
            super.isHidden
        }
        set {
            super.isHidden = newValue
        }
    }
}
#endif
