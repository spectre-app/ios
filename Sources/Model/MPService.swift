//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import SwiftLinkPreview

class MPService: MPOperand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, MPServiceObserver, MPQuestionObserver {
    public let observers = Observers<MPServiceObserver>()

    public let user: MPUser
    public var serviceName: String {
        didSet {
            if oldValue != self.serviceName {
                self.dirty = true
                self.preview = MPServicePreview.for( self.serviceName )
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var algorithm: MPAlgorithmVersion {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var counter: MPCounterValue = .default {
        didSet {
            if oldValue != self.counter {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var resultType: MPResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var loginType: MPResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }

    public var resultState: String? {
        didSet {
            if oldValue != self.resultState {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }

    public var url: String? {
        didSet {
            if oldValue != self.url {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var uses: UInt32 = 0 {
        didSet {
            if oldValue != self.uses {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public lazy var preview: MPServicePreview = MPServicePreview.for( self.serviceName ) {
        didSet {
            if oldValue != self.preview {
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var questions = [ MPQuestion ]() {
        didSet {
            if oldValue != self.questions {
                self.dirty = true
                self.questions.forEach { question in question.observers.register( observer: self ) }
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }
    public var isNew: Bool {
        !self.user.services.contains( self )
    }
    var description: String {
        self.serviceName
    }
    var dirty = false {
        didSet {
            if self.dirty {
                if !self.initializing && self.dirty {
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

    init(user: MPUser, serviceName: String, algorithm: MPAlgorithmVersion? = nil, counter: MPCounterValue? = nil,
         resultType: MPResultType? = nil, resultState: String? = nil,
         loginType: MPResultType? = nil, loginState: String? = nil,
         url: String? = nil, uses: UInt32 = 0, lastUsed: Date? = nil, questions: [MPQuestion] = [],
         initialize: (MPService) -> Void = { _ in }) {
        self.user = user
        self.serviceName = serviceName
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
        hasher.combine( self.serviceName )
    }

    static func ==(lhs: MPService, rhs: MPService) -> Bool {
        lhs.serviceName == rhs.serviceName
    }

    // MARK: Comparable

    public static func <(lhs: MPService, rhs: MPService) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.serviceName > rhs.serviceName
    }

    // MARK: --- Interface ---

    public func use() {
        self.lastUsed = Date()
        self.uses += 1
        self.user.use()
    }

    public func refresh() {
        self.preview.update().success { updated in
            if updated {
                self.observers.notify { $0.serviceDidChange( self ) }
            }
        }
    }

    public func copy(to user: MPUser) -> MPService {
        // TODO: do we need to re-encode state?
        let service = MPService( user: user, serviceName: self.serviceName, algorithm: self.algorithm, counter: self.counter,
                                 resultType: self.resultType, resultState: self.resultState,
                                 loginType: self.loginType, loginState: self.loginState,
                                 url: self.url, uses: self.uses, lastUsed: self.lastUsed )
        service.questions = self.questions.map { $0.copy( to: service ) }
        return service
    }

    // MARK: --- MPServiceObserver ---

    func serviceDidChange(_ service: MPService) {
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
                return self.user.result( for: name ?? self.serviceName, counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.resultType, resultParam: resultParam ?? self.resultState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user.result( for: name ?? self.serviceName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user.result( for: name ?? self.serviceName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                         resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                         algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return MPOperation( serviceName: name ?? self.serviceName, counter: counter ?? .initial, purpose: keyPurpose,
                                    type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                    Promise( .failure( MPError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }

    public func state(for name: String? = nil, counter: MPCounterValue? = nil, keyPurpose: MPKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: MPResultType? = nil, resultParam: String, algorithm: MPAlgorithmVersion? = nil, operand: MPOperand? = nil)
                    -> MPOperation {
        switch keyPurpose {
            case .authentication:
                return self.user.state( for: name ?? self.serviceName, counter: counter ?? self.counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.resultType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.user.state( for: name ?? self.serviceName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? self.loginType, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.user.state( for: name ?? self.serviceName, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                                        resultType: resultType ?? MPResultType.templatePhrase, resultParam: resultParam,
                                        algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return MPOperation( serviceName: name ?? self.serviceName, counter: counter ?? .initial, purpose: keyPurpose,
                                    type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                    Promise( .failure( MPError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }
}

protocol MPServiceObserver {
    func serviceDidChange(_ service: MPService)
}
