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

@Observable class Question: SpectreOperand, CustomStringConvertible, Observed, Persisting, QuestionObserver {
    public let observers = Observers<QuestionObserver>()

    public weak var site: Site?
    public var keyword: String {
        didSet {
            if oldValue != self.keyword {
                self.dirty = true
                self.observers.notify { $0.didChange( question: self ) }
            }
        }
    }
    public var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.didChange( question: self ) }
            }
        }
    }
    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.didChange( question: self ) }
            }
        }
    }
    var description: String {
        "\(self.keyword)"
    }
    var dirty = false {
        didSet {
            if self.dirty {
                self.site?.dirty = true
            }
        }
    }

    // MARK: - Life

    init(site: Site, keyword: String, resultType: SpectreResultType? = nil, resultState: String? = nil) {
        self.site = site
        self.keyword = keyword
        self.resultType = resultType ?? .templatePhrase
        self.resultState = resultState
        LeakRegistry.shared.register( self )
    }

    // MARK: - Interface

    func copy(to site: Site) -> Question {
        Question( site: site, keyword: self.keyword, resultType: self.resultType, resultState: self.resultState )
    }

    // MARK: - QuestionObserver

    func didChange(question: Question) {
    }

    // MARK: - Operand

    func use() {
        self.site?.use()
    }

    public func result(for name: String? = nil, counter: SpectreCounter? = nil,
                       keyPurpose: SpectreKeyPurpose = .recovery, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil,
                       algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        self.site?.result( for: name, counter: counter,
                          keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                          resultType: resultType, resultParam: resultParam ?? self.resultState,
                          algorithm: algorithm, operand: operand ?? self )
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil,
                      keyPurpose: SpectreKeyPurpose = .recovery, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String,
                      algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        self.site?.state( for: name, counter: counter,
                         keyPurpose: keyPurpose, keyContext: keyContext ?? self.keyword,
                         resultType: resultType, resultParam: resultParam,
                         algorithm: algorithm, operand: operand ?? self )
    }
}

extension Question: Identifiable {
    public var id: String { self.keyword }
}

extension Question: Hashable {
    public static func == (lhs: Question, rhs: Question) -> Bool {
        lhs.keyword == rhs.keyword &&
            lhs.resultType == rhs.resultType &&
            lhs.resultState == rhs.resultState
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine( self.keyword )
        hasher.combine( self.resultType )
        hasher.combine( self.resultState )
    }
}

extension Question: Comparable {
    public static func < (lhs: Question, rhs: Question) -> Bool {
        lhs.keyword < rhs.keyword
    }
}

protocol QuestionObserver {
    func didChange(question: Question)
}
