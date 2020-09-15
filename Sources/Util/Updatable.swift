//
// Created by Maarten Billemont on 2020-09-14.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation


public protocol Updatable: class {
    var updatesPostponed: Bool { get }
    var updatesRejected:  Bool { get }

    func update()
}

public extension Updatable {
    var updatesPostponed: Bool {
        false
    }
    var updatesRejected:  Bool {
        false
    }
}
