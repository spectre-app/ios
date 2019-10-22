//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPQuestion: Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPQuestionObserver {
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

    public func mpw_result(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                           resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<String?> {
        self.site.mpw_result( counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                              resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm )
    }

    public func mpw_state(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                          resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<String?> {
        self.site.mpw_state( counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                             resultType: resultType, resultParam: resultParam, algorithm: algorithm )
    }

    public func mpw_copy(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                         resultType: MPResultType? = nil, resultParam: String? = nil, algorithm: MPAlgorithmVersion? = nil,
                         for host: UIView? = nil) -> Promise<Void> {
        self.site.mpw_copy( counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                            resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm,
                            for: host )
    }
}

protocol MPQuestionObserver {
    func questionDidChange(_ question: MPQuestion)
}
