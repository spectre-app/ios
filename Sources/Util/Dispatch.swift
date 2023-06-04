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

enum Interruption: Error {
    case invalidated, rejected, postponed
}

/**
 * A task that can be scheduled by request.
 */
public class DispatchTask<V>: CustomDebugStringConvertible, LeakObserver {
    private let name:      String
//    private let workQueue: DispatchQueue
    private let deadline:  () -> TimeInterval //DispatchTime
//    private let group:     DispatchGroup?
//    private let qos:       DispatchQoS
//    private let flags:     DispatchWorkItemFlags
    private let work:      () async throws -> V
//    private let work:      () throws -> Void

//    private var requestItem:    DispatchWorkItem?
//    private var requestPromise: Promise<V>?
//    private var requestRunning = false
//    private lazy var requestQueue = DispatchQueue( label: "\(productName): DispatchTask: \(self.name)", qos: .userInitiated )
    private var task: Task<V, Error>?
    private var isInvalidated = false

    public var debugDescription: String { self.name }

    public init(named name: String, //queue: DispatchQueue,
                deadline: @escaping @autoclosure () -> TimeInterval = .short, //DispatchTime = DispatchTime.now() + .seconds( .short ),
                //group: DispatchGroup? = nil, qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [],
                execute work: @escaping () async throws -> V) {
        self.name = name
//        self.workQueue = queue
        self.deadline = deadline
//        self.group = group
//        self.qos = qos
//        self.flags = flags
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
    public func request() -> Task<V, Error> {
        guard !self.isInvalidated
        else { return Task.detached { throw CancellationError() } }

        let task = Task.detached {
            repeat {
                try await Task.sleep( nanoseconds: UInt64( self.deadline() * Double( NSEC_PER_SEC ) ) )
                try Task.checkCancellation()

                do { return try await self.work() }
                catch Interruption.postponed { continue }
            }
            while true
        }

        self.task = task
        return task
    }

    @discardableResult
    public func requestNow() async throws -> V {
        do { return try await self.work() }
        catch Interruption.postponed { return try await self.request().value }
    }

    /**
     * Remove the task from the request queue if it is queued.
     */
    @discardableResult
    public func cancel() -> Bool {
        guard let task = self.task, !task.isCancelled
        else { return false }

        task.cancel()
        return true
    }

    // MARK: - LeakObserver

    func shouldCancelOperations() {
        self.isInvalidated = true
        self.cancel()
    }

    func willReportLeaks() {
    }
}
