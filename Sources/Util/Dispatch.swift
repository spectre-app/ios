// =============================================================================
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

extension DispatchTime {
    static func - (lhs: DispatchTime, rhs: DispatchTime) -> TimeInterval {
        TimeInterval( lhs.uptimeNanoseconds - rhs.uptimeNanoseconds ) / TimeInterval( NSEC_PER_SEC )
    }
}

extension DispatchQueue {
    public static let api = DispatchQueue( label: "\(productName): api", qos: .utility )

    public var isActive: Bool {
        (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label )
        || self.label == String.valid( __dispatch_queue_get_label( nil ) )
    }

    private static let threadLabelsKey = "DispatchQueue+Spectre"
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
    public func perform(deadline: DispatchTime? = nil, group: DispatchGroup? = nil,
                        qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                        await: Bool = false, execute work: @escaping @convention(block) () -> Void) {
        let deadNow = deadline.flatMap { $0 <= DispatchTime.now() } ?? true

        if `await` {
            if self.isActive {
                self.run( deadline: deadNow ? nil : deadline, group: group, qos: qos, flags: flags, work: work )
            }
            else {
                self.sync( flags: flags ) {
                    self.run( deadline: deadNow ? nil : deadline, group: group, qos: qos, flags: flags, work: work )
                }
            }
        }
        else if deadNow && self.isActive {
            self.run( group: group, qos: qos, flags: flags, work: work )
        }
        else if !deadNow, let deadline = deadline {
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

    private func run(deadline: DispatchTime? = nil, group: DispatchGroup? = nil,
                     qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                     work: @escaping @convention(block) () -> Void) {
        if let deadline = deadline {
            Thread.sleep( forTimeInterval: deadline - .now() )
        }

        group?.enter()
        let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
        defer {
            if threadOwnsLabel { self.threadLabels.remove( self.label ) }
            group?.leave()
        }

        if qos != .unspecified || !flags.isEmpty {
            DispatchWorkItem( qos: qos, flags: flags, block: work ).perform()
        }
        else {
            work()
        }
    }

    /** Performs the work synchronously, returning the work's result. */
    public func await<T>(flags: DispatchWorkItemFlags = [], execute work: () throws -> T) rethrows
            -> T {
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
                           deadline: DispatchTime? = nil, group: DispatchGroup? = nil,
                           qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                           execute work: @escaping () throws -> V)
            -> Promise<V> {
        self.promising( promise, deadline: deadline, flags: flags, execute: { Promise( .success( try work() ) ) } )
    }

    /** Performs work that yields a promise. The promise finishes the given promise. */
    public func promising<V>(_ promise: Promise<V> = Promise<V>(),
                             deadline: DispatchTime? = nil, group: DispatchGroup? = nil,
                             qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                             execute work: @escaping () throws -> Promise<V>)
            -> Promise<V> {
        self.perform( deadline: deadline, group: group, qos: qos, flags: flags ) {
            do { try work().finishes( promise ) }
            catch Interruption.postponed {
                _ = self.promising( promise, deadline: .now() + .milliseconds( 300 ),
                                    group: group, qos: qos, flags: flags, execute: work )
            }
            catch { promise.finish( .failure( error ) ) }
        }

        return promise
    }
}

public class Promise<V>: CustomDebugStringConvertible {
    private var     result: Result<V, Error>?
    private var     targets   = [ (queue: DispatchQueue?, consumer: (Result<V, Error>) -> Void) ]()
    fileprivate let semaphore = DispatchQueue( label: "Promise" )

    public var debugDescription: String {
        if let result = self.result {
            return "{\(ObjectIdentifier( self ).identity): Promise<\(V.self)>, finished: \(result)}"
        }
        else {
            return "{\(ObjectIdentifier( self ).identity): Promise<\(V.self)>, targets: \(self.targets.count)}"
        }
    }

    public init(_ result: Result<V, Error>? = nil) {
        LeakRegistry.shared.register( self )

        if let result = result {
            self.finish( result )
        }
    }

    public convenience init(_ task: @escaping () async throws -> V) {
        self.init()
        Task {
            do {
                let result = try await task()
                self.finish(.success(result))
            }
            catch { self.finish(.failure(error)) }
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
    public func finish(_ result: Result<V, Error>, ignoreIfFinished: Bool = false)
            -> Self {
        self.semaphore.await { () -> [(queue: DispatchQueue?, consumer: (Result<V, Error>) -> Void)] in
                if ignoreIfFinished && self.result != nil {
                    return []
                }

                assert( self.result == nil, "Tried to finish promise with \(result), but was already finished with \(self.result!)" )
                self.result = result

                let targets = self.targets
                self.targets = []
                return targets
            }
            .forEach { target in
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
    public func finishes(_ promise: Promise<V>)
            -> Self {
        self.then { (result: Result<V, Error>) in
            promise.finish( result )
        }
    }

    /** When this promise succeeds, run the given block. */
    public func success(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) -> Void)
            -> Self {
        self.then( on: queue ) { if case .success(let value) = $0 { consumer( value ) } }
    }

    /** When this promise fails, run the given block. */
    @discardableResult
    public func failure(on queue: DispatchQueue? = nil, _ consumer: @escaping (Error) -> Void)
            -> Self {
        self.then( on: queue ) { if case .failure(let error) = $0 { consumer( error ) } }
    }

    /** When this promise is finished, regardless of the result, run the given block. */
    @discardableResult
    public func finally(on queue: DispatchQueue? = nil, _ consumer: @escaping () -> Void)
            -> Self {
        self.then( on: queue ) { _ in consumer() }
    }

    /** When this promise is finished, consume its result with the given block. */
    @discardableResult
    public func then(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) -> Void)
            -> Self {
        if let result = self.result {
            if let queue = queue, !queue.isActive {
                queue.perform { consumer( result ) }
            }
            else {
                consumer( result )
            }
        }
        else {
            self.semaphore.await {
                self.targets.append( (queue: queue, consumer: consumer) )
            }
        }
        return self
    }

    /** When this promise is finished, transform its successful result with the given block, yielding a new promise for the block's result. */
    public func promise<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) throws -> V2)
            -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try promise.finish( .success( consumer( $0.get() ) ) ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, consume its result with the given block.  Return a new promise for the block's result. */
    public func thenPromise<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) throws -> V2)
            -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try promise.finish( .success( consumer( $0 ) ) ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, transform its successful result with the given block, yielding a new promise for the block. */
    public func promising<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) throws -> Promise<V2>)
            -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try consumer( $0.get() ).finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** When this promise is finished, transform its successful result with the given block, yielding a new promise for the block. */
    public func promising<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) async throws -> V2)
            -> Promise<V2> {
        self.promising(on: queue) { value in
            Promise<V2> { try await consumer( value ) }
        }
    }

    /** When this promise is finished, transform its result with the given block, yielding a new promise for the block. */
    public func thenPromising<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) throws -> Promise<V2>)
            -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try consumer( $0 ).finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
            // TODO: handle Interruption.postponed?
        } )

        return promise
    }

    /** Return a new promise that finishes with a successful result of this promise or falls back to the result of the given promise. */
    public func or(_ other: @autoclosure @escaping () -> Promise<V>)
            -> Promise<V> {
        self.thenPromising {
            switch $0 {
                case .success:
                    return self
                case .failure:
                    return other()
            }
        }
    }

    /** Return a new promise that finishes with a successful result of this promise or nil if this promise fails. */
    public func orNil()
            -> Promise<V?> {
        self.thenPromise {
            switch $0 {
                case let .success(value):
                    return value
                case .failure:
                    return nil
            }
        }
    }

    /** Return a new promise that finishes after both this and the given promise have finished. */
    public func and(_ other: Promise<V>)
            -> Promise<V> where V == Void {
        self.promising { other }
    }

    /** Return a new promise that combines the result of this and the given promise. */
    public func and<V2>(_ other: Promise<V2>)
            -> Promise<(V, V2)> {
        and( other, reducing: { ($0, $1) } )
    }

    /** Return a new promise that combines the result of this and the given promise. */
    public func and<V2, V3>(_ other: Promise<V2>, reducing: @escaping (V, V2) -> V3)
            -> Promise<V3> {
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
    public func await() throws
            -> V {
        // FIXME: promise runs Thread 2, then Thread 1; await on Thread 1 -> deadlock.
        let group = DispatchGroup()
        var awaitedResult: Result<V, Error> = .failure( AppError.internal( cause: "Missing result from await()" ) )
        self.semaphore.await {
            if let result = self.result {
                awaitedResult = result
            } else {
                group.enter()
                self.targets.append( (queue: nil, consumer: {
                    awaitedResult = $0
                    group.leave()
                }) )
            }
        }
        group.wait()

        return try self.semaphore.await { try awaitedResult.get() }
    }
}

enum Interruption: Error {
    case cancelled, invalidated, rejected, postponed
}

extension Collection {
    /// A promise that succeeds once all the promises in this collection have completed, with only the successful results in the same order as their respective promises in this collection.
    ///
    /// The promise never fails.
    func compactPromise<V>() -> Promise<[V]> where Self.Element == Promise<V> {
        guard !self.isEmpty
        else { return Promise<[V]>( .success( [] ) ) }

        let compactPromise = Promise<[V]>()
        var compactResults = [ Result<V, Error>? ]( repeating: nil, count: self.count )
        for (p, _promise) in self.enumerated() {
            _promise.then { result in
                compactPromise.semaphore.await {
                    compactResults[p] = result

                    if !compactResults.contains( where: { $0 == nil } ) {
                        compactPromise.finish( .success( compactResults.map { try? $0?.get() }.compactMap { $0 } ) )
                    }
                }
            }
        }

        return compactPromise
    }

    /// A promise that succeeds once all the promises in this collection have completed successfully, with all results in the same order as their respective promises in this collection.
    ///
    /// The promise fails with the first error if any promise in the collection fails.
    func flatPromise<V>() -> Promise<[V]> where Self.Element == Promise<V> {
        guard !self.isEmpty
        else { return Promise<[V]>( .success( [] ) ) }

        let flatPromise = Promise<[V]>()
        var flatResults = [ V? ]( repeating: nil, count: self.count )
        var aborted     = false
        for (p, _promise) in self.enumerated() {
            _promise.then { result in
                flatPromise.semaphore.await {
                    guard !aborted
                    else { return }
                    do {
                        flatResults[p] = try result.get()

                        if !flatResults.contains( where: { $0 == nil } ) {
                            flatPromise.finish( .success( flatResults.compactMap { $0 } ) )
                        }
                    } catch {
                        aborted = true
                        flatPromise.finish( .failure( error ) )
                    }
                }
            }
        }

        return flatPromise
    }
}

/**
 * A task that can be scheduled by request.
 */
public class DispatchTask<V>: CustomDebugStringConvertible, LeakObserver {
    private let name:      String
    private let workQueue: DispatchQueue
    private let deadline:  () -> DispatchTime
    private let group:     DispatchGroup?
    private let qos:       DispatchQoS
    private let flags:     DispatchWorkItemFlags
    private let work:      () throws -> V

    private var requestItem:    DispatchWorkItem?
    private var requestPromise: Promise<V>?
    private var requestRunning = false
    private lazy var requestQueue = DispatchQueue( label: "\(productName): DispatchTask: \(self.name)", qos: .userInitiated )

    public var debugDescription: String { self.name }

    public init(named name: String, queue: DispatchQueue,
                deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now() + .seconds( .short ), group: DispatchGroup? = nil,
                qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [], execute work: @escaping () throws -> V) {
        self.name = name
        self.workQueue = queue
        self.deadline = deadline
        self.group = group
        self.qos = qos
        self.flags = flags
        self.work = work

        LeakRegistry.shared.register( self )
        LeakRegistry.shared.observers.register( observer: self )
    }

    /**
     * Queue the task for execution if it has not already been queued.
     * The task is removed from the request queue as soon as the work begins.
     * - Parameters:
     *  - Parameter: now Skip the task's deadline and schedule the task for immediate execution.
     *  - Parameter: await Perform the task synchronously, blocking the request until it has completed.
     */
    @discardableResult
    public func request(now: Bool = false, await: Bool = false)
            -> Promise<V> {
        self.requestQueue.await {
            if now && !self.requestRunning {
                self.cancel()
            }

            if let requestPromise = self.requestPromise {
                return requestPromise
            }

            let requestPromise = Promise<V>()
            let requestItem = DispatchWorkItem( qos: self.qos, flags: self.flags ) { [weak self, weak requestPromise] in
                self?.requestQueue.await {
                    guard let self = self, self.requestPromise === requestPromise
                    else { return }

                    self.requestRunning = true
                }

                var result: V?, failure: Error?, postponed = false
                do { result = try self?.work() }
                catch Interruption.postponed { postponed = true }
                catch { failure = error }

                guard let self = self, let requestPromise = requestPromise
                else { return }

                if let result = result {
                    self.requestQueue.await {
                        self.requestRunning = false
                        requestPromise.finish( .success( result ), ignoreIfFinished: true )
                    }
                }
                else if postponed {
                    self.workQueue.perform( deadline: .now() + .seconds( .short ), group: self.group, qos: self.qos, flags: self.flags ) {
                        self.requestItem?.perform()
                    }
                }
                else if let failure = failure {
                    self.requestQueue.await {
                        self.requestRunning = false
                        requestPromise.finish( .failure( failure ), ignoreIfFinished: true )
                    }
                }
            }

            self.requestItem = requestItem
            self.requestPromise = requestPromise.finally( on: self.requestQueue ) { [weak self] in
                self?.requestItem = nil
                self?.requestPromise = nil
            }

            self.workQueue.perform( deadline: now ? nil : self.deadline(), group: self.group,
                                    qos: self.qos, flags: self.flags, await: `await` ) {
                requestItem.perform()
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

            if !(self.requestItem?.isCancelled ?? true) {
                self.requestItem?.cancel()
                self.requestPromise?.finish( .failure( Interruption.cancelled ) )
            }

            return self.requestItem?.isCancelled ?? false
        }
    }

    // MARK: - LeakObserver

    func shouldCancelOperations() {
        self.cancel()
    }

    func willReportLeaks() {
    }
}
