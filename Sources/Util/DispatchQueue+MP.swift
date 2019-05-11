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
        if (self == DispatchQueue.main) && Thread.isMainThread {
            group?.enter()
            DispatchWorkItem( qos: qos, flags: flags, block: work ).perform()
            group?.leave()
        }
        else {
            self.async( group: group, qos: qos, flags: flags, execute: work )
        }
    }
}
