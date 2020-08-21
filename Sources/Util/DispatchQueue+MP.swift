//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension DispatchQueue {
    public static var mpw = DispatchQueue( label: "\(productName): mpw", qos: .utility )
    public static var net = DispatchQueue( label: "\(productName): Network Queue", qos: .background )
    public var isActive: Bool {
        (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label ) ||
                self.label == String( validate: __dispatch_queue_get_label( nil ) )
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
            self.now( group: group ) { DispatchWorkItem( qos: qos, flags: flags, block: work ).perform() }
        }
        else if let deadline = deadline, !deadNow {
            self.asyncAfter( deadline: deadline, qos: qos, flags: flags ) {
                self.now( group: group, work: work )
            }
        }
        else {
            self.async( group: group, qos: qos, flags: flags ) {
                self.now( work: work )
            }
        }
    }

    private func now(group: DispatchGroup? = nil, work: @escaping @convention(block) () -> Void) {
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

    public func promised<V>(deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                            execute work: @escaping () throws -> Promise<V>) -> Promise<V> {
        let promise = Promise<V>()

        self.perform( deadline: deadline, group: group, qos: qos, flags: flags ) {
            do { try work().finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
        }

        return promise
    }

    public func promise<V>(deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                           execute work: @escaping () throws -> V) -> Promise<V> {
        self.promised( deadline: deadline, flags: flags, execute: { Promise( .success( try work() ) ) } )
    }

    public func promise(deadline: DispatchTime? = nil, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                        execute work: @escaping () throws -> Void) -> Promise<Void> {
        self.promised( deadline: deadline, flags: flags, execute: { Promise( .success( try work() ) ) } )
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
                    }
                }
            }
        }
    }

    @discardableResult
    public func finish(_ result: Result<V, Error>) -> Self {
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

    @discardableResult
    public func finishes(_ promise: Promise<V>) -> Self {
        self.then { (result: Result<V, Error>) in
            promise.finish( result )
        }
    }

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

    public func then<V2>(on queue: DispatchQueue? = nil, x: Void = (), _ consumer: @escaping (Result<V, Error>) throws -> V2) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try promise.finish( .success( consumer( $0 ) ) ) }
            catch { promise.finish( .failure( error ) ) }
        } )

        return promise
    }

    public func then<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (V) throws -> V2) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            switch $0 {
                case .success(let value):
                    do { try promise.finish( .success( consumer( value ) ) ) }
                    catch { promise.finish( .failure( error ) ) }

                case .failure(let error):
                    promise.finish( .failure( error ) )
            }
        } )

        return promise
    }

    public func promised<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping () throws -> Promise<V2>) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            switch $0 {
                case .success:
                    do { try consumer().finishes( promise ) }
                    catch { promise.finish( .failure( error ) ) }

                case .failure(let error):
                    promise.finish( .failure( error ) )
            }
        } )

        return promise
    }

    public func promised<V2>(on queue: DispatchQueue? = nil, _ consumer: @escaping (Result<V, Error>) throws -> Promise<V2>) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( on: queue, {
            do { try consumer( $0 ).finishes( promise ) }
            catch { promise.finish( .failure( error ) ) }
        } )

        return promise
    }

    public func and<V2>(_ other: Promise<V2>) -> Promise<Void> {
        self.promised {
            other.then { _ in
                ()
            }
        }
    }

    public func and<V2>(_ other: Promise<V2>) -> Promise<(V, V2)> {
        and( other, reducing: { ($0, $1) } )
    }

    public func and<V2, V3>(_ other: Promise<V2>, reducing: @escaping (V, V2) -> V3) -> Promise<V3> {
        let promise = Promise<V3>()

        self.then { result1 in
            _ = other.then { result2 in
                switch result1 {
                    case .success(let value1):
                        switch result2 {
                            case .success(let value2):
                                promise.finish( .success( reducing( value1, value2 ) ) )

                            case .failure(let error):
                                promise.finish( .failure( error ) )
                        }

                    case .failure(let error):
                        promise.finish( .failure( error ) )
                }
            }
        }

        return promise
    }

    public func await() throws -> V {
        if let result = self.result {
            switch result {
                case .success(let value):
                    return value

                case .failure(let error):
                    throw error
            }
        }

        // FIXME: promise runs Thread 2, then Thread 1; await on Thread 1 -> deadlock.
        let group = DispatchGroup()
        group.enter()
        self.targets.append( (queue: nil, consumer: { _ in group.leave() }) )
        group.wait()

        return try self.await()
    }
}

/**
 * A task that can be scheduled by request.
 */
public class DispatchTask<V> {
    private let requestQueue = DispatchQueue( label: "DispatchTask request", qos: .userInitiated )
    private let workQueue: DispatchQueue
    private let deadline:  () -> DispatchTime
    private let group:     DispatchGroup?
    private let qos:       DispatchQoS
    private let flags:     DispatchWorkItemFlags
    private let work:      () -> V

    private var requestItem: DispatchWorkItem?
    private var workPromise: Promise<V>?

    public init(queue: DispatchQueue, deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(), group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], execute work: @escaping () -> V) {
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
        self.requestQueue.promised {
            if let workPromise = self.workPromise {
                return workPromise
            }
            guard self.requestItem?.isCancelled ?? true
            else { return Promise( .failure( MPError.internal( details: "Task is cancelled." ) ) ) }

            var value: V?
            self.requestItem = DispatchWorkItem( qos: self.qos, flags: self.flags ) {
                value = self.work()
            }

            let workPromise: Promise<V>
                    = self.workQueue.promise( deadline: self.deadline(), group: self.group, qos: self.qos, flags: self.flags ) {
                if self.requestItem?.isCancelled ?? true {
                    throw MPError.internal( details: "Task was cancelled." )
                }

                self.requestItem?.perform()
                self.requestItem = nil
                self.workPromise = nil

                if let value = value {
                    return value
                }

                throw MPError.internal( details: "Task was skipped." )
            }

            self.workPromise = workPromise
            return workPromise
        }
    }

    /**
     * Remove the task from the request queue if it is queued.
     */
    @discardableResult
    public func cancel() -> Bool {
        self.requestQueue.await {
            self.requestItem?.cancel()
            return self.requestItem?.isCancelled ?? false
        }
    }
}

extension DispatchTask where V == Void {
    public convenience init(queue: DispatchQueue, deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(), group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], update: Updatable, animated: Bool = false) {
        self.init( queue: queue, deadline: deadline(), group: group, qos: qos, flags: flags ) {
            if animated {
                UIView.animate( withDuration: .short ) { update.update() }
            }
            else {
                update.update()
            }
        }
    }
}
