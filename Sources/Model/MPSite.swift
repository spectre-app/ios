//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite: NSObject {
    var observers = Observers<MPSiteObserver>()

    let siteName: String

    var uses:     UInt = 0 {
        didSet {
            self.changed()
        }
    }
    var lastUsed: Date? {
        didSet {
            self.changed()
        }
    }
    var color:    UIColor {
        didSet {
            self.changed()
        }
    }
    var image:    UIImage? {
        didSet {
            self.changed()
        }
    }

    // MARK: - Life

    init(named name: String, uses: UInt = 0, lastUsed: Date? = nil) {
        self.siteName = name
        self.uses = uses
        self.lastUsed = lastUsed
        self.color = MPUtils.color( message: self.siteName )
        super.init()

        MPURLUtils.preview( url: self.siteName, imageResult: { image in
            if let image = image, image != self.image {
                self.image = image
            }
        }, colorResult: { color in
            if let color = color, color != self.color {
                self.color = color
            }
        } )
    }

    private func changed() {
        self.observers.notify { $0.siteDidChange() }
    }
}

@objc
protocol MPSiteObserver {
    func siteDidChange()
}
