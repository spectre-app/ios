//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSite: MPOperand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPSiteObserver, MPQuestionObserver {
    public let observers = Observers<MPSiteObserver>()

    public let user: MPUser
    public var siteName: String {
        didSet {
            if oldValue != self.siteName {
                self.dirty = true
                self.preview = MPSitePreview.for( self.siteName )
                self.observers.notify { $0.siteDidChange( self ) }
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
    public lazy var preview: MPSitePreview = MPSitePreview.for( self.siteName ) {
        didSet {
            if oldValue != self.preview {
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
    public var isNew: Bool {
        !self.user.sites.contains( self )
    }
    var description: String {
        self.siteName
    }
    var dirty = false {
        didSet {
            if self.dirty {
                if !self.initializing && !self.isNew {
                    self.user.dirty = true
                }
            }
            else {
                self.questions.forEach { $0.dirty = false }
            }
        }
    }
    private var initializing = true {
        didSet {
            self.dirty = false
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
        self.loginType = loginType ?? .none
        self.loginState = loginState
        self.url = url
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.questions = questions

        defer {
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

    #if TARGET_APP
    public func refresh() {
        self.preview.update().success { updated in
            if updated {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    #endif

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

    // MARK: --- MPOperand ---

    public func result(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil, operand: MPOperand? = nil)
                    -> MPOperation {
        switch keyPurpose {
            case .authentication:
                return self.user.result( for: name ?? self.siteName, counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.resultType, resultParam: resultParam ?? self.resultState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user.result( for: name ?? self.siteName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user.result( for: name ?? self.siteName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return MPOperation( siteName: name ?? self.siteName, counter: counter ?? .initial, purpose: keyPurpose,
                                    type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                    Promise( .failure( MPError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }

    public func state(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil, operand: MPOperand? = nil)
                    -> MPOperation {
        switch keyPurpose {
            case .authentication:
                return self.user.state( for: name ?? self.siteName, counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.resultType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user.state( for: name ?? self.siteName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.loginType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user.state( for: name ?? self.siteName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return MPOperation( siteName: name ?? self.siteName, counter: counter ?? .initial, purpose: keyPurpose,
                                    type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                    Promise( .failure( MPError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }
}

protocol MPSiteObserver {
    func siteDidChange(_ site: MPSite)
}
