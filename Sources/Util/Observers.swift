//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public protocol Observable {
    associatedtype O: Any
    var observers: Observers<O> { get }
}

public class Observers<O> {
    private var observers = [ WeakBox<O> ]()

    @discardableResult
    public func register(observer: O) -> O {
        self.observers.append( WeakBox( observer ) )
        return observer
    }

    @discardableResult
    public func unregister(observer: O) -> O {
        self.observers.removeAll { $0 == observer }
        return observer
    }

    @discardableResult
    public func notify(event: (O) -> ()) -> Bool {
        var notified = false

        for observer in self.observers {
            if let observer = observer.value {
                event( observer )
                notified = true
            }
        }

        return notified
    }
}
