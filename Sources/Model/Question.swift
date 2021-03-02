//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class Question: Operand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, QuestionObserver {
    public let observers = Observers<QuestionObserver>()

    public let site: Site
    public var keyword: String {
        didSet {
            if oldValue != self.keyword {
                self.dirty = true
                self.observers.notify { $0.questionDidChange( self ) }
            }
        }
    }
    public var resultType: SpectreResultType {
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

    init(site: Site, keyword: String, resultType: SpectreResultType? = nil, resultState: String? = nil) {
        self.site = site
        self.keyword = keyword
        self.resultType = resultType ?? .templatePhrase
        self.resultState = resultState
    }

    // MARK: --- Interface ---

    func copy(to site: Site) -> Question {
        Question( site: site, keyword: self.keyword, resultType: self.resultType, resultState: self.resultState )
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.keyword )
    }

    static func ==(lhs: Question, rhs: Question) -> Bool {
        lhs.keyword == rhs.keyword
    }

    // MARK: Comparable

    public static func <(lhs: Question, rhs: Question) -> Bool {
        lhs.keyword > rhs.keyword
    }

    // MARK: --- QuestionObserver ---

    func questionDidChange(_ question: Question) {
    }

    // MARK: --- Operand ---

    func use() {
        self.site.use()
    }

    public func result(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .recovery, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
        self.site.result( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                          resultType: resultType, resultParam: resultParam ?? self.resultState, algorithm: algorithm, operand: operand ?? self )
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .recovery, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
        self.site.state( for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                         resultType: resultType, resultParam: resultParam, algorithm: algorithm, operand: operand ?? self )
    }
}

protocol QuestionObserver {
    func questionDidChange(_ question: Question)
}