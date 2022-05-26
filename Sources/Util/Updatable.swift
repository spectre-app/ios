// =============================================================================
// Created by Maarten Billemont on 2020-09-14.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

protocol Updates: AnyObject {
    func doUpdate()
}

protocol Updatable: AnyObject {
    associatedtype V = Void
    var updatesPostponed: Bool { get }
    var updatesRejected:  Bool { get }
    var updateTask:       DispatchTask<V> { get }
}

extension Updatable {
    var updatesPostponed: Bool {
        false
    }
    var updatesRejected:  Bool {
        false
    }
}

extension DispatchTask {
    static func update<U>(_ updatable: U, queue: DispatchQueue = .main,
                          deadline: @escaping @autoclosure () -> DispatchTime = DispatchTime.now() + .seconds( .short * .short ),
                          group: DispatchGroup? = nil, qos: DispatchQoS = .utility, flags: DispatchWorkItemFlags = [],
                          animated: Bool = false, update: @escaping () throws -> V)
            -> DispatchTask<V> where U: Updatable, U.V == V {
        DispatchTask( named: "Update: \(type( of: updatable ))", queue: queue,
                      deadline: deadline(), group: group, qos: qos, flags: flags ) { [weak updatable] in
            if let updatable = updatable {
                if updatable.updatesRejected {
                    throw Interruption.rejected
                }
                if updatable.updatesPostponed {
                    wrn( "Postponing update of: %@", updatable )
                    throw Interruption.postponed
                }
            } else {
                throw Interruption.invalidated
            }

            var result: V?
            if animated {
                var _error: Error?
                UIView.animate( withDuration: .short ) {
                    do { result = try update() }
                    catch { _error = error }
                }
                if let error = _error {
                    throw error
                }
            }
            else {
                result = try update()
            }

            return result!
        }
    }
}
