//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite: Hashable, Comparable, CustomStringConvertible, Observable {
    public let observers = Observers<MPSiteObserver>()

    public let user: MPUser
    public var siteName: String {
        didSet {
            if oldValue != self.siteName {
                self.observers.notify { $0.siteDidChange( self ) }

                MPURLUtils.preview( url: self.siteName, result: { info in
                    self.color = info.color?.uiColor
                    self.image = info.imageData.flatMap { UIImage( data: $0 ) }
                } )
            }
        }
    }
    public var algorithm: MPAlgorithmVersion {
        didSet {
            if oldValue != self.algorithm {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var counter: MPCounterValue = .default {
        didSet {
            if oldValue != self.counter {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var resultType: MPResultType {
        didSet {
            if oldValue != self.resultType {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var loginType: MPResultType {
        didSet {
            if oldValue != self.loginType {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }

    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }

    public var url: String? {
        didSet {
            if oldValue != self.url {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var uses: UInt32 = 0 {
        didSet {
            if oldValue != self.uses {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var color: UIColor? {
        didSet {
            if oldValue != self.color {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var image: UIImage? {
        didSet {
            if (oldValue == nil) != (self.image == nil) {
                self.observers.notify { $0.siteDidChange( self ) }
            }
            else if oldValue !== self.image,
                    let oldValue = oldValue,
                    let image = self.image,
                    oldValue.pngData( ) == image.pngData( ) {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    var description: String {
        "\(self.siteName)"
    }

    // MARK: --- Life ---

    init(user: MPUser, siteName: String, algorithm: MPAlgorithmVersion? = nil, counter: MPCounterValue? = nil,
         resultType: MPResultType? = nil, resultState: String? = nil,
         loginType: MPResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt32 = 0, lastUsed: Date? = nil) {
        self.user = user
        self.siteName = ""
        self.algorithm = algorithm ?? user.algorithm
        self.counter = counter ?? MPCounterValue.default
        self.resultType = resultType ?? user.defaultType
        self.loginType = loginType ?? MPResultType.templateName
        self.url = url
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.color = siteName.color()

        defer {
            self.siteName = siteName
        }
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.siteName )
    }

    static func ==(lhs: MPSite, rhs: MPSite) -> Bool {
        lhs.siteName == rhs.siteName
    }

    // MARK: Comparable

    public static func <(lhs: MPSite, rhs: MPSite) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.siteName > rhs.siteName
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
        self.uses += 1
        self.user.use()
    }

    public func copy(for user: MPUser) -> MPSite {
        // TODO: copy questions
        // TODO: do we need to re-encode state?
        MPSite( user: user, siteName: self.siteName, algorithm: self.algorithm, counter: self.counter,
                       resultType: self.resultType, resultState: self.resultState,
                       loginType: self.loginType, loginState: self.loginState,
                       url: self.url, uses: self.uses, lastUsed: self.lastUsed )
    }

    // MARK: --- mpw ---

    public func mpw_result(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                           resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> String? {
        guard let masterKey = self.user.masterKey
        else {
            return nil
        }

        return DispatchQueue.mpw.await {
            mpw_site_result( masterKey, self.siteName, counter ?? self.counter, keyPurpose, keyContext,
                             resultType ?? self.resultType, resultParam ?? self.resultState, algorithm ?? self.algorithm )?
                    .toStringAndDeallocate()
        }
    }

    @discardableResult
    public func mpw_result_save(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                                resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Bool {
        guard let masterKey = self.user.masterKey
        else {
            return false
        }

        return DispatchQueue.mpw.await {
            if let resultState = mpw_site_state( masterKey, self.siteName, counter ?? self.counter, keyPurpose, keyContext,
                                                 resultType ?? self.resultType, resultParam, algorithm ?? self.algorithm )?
                    .toStringAndDeallocate() {
                self.resultState = resultState
                return true
            }

            return false
        }
    }

    public func mpw_login(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .identification, keyContext: String? = nil,
                          resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> String? {
        guard let masterKey = self.user.masterKey
        else {
            return nil
        }

        return DispatchQueue.mpw.await {
            mpw_site_result( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                             resultType ?? self.loginType, resultParam ?? self.loginState, algorithm ?? self.algorithm )?
                    .toStringAndDeallocate()
        }
    }

    @discardableResult
    public func mpw_login_save(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                               resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Bool {
        guard let masterKey = self.user.masterKey
        else {
            return false
        }

        return DispatchQueue.mpw.await {
            if let loginState = mpw_site_state( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                                                resultType ?? self.loginType, resultParam, algorithm ?? self.algorithm )?
                    .toStringAndDeallocate() {
                self.loginState = loginState
                return true
            }

            return false
        }
    }

    public func mpw_answer(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                           resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> String? {
        guard let masterKey = self.user.masterKey
        else {
            return nil
        }

        return DispatchQueue.mpw.await {
            mpw_site_result( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                             resultType ?? MPResultType.templatePhrase, resultParam, algorithm ?? self.algorithm )?
                    .toStringAndDeallocate()
        }
    }
}

protocol MPSiteObserver {
    func siteDidChange(_ site: MPSite)
}
