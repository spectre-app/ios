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

@Observable class User: CustomStringConvertible, Persisting, CredentialSupplier, SpectreOperand,
    Observed, UserObserver, SiteObserver
{
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
                self.save()
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
            }
        }
    }
    public var authenticatedIdentifier: String? {
        get async throws {
            try await self.userKeyFactory?.authenticatedIdentifier( for: self.algorithm )
        }
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

                Task.detached { await AutoFill.shared.update( for: self ) }
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

            self.save()
        }
    }

    @ObservationIgnored
    private lazy var saveTask = DispatchTask( named: self.userName ) { [weak self] () -> URL? in
        guard let self = self, self.dirty, self.file != nil
        else { return nil }

        defer { self.dirty = false }

        do {
            let destination = try await Marshal.shared.save( user: self )
            if let origin = self.origin, origin != destination,
               FileManager.default.fileExists( atPath: origin.path ) {
                do { try FileManager.default.removeItem( at: origin ) }
                catch {
                    mperror( title: "Migration issue", message: "Obsolete origin document could not be deleted.",
                             details: origin.lastPathComponent, error: error )
                }
            }
            self.origin = destination
            return destination
        }
        catch {
            mperror( title: "Couldn't save user", details: self, error: error )
            throw error
        }
    }

    // MARK: - Life

    init(algorithm: SpectreAlgorithm? = nil, avatar: Avatar = .avatar_0, userName: String,
         identicon: SpectreIdenticon = SpectreIdenticonUnset, userKeyID: SpectreKeyID = .unset,
         defaultType: SpectreResultType? = nil, loginType: SpectreResultType? = nil, loginState: String? = nil,
         lastUsed: Date = Date(), origin: URL? = nil,
         file: UnsafeMutablePointer<SpectreMarshalledFile>? = spectre_marshal_file( nil, nil, nil ),
         initialize: (User) -> Void = { _ in }) {
        // TODO: why are these defaults in here and not in the method signature?
        // TODO: is self.file ever free'ed?
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
        LeakRegistry.shared.register( self )

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

    @discardableResult
    func login(using keyFactory: KeyFactory) async throws -> User {
        do {
            let authKey = try await keyFactory.newKey( for: self.algorithm )
            defer { authKey.deallocate() }

            guard spectre_id_valid( [ authKey.pointee.keyID ] )
            else { throw AppError.internal( cause: "Could not determine key ID for authentication key", details: self ) }

            if !spectre_id_valid( &self.userKeyID ) {
                self.userKeyID = authKey.pointee.keyID
            }
            else if self.userKeyID != authKey.pointee.keyID {
                throw AppError.state( title: "Incorrect user key", details: self )
            }

            if let keyFactory = keyFactory as? SecretKeyFactory {
                self.identicon = keyFactory.metadata.identicon
            }

            self.userKeyFactory = keyFactory
            return self
        }
        catch {
            self.logout()
            throw error
        }
    }

    func logout() {
        save()
        self.userKeyFactory = nil
    }

    func save(onlyIfDirty: Bool = true) {
        if !onlyIfDirty || (self.dirty && !self.initializing) {
            self.saveTask.request()
        }
    }

    // MARK: - Private

    private func tryKeyFactoryMigration() {
        guard InAppFeature.biometrics.isEnabled
        else { return }

        if self.biometricLock {
            // biometric lock is on; if key factory is secret, migrate it to keychain.
            if let secretKeyFactory = userKeyFactory as? SecretKeyFactory {
                Task.detached {
                    do { self.userKeyFactory = try await secretKeyFactory.toKeychain() }
                    catch { mperror(title: "Couldn't migrate to biometrics", error: error) }
                }
            }
        }
        else if let keychainKeyFactory = self.userKeyFactory as? KeychainKeyFactory {
            // biometric lock is off; if key factory is keychain, remove and purge it.
            self.userKeyFactory = nil
            Task.detached {
                do { try await keychainKeyFactory.purgeKeys() }
                catch { mperror( title: "Couldn't clear biometrics", error: error ) }
            }
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
            Task.detached { await AutoFill.shared.update( for: self ) }
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

    // MARK: - SpectreOperand

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
                return SpectreOperation( siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                                         param: resultParam, purpose: keyPurpose, context: keyContext,
                                         identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                                         task: Task.detached {
                                             throw AppError.internal( cause: "Unsupported key purpose", details: keyPurpose )
                                         } )
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
                return SpectreOperation( siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                                         param: resultParam, purpose: keyPurpose, context: keyContext,
                                         identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                                         task: Task.detached {
                                             throw AppError.internal( cause: "Unsupported key purpose", details: keyPurpose )
                                         } )
        }
    }

    private func spectre_result(for name: String, counter: SpectreCounter,
                                keyPurpose: SpectreKeyPurpose, keyContext: String?,
                                resultType: SpectreResultType, resultParam: String?,
                                algorithm: SpectreAlgorithm, operand: SpectreOperand)
            -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation( siteName: name, counter: counter, type: resultType,
                                 param: resultParam, purpose: keyPurpose, context: keyContext,
                                 identity: self.userKeyID, algorithm: algorithm, operand: operand,
                                 task: Task.detached {
                                     let userKey = try await keyFactory.newKey( for: algorithm )
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

        return SpectreOperation( siteName: name, counter: counter, type: resultType,
                                 param: resultParam, purpose: keyPurpose, context: keyContext,
                                 identity: self.userKeyID, algorithm: algorithm, operand: operand,
                                 task: Task.detached {
                                     let userKey = try await keyFactory.newKey( for: algorithm )
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

        public static func random() -> Avatar {
            allCases.randomElement() ?? .avatar_0
        }

        public mutating func previous() {
            self = Avatar.allCases[((Avatar.allCases.firstIndex(of: self) ?? -1) + Avatar.allCases.count - 1) % Avatar.allCases.count]
        }

        public mutating func next() {
            self = Avatar.allCases[((Avatar.allCases.firstIndex(of: self) ?? -1) + Avatar.allCases.count + 1) % Avatar.allCases.count]
        }

        public var description: String {
            "avatar-\(self.rawValue)"
        }

        public var image: UIImage? {
            UIImage( named: "\(self)" )
        }
    }
}

extension User: Identifiable {
    public var id: String { userName }
}

extension User: Hashable {
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.algorithm == rhs.algorithm &&
            lhs.avatar == rhs.avatar &&
            lhs.userName == rhs.userName &&
            lhs.identicon == rhs.identicon &&
            lhs.userKeyID == rhs.userKeyID &&
            lhs.defaultType == rhs.defaultType &&
            lhs.loginType == rhs.loginType &&
            lhs.loginState == rhs.loginState &&
            lhs.lastUsed == rhs.lastUsed &&
            lhs.exportDate == rhs.exportDate &&
            lhs.maskPasswords == rhs.maskPasswords &&
            lhs.biometricLock == rhs.biometricLock &&
            lhs.autofill == rhs.autofill &&
            lhs.autofillDecided == rhs.autofillDecided &&
            lhs.sharing == rhs.sharing &&
            lhs.attacker == rhs.attacker &&
            lhs.file == rhs.file &&
            lhs.origin == rhs.origin &&
            lhs.sites == rhs.sites
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(algorithm)
        hasher.combine(avatar)
        hasher.combine(userName)
        hasher.combine(identicon)
        hasher.combine(userKeyID)
        hasher.combine(defaultType)
        hasher.combine(loginType)
        hasher.combine(loginState)
        hasher.combine(lastUsed)
        hasher.combine(exportDate)
        hasher.combine(maskPasswords)
        hasher.combine(biometricLock)
        hasher.combine(autofill)
        hasher.combine(autofillDecided)
        hasher.combine(sharing)
        hasher.combine(attacker)
        hasher.combine(file)
        hasher.combine(origin)
        hasher.combine(sites)
    }
}

extension User: Comparable {
    public static func < (lhs: User, rhs: User) -> Bool {
        if lhs.lastUsed != rhs.lastUsed {
            return lhs.lastUsed > rhs.lastUsed
        }

        return lhs.userName < rhs.userName
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
