//
// Created by Maarten Billemont on 2019-06-07.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

protocol Observable {
    associatedtype O: AnyObject
    var observers : Observers<O> { get }
}

public class Observers<O: AnyObject> {
    private var observers: [WeakBox<O>] = []

    @discardableResult
    public func register(observer: O) -> O {
        self.observers.append( WeakBox( observer ) )
        return observer
    }

    @discardableResult
    public func unregister(observer: O) -> O {
        self.observers.removeAll { $0.value === observer }
        return observer
    }

    @discardableResult
    public func notify(event: (O) -> ()) -> Bool {
        var notified = false

        for observer in self.observers {
            if let value = observer.value {
                event( value )
                notified = true
            }
        }

        return notified
    }
}

final class WeakBox<V: AnyObject> {
    weak var value: V?

    init(_ value: V) {
        self.value = value
    }
}
