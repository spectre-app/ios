//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class User: Operand, Hashable, Comparable, CustomStringConvertible, Observable, Persisting, UserObserver, SiteObserver, CredentialSupplier {
    public let observers = Observers<UserObserver>()

    public var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public let userName: String
    public var identicon: SpectreIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var userKeyID: SpectreKeyID {
        didSet {
            if !spectre_id_equals( [ oldValue ], &self.userKeyID ) {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public private(set) var userKeyFactory: KeyFactory? {
        willSet {
            if self.userKeyFactory != nil, newValue == nil {
                let _ = try? self.saveTask.request( immediate: true ).await()
            }
        }
        didSet {
            if self.userKeyFactory !== oldValue {
                if self.userKeyFactory != nil, oldValue == nil {
                    trc( "Logging in: %@", self )
                    self.observers.notify { $0.userDidLogin( self ) }
                }
                if self.userKeyFactory == nil, oldValue != nil {
                    trc( "Logging out: %@", self )
                    self.observers.notify { $0.userDidLogout( self ) }
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
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
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
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }
    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock, !self.initializing,
               self.file?.spectre_set( self.biometricLock, path: "user", "_ext_spectre", "biometricLock" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }

            self.tryKeyFactoryMigration()
        }
    }
    public var autofill = false {
        didSet {
            if oldValue != self.autofill, !self.initializing,
               self.file?.spectre_set( self.autofill, path: "user", "_ext_spectre", "autofill" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }

                AutoFill.shared.update( for: self )
            }
        }
    }
    public var autofillDecided: Bool {
        self.file?.spectre_find( path: "user", "_ext_spectre", "autofill" ) != nil
    }
    public var attacker: Attacker? {
        didSet {
            if oldValue != self.attacker, !self.initializing,
               self.file?.spectre_set( self.attacker?.description, path: "user", "_ext_spectre", "attacker" ) ?? true {
                self.dirty = true
                self.observers.notify { $0.userDidChange( self ) }
            }
        }
    }

    public var file:   UnsafeMutablePointer<SpectreMarshalledFile>?
    public var origin: URL?

    public var sites = [ Site ]() {
        didSet {
            if oldValue != self.sites {
                self.dirty = true
                Set( oldValue ).subtracting( self.sites ).forEach { site in site.observers.unregister( observer: self ) }
                self.sites.forEach { site in site.observers.register( observer: self ) }
                self.observers.notify { $0.userDidUpdateSites( self ) }
                self.observers.notify { $0.userDidChange( self ) }
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
            if self.dirty {
                if !self.initializing {
                    self.saveTask.request()
                }
            }
            else {
                self.sites.forEach { $0.dirty = false }
            }
        }
    }

    private lazy var saveTask = DispatchTask( named: self.userName, queue: .global( qos: .utility ), deadline: .now() + .seconds( 1 ) ) {
        () -> URL? in
        guard self.dirty, self.file != nil
        else { return nil }

        return try Marshal.shared.save( user: self ).then( {
            defer { self.dirty = false }

            do {
                let destination = try $0.get()
                if let origin = self.origin, origin != destination,
                   FileManager.default.fileExists( atPath: origin.path ) {
                    do { try FileManager.default.removeItem( at: origin ) }
                    catch {
                        mperror( title: "Migration issue", message: "Cannot delete obsolete origin document",
                                 details: origin.lastPathComponent, error: error )
                    }
                }
                self.origin = destination
            }
            catch {
                mperror( title: "Couldn't save changes.", details: self, error: error )
            }
        } ).await()
    }

    // MARK: --- Life ---

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
            self.attacker = self.file?.spectre_get( path: "user", "_ext_spectre", "attacker" ).flatMap { Attacker.named( $0 ) }

            initialize( self )
            self.initializing = false

            self.observers.register( observer: self )
        }
    }

    func login(using keyFactory: KeyFactory) -> Promise<User> {
        keyFactory.newKey( for: self.algorithm ).promise( on: .api ) { authKey in
            defer { authKey.deallocate() }

            guard spectre_id_valid( [ authKey.pointee.keyID ] )
            else { throw AppError.internal( cause: "Could not determine key ID for authentication key.", details: self ) }

            if !spectre_id_valid( &self.userKeyID ) {
                self.userKeyID = authKey.pointee.keyID
            }
            else if !spectre_id_equals( &self.userKeyID, [ authKey.pointee.keyID ] ) {
                throw AppError.state( title: "Incorrect User Key", details: self )
            }

            return self
        }.then { (result: Result<User, Error>) -> Void in
            switch result {
                case .success:
                    if let keyFactory = keyFactory as? SecretKeyFactory {
                        self.identicon = keyFactory.identicon
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

    func save() -> Promise<URL?> {
        self.saveTask.request()
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine( self.userName )
    }

    static func ==(lhs: User, rhs: User) -> Bool {
        lhs.userName == rhs.userName
    }

    // MARK: Comparable

    static func <(lhs: User, rhs: User) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.userName > rhs.userName
    }

    // MARK: --- Private ---

    private func tryKeyFactoryMigration() {
        guard InAppFeature.premium.isEnabled
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

    // MARK: --- UserObserver ---

    func userDidLogin(_ user: User) {
        Tracker.shared.login( user: self )
    }

    func userDidLogout(_ user: User) {
        Tracker.shared.logout()
    }

    func userDidChange(_ user: User) {
    }

    func userDidUpdateSites(_ user: User) {
        AutoFill.shared.update( for: self )
    }

    // MARK: --- SiteObserver ---

    func siteDidChange(_ site: Site) {
    }

    // MARK: --- CredentialSupplier ---

    var credentialOwner: String {
        self.userName
    }
    var credentials: [AutoFill.Credential]? {
        self.autofill ? self.sites.map { AutoFill.Credential( supplier: self, name: $0.siteName ) }: nil
    }

    // MARK: --- Operand ---

    public func use() {
        self.lastUsed = Date()
    }

    public func result(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                       resultType: SpectreResultType? = nil, resultParam: String? = nil, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
        switch keyPurpose {
            case .authentication:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? self.defaultType, resultParam: resultParam,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam ?? self.loginState,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.spectre_result( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                            resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                            algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return Operation( siteName: name ?? self.userName, counter: counter ?? .initial, purpose: keyPurpose,
                                  type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                  Promise( .failure( AppError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil, keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String, algorithm: SpectreAlgorithm? = nil, operand: Operand? = nil)
                    -> Operation {
        switch keyPurpose {
            case .authentication:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? self.defaultType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .identification:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            case .recovery:
                return self.spectre_state( for: name ?? self.userName, counter: counter ?? .initial, keyPurpose: keyPurpose, keyContext: keyContext,
                                           resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                                           algorithm: algorithm ?? self.algorithm, operand: operand ?? self )

            @unknown default:
                return Operation( siteName: name ?? self.userName, counter: counter ?? .initial, purpose: keyPurpose,
                                  type: resultType ?? .none, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, token:
                                  Promise( .failure( AppError.internal( cause: "Unsupported key purpose.", details: keyPurpose ) ) ) )
        }
    }

    private func spectre_result(for name: String, counter: SpectreCounter, keyPurpose: SpectreKeyPurpose, keyContext: String?,
                                resultType: SpectreResultType, resultParam: String?, algorithm: SpectreAlgorithm, operand: Operand)
                    -> Operation {
        Operation( siteName: name, counter: counter, purpose: keyPurpose, type: resultType, algorithm: algorithm, operand: operand, token:
        self.userKeyFactory?.newKey( for: algorithm ).promise( on: .api ) { userKey in
            defer { userKey.deallocate() }

            guard let result = String.valid(
                    spectre_site_result( userKey, name, resultType, resultParam, counter, keyPurpose, keyContext ), consume: true )
            else { throw AppError.internal( cause: "Cannot calculate result.", details: self ) }

            return result
        } ?? Promise( .failure( AppError.state( title: "User is not authenticated." ) ) ) )
    }

    private func spectre_state(for name: String, counter: SpectreCounter, keyPurpose: SpectreKeyPurpose, keyContext: String?,
                               resultType: SpectreResultType, resultParam: String?, algorithm: SpectreAlgorithm, operand: Operand)
                    -> Operation {
        Operation( siteName: name, counter: counter, purpose: keyPurpose, type: resultType, algorithm: algorithm, operand: operand, token:
        self.userKeyFactory?.newKey( for: algorithm ).promise( on: .api ) { userKey in
            defer { userKey.deallocate() }

            guard let result = String.valid(
                    spectre_site_state( userKey, name, resultType, resultParam, counter, keyPurpose, keyContext ), consume: true )
            else { throw AppError.internal( cause: "Cannot calculate result.", details: self ) }

            return result
        } ?? Promise( .failure( AppError.state( title: "User is not authenticated." ) ) ) )
    }

    // MARK: --- Types ---

    enum Avatar: UInt32, CaseIterable, CustomStringConvertible {
        static let userAvatars: [Avatar] = [
            .avatar_0, .avatar_1, .avatar_2, .avatar_3, .avatar_4, .avatar_5, .avatar_6, .avatar_7, .avatar_8, .avatar_9,
            .avatar_10, .avatar_11, .avatar_12, .avatar_13, .avatar_14, .avatar_15, .avatar_16, .avatar_17, .avatar_18 ]

        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18,
             avatar_add

        public var description: String {
            if case .avatar_add = self {
                return "avatar-add"
            }

            return "avatar-\(self.rawValue)"
        }

        public var image: UIImage? {
            UIImage( named: "\(self)" )
        }

        public mutating func next() {
            self = Avatar.userAvatars[((Avatar.userAvatars.firstIndex( of: self ) ?? -1) + 1) % Avatar.userAvatars.count]
        }
    }
}

protocol UserObserver {
    func userDidLogin(_ user: User)

    func userDidLogout(_ user: User)

    func userDidChange(_ user: User)

    func userDidUpdateSites(_ user: User)
}

extension UserObserver {
    func userDidLogin(_ user: User) {
    }

    func userDidLogout(_ user: User) {
    }

    func userDidChange(_ user: User) {
    }

    func userDidUpdateSites(_ user: User) {
    }
}
