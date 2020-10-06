//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension DispatchQueue {
    public static let mpw = DispatchQueue( label: "\(productName): mpw", qos: .utility )

    public var isActive: Bool {
        (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label ) ||
                self.label == String.valid( __dispatch_queue_get_label( nil ) )
    }

    private static let threadLabelsKey = "DispatchQueue+MP"
    private var threadLabels: Set<String> {
        get {
            Thread.current.threadDictionary[DispatchQueue.threadLabelsKey] as? Set<String> ?? .init()
        }
        set {
            Thread.current.threadDictionary[DispatchQueue.threadLabelsKey] = newValue
        }
    }

    /**
     * Execute the work synchronously if our queue:
     *   - is .main and we're on the Main thread.
     *   - its label is in the current thread's active labels.
     *   - its label matches the current dispatch queue's label.
     */
    public func perform(deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                        execute work: @escaping @convention(block) () -> Void) {
        let deadNow = deadline ?? .now() <= DispatchTime.now()

        if self.isActive && deadNow {
            self.run( group: group ) { DispatchWorkItem( qos: qos, flags: flags, block: work ).perform() }
        }
        else if let deadline = deadline, !deadNow {
            self.asyncAfter( deadline: deadline, qos: qos, flags: flags ) {
                self.run( group: group, work: work )
            }
        }
        else {
            self.async( group: group, qos: qos, flags: flags ) {
                self.run( work: work )
            }
        }
    }

    private func run(group: DispatchGroup? = nil, work: @escaping @convention(block) () -> Void) {
        group?.enter()
        let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
        defer {
            if threadOwnsLabel { self.threadLabels.remove( self.label ) }
            group?.leave()
        }

        work()
    }

    /** Performs the work synchronously, returning the work's result. */
    public func await<T>(flags: DispatchWorkItemFlags = [], execute work: () throws -> T) rethrows -> T {
        if self.isActive {
            // Already in the queue's thread.
            let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
            defer { if threadOwnsLabel { self.threadLabels.remove( self.label ) } }

            return try work()
        }
        else {
            // Dispatch to the queue's thread.
            return try self.sync( flags: flags ) {
                let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
                defer { if threadOwnsLabel { self.threadLabels.remove( self.label ) } }

                return try work()
            }
        }
    }

    /** Performs work that yields a result. */
    public func promise<V>(_ promise: Promise<V> = Promise<V>(),
                           deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                           execute work: @escaping () throws -> V) -> Promise<V> {
        self.promising( promise, deadline: deadline, flags: flags, execute: { Promise( .success( try work() ) ) } )
    }

    /** Performs work that yields a promise. The promise finishes the given promise. */
    public func promising<V>(_ promise: Promise<V> = Promise<V>(),
                             deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                             execute work: @escaping () throws -> Promise<V>) -> Promise<V> {
        self.perform( deadline: deadline, group: group, qos: qos, flags: flags ) {
            do { try work().finishes( promise ) }
            catch Promise<V>.Interruption.postponed {
                let _ = self.promising( promise, deadline: .now() + .milliseconds( 300 ), group: group, qos: qos, flags: flags, execute: work )
            }
            catch { promise.finish( .failure( error ) ) }
        }

        return promise
    }
}

public class Promise<V> {
    private var result: Result<V, Error>?
    private var targets = [ (queue: DispatchQueue?, consumer: (Result<V, Error>) -> Void) ]()

    public init(_ result: Result<V, Error>? = nil) {
        if let result = result {
            self.finish( result )
        }
    }

    public convenience init(reducing promises: [Promise<V>], from value: V, _ partialResult: @escaping (V, V) throws -> V = { a, b in a }) {
        if promises.isEmpty {
            self.init( .success( value ) )
        }
        else {
            self.init()

            var results = [ Result<V, Error>? ]( repeating: nil, count: promises.count )
            for (p, promise) in promises.enumerated() {
                promise.then {
                    results[p] = $0

                    if !results.contains( where: { $0 == nil } ) {
                        do { self.finish( .success( try results.compactMap( { try $0?.get() } ).reduce( value, partialResult ) ) ) }
                        catch { self.finish( .failure( error ) ) }
                        // TODO: handle Interruption.postponed?
                    }
                }
            }
        }
    }

    public func optional() -> Promise<V?> {
        let promise = Promise<V?>()

        self.then {
            switch $0 {
                case .success(let value):
                    promise.finish( .success( value ) )
                case .failure(let error):
                    promise.finish( .failure( error ) )
            }
        }

        return promise
    }

    /** Submit the promised result, completing the promise for all that are awaiting it. */
    @discardableResult
    public func finish(_ result: Result<V, Error>) -> Self {
        assert( self.result == nil, "Tried to finish promise with \(result), but was already finished with \(self.result!)" )
        self.result = result

        self.targets.forEach { target in
            if let queue = target.queue {
                queue.perform { target.consumer( result ) }
            }
            else {
                target.consumer( result )
            }
        }

        return self
    }

    /** When this promise is finished, submit its result to another promise, thereby also finishing the other promise. */
    @discardableResult
    public func finishes(_ promise: Promise<V>) -> Self {
        self.then { (result: Result<V, Error>) in
            promise.finish( result )
        }
    }

    /** When this promise fails, run the given block. */
    @discardableResult
    public func success(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) -> Void) -> Self {
        self.then( on: queue ) { if case .success(let value) = $0 { consumer( value ) } }
    }

    /** When this promise fails, run the given block. */
    @discardableResult
    public func failure(on queue: DispatchQueue? = nil, _ consumer: @escaping (Error) -> Void) -> Self {
        self.then( on: queue ) { if case .failure(let error) = $0 { consumer( error ) } }
    }

    /** When this promise is finished, run the given block. */
    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping () -> Void) -> Self {
        self.then( on: queue ) { _ in consumer() }
    }

    /** When this promise is finished, consume its result with the given block. */
    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) -> Void) -> Self {
        if let result = self.result, queue?.isActive ?? true {
            consumer( result )
        }
        else {
            self.targets.append( (queue: queue, consumer: consumer) )
        }

        return self
    }

    /** When this promise is finished, consume its result with the given block.  Return a new promise for the block's result. */
    public func then<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) throws -> V2) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try promise.finish( .success( consumer( $0 ) ) ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, transform its successful result with the given block, yielding a new promise for the block's result. */
    public func promise<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) throws -> V2) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try promise.finish( .success( consumer( $0.get() ) ) ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, transform its successful result with the given block, yielding a new promise for the block. */
    public func promising<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) throws -> Promise<V2>) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try consumer( $0.get() ).finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, transform its result with the given block, yielding a new promise for the block. */
    public func thenPromising<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) throws -> Promise<V2>) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try consumer( $0 ).finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** Return a new promise that finishes after both this and the given promise have finished. */
    public func and(_ other: Promise<V>) -> Promise<V> where V == Void {
        self.promising { other }
    }

    /** Return a new promise that combines the result of this and the given promise. */
    public func and<V2>(_ other: Promise<V2>) -> Promise<(V, V2)> {
        and( other, reducing: { ($0, $1) } )
    }

    /** Return a new promise that combines the result of this and the given promise. */
    public func and<V2, V3>(_ other: Promise<V2>, reducing: @escaping (V, V2) -> V3) -> Promise<V3> {
        let promise = Promise<V3>()

        self.then { result1 in
            _ = other.then { result2 in
                do { promise.finish( .success( try reducing( result1.get(), result2.get() ) ) ) }
                catch { promise.finish( .failure( error ) ) }
            }
        }

        return promise
    }

    /** Obtain the result of this promise if it has already been submitted, or block the current thread until it is. */
    public func await() throws -> V {
        if let result = self.result {
            return try result.get()
        }

        // FIXME: promise runs Thread 2, then Thread 1; await on Thread 1 -> deadlock.
        let group = DispatchGroup()
        group.enter()
        self.targets.append( (queue: nil, consumer: { _ in group.leave() }) )
        group.wait()

        return try self.await()
    }

    enum Interruption: Error {
        case invalidated, rejected, postponed
    }
}

/**
 * A task that can be scheduled by request.
 */
public class DispatchTask<V> {
    private let name:      String
    private let workQueue: DispatchQueue
    private let deadline:  () -> DispatchTime
    private let group:     DispatchGroup?
    private let qos:       DispatchQoS
    private let flags:     DispatchWorkItemFlags
    private let work:      () throws -> V

    private var requestItem:    DispatchWorkItem?
    private var requestPromise: Promise<V>?
    private lazy var requestQueue = DispatchQueue( label: "\(productName): DispatchTask: \(self.name)", qos: .userInitiated )

    public init(named identifier: String, queue: DispatchQueue, deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(), group: DispatchGroup? = nil,
                qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [], execute work: @escaping () throws -> V) {
        self.name = identifier
        self.workQueue = queue
        self.deadline = deadline
        self.group = group
        self.qos = qos
        self.flags = flags
        self.work = work
    }

    /**
     * Queue the task for execution if it has not already been queued.
     * The task is removed from the request queue as soon as the work begins.
     */
    @discardableResult
    public func request() -> Promise<V> {
        self.requestQueue.await {
            if let requestPromise = self.requestPromise {
                return requestPromise
            }

            if self.requestItem?.isCancelled ?? false {
                return Promise( .failure( MPError.internal( cause: "Task is cancelled." ) ) )
            }

            var value: V?, workError: Error?
            self.requestItem = DispatchWorkItem( qos: self.qos, flags: self.flags ) {
                do { value = try self.work() }
                catch { workError = error }
            }

            let requestPromise = Promise<V>()
            self.requestPromise = requestPromise
            let _ = self.workQueue.promise( requestPromise, deadline: self.deadline(), group: self.group,
                                            qos: self.qos, flags: self.flags ) { () -> V in
                if self.requestItem?.isCancelled ?? false {
                    throw MPError.internal( cause: "Task was cancelled." )
                }

                self.requestItem?.perform()
                if let workError = workError {
                    throw workError
                }

                if let value = value {
                    return value
                }

                throw MPError.internal( cause: "Task was skipped." )
            }.then( on: self.requestQueue ) { _ in
                self.requestItem = nil
                self.requestPromise = nil
            }

            return requestPromise
        }
    }

    /**
     * Remove the task from the request queue if it is queued.
     */
    @discardableResult
    public func cancel() -> Bool {
        self.requestQueue.await {
            defer {
                self.requestItem = nil
                self.requestPromise = nil
            }

            self.requestItem?.cancel()
            return self.requestItem?.isCancelled ?? false
        }
    }
}

extension DispatchTask where V == Void {
    public convenience init(named identifier: String? = nil, queue: DispatchQueue, deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(), group: DispatchGroup? = nil,
                            qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [], update updatable: Updatable, animated: Bool = false) {
        self.init( named: "\(type( of: updatable )): \(identifier ?? "-")", queue: queue, deadline: deadline(), group: group, qos: qos, flags: flags ) { [weak updatable] in
            guard let updatable = updatable
            else { throw Promise<V>.Interruption.invalidated }

            if updatable.updatesRejected {
                throw Promise<V>.Interruption.rejected
            }
            if updatable.updatesPostponed {
                wrn( "Postponing update of: %@", updatable )
                throw Promise<V>.Interruption.postponed
            }

            if animated {
                UIView.animate( withDuration: .short ) { updatable.update() }
            }
            else {
                updatable.update()
            }
        }
    }
}
