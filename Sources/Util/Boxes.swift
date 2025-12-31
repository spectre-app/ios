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
public struct WeakBox<O: AnyObject>: Hashable {
    public weak var object: O?

    public init(object: O) {
        self.object = object
        self.identifier = ObjectIdentifier(object)
    }

    // - Equatable
    public static func == (lhs: WeakBox<O>, rhs: WeakBox<O>) -> Bool {
        lhs.identifier == rhs.identifier
    }

    // - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }

    // - Private
    private let identifier: ObjectIdentifier
}

/// A container for an object that should be created on-demand and can be cleared.
///
/// If the object is cleared and requested again in the future, it will be re-created on-demand.
/// Use this container if you want an object to only exist as-needed, while manually controlling its expiry.
public struct LazyBox<O> {
    public var object: O {
        mutating get {
            if let object = self.storage.use({ $0 }) {
                return object
            }

            let object = self.provider()
            self.storage.using { $0 = object }
            LeakRegistry.shared.register(object as AnyObject)
            return object
        }

        set {
            self.storage.using {
                $0.flatMap(self.unset)
                $0 = newValue
            }
        }
    }

    public var provider: () -> O {
        willSet {
            self.clear()
        }
    }

    public var unset: (O) -> Void

    public init<OO>() where O == OO? {
        self.init(provider: { nil })
    }

    public init(provider: @escaping () -> O, unset: @escaping (O) -> Void = { _ in }) {
        self.provider = provider
        self.unset = unset
    }

    public mutating func clear() {
        self.storage.using {
            $0.flatMap(self.unset)
            $0 = nil
        }
    }

    /// `true` if this box is not currently storing any value for the ``object``, meaning the next time it is requested, the provider will need to be consulted to actualize the value.
    public var isClear: Bool {
        self.storage.use { $0 == nil }
    }

    // - Private
    private var storage = SingleLockBox<O?>(value: nil)
}

/// A reference-type container for storing and sharing non-reference type values.
public class ReferenceBox<V>: CustomStringConvertible {
    public var value: V
    public var description: String {
        "\(self.value)"
    }

    private var `deinit`: () -> Void

    public init(value: V, deinit: @escaping () -> Void = {}) {
        self.value = value
        self.deinit = `deinit`
    }

    deinit {
        self.deinit()
    }
}

/// A container used purely for detecting changes to Equatable types.
public struct ChangesBox<V: Equatable> {
    public var value: V?

    public init(initial: V? = nil) {
        self.value = initial
    }

    public mutating func hasChanged(_ value: V) -> Bool {
        guard self.value == value else {
            self.value = value
            return true
        }
        return false
    }
}

/// A container for keeping a current task, cancelling the previous task if it is replaced by a new one.
public class TaskBox<R> {
    public var value: Task<R, Never>? {
        didSet {
            oldValue?.cancel()
        }
    }

    public init(initial: Task<R, Never>? = nil) {
        self.value = initial
    }

    public func send(task: Task<R, Never>) {
        self.value = task
    }

    public func send(name: String? = nil, priority: TaskPriority? = nil, task: @escaping () async -> R) {
        self.value = Task(name: name, priority: priority, operation: task)
    }

    public func clear() {
        self.value = nil
    }
}

/// A container for an object that should not be held strongly and only be created on-demand.
///
/// If the object is no longer used by the application it will be cleared.
/// If a cleared object requested again in the future, it will be re-created on-demand.
/// Use this container if you want an object to only exist as-needed, while tying its expiry to its usage.
public struct WeakLazyBox<O: AnyObject> {
    public var object: O {
        mutating get {
            if let object = self.storage {
                return object
            }

            let object = self.provider()
            self.storage = object
            return object
        }

        set {
            self.storage = newValue
        }
    }

    public var provider: () -> O {
        didSet {
            self.clear()
        }
    }

    public init(provider: @escaping () -> O) {
        self.provider = provider
    }

    public mutating func clear() {
        self.storage = nil
    }

    // - Private
    private weak var storage: O?
}

/// A reference-type holder for blocks.
///
/// Useful in order to apply reference semantics to block types.
@dynamicCallable public final class BlockBox<R, E: Error> {
    public let block: @Sendable () throws(E) -> R

    @inlinable
    public init(_ block: @escaping @Sendable () throws(E) -> R) {
        self.block = block
    }

    @inlinable
    public func dynamicallyCall(withArguments: [Void]) throws(E) -> R {
        try self.block()
    }
}

/// An mutable container for an object whose access should be protected by Swift Concurrency.
///
/// Particularly useful for safely passing data between concurrent contexts or waiting for a desired value to appear in the box.
///
/// Accessing and mutating the value will be guarded by the lock, but any use of the object itself is entirely unprotected by this container.
public actor AsyncBox<V: Sendable> {
    public init(value: V) {
        self.value = value
    }

    deinit {
        self.continuations.forEach { $0.finish() }
    }

    /// For reading the box.
    public var value: V {
        didSet {
            self.continuations.forEach { $0.yield(self.value) }
        }
    }

    /// For isolated read-write access to the box.
    public func use<R>(_ perform: (isolated AsyncBox<V>) async throws -> R) async rethrows -> R {
        try await perform(self)
    }

    /// For writing to the box.
    public func send(_ value: V) {
        self.value = value
    }

    @discardableResult
    public nonisolated func task<R>(priority: TaskPriority = .utility, _ perform: @escaping (isolated AsyncBox<V>) -> R) -> Task<R, Never> {
        Task(priority: priority) {
            await perform(self)
        }
    }

    public var values: AsyncStream<V> {
        .init(V.self) {
            $0.yield(self.value)
            self.continuations.append($0)
        }
    }

    private var continuations: [AsyncStream<V>.Continuation] = []
}

/// A nillable AsyncBox can be useful for clients who want to wait on the first non-nil value.
extension AsyncBox {
    public init<O>() where V == O? {
        self.init(value: nil)
    }

    /// Suspend until the box has a non-nil value and returns it.
    public func firstNonNilValue<O>() async -> O where V == O? {
        var it = self.values.makeAsyncIterator()
        repeat {
            if let value = await it.next(), let value {
                // swiftformat:disable:next redundantReturn
                return value
            }
        }
        while true
    }

    public var isEmpty: Bool {
        (self.value as AnyObject) is NSNull
    }
}

/// An mutable container for an object whose access should be protected by a mutually exclusive lock.
///
/// Particularly useful for safely passing data between concurrent contexts.
///
/// Accessing and mutating the value will be guarded by the lock, but any use of the object itself is entirely unprotected by this container.
public struct AtomicBox<V: Sendable>: Sendable {
    public init(value: V? = nil) {
        if let value {
            self.value = value
        }
    }

    public var value: V? {
        get { self.lock.use(\.contents) }
        nonmutating set { self.lock.use { $0.contents = newValue } }
    }

    /// Atomically remove the current value in the box and return it.
    public var removeValue: V? {
        self.replaceValue(with: nil)
    }

    /// Atomically replace the current value in the box with a new one and return the old one.
    public func replaceValue(with newValue: V?) -> V? {
        self.lock.use {
            let contents = $0.contents
            $0.contents = newValue
            return contents
        }
    }

    // - Private
    private let lock = SingleLockBox(value: Locked())
    private final class Locked: @unchecked Sendable {
        var contents: V?
    }
}

/// An mutable container for safely awaiting the arrival of a value from another thread.
///
/// Accessing the value when it has not yet been assigned will cause the current thread to block until the value gets assigned from another thread.
public struct AwaitBox<V: Sendable>: Sendable {
    public init(value: V? = nil) {
        self.lock.use {
            $0.contents = value
        }
    }

    /// Synchronously access or assign the value. Blocks execution if the value has not yet been assigned until another thread assigns a value!
    public var value: V {
        get {
            self.await()
        }
        nonmutating set {
            self.lock.use { $0.contents = newValue }
            self.condition.broadcast()
        }
    }

    public var isEmpty: Bool {
        self.lock.use { $0.contents == nil }
    }

    public var clearingValue: V {
        self.await(clear: true)
    }

    public func await(abnormal time: TimeInterval = 5, clear: Bool = false) -> V {
        repeat {
            guard let value = self.lock.use({
                guard let contents = $0.contents
                else { return nil as V? }

                if clear {
                    $0.contents = nil
                }

                return contents
            })
            else {
                if !self.condition.wait(until: .now + time) {
                    err("Abnormally long wait (\(time)s) for: \(V.self)")
                }
                continue
            }

            return value
        }
        while true
    }

    public func clear() {
        self.lock.use { $0.contents = nil }
    }

    // - Private
    private let lock = SingleLockBox(value: Locked())
    private let condition = NSCondition()
    private final class Locked: @unchecked Sendable {
        var contents: V?
    }
}

/// An immutable container for a mutable object whose usage should be protected by a mutually exclusive lock.
///
/// The value will only be accessible within the ``use`` closure, during which a lock will protect it from all other access.
///
/// Accessing the container from within the closure is a programming error and may crash or lead to a deadlock.
/// Value usage must be carefully scoped to avoid this. If recursive access is possible, use a ``RecursiveLockBox`` instead.
public struct SingleLockBox<V: Sendable>: Sendable {
    public init(value: V) {
        self.value = value
        LeakRegistry.shared.register(value as AnyObject)
    }

    public func use<R>(_ perform: (V) throws -> R) rethrows -> R {
        self.lock.lock()
        defer { self.lock.unlock() }
        return try perform(self.value)
    }

    /// Variant for modifying value types which are read-only from ``.use()``.
    public mutating func using<R>(_ perform: (inout V) throws -> R) rethrows -> R {
        self.lock.lock()
        defer { self.lock.unlock() }
        return try perform(&self.value)
    }

    // - Private
    private var value: V
    private let lock = OSAllocatedUnfairLock()
}

/// A container for an object whose access should be protected by a thread-exclusive lock.
///
/// The value will only be accessible within the ``use`` closure, during which a lock will protect it from access via another thread.
public struct RecursiveLockBox<V: Sendable> {
    public init(value: V) {
        self.value = value
        LeakRegistry.shared.register(value as AnyObject)
    }

    public func use<R>(_ perform: (V) throws -> R) rethrows -> R {
        self.locking.lock()
        defer { self.locking.unlock() }
        return try perform(self.value)
    }

    // - Private
    private let value: V
    private var locking = NSRecursiveLock()
}

private protocol Locking {
    func lock()
    func unlock()
}
