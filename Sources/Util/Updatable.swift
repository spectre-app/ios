//
// Created by Maarten Billemont on 2020-09-14.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

protocol Updates: class {
    func doUpdate()
}

protocol Updatable: class {
    var updatesPostponed: Bool { get }
    var updatesRejected:  Bool { get }
    var updateTask:       DispatchTask<Void> { get }
}

extension Updatable {
    var updatesPostponed: Bool {
        false
    }
    var updatesRejected:  Bool {
        false
    }
}

extension DispatchTask where V == Void {
    static func update(_ updatable: Updatable, queue: DispatchQueue = .main, deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now(), group: DispatchGroup? = nil,
                              qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [], animated: Bool = false, update: @escaping () -> ()) -> DispatchTask<V> {
        DispatchTask( named: "Update: \(type( of: updatable ))", queue: queue, deadline: deadline(), group: group, qos: qos, flags: flags ) { [weak updatable] in
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
                UIView.animate( withDuration: .short ) { update() }
            }
            else {
                update()
            }
        }
    }
}
