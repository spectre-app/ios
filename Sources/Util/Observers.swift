//==============================================================================
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import Foundation

public protocol Observable {
    associatedtype O: Any
    var observers: Observers<O> { get }
}

public class Observers<O> {
    private var observers = [ WeakBox<O> ]()

    @discardableResult
    public func register(observer: O) -> O {
        let box = WeakBox( observer )
        if !self.observers.contains( box ) {
            self.observers.append( box )
        }
        return observer
    }

    @discardableResult
    public func unregister(observer: O) -> O {
        self.observers.removeAll { $0 == observer }
        return observer
    }

    public func clear() {
        self.observers.removeAll()
    }

    @discardableResult
    public func notify(event: (O) -> Void) -> Bool {
        var notified = false

        for observer in self.observers.compactMap( { $0.value } ) {
            event( observer )
            notified = true
        }

        return notified
    }
}
