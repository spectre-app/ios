//==============================================================================
// Created by Maarten Billemont on 2019-10-20.
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

/** A global state that is only active while a block operation that uses it is running. */
public enum TransientState {
    static let observers = Observers<TransientStateObserver>()
    static var activeStates = [ TransientState: Int ]() {
        didSet {
            self.activeStates.forEach { state, counter in
                if (counter == 0) != (oldValue[state] == 0) {
                    self.observers.notify { $0.didChange( state: state ) }
                }
            }
        }
    }

    case cursing // Recurse prevention

    public var isActive: Bool {
        TransientState.activeStates[self] ?? 0 > 0
    }

    public func perform<V>(_ action: () throws -> V) rethrows -> V {
        TransientState.activeStates[self] = (TransientState.activeStates[self] ?? 0) + 1
        defer { TransientState.activeStates[self] = (TransientState.activeStates[self] ?? 0) - 1 }

        return try action()
    }
}

protocol TransientStateObserver {
    func didChange(state: TransientState)
}
