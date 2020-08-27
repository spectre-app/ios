//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

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
            dbg( "[preview set] %@: image %@ -> %@", self.siteName, oldValue, self.image )
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
    var dirty = false {
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
         initialize: (MPSite) -> Void = { _ in }) {
        self.user = user
        self.siteName = siteName
        self.algorithm = algorithm ?? user.algorithm
        self.counter = counter ?? MPCounterValue.default
        self.resultType = resultType ?? user.defaultType
        self.resultState = resultState
        self.loginType = loginType ?? MPResultType.templateName
        self.loginState = loginState
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

    public func result(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        DispatchQueue.mpw.promised {
            switch keyPurpose {
                case .authentication:
                    return self.mpw_result( counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? self.resultType, resultParam: resultParam ?? self.resultState,
                                            algorithm: algorithm ?? self.algorithm )

                case .identification:
                    return self.mpw_result( counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                            algorithm: algorithm ?? self.algorithm )

                case .recovery:
                    return self.mpw_result( counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                            algorithm: algorithm ?? self.algorithm )

                @unknown default:
                    throw MPError.internal( details: "Unsupported key purpose: \(keyPurpose)" )
            }
        }
    }

    public func state(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        DispatchQueue.mpw.promised {
            switch keyPurpose {
                case .authentication:
                    return self.mpw_state( counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? self.resultType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm )

                case .identification:
                    return self.mpw_state( counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? self.loginType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm )

                case .recovery:
                    return self.mpw_state( counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm )

                @unknown default:
                    throw MPError.internal( details: "Unsupported key purpose: \(keyPurpose)" )
            }
        }
    }

    @discardableResult
    public func copy(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                     resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil,
                     for host: UIView? = nil) -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        let copyEvent = MPTracker.shared.begin( named: "site #copy" )

        return self.result( counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                            resultType: resultType, resultParam: resultParam, algorithm: algorithm ).then {
            do {
                let result = try $0.get()
                guard let token = result.token
                else { return }

                self.use()
                MPFeedback.shared.play( .trigger )

                UIPasteboard.general.setItems(
                        [ [ UIPasteboard.typeAutomatic: token ] ],
                        options: [
                            UIPasteboard.OptionsKey.localOnly: true,
                            UIPasteboard.OptionsKey.expirationDate: Date( timeIntervalSinceNow: 3 * 60 )
                        ] )

                MPAlert( title: "Copied \(keyPurpose) (3 min)", message: self.siteName, details:
                """
                Your \(keyPurpose) for \(self.siteName) is:
                \(token)

                It was copied to the pasteboard, you can now switch to your application and paste it into the \(keyPurpose) field.

                Note that after 3 minutes, the \(keyPurpose) will expire from the pasteboard for security reasons.
                """ ).show( in: host )

                copyEvent.end(
                        [ "result": $0.name,
                          "counter": "\(result.counter)",
                          "purpose": "\(result.purpose)",
                          "type": "\(result.type)",
                          "algorithm": "\(result.algorithm)",
                          "entropy": MPAttacker.entropy( type: result.3 ) ?? MPAttacker.entropy( string: token ) ?? 0,
                        ] )
            }
            catch {
                copyEvent.end( [ "result": $0.name ] )
                mperror( title: "Couldn't copy site", message: "Site value could not be calculated", error: error )
            }
        }
    }

    private func mpw_result(counter: MPCounterValue, keyPurpose: MPKeyPurpose, keyContext: String?,
                            resultType: MPResultType, resultParam: String?, algorithm: MPAlgorithmVersion)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        DispatchQueue.mpw.promise {
            guard let masterKey = self.user.masterKeyFactory?.newKey( for: algorithm )
            else { throw MPError.internal( details: "Cannot calculate result since master key is missing." ) }
            defer { masterKey.deallocate() }

            return (token: String( validate: mpw_site_result(
                    masterKey, self.siteName, counter, keyPurpose, keyContext, resultType, resultParam, algorithm ),
                                   deallocate: true ),
                    counter: counter, purpose: keyPurpose, type: resultType, algorithm: algorithm)
        }
    }

    public func mpw_state(counter: MPCounterValue, keyPurpose: MPKeyPurpose, keyContext: String?,
                          resultType: MPResultType, resultParam: String?, algorithm: MPAlgorithmVersion)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        DispatchQueue.mpw.promise {
            guard let masterKey = self.user.masterKeyFactory?.newKey( for: algorithm )
            else { throw MPError.internal( details: "Cannot calculate result since master key is missing." ) }
            defer { masterKey.deallocate() }

            return (token: String( validate: mpw_site_state(
                    masterKey, self.siteName, counter, keyPurpose, keyContext, resultType, resultParam, algorithm ),
                                   deallocate: true ),
                    counter: counter, purpose: keyPurpose, type: resultType, algorithm: algorithm)
        }
    }
}

protocol MPSiteObserver {
    func siteDidChange(_ site: MPSite)
}
