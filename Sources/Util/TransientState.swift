//
// Created by Maarten Billemont on 2019-10-20.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

/** A state that is only active while a block operation that uses it is running, and can be checked globally. */
public enum TransientState {
    static let observers = Observers<TransientStateObserver>()
    static var activeStates = [ TransientState: Int ]() {
        didSet {
            self.activeStates.forEach { state, counter in
                if (counter == 0) != (oldValue[state] == 0) {
                    self.observers.notify { $0.stateChanged( state ) }
                }
            }
        }
    }

    case sideEffect

    public var isActive: Bool {
        TransientState.activeStates[self] ?? 0 > 0
    }

    public func perform(_ action: () -> Void) {
        TransientState.activeStates[self] = (TransientState.activeStates[self] ?? 0) + 1
        defer { TransientState.activeStates[self] = (TransientState.activeStates[self] ?? 0) - 1 }

        action()
    }
}

protocol TransientStateObserver {
    func stateChanged(_ state: TransientState)
}
