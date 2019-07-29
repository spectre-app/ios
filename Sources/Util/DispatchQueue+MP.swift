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
            // Claim the queue with this thread.
            group?.enter()
            var ownsThreadLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if ownsThreadLabel {
                    self.threadLabels.remove( self.label )
                }
                group?.leave()
            }

            DispatchWorkItem( qos: qos, flags: flags, block: work ).perform()
        }
        else {
            self.async( group: group, qos: qos, flags: flags ) {
                // Claim the queue with this thread.
                var ownsThreadLabel = self.threadLabels.insert( self.label ).inserted
                defer {
                    if ownsThreadLabel {
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
            // Claim the queue with this thread.
            var ownsThreadLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if ownsThreadLabel {
                    self.threadLabels.remove( self.label )
                }
            }

            return try work()
        }
        else {
            // Claim the queue with this thread.
            var ownsThreadLabel = self.threadLabels.insert( self.label ).inserted
            defer {
                if ownsThreadLabel {
                    self.threadLabels.remove( self.label )
                }
            }

            return try self.sync( flags: flags, execute: work )
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
        return self.requestQueue.sync {
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
        return self.requestQueue.sync {
            defer {
                self.item = nil
            }

            return self.item != nil
        }
    }
}
