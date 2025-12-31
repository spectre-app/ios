//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation
import OrderedCollections

@Observable
class Site: SpectreOperand, CustomStringConvertible, Observed, SiteObserver, QuestionObserver {
    let observers = Observers<SiteObserver>()

    weak var user: User?
    let siteName: String
    var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.algorithm) }
            }
        }
    }

    var counter: SpectreCounter = .default {
        didSet {
            if oldValue != self.counter {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.counter) }
            }
        }
    }

    var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.resultType) }
            }
        }
    }

    var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.loginType) }
            }
        }
    }

    var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.resultState) }
            }
        }
    }

    var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.loginState) }
            }
        }
    }

    var url: String {
        didSet {
            if oldValue != self.url {
                //                self.preview.url = self.url
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.url) }
            }
        }
    }

    var domains: OrderedSet<String> {
        didSet {
            if oldValue != self.domains {
                //                self.preview.domains = self.domains
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.domains) }
            }
        }
    }

    var uses: UInt32 = .zero {
        didSet {
            if oldValue != self.uses {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.uses) }
            }
        }
    }

    var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.didChange(site: self, at: \Site.lastUsed) }
            }
        }
    }

    //    @ObservationIgnored
    //    public lazy var preview: SitePreview = SitePreview.for( self.siteName, withURL: self.url ) {
    //        didSet {
    //            if oldValue != self.preview {
    //                self.observers.notify { $0.didChange( site: self, at: \Site.preview ) }
    //            }
    //        }
    //    }
    var questions: [Question] = [] {
        didSet {
            if oldValue != self.questions {
                self.dirty = true
                for oldQuestion in oldValue where !self.questions.contains(oldQuestion) {
                    oldQuestion.observers.unregister(observer: self)
                }
                self.questions.forEach { question in question.observers.register(observer: self) }
                self.observers.notify { $0.didChange(site: self, at: \Site.questions) }
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

    init(
        user: User?, siteName: String, algorithm: SpectreAlgorithm? = nil, counter: SpectreCounter? = nil,
        resultType: SpectreResultType? = nil, resultState: String? = nil,
        loginType: SpectreResultType? = nil, loginState: String? = nil,
        url: String? = nil, domains: OrderedSet<String> = [], uses: UInt32 = .zero, lastUsed: Date? = nil, questions: [Question] = [],
        initialize: (Site) -> Void = { _ in },
    ) {
        self.user = user
        self.siteName = siteName
        self.algorithm = algorithm ?? user?.algorithm ?? .current
        self.counter = counter ?? SpectreCounter.default
        self.resultType = resultType ?? user?.resultType ?? .defaultResult
        self.resultState = resultState
        self.loginType = loginType ?? .none
        self.loginState = loginState
        self.url = url ?? ""
        self.domains = domains
        self.uses = uses
        self.lastUsed = lastUsed ?? Date()
        self.questions = questions
        LeakRegistry.shared.register(self)

        defer {
            initialize(self)
            self.initializing = false
        }
    }

    // MARK: - Interface

    func use() {
        self.lastUsed = Date()
        self.uses += 1
        self.user?.use()
    }

    func copy(to user: User? = nil) -> Site {
        // TODO: do we need to re-encode state?
        let site = Site(
            user: user ?? self.user, siteName: self.siteName, algorithm: self.algorithm, counter: self.counter,
            resultType: self.resultType, resultState: self.resultState,
            loginType: self.loginType, loginState: self.loginState,
            url: self.url, domains: self.domains, uses: self.uses, lastUsed: self.lastUsed,
        )
        site.questions = self.questions.map { $0.copy(to: site) }
        return site
    }

    // MARK: - SiteObserver

    func didChange(site: Site, at change: PartialKeyPath<Site>) {
        if change == \Site.siteName || change == \Site.url || change == \Site.domains, let user = self.user {
            Task.detached { await AutoFill.shared.update(for: user) }
        }
    }

    // MARK: - QuestionObserver

    func didChange(question: Question) {}

    // MARK: - Credential

    var credential: AutoFill.Credential? {
        self.user.flatMap { .init(supplier: $0, siteName: self.siteName, url: self.url.nonEmpty, domains: self.domains) }
    }

    // MARK: - Operand

    func result(
        for name: String? = nil, counter: SpectreCounter? = nil,
        keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
        resultType: SpectreResultType? = nil, resultParam: String? = nil,
        algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil,
    )
        -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.user?.result(
                    for: name ?? self.siteName, counter: counter ?? self.counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam ?? self.resultState,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .identification:
                return self.user?.result(
                    for: name ?? self.siteName, counter: counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.loginType, resultParam: resultParam ?? self.loginState,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .recovery:
                return self.user?.result(
                    for: name ?? self.siteName, counter: counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.siteName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.user?.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                    task:
                    Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    },
                )
        }
    }

    func state(
        for name: String? = nil, counter: SpectreCounter? = nil,
        keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
        resultType: SpectreResultType? = nil, resultParam: String,
        algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil,
    )
        -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.user?.state(
                    for: name ?? self.siteName, counter: counter ?? self.counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .identification:
                return self.user?.state(
                    for: name ?? self.siteName, counter: counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.loginType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .recovery:
                return self.user?.state(
                    for: name ?? self.siteName, counter: counter,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.siteName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.user?.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                    task:
                    Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    },
                )
        }
    }
}

extension Site: Identifiable {
    var id: String { self.siteName }
}

extension Site: Hashable {
    static func == (lhs: Site, rhs: Site) -> Bool {
        lhs.siteName == rhs.siteName && lhs.algorithm == rhs.algorithm && lhs.counter == rhs.counter && lhs.resultType == rhs.resultType
            && lhs.loginType == rhs.loginType && lhs.resultState == rhs.resultState && lhs.loginState == rhs.loginState
            && lhs.url == rhs.url && lhs.uses == rhs.uses && lhs.lastUsed == rhs.lastUsed && lhs.questions == rhs.questions
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.siteName)
        hasher.combine(self.algorithm)
        hasher.combine(self.counter)
        hasher.combine(self.resultType)
        hasher.combine(self.loginType)
        hasher.combine(self.resultState)
        hasher.combine(self.loginState)
        hasher.combine(self.url)
        hasher.combine(self.domains)
        hasher.combine(self.uses)
        hasher.combine(self.lastUsed)
        hasher.combine(self.questions)
    }
}

extension Site: Comparable {
    static func < (lhs: Site, rhs: Site) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.siteName < rhs.siteName
    }
}

protocol SiteObserver {
    func didChange(site: Site, at: PartialKeyPath<Site>)
}
