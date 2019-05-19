//
// Created by Maarten Billemont on 2019-05-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

extension DispatchQueue {
    public static var mpw = DispatchQueue( label: "mpw", qos: .utility )

    /** Performs the work asynchronously, unless queue is main and already on the main thread, then perform synchronously. */
    public func perform(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [],
                        execute work: @escaping @convention(block) () -> Void) {
        if (self == .main && Thread.isMainThread) ||
                   self.label == String( safeUtf8String: __dispatch_queue_get_label( nil ) ) {
            group?.enter()
            DispatchWorkItem( qos: qos, flags: flags, block: work ).perform()
            group?.leave()
        }
        else {
            self.async( group: group, qos: qos, flags: flags, execute: work )
        }
    }

    /** Performs the work synchronously, returning the work's result. */
    public func await<T>(flags: DispatchWorkItemFlags = [], execute work: () throws -> T) rethrows -> T {
        if (self == .main && Thread.isMainThread) ||
                   self.label == String( safeUtf8String: __dispatch_queue_get_label( nil ) ) {
            return try work()
        }
        else {
            return try self.sync( flags: flags, execute: work )
        }
    }
}
