// =============================================================================
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

@Observable class Site: SpectreOperand, CustomStringConvertible, Observed, Persisting, SiteObserver, QuestionObserver {
    public let observers = Observers<SiteObserver>()

    public weak var user:     User?
    public let siteName: String
    public var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.algorithm ) }
            }
        }
    }
    public var counter: SpectreCounter = .default {
        didSet {
            if oldValue != self.counter {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.counter ) }
            }
        }
    }
    public var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.resultType ) }
            }
        }
    }
    public var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.loginType ) }
            }
        }
    }

    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.resultState ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.loginState ) }
            }
        }
    }

    public var url: String? {
        didSet {
            if oldValue != self.url {
                self.preview.url = self.url
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.url ) }
            }
        }
    }
    public var uses: UInt32 = 0 {
        didSet {
            if oldValue != self.uses {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.uses ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.didChange( site: self, at: \Site.lastUsed ) }
            }
        }
    }
    @ObservationIgnored
    public lazy var preview: SitePreview = SitePreview.for( self.siteName, withURL: self.url ) /*{
        didSet {
            if oldValue != self.preview {
                self.observers.notify { $0.didChange( site: self, at: \Site.preview ) }
            }
        }
    }*/
    public var questions = [ Question ]() {
        didSet {
            if oldValue != self.questions {
                self.dirty = true
                oldValue.forEach { oldQuestion in
                    if !self.questions.contains(oldQuestion) {
                        oldQuestion.observers.unregister(observer: self)
                    }
                }
                self.questions.forEach { question in question.observers.register( observer: self ) }
                self.observers.notify { $0.didChange( site: self, at: \Site.questions ) }
            }
        }
    }

    var description: String {
        self.siteName
    }
    var dirty = false {
        didSet {
            if self.dirty {
                if !self.initializing {
                    self.user?.dirty = true
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

    // MARK: - Life

    init(user: User?, siteName: String, algorithm: SpectreAlgorithm? = nil, counter: SpectreCounter? = nil,
         resultType: SpectreResultType? = nil, resultState: String? = nil,
         loginType: SpectreResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt32 = 0, lastUsed: Date? = nil, questions: [Question] = [],
         initialize: (Site) -> Void = { _ in }) {
        self.user = user
        self.siteName = siteName
        self.algorithm = algorithm ?? user?.algorithm ?? .current
        self.counter = counter ?? SpectreCounter.default
        self.resultType = resultType ?? user?.defaultType ?? .defaultResult
        self.resultState = resultState
        self.loginType = loginType ?? .none
        self.loginState = loginState
        self.url = url
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.questions = questions
        LeakRegistry.shared.register( self )

        defer {
            initialize( self )
            self.initializing = false
        }
    }

    // MARK: - Interface

    public func use() {
        self.lastUsed = Date()
        self.uses += 1
        self.user?.use()
    }

    #if TARGET_APP
    public func refresh() {
        Task.detached {
            do {
                if try await self.preview.updateTask.request().value {
                    self.observers.notify { $0.didChange( site: self, at: \Site.preview ) }
                }
            } catch {
                wrn("Couldn't refresh preview for %@: %@", self.siteName, error.localizedDescription)
            }
        }
    }
    #endif

    public func copy(to user: User? = nil) -> Site {
        // TODO: do we need to re-encode state?
        let site = Site( user: user ?? self.user, siteName: self.siteName, algorithm: self.algorithm, counter: self.counter,
                         resultType: self.resultType, resultState: self.resultState,
                         loginType: self.loginType, loginState: self.loginState,
                         url: self.url, uses: self.uses, lastUsed: self.lastUsed )
        site.questions = self.questions.map { $0.copy( to: site ) }
        return site
    }

    // MARK: - SiteObserver

    func didChange(site: Site, at change: PartialKeyPath<Site>) {
        if change == \Site.url, let user = self.user {
            Task.detached { await AutoFill.shared.update( for: user ) }
        }
    }

    // MARK: - QuestionObserver

    func didChange(question: Question) {
    }

    // MARK: - Operand

    public func result(for name: String? = nil, counter: SpectreCounter? = nil,
                       keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil,
                       algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.user?.result( for: name ?? self.siteName, counter: counter ?? self.counter,
                                         keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.resultType, resultParam: resultParam ?? self.resultState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user?.result( for: name ?? self.siteName, counter: counter,
                                         keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user?.result( for: name ?? self.siteName, counter: counter,
                                         keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return SpectreOperation( siteName: name ?? self.siteName, counter: counter ?? .initial, type: resultType ?? .none,
                                         param: resultParam, purpose: keyPurpose, context: keyContext,
                                         identity: self.user?.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, task:
                                         Task.detached {
                                             throw AppError.internal( cause: "Unsupported key purpose", details: keyPurpose )
                                         } )
        }
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil,
                      keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String,
                      algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.user?.state( for: name ?? self.siteName, counter: counter ?? self.counter,
                                        keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.resultType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user?.state( for: name ?? self.siteName, counter: counter,
                                        keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.loginType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user?.state( for: name ?? self.siteName, counter: counter,
                                        keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return SpectreOperation( siteName: name ?? self.siteName, counter: counter ?? .initial, type: resultType ?? .none,
                                         param: resultParam, purpose: keyPurpose, context: keyContext,
                                         identity: self.user?.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, task:
                                         Task.detached {
                                             throw AppError.internal( cause: "Unsupported key purpose", details: keyPurpose )
                                         } )
        }
    }
}

extension Site: Identifiable {
    public var id: String { self.siteName }
}

extension Site: Hashable {
    public static func == (lhs: Site, rhs: Site) -> Bool {
        lhs.siteName == rhs.siteName &&
            lhs.algorithm == rhs.algorithm &&
            lhs.counter == rhs.counter &&
            lhs.resultType == rhs.resultType &&
            lhs.loginType == rhs.loginType &&
            lhs.resultState == rhs.resultState &&
            lhs.loginState == rhs.loginState &&
            lhs.url == rhs.url &&
            lhs.uses == rhs.uses &&
            lhs.lastUsed == rhs.lastUsed &&
            lhs.questions == rhs.questions
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.siteName)
        hasher.combine(self.algorithm)
        hasher.combine(self.counter)
        hasher.combine(self.resultType)
        hasher.combine(self.loginType)
        hasher.combine(self.resultState)
        hasher.combine(self.loginState)
        hasher.combine(self.url)
        hasher.combine(self.uses)
        hasher.combine(self.lastUsed)
        hasher.combine(self.questions)
    }
}

extension Site: Comparable {
    public static func < (lhs: Site, rhs: Site) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.siteName < rhs.siteName
    }
}

protocol SiteObserver {
    func didChange(site: Site, at: PartialKeyPath<Site>)
}
