//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPQuestion: MPResult, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPQuestionObserver {
    public let observers = Observers<MPQuestionObserver>()

    public let site: MPSite
    public var keyword: String {
        didSet {
            if oldValue != self.keyword {
                self.dirty = true
                self.observers.notify { $0.questionDidChange( self ) }
            }
        }
    }
    public var resultType: MPResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.questionDidChange( self ) }
            }
        }
    }
    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.questionDidChange( self ) }
            }
        }
    }
    var description: String {
        "\(self.keyword)"
    }
    var dirty = false {
        didSet {
            if self.dirty {
                self.site.dirty = true
            }
        }
    }

    // MARK: --- Life ---

    init(site: MPSite, keyword: String, resultType: MPResultType? = nil, resultState: String? = nil) {
        self.site = site
        self.keyword = keyword
        self.resultType = resultType ?? .templatePhrase
        self.resultState = resultState
    }

    // MARK: --- Interface ---

    func copy(to site: MPSite) -> MPQuestion {
        MPQuestion( site: site, keyword: self.keyword, resultType: self.resultType, resultState: self.resultState )
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.keyword )
    }

    static func ==(lhs: MPQuestion, rhs: MPQuestion) -> Bool {
        lhs.keyword == rhs.keyword
    }

    // MARK: Comparable

    public static func <(lhs: MPQuestion, rhs: MPQuestion) -> Bool {
        lhs.keyword > rhs.keyword
    }

    // MARK: --- MPQuestionObserver ---

    func questionDidChange(_ question: MPQuestion) {
    }

    // MARK: --- mpw ---

    public func result(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                       resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        self.site.result( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                          resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm )
    }

    public func state(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                      resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        self.site.state( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                         resultType: resultType, resultParam: resultParam, algorithm: algorithm )
    }

    @discardableResult
    public func copy(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                     resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil,
                     by host: UIView? = nil) -> Promise<(token: String?, counter: MPCounterValue, purpose: MPKeyPurpose, type: MPResultType, algorithm: MPAlgorithmVersion)> {
        self.site.copy( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                        resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm,
                        by: host )
    }
}

protocol MPQuestionObserver {
    func questionDidChange(_ question: MPQuestion)
}
