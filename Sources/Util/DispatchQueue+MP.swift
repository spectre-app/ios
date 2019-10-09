//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension DispatchQueue {
    public static var mpw = DispatchQueue( label: "mpw", qos: .utility )

    private static let threadLabelsKey = "DispatchQueue+MP"
    private var threadLabels: Set<String> {
        get {
            let threadLabels: Set<String>? = Thread.current.threadDictionary[DispatchQueue.threadLabelsKey] as? Set<String>
            if let threadLabels = threadLabels {
                return threadLabels
            }

            let newThreadLabels = Set<String>()
            self.threadLabels = newThreadLabels
            return newThreadLabels
        }
        set {
            Thread.current.threadDictionary[DispatchQueue.threadLabelsKey] = newValue
        }
    }

    /** Performs the work asynchronously, unless queue is main and already on the main thread, then perform synchronously. */
    public func perform(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                        execute work: @escaping @convention(block) () -> Void) {
        if (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label ) ||
                   self.label == String( safeUTF8: __dispatch_queue_get_label( nil ) ) {
            // Already in the queue's thread.
            group?.enter()
            let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if threadOwnsLabel {
                    self.threadLabels.remove( self.label )
                }
                group?.leave()
            }

            DispatchWorkItem( qos: qos, flags: flags, block: work ).perform()
        }
        else {
            // Dispatch to the queue's thread.
            self.async( group: group, qos: qos, flags: flags ) {
                let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
                defer {
                    if threadOwnsLabel {
                        self.threadLabels.remove( self.label )
                    }
                }

                work()
            }
        }
    }

    /** Performs the work synchronously, returning the work's result. */
    public func await<T>(flags: DispatchWorkItemFlags = [], execute work: () throws -> T) rethrows -> T {
        if (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label ) ||
                   self.label == String( safeUTF8: __dispatch_queue_get_label( nil ) ) {
            // Already in the queue's thread.
            var threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if threadOwnsLabel {
                    self.threadLabels.remove( self.label )
                }
            }

            return try work()
        }
        else {
            // Dispatch to the queue's thread.
            return try self.sync( flags: flags ) {
                var threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
                defer {
                    if threadOwnsLabel {
                        self.threadLabels.remove( self.label )
                    }
                }

                return try work()
            }
        }
    }

    @discardableResult
    public func promise<V>(flags: DispatchWorkItemFlags = [], execute work: @escaping () throws -> V) -> Promise<V> {
        let promise = Promise<V>()

        if (self == .main && Thread.isMainThread) || self.threadLabels.contains( self.label ) ||
                   self.label == String( safeUTF8: __dispatch_queue_get_label( nil ) ) {
            // Already in the queue's thread.
            let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if threadOwnsLabel {
                    self.threadLabels.remove( self.label )
                }
            }

            do { promise.finish( .success( try work() ) ) }
            catch { promise.finish( .failure( error ) ) }
        }
        else {
            // Dispatch to the queue's thread.
            self.perform( flags: flags ) {
                let threadOwnsLabel = self.threadLabels.insert( self.label ).inserted
                defer {
                    if threadOwnsLabel {
                        self.threadLabels.remove( self.label )
                    }
                }

                do { promise.finish( .success( try work() ) ) }
                catch { promise.finish( .failure( error ) ) }
            }
        }

        return promise
    }

    @discardableResult
    public func promise<V>(flags: DispatchWorkItemFlags = [], execute work: @escaping () throws -> Promise<V>) -> Promise<V> {
        let promise = Promise<V>()

        self.promise {
            do { try work().then( promise ) }
            catch { promise.finish( .failure( error ) ) }
        }

        return promise
    }
}

public class Promise<V> {
    private var result: Result<V, Error>?
    private var consumers = [ (Result<V, Error>) -> () ]()

    public init(_ result: Result<V, Error>? = nil) {
        if let result = result {
            self.finish( result )
        }
    }

    public func finish(_ result: Result<V, Error>) {
        self.result = result
        self.consumers.forEach { $0( result ) }
    }

    @discardableResult
    public func then(_ consumer: @escaping (Result<V, Error>) -> ()) -> Promise<V> {
        if let result = self.result {
            consumer( result )
        }
        else {
            self.consumers.append( consumer )
        }

        return self
    }

    @discardableResult
    public func then(_ promise: Promise<V>) -> Promise<V> {
        self.then( { promise.finish( $0 ) } )
        return promise
    }

    @discardableResult
    public func then<V2>(_ consumer: @escaping (Result<V, Error>) throws -> (V2)) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( {
            do { try promise.finish( .success( consumer( $0 ) ) ) }
            catch { promise.finish( .failure( error ) ) }
        } )

        return promise
    }

    @discardableResult
    public func then<V2>(_ consumer: @escaping (V) throws -> (V2)) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( {
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

    @discardableResult
    public func then<V2>(_ consumer: @escaping (Result<V, Error>) throws -> (Promise<V2>)) -> Promise<V2> {
        let promise = Promise<V2>()

        self.then( {
            do { try consumer( $0 ).then( promise ) }
            catch { promise.finish( .failure( error ) ) }
        } )

        return promise
    }

    public func await() throws -> V {
        if let result = result {
            switch result {
                case .success(let value): return value
                case .failure(let error): throw error
            }
        }

        let group = DispatchGroup()
        group.enter()
        var result: Result<V, Error>?
        self.then {
            result = $0
            group.leave()
        }
        group.wait()

        switch result {
            case .success(let value): return value
            case .failure(let error): throw error
            case .none: throw MPError.internal( details: "Couldn't obtain result" )
        }
    }
}

public class DispatchTask {
    private let requestQueue = DispatchQueue( label: "DispatchTask request", qos: .userInitiated )
    private let workQueue: DispatchQueue
    private let qos:       DispatchQoS
    private let group:     DispatchGroup?
    private let deadline:  () -> DispatchTime
    private let work:      () -> Void
    private var item:      DispatchWorkItem? {
        willSet {
            self.item?.cancel()
        }
        didSet {
            if let item = self.item {
                self.workQueue.asyncAfter( deadline: self.deadline(), execute: item )
            }
        }
    }

    public init(queue: DispatchQueue, group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified,
                deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(),
                execute work: @escaping @convention(block) () -> Void) {
        self.workQueue = queue
        self.group = group
        self.qos = qos
        self.deadline = deadline
        self.work = work
    }

    @discardableResult
    public func request() -> Bool {
        self.requestQueue.sync {
            guard self.item == nil
            else {
                return false
            }

            self.item = DispatchWorkItem( qos: self.qos ) {
                self.requestQueue.sync { self.item = nil }
                self.workQueue.perform( group: self.group, qos: self.qos, execute: self.work )
            }
            return true
        }
    }

    @discardableResult
    public func cancel() -> Bool {
        self.requestQueue.sync {
            defer {
                self.item = nil
            }

            return self.item != nil
        }
    }
}
