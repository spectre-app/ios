//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPQuestion: MPOperand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPQuestionObserver {
    public let observers = Observers<MPQuestionObserver>()

    public let service: MPService
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
                self.service.dirty = true
            }
        }
    }

    // MARK: --- Life ---

    init(service: MPService, keyword: String, resultType: MPResultType? = nil, resultState: String? = nil) {
        self.service = service
        self.keyword = keyword
        self.resultType = resultType ?? .templatePhrase
        self.resultState = resultState
    }

    // MARK: --- Interface ---

    func copy(to service: MPService) -> MPQuestion {
        MPQuestion( service: service, keyword: self.keyword, resultType: self.resultType, resultState: self.resultState )
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
                    -> MPOperation {
        self.service.result( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                          resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm )
    }

    public func state(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .recovery, keyContext: String? = nil,
                      resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> MPOperation {
        self.service.state( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                         resultType: resultType, resultParam: resultParam, algorithm: algorithm )
    }
}

protocol MPQuestionObserver {
    func questionDidChange(_ question: MPQuestion)
}
