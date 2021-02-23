//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class Site: Operand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, SiteObserver, QuestionObserver {
    public let observers = Observers<SiteObserver>()

    public let user: User
    public var siteName: String {
        didSet {
            if oldValue != self.siteName {
                self.dirty = true
                self.preview = SitePreview.for( self.siteName )
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var counter: SpectreCounter = .default {
        didSet {
            if oldValue != self.counter {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var loginType: SpectreResultType {
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
    public lazy var preview: SitePreview = SitePreview.for( self.siteName ) {
        didSet {
            if oldValue != self.preview {
                self.observers.notify { $0.siteDidChange( self ) }
            }
        }
    }
    public var questions = [ Question ]() {
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

    init(user: User, siteName: String, algorithm: SpectreAlgorithm? = nil, counter: SpectreCounter? = nil,
         resultType: SpectreResultType? = nil, resultState: String? = nil,
         loginType: SpectreResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt32 = 0, lastUsed: Date? = nil, questions: [Question] = [],
         initialize: (Site) -> Void = { _ in }) {
        self.user = user
        self.siteName = siteName
        self.algorithm = algorithm ?? user.algorithm
        self.counter = counter ?? SpectreCounter.default
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

    static func ==(lhs: Site, rhs: Site) -> Bool {
        lhs.siteName == rhs.siteName
    }

    // MARK: Comparable

    public static func <(lhs: Site, rhs: Site) -> Bool {
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

    public func copy(to user: User) -> Site {
        // TODO: do we need to re-encode state?
        let site = Site( user: user, siteName: self.siteName, algorithm: self.algorithm, counter: self.counter,
                         resultType: self.resultType, resultState: self.resultState,
                         loginType: self.loginType, loginState: self.loginState,
                         url: self.url, uses: self.uses, lastUsed: self.lastUsed )
        site.questions = self.questions.map { $0.copy( to: site ) }
        return site
    }

    // MARK: --- SiteObserver ---

    func siteDidChange(_ site: Site) {
    }

    // MARK: --- QuestionObserver ---

    func questionDidChange(_ question: Question) {
    }

    // MARK: --- Operand ---

    public func result(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
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
                                         resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return Operation( siteName: name ?? self.siteName, counter: counter ?? .initial, purpose: keyPurpose,
                                  type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                  Promise( .failure( AppError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
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
                                        resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return Operation( siteName: name ?? self.siteName, counter: counter ?? .initial, purpose: keyPurpose,
                                  type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                  Promise( .failure( AppError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }
}

protocol SiteObserver {
    func siteDidChange(_ site: Site)
}
