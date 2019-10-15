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
        DispatchQueue.mpw.promise { () -> String? in
            let masterKey = self.site.user.masterKeyFactory?.newMasterKey( algorithm: algorithm ?? self.site.algorithm )
            defer { masterKey?.deallocate() }

            return String( safeUTF8: mpw_site_result( masterKey, self.keyword, counter ?? .initial, keyPurpose, keyContext ?? self.keyword,
                                                      resultType ?? self.resultType, resultParam ?? self.resultState, algorithm ?? self.site.algorithm ),
                           deallocate: true )
        }
    }

    @discardableResult
    public func mpw_result_save(counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                                resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil)
                    -> Promise<Bool> {
        DispatchQueue.mpw.promise { () -> Bool in
            let masterKey = self.site.user.masterKeyFactory?.newMasterKey( algorithm: algorithm ?? self.site.algorithm )
            defer { masterKey?.deallocate() }

            if let resultState = String( safeUTF8: mpw_site_state( masterKey, self.keyword, counter ?? .initial, keyPurpose, keyContext ?? self.keyword,
                                                                   resultType ?? self.resultType, resultParam, algorithm ?? self.site.algorithm ),
                                         deallocate: true ) {
                self.resultState = resultState
                return true
            }

            return false
        }
    }
}

protocol MPQuestionObserver {
    func questionDidChange(_ question: MPQuestion)
}
