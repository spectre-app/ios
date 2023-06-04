//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation
import os

/// A container for an object that should not be held strongly.
///
/// If the object is no longer used by the application, its reference in this Box will become `nil`.
/// Use this container if you want a reference to an object without strongly referencing it and keeping it alive.
/// Useful for cases where you want weak references in a container, such as a `Set` or `Array`.
public struct WeakBox<E>: Equatable, CustomDebugStringConvertible {
    private weak var _value: AnyObject?

    private let name:  String
    public var  value: E? {
        get {
            self._value as? E
        }
        set {
            self._value = newValue as AnyObject
        }
    }

    public var debugDescription: String {
        "[\(self.value.flatMap { String(reflecting: $0) } ?? "gone: \(self.name)")]"
    }

    public init(_ value: E) {
        self.name = "\(String(reflecting: value))"
        self.value = value
    }

    public static func == (lhs: WeakBox<E>, rhs: WeakBox<E>) -> Bool {
        lhs._value === rhs._value
    }

    public static func == (lhs: WeakBox<E>, rhs: E) -> Bool {
        lhs._value === rhs as AnyObject
    }

    public static func == (lhs: WeakBox<E>, rhs: WeakBox<E>) -> Bool where E: Equatable {
        guard let lhs = lhs.value, let rhs = rhs.value
        else { return false }

        return lhs == rhs
    }

    public static func == (lhs: WeakBox<E>, rhs: E) -> Bool where E: Equatable {
        lhs.value == rhs
    }
}

extension WeakBox: CustomStringConvertible where E: CustomStringConvertible {
    public var description: String {
        "<\(self.value?.description ?? "nil")>"
    }
}

extension WeakBox: Hashable where E: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.value?.hashValue)
    }
}

/// A container for an object that should be created on-demand and can be cleared.
///
/// If the object is cleared and requested again in the future, it will be re-created on-demand.
/// Use this container if you want an object to only exist as-needed, while manually controlling its expiry.
public class LazyBox<E> {
    private let valueFactory:  () -> E?
    private let valueDisposal: (E) -> Void
    private var value: E? {
        didSet {
            oldValue.flatMap { self.valueDisposal($0) }
        }
    }

    public init(_ valueFactory: @escaping () -> E?, unset valueDisposal: @escaping (E) -> Void = { _ in }) {
        self.valueFactory = valueFactory
        self.valueDisposal = valueDisposal
        LeakRegistry.shared.register(self)
    }

    public func get() -> E? {
        if let value = self.value {
            return value
        }
        if let value = self.valueFactory() {
            self.value = value
            return value
        }
        return nil
    }

    public func unset() {
        self.value = nil
    }
}

/// A container for an object whose access should be protected by a mutually exclusive lock.
///
/// The value will only be accessible within the ``use`` closure, during which a lock will protect it from all other access.
///
/// Accessing the container from within the closure is a programming error and may crash or lead to a deadlock.
/// Value usage must be carefully scoped to avoid this. If recursive access is possible, use a ``RecursiveLockBox`` instead.
public class SingleLockBox<V> {
    public init(value: V) {
        self.value = value
        LeakRegistry.shared.register(self)
    }

    public func use<R>(_ perform: (inout V) -> R) -> R {
        self.locking.lock()
        defer { self.locking.unlock() }
        return perform(&self.value)
    }

    // - Private
    private var value:   V
    private let locking = OSAllocatedUnfairLock()
}

/// A container for an object whose access should be protected by a thread-exclusive lock.
///
/// The value will only be accessible within the ``use`` closure, during which a lock will protect it from access via another thread.
public class RecursiveLockBox<V> {
    public init(value: V) {
        self.value = value
        LeakRegistry.shared.register(self)
    }

    public func use<R>(_ perform: (inout V) -> R) -> R {
        self.locking.lock()
        defer { self.locking.unlock() }
        return perform(&self.value)
    }

    // - Private
    private var value: V
    private var locking = NSRecursiveLock()
}
