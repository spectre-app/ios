//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

public protocol Observed {
    associatedtype O: Any
    var observers: Observers<O> { get }
}

public class Observers<O> {
    private var observers: [WeakBox<AnyObject>] = []
    public var registration: (O) -> Void

    public init(registration: @escaping (O) -> Void = { _ in }) {
        self.registration = registration
    }

    @discardableResult
    public func register(observer: O) -> O? {
        let box = WeakBox(object: observer as AnyObject)
        if self.observers.contains(box) {
            return nil
        }
        self.observers.append(box)
        self.registration(observer)
        return observer
    }

    @discardableResult
    public func unregister(observer: O) -> O? {
        let count = self.observers.count
        self.observers.removeAll { $0.object === observer as AnyObject }
        return count != self.observers.count ? observer : nil
    }

    public func clear() {
        self.observers.removeAll()
    }

    @discardableResult
    public func notify(event: (O) -> Void) -> Bool {
        var notified = false

        for observer in self.observers.compactMap(\.object) {
            if let observer = observer as? O {
                event(observer)
                notified = true
            }
        }

        return notified
    }
}
