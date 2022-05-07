// =============================================================================
// Created by Maarten Billemont on 2018-03-04.
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

class User: Hashable, Comparable, CustomStringConvertible, Persisting, CredentialSupplier, SpectreOperand,
            Observable, UserObserver, SiteObserver {
    public let observers = Observers<UserObserver>()

    public var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.algorithm ) }
            }
        }
    }
    public var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.avatar ) }
            }
        }
    }
    public let userName: String
    public var identicon: SpectreIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.identicon ) }
            }
        }
    }
    public var userKeyID: SpectreKeyID {
        didSet {
            if !spectre_id_equals( [ oldValue ], &self.userKeyID ) {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.userKeyID ) }
            }
        }
    }
    public private(set) var userKeyFactory: KeyFactory? {
        willSet {
            if self.userKeyFactory != nil, newValue == nil {
                self.save( onlyIfDirty: true )
            }
        }
        didSet {
            if self.userKeyFactory !== oldValue {
                if self.userKeyFactory != nil, oldValue == nil {
                    trc( "Logging in: %@", self )
                    self.observers.notify { $0.didLogin( user: self ) }
                }
                if self.userKeyFactory == nil, oldValue != nil {
                    trc( "Logging out: %@", self )
                    self.observers.notify { $0.didLogout( user: self ) }
                }

                self.tryKeyFactoryMigration()
                oldValue?.invalidate()
            }
        }
    }
    public var authenticatedIdentifier: Promise<String?> {
        self.userKeyFactory?.authenticatedIdentifier( for: self.algorithm ) ?? Promise( .success( nil ) )
    }
    public var defaultType: SpectreResultType {
        didSet {
            if oldValue != self.defaultType {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.defaultType ) }
            }
        }
    }
    public var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.loginType ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.loginState ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.lastUsed ) }
            }
        }
    }
    public var exportDate: Date? {
        self.file?.spectre_get( path: "export", "date" )
    }

    public var maskPasswords = false {
        didSet {
            if oldValue != self.maskPasswords, !self.initializing,
               self.file?.spectre_set( self.maskPasswords, path: "user", "_ext_spectre", "maskPasswords" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.maskPasswords ) }
            }
        }
    }
    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock, !self.initializing,
               self.file?.spectre_set( self.biometricLock, path: "user", "_ext_spectre", "biometricLock" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.biometricLock ) }
            }

            self.tryKeyFactoryMigration()
        }
    }
    public var autofill = false {
        didSet {
            if oldValue != self.autofill, !self.initializing,
               self.file?.spectre_set( self.autofill, path: "user", "_ext_spectre", "autofill" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.autofill ) }

                AutoFill.shared.update( for: self )
            }
        }
    }
    public var autofillDecided: Bool {
        self.file?.spectre_find( path: "user", "_ext_spectre", "autofill" ) != nil
    }
    public var sharing = false {
        didSet {
            if oldValue != self.sharing, !self.initializing,
               self.file?.spectre_set( self.sharing, path: "user", "_ext_spectre", "sharing" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.autofillDecided ) }
            }
        }
    }
    public var attacker: Attacker? {
        didSet {
            if oldValue != self.attacker, !self.initializing,
               self.file?.spectre_set( self.attacker?.description, path: "user", "_ext_spectre", "attacker" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange( user: self, at: \User.attacker ) }
            }
        }
    }

    public var file:   UnsafeMutablePointer<SpectreMarshalledFile>?
    public var origin: URL?

    public var sites = [ Site ]() {
        didSet {
            if oldValue != self.sites {
                self.dirty = true
                Set( oldValue ).subtracting( self.sites ).forEach { site in
                    site.observers.unregister( observer: self )
                }
                self.sites.forEach { site in
                    site.observers.register( observer: self )
                }
                self.observers.notify { $0.didChange( user: self, at: \User.sites ) }
            }
        }
    }
    public var  description: String {
        if let identicon = self.identicon.encoded() {
            return "\(self.userName): \(identicon)"
        }
        else {
            return "\(self.userName): \(self.userKeyID)"
        }
    }
    private var initializing = true {
        didSet {
            self.dirty = false
        }
    }
    internal var dirty = false {
        didSet {
            if !self.dirty {
                self.sites.forEach { $0.dirty = false }
            }

            self.save( onlyIfDirty: true )
        }
    }

    private lazy var saveTask = DispatchTask( named: self.userName, queue: .global( qos: .utility ) ) { [weak self] () -> URL? in
        guard let self = self, self.dirty, self.file != nil
        else { return nil }

        return try Marshal.shared.save( user: self ).then {
                              defer { self.dirty = false }

                              do {
                                  let destination = try $0.get()
                                  if let origin = self.origin, origin != destination,
                                     FileManager.default.fileExists( atPath: origin.path ) {
                                      do { try FileManager.default.removeItem( at: origin ) }
                                      catch {
                                          mperror( title: "Migration issue", message: "Obsolete origin document could not be deleted.",
                                                   details: origin.lastPathComponent, error: error )
                                      }
                                  }
                                  self.origin = destination
                              }
                              catch {
                                  mperror( title: "Couldn't save user", details: self, error: error )
                              }
                          }
                          .await()
    }

    // MARK: - Life

    init(algorithm: SpectreAlgorithm? = nil, avatar: Avatar = .avatar_0, userName: String,
         identicon: SpectreIdenticon = SpectreIdenticonUnset, userKeyID: SpectreKeyID = SpectreKeyIDUnset,
         defaultType: SpectreResultType? = nil, loginType: SpectreResultType? = nil, loginState: String? = nil,
         lastUsed: Date = Date(), origin: URL? = nil,
         file: UnsafeMutablePointer<SpectreMarshalledFile>? = spectre_marshal_file( nil, nil, nil ),
         initialize: (User) -> Void = { _ in }) {
        self.algorithm = algorithm ?? .current
        self.avatar = avatar
        self.userName = userName
        self.identicon = identicon
        self.userKeyID = userKeyID
        self.defaultType = defaultType ?? .defaultResult
        self.loginType = loginType ?? .defaultLogin
        self.loginState = loginState
        self.lastUsed = lastUsed
        self.origin = origin
        self.file = file

        defer {
            self.maskPasswords = self.file?.spectre_get( path: "user", "_ext_spectre", "maskPasswords" ) ?? false
            self.biometricLock = self.file?.spectre_get( path: "user", "_ext_spectre", "biometricLock" ) ?? false
            self.autofill = self.file?.spectre_get( path: "user", "_ext_spectre", "autofill" ) ?? false
            self.sharing = self.file?.spectre_get( path: "user", "_ext_spectre", "sharing" ) ?? false
            self.attacker = self.file?.spectre_get( path: "user", "_ext_spectre", "attacker" ).flatMap { Attacker.named( $0 ) }

            initialize( self )
            self.initializing = false

            self.observers.register( observer: self )
        }
    }

    func login(using keyFactory: KeyFactory) -> Promise<User> {
        keyFactory.newKey( for: self.algorithm )
                  .promise( on: .api ) { authKey in
                      defer { authKey.deallocate() }

                      guard spectre_id_valid( [ authKey.pointee.keyID ] )
                      else { throw AppError.internal( cause: "Could not determine key ID for authentication key", details: self ) }

                      if !spectre_id_valid( &self.userKeyID ) {
                          self.userKeyID = authKey.pointee.keyID
                      }
                      else if !spectre_id_equals( &self.userKeyID, [ authKey.pointee.keyID ] ) {
                          throw AppError.state( title: "Incorrect user key", details: self )
                      }

                      return self
                  }
                  .then { (result: Result<User, Error>) -> Void in
                      switch result {
                          case .success:
                              if let keyFactory = keyFactory as? SecretKeyFactory {
                                  self.identicon = keyFactory.metadata.identicon
                              }

                              self.userKeyFactory = keyFactory

                          case .failure:
                              self.logout()
                      }
                  }
    }

    func logout() {
        self.userKeyFactory = nil
    }

    @discardableResult
    func save(onlyIfDirty: Bool, await: Bool = false) -> Promise<URL?> {
        if !onlyIfDirty || (self.dirty && !self.initializing) {
            return self.saveTask.request( now: true, await: `await` )
        }
        else {
            return Promise( .success( nil ) )
        }
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.userName )
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.userName == rhs.userName
    }

    // MARK: Comparable

    static func < (lhs: User, rhs: User) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.userName > rhs.userName
    }

    // MARK: - Private

    private func tryKeyFactoryMigration() {
        guard InAppFeature.biometrics.isEnabled
        else { return }

        if self.biometricLock {
            // biometric lock is on; if key factory is secret, migrate it to keychain.
            (self.userKeyFactory as? SecretKeyFactory)?.toKeychain().then {
                do { self.userKeyFactory = try $0.get() }
                catch { mperror( title: "Couldn't migrate to biometrics", error: error ) }
            }
        }
        else if let keychainKeyFactory = self.userKeyFactory as? KeychainKeyFactory {
            // biometric lock is off; if key factory is keychain, remove and purge it.
            self.userKeyFactory = nil
            keychainKeyFactory.purgeKeys()
        }
    }

    // MARK: - UserObserver

    func didLogin(user: User) {
        Tracker.shared.login( user: self )
    }

    func didLogout(user: User) {
        Tracker.shared.logout()
    }

    func didChange(user: User, at change: PartialKeyPath<User>) {
        if change == \User.sites {
            AutoFill.shared.update( for: self )
        }
    }

    // MARK: - SiteObserver

    func didChange(site: Site, at change: PartialKeyPath<Site>) {
    }

    // MARK: - CredentialSupplier

    var credentialOwner: String {
        self.userName
    }
    var credentials: [AutoFill.Credential]? {
        self.autofill ? self.sites.map { site in
            .init( supplier: self, siteName: site.siteName, url: site.url )
        } : nil
    }

    // MARK: - Operand

    public func use() {
        self.lastUsed = Date()
    }

    public func result(for name: String? = nil, counter: SpectreCounter? = nil,
                       keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil,
                       algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial,
                                            keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? self.defaultType, resultParam: resultParam,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial,
                                            keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial,
                                            keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return SpectreOperation( siteName: name ?? self.userName, counter: counter ?? .initial, purpose: keyPurpose,
                                         type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                         Promise( .failure( AppError.internal( cause: "Unsupported key purpose", details: keyPurpose ) ) ) )
        }
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil,
                      keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String,
                      algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
            -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial,
                                           keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? self.defaultType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial,
                                           keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial,
                                           keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return SpectreOperation( siteName: name ?? self.userName, counter: counter ?? .initial, purpose: keyPurpose,
                                         type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                         Promise( .failure( AppError.internal( cause: "Unsupported key purpose", details: keyPurpose ) ) ) )
        }
    }

    private func spectre_result(for name: String, counter: SpectreCounter,
                                keyPurpose: SpectreKeyPurpose, keyContext: String?,
                                resultType: SpectreResultType, resultParam: String?,
                                algorithm: SpectreAlgorithm, operand: SpectreOperand)
            -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation( siteName: name, counter: counter, purpose: keyPurpose,
                                 type: resultType, algorithm: algorithm, operand: operand,
                                 token: keyFactory.newKey( for: algorithm ).promise( on: .api ) { userKey in
                                     defer { userKey.deallocate() }

                                     guard let result = String.valid(
                                             spectre_site_result( userKey, name, resultType, resultParam,
                                                                  counter, keyPurpose, keyContext ), consume: true )
                                     else { throw AppError.internal( cause: "Cannot calculate result", details: self ) }

                                     return result
                                 } )
    }

    private func spectre_state(for name: String, counter: SpectreCounter,
                               keyPurpose: SpectreKeyPurpose, keyContext: String?,
                               resultType: SpectreResultType, resultParam: String?,
                               algorithm: SpectreAlgorithm, operand: SpectreOperand)
            -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation( siteName: name, counter: counter, purpose: keyPurpose,
                                 type: resultType, algorithm: algorithm, operand: operand,
                                 token: keyFactory.newKey( for: algorithm ).promise( on: .api ) { userKey in
                                     defer { userKey.deallocate() }

                                     guard let result = String.valid(
                                             spectre_site_state( userKey, name, resultType, resultParam,
                                                                 counter, keyPurpose, keyContext ), consume: true )
                                     else { throw AppError.internal( cause: "Cannot calculate result", details: self ) }

                                     return result
                                 } )
    }

    // MARK: - Types

    enum Avatar: UInt32, CaseIterable, CustomStringConvertible {
        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18

        public var description: String {
            "avatar-\(self.rawValue)"
        }

        public var image: UIImage? {
            UIImage( named: "\(self)" )
        }

        public mutating func next() {
            self = Avatar.allCases[((Avatar.allCases.firstIndex( of: self ) ?? -1) + 1) % Avatar.allCases.count]
        }
    }
}

protocol UserObserver {
    func didLogin(user: User)

    func didLogout(user: User)

    func didChange(user: User, at change: PartialKeyPath<User>)
}

extension UserObserver {
    func didLogin(user: User) {
    }

    func didLogout(user: User) {
    }

    func didChange(user: User, at change: PartialKeyPath<User>) {
    }
}
