//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite: NSObject, Comparable {
    let observers = Observers<MPSiteObserver>()

    let user:     MPUser
    var siteName: String {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var algorithm: MPAlgorithmVersion {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var counter: MPCounterValue = .default {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var resultType: MPResultType {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var loginType: MPResultType {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }

    var resultState: String? {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var loginState: String? {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }

    var url: String? {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var uses: UInt = 0 {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var lastUsed: Date {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var color: UIColor? {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }
    var image: UIImage? {
        didSet {
            self.observers.notify { $0.siteDidChange() }
        }
    }

    // MARK: - Life

    init(user: MPUser, named name: String,
         algorithm: MPAlgorithmVersion? = nil, counter: MPCounterValue? = nil,
         resultType: MPResultType? = nil, resultState: String? = nil,
         loginType: MPResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt = 0, lastUsed: Date? = nil) {
        self.user = user
        self.siteName = name
        self.algorithm = algorithm ?? user.algorithm
        self.counter = counter ?? MPCounterValue.default
        self.resultType = resultType ?? user.defaultType
        self.loginType = loginType ?? MPResultType.templateName
        self.url = url
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.color = self.siteName.color()
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

    static func <(lhs: MPSite, rhs: MPSite) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed < rhs.lastUsed
        }

        return lhs.siteName < rhs.siteName
    }

    // MARK: - mpw

    func result(keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil, resultParam: String? = nil)
                    -> String? {
        if let masterKey = self.user.masterKey,
           let result = mpw_siteResult( masterKey, self.siteName, self.counter,
                                        keyPurpose, keyContext, self.resultType, resultParam, self.algorithm ) {
            return String( utf8String: result )
        }

        return nil
    }
}

@objc
protocol MPSiteObserver {
    func siteDidChange()
}
