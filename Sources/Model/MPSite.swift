//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSite: Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPSiteObserver, MPQuestionObserver {
    public let observers = Observers<MPSiteObserver>()

    public let user: MPUser
    public var siteName: String {
        didSet {
            if oldValue != self.siteName {
                self.dirty = true
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
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var counter: MPCounterValue = .default {
        didSet {
            if oldValue != self.counter {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var resultType: MPResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var loginType: MPResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }

    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }

    public var url: String? {
        didSet {
            if oldValue != self.url {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var uses: UInt32 = 0 {
        didSet {
            if oldValue != self.uses {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
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
            else if oldValue !== self.image, let oldValue = oldValue, let image = self.image,
                    oldValue.pngData() == image.pngData() {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var questions = [ MPQuestion ]() {
        didSet {
            if oldValue != self.questions {
                self.dirty = true
                self.questions.forEach { question in question.observers.register( observer: self ) }
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    var description: String {
        "\(self.siteName)"
    }
    var initializing = true {
        didSet {
            self.dirty = false
        }
    }
    var dirty        = false {
        didSet {
            if self.dirty {
                if !self.initializing && self.dirty {
                    self.user.dirty = true
                }
            }
            else {
                self.questions.forEach { $0.dirty = false }
            }
        }
    }

    // MARK: --- Life ---

    init(user: MPUser, siteName: String, algorithm: MPAlgorithmVersion? = nil, counter: MPCounterValue? = nil,
         resultType: MPResultType? = nil, resultState: String? = nil,
         loginType: MPResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt32 = 0, lastUsed: Date? = nil, questions: [MPQuestion] = [],
         initialize: (MPSite) -> () = { _ in }) {
        self.user = user
        self.siteName = siteName
        self.algorithm = algorithm ?? user.algorithm
        self.counter = counter ?? MPCounterValue.default
        self.resultType = resultType ?? user.defaultType
        self.loginType = loginType ?? MPResultType.templateName
        self.url = url
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.questions = questions
        self.color = siteName.color()

        defer {
            // TODO: make efficient
            MPURLUtils.preview( url: self.siteName, result: { info in
                self.color = info.color?.uiColor
                self.image = info.imageData.flatMap { UIImage( data: $0 ) }
            } )

            initialize( self )
            self.initializing = false
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

    public func copy(to user: MPUser) -> MPSite {
        // TODO: do we need to re-encode state?
        let site = MPSite( user: user, siteName: self.siteName, algorithm: self.algorithm, counter: self.counter,
                           resultType: self.resultType, resultState: self.resultState,
                           loginType: self.loginType, loginState: self.loginState,
                           url: self.url, uses: self.uses, lastUsed: self.lastUsed )
        site.questions = self.questions.map { $0.copy( to: site ) }
        return site
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
    }

    // MARK: --- MPQuestionObserver ---

    func questionDidChange(_ question: MPQuestion) {
    }

    // MARK: --- mpw ---

    public func mpw_result(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                           resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<String?> {
        DispatchQueue.mpw.promise { () -> String? in
            let masterKey = self.user.masterKeyFactory?.newMasterKey( algorithm: algorithm ?? self.algorithm )
            defer { masterKey?.deallocate() }

            switch keyPurpose {
                case .authentication:
                    return String( safeUTF8: mpw_site_result( masterKey, self.siteName, counter ?? self.counter, keyPurpose, keyContext,
                                                              resultType ?? self.resultType, resultParam ?? self.resultState, algorithm ?? self.algorithm ),
                                   deallocate: true )

                case .identification:
                    return String( safeUTF8: mpw_site_result( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                                                              resultType ?? self.loginType, resultParam ?? self.loginState, algorithm ?? self.algorithm ),
                                   deallocate: true )

                case .recovery:
                    return String( safeUTF8: mpw_site_result( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                                                              resultType ?? MPResultType.templatePhrase, resultParam, algorithm ?? self.algorithm ),
                                   deallocate: true )

                @unknown default:
                    throw MPError.internal( details: "Unsupported key purpose: \(keyPurpose)" )
            }
        }
    }

    public func mpw_state(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                          resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<String?> {
        DispatchQueue.mpw.promise { () -> String? in
            let masterKey = self.user.masterKeyFactory?.newMasterKey( algorithm: algorithm ?? self.algorithm )
            defer { masterKey?.deallocate() }

            switch keyPurpose {
                case .authentication:
                    return String( safeUTF8: mpw_site_state( masterKey, self.siteName, counter ?? self.counter, keyPurpose, keyContext,
                                                             resultType ?? self.resultType, resultParam, algorithm ?? self.algorithm ),
                                   deallocate: true )

                case .identification:
                    return String( safeUTF8: mpw_site_state( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                                                             resultType ?? self.loginType, resultParam, algorithm ?? self.algorithm ),
                                   deallocate: true )

                case .recovery:
                    return String( safeUTF8: mpw_site_state( masterKey, self.siteName, counter ?? .initial, keyPurpose, keyContext,
                                                             resultType ?? MPResultType.templatePhrase, resultParam, algorithm ?? self.algorithm ),
                                   deallocate: true )

                @unknown default:
                    throw MPError.internal( details: "Unsupported key purpose: \(keyPurpose)" )
            }
        }
    }

    public func mpw_copy(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                         resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil,
                         for host: UIView? = nil) -> Promise<Void> {
        self.mpw_result( counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                         resultType: resultType, resultParam: resultParam, algorithm: algorithm ).then { (result: String?) in
            guard let result = result
            else { return }

            self.use()

            if #available( iOS 10.0, * ) {
                UIPasteboard.general.setItems(
                        [ [ UIPasteboard.typeAutomatic: result ] ],
                        options: [
                            UIPasteboard.OptionsKey.localOnly: true,
                            UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                        ] )

                MPAlert( title: self.siteName, message: "Copied \(keyPurpose.result) (3 min)", details:
                """
                Your \(keyPurpose.result) for \(self.siteName) is:
                \(result)

                It was copied to the pasteboard, you can now switch to your application and paste it into the \(keyPurpose.result) field.

                Note that after 3 minutes, the \(keyPurpose.result) will expire from the pasteboard for security reasons.
                """ ).show( in: host )
            }
            else {
                UIPasteboard.general.string = result

                MPAlert( title: self.siteName, message: "Copied \(keyPurpose.result)", details:
                """
                Your \(keyPurpose.result) for \(self.siteName) is:
                \(result)

                It was copied to the pasteboard, you can now switch to your application and paste it into the \(keyPurpose.result) field.
                """ ).show( in: host )
            }
        }
    }
}

protocol MPSiteObserver {
    func siteDidChange(_ site: MPSite)
}
