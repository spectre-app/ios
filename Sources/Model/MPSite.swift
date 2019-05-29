//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite: NSObject, Comparable {
    let observers = Observers<MPSiteObserver>()

    let user: MPUser
    var siteName: String {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var algorithm: MPAlgorithmVersion {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var counter: MPCounterValue = .default {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var resultType: MPResultType {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var loginType: MPResultType {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }

    var resultState: String? {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var loginState: String? {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }

    var url: String? {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var uses: UInt = 0 {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var lastUsed: Date {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var color: UIColor? {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }
    var image: UIImage? {
        didSet {
            self.observers.notify { $0.siteDidChange( self ) }
        }
    }

    // MARK: --- Life ---

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

    // MARK: --- mpw ---

    func mpw_result(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                    resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> String? {
        guard let masterKey = self.user.masterKey
        else {
            return nil
        }

        return DispatchQueue.mpw.await {
            String( safeUTF8: mpw_siteResult( masterKey, self.siteName, counter ?? self.counter, keyPurpose, keyContext,
                                              resultType ?? self.resultType, resultParam, algorithm ?? self.algorithm ) )
        }
    }
}

@objc
protocol MPSiteObserver {
    func siteDidChange(_ site: MPSite)
}
