//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite {
    let siteName: String
    var uses:     UInt = 0
    var lastUsed: Date?

    // MARK: - Life

    init(named name: String, uses: UInt = 0, lastUsed: Date? = nil) {
        self.siteName = name
        self.uses = uses
        self.lastUsed = lastUsed
    }
}
