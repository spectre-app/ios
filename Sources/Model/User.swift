//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

@Observable
class User: CustomStringConvertible, CredentialSupplier, SpectreOperand, Observed, UserObserver, SiteObserver, MarshalObserver {
    public let observers = Observers<UserObserver>()

    public var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.algorithm) }
            }
        }
    }

    public var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.avatar) }
            }
        }
    }

    public let userName: String
    public var identicon: SpectreIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.identicon) }
            }
        }
    }

    public var userKeyID: SpectreKeyID {
        didSet {
            if !spectre_id_equals([oldValue], &self.userKeyID) {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.userKeyID) }
            }
        }
    }

    public private(set) var userKeyFactory: KeyFactory? {
        didSet {
            if self.userKeyFactory !== oldValue {
                if self.userKeyFactory != nil, oldValue == nil {
                    trc("Logging in: \(self)")
                    self.observers.notify { $0.didLogin(user: self) }
                }
                if self.userKeyFactory == nil, oldValue != nil {
                    trc("Logging out: \(self)")
                    self.observers.notify { $0.didLogout(user: self) }
                }

                self.updateBiometricKeyFactory()
            }
        }
    }

    public var authenticatedIdentifier: String? {
        get throws {
            try self.userKeyFactory?.authenticatedIdentifier(for: self.algorithm)
        }
    }

    public var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.resultType) }
            }
        }
    }

    public var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.loginType) }
            }
        }
    }

    public var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.loginState) }
            }
        }
    }

    public var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.lastUsed) }
            }
        }
    }

    public var exportDate: Date? {
        self.file?.spectre_get(path: "export", "date")
    }

    public var maskPasswords = false {
        didSet {
            if oldValue != self.maskPasswords, !self.initializing,
               self.file?.spectre_set(self.maskPasswords, path: "user", "_ext_spectre", "maskPasswords") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.maskPasswords) }
            }
        }
    }

    public var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock, !self.initializing,
               self.file?.spectre_set(self.biometricLock, path: "user", "_ext_spectre", "biometricLock") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.biometricLock) }
            }

            self.updateBiometricKeyFactory()
        }
    }

    public var autofill = false {
        didSet {
            if oldValue != self.autofill, !self.initializing,
               self.file?.spectre_set(self.autofill, path: "user", "_ext_spectre", "autofill") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.autofill) }

                Task.detached { await AutoFill.shared.update(for: self) }
            }
        }
    }

    public var autofillDecided: Bool {
        (self.file?.spectre_get(path: "user", "_ext_spectre", "autofill") as Bool?) != nil
    }

    public var sharing = false {
        didSet {
            if oldValue != self.sharing, !self.initializing,
               self.file?.spectre_set(self.sharing, path: "user", "_ext_spectre", "sharing") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.autofillDecided) }
            }
        }
    }

    public var attacker: Attacker? {
        didSet {
            if oldValue != self.attacker, !self.initializing,
               self.file?.spectre_set(self.attacker?.description, path: "user", "_ext_spectre", "attacker") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.attacker) }
            }
        }
    }

    public var file:   UnsafeMutablePointer<SpectreMarshalledFile>?
    public var origin: URL?

    public var sites = [Site]() {
        didSet {
            if oldValue != self.sites {
                self.dirty = true
                for site in Set(oldValue).subtracting(self.sites) {
                    site.observers.unregister(observer: self)
                }
                for site in self.sites {
                    site.observers.register(observer: self)
                }
                self.observers.notify { $0.didChange(user: self, at: \User.sites) }
            }
        }
    }

    public var  description: String {
        if let identicon = self.identicon.encoded() {
            "\(self.userName): \(identicon)"
        }
        else {
            "\(self.userName): \(self.userKeyID)"
        }
    }

    private var initializing = true {
        didSet {
            self.dirty = false
        }
    }

    var dirty = false {
        didSet {
            guard !self.initializing
            else { return }

            if self.dirty {
                assert(self.userKeyFactory != nil)

                if !oldValue {
                    OperationQueue.main.addOperation {
                        Task { try await self.save() }
                    }
                }
            }
            else {
                self.sites.forEach { $0.dirty = false }
            }
        }
    }

    // MARK: - Life

    init(algorithm: SpectreAlgorithm? = nil, avatar: Avatar = .avatar_0, userName: String,
         identicon: SpectreIdenticon = SpectreIdenticonUnset, userKeyID: SpectreKeyID = .unset,
         resultType: SpectreResultType? = nil, loginType: SpectreResultType? = nil, loginState: String? = nil,
         lastUsed: Date = Date(), origin: URL? = nil,
         file: UnsafeMutablePointer<SpectreMarshalledFile>? = spectre_marshal_file(nil, nil, nil),
         initialize: (User) -> Void = { _ in }) {
        // TODO: why are these defaults in here and not in the method signature?
        // TODO: is self.file ever free'ed?
        self.algorithm = algorithm ?? .current
        self.avatar = avatar
        self.userName = userName
        self.identicon = identicon
        self.userKeyID = userKeyID
        self.resultType = resultType ?? .defaultResult
        self.loginType = loginType ?? .defaultLogin
        self.loginState = loginState
        self.lastUsed = lastUsed
        self.origin = origin
        self.file = file
        LeakRegistry.shared.register(self)

        defer {
            self.maskPasswords = self.file?.spectre_get(path: "user", "_ext_spectre", "maskPasswords") ?? false
            self.biometricLock = self.file?.spectre_get(path: "user", "_ext_spectre", "biometricLock") ?? false
            self.autofill = self.file?.spectre_get(path: "user", "_ext_spectre", "autofill") ?? false
            self.sharing = self.file?.spectre_get(path: "user", "_ext_spectre", "sharing") ?? false
            self.attacker = self.file?.spectre_get(path: "user", "_ext_spectre", "attacker").flatMap { Attacker.named($0) }

            initialize(self)
            self.initializing = false

            self.observers.register(observer: self)
            Marshal.shared.observers.register(observer: self)
        }
    }

    @discardableResult
    func login(using keyFactory: KeyFactory) async throws -> User {
        do {
            let authKey = try keyFactory.newKey(for: self.algorithm)
            defer { authKey.deallocate() }

            guard spectre_id_valid([authKey.pointee.keyID])
            else { throw AppError.internal(reason: "Could not determine key ID for authentication key", details: self) }

            if self.userKeyID != authKey.pointee.keyID {
                throw AppError.issue("Incorrect user key", reason: self)
            }
            self.userKeyFactory = keyFactory

            if !spectre_id_valid(&self.userKeyID) {
                self.userKeyID = authKey.pointee.keyID
            }
            if let keyFactory = keyFactory as? SecretKeyFactory {
                self.identicon = keyFactory.metadata.identicon
            }

            return self
        }
        catch {
            self.logout()
            throw error
        }
    }

    func logout() {
        Task.detached {
            try await self.save()
            self.userKeyFactory = nil
        }
    }

    func save(onlyIfDirty: Bool = true) async throws {
        assert(self.userKeyFactory != nil)

        if onlyIfDirty && !self.dirty {
            return
        }

        do {
            let destination = try await Marshal.shared.save(user: self)
            if let origin = self.origin, origin != destination,
               FileManager.default.fileExists(atPath: origin.path) {
                // swiftlint:disable:next statement_position - FIXME: https://github.com/realm/SwiftLint/issues/4632
                do { try FileManager.default.removeItem(at: origin) }
                catch {
                    err("Obsolete origin document could not be deleted.", data: origin, error)
                }
            }
            self.origin = destination
            self.dirty = false
        }
        catch {
            err("Couldn't save user", data: self, error)
            throw error
        }
    }

    // MARK: - Private

    private func updateBiometricKeyFactory() {
        Task.detached { [self] in
            if self.biometricLock, AppFeature.biometrics.isEnabled {
                // biometric lock is on; if key factory is secret, migrate it to keychain.
                if let secretKeyFactory = self.userKeyFactory as? SecretKeyFactory {
                    try? await self.save()
                    // swiftlint:disable:next statement_position - FIXME: https://github.com/realm/SwiftLint/issues/4632
                    do { self.userKeyFactory = try await secretKeyFactory.toKeychain() }
                    catch { err("Couldn't migrate to biometrics", data: error) }
                }
            }
            else if let keychainKeyFactory = self.userKeyFactory as? KeychainKeyFactory {
                // biometric lock is off; if key factory is keychain, remove and purge it.
                try? await self.save()
                self.userKeyFactory = nil

                // swiftlint:disable:next statement_position - FIXME: https://github.com/realm/SwiftLint/issues/4632
                do { try await keychainKeyFactory.purgeKeys() }
                catch { err("Couldn't clear biometrics", data: error) }
            }
        }
    }

    // MARK: - UserObserver

    func didLogin(user: User) {
        Tracker.shared.login(user: self)
    }

    func didLogout(user: User) {
        Tracker.shared.logout()
    }

    func didChange(user: User, at change: PartialKeyPath<User>) {
        if change == \User.sites {
            Task.detached { await AutoFill.shared.update(for: self) }
        }
    }

    // MARK: - SiteObserver

    func didChange(site: Site, at change: PartialKeyPath<Site>) {}

    // MARK: - MarshalObserver

    func didChange(userFiles: [Marshal.UserFile]) {
        if self.userKeyFactory != nil,
           let userFile = userFiles.first(where: { $0.origin == self.origin && $0.userName == self.userName }),
           self != userFile {
            dbg("External user modification detected for \(self.userName), logging out")
            self.logout()
        }
    }

    // MARK: - CredentialSupplier

    var credentialOwnerName: String {
        self.userName
    }

    var credentialOwnerRank: Int {
        Int(self.lastUsed.timeIntervalSinceReferenceDate)
    }

    var credentials: [AutoFill.Credential]? {
        self.autofill ? self.sites.compactMap(\.credential) : nil
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
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            case .identification:
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam ?? self.loginState,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            case .recovery:
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, task: Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    }
                )
        }
    }

    public func state(for name: String? = nil, counter: SpectreCounter? = nil,
                      keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
                      resultType: SpectreResultType? = nil, resultParam: String,
                      algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil)
        -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            case .identification:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            case .recovery:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self, task: Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    }
                )
        }
    }

    private func spectre_result(for name: String, counter: SpectreCounter,
                                keyPurpose: SpectreKeyPurpose, keyContext: String?,
                                resultType: SpectreResultType, resultParam: String?,
                                algorithm: SpectreAlgorithm, operand: SpectreOperand)
        -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation(
            siteName: name, counter: counter, type: resultType,
            param: resultParam, purpose: keyPurpose, context: keyContext,
            identity: self.userKeyID, algorithm: algorithm, operand: operand, task: Task.detached {
                let userKey = try keyFactory.newKey(for: algorithm)
                defer { userKey.deallocate() }

                guard let result = String.valid(
                    spectre_site_result(
                        userKey, name, resultType, resultParam,
                        counter, keyPurpose, keyContext
                    ), consume: true
                )
                else { throw AppError.internal(reason: "Cannot calculate result", details: self) }

                return result
            }
        )
    }

    private func spectre_state(for name: String, counter: SpectreCounter,
                               keyPurpose: SpectreKeyPurpose, keyContext: String?,
                               resultType: SpectreResultType, resultParam: String?,
                               algorithm: SpectreAlgorithm, operand: SpectreOperand)
        -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation(
            siteName: name, counter: counter, type: resultType,
            param: resultParam, purpose: keyPurpose, context: keyContext,
            identity: self.userKeyID, algorithm: algorithm, operand: operand, task: Task.detached {
                let userKey = try keyFactory.newKey(for: algorithm)
                defer { userKey.deallocate() }

                guard let result = String.valid(
                    spectre_site_state(
                        userKey, name, resultType, resultParam,
                        counter, keyPurpose, keyContext
                    ), consume: true
                )
                else { throw AppError.internal(reason: "Cannot calculate result", details: self) }

                return result
            }
        )
    }

    // MARK: - Types

    enum Avatar: UInt32, CaseIterable, Identifiable {
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

        public var imageName: String {
            "avatar-\(self.rawValue)"
        }
    }
}

extension User: Identifiable {
    public var id: String { self.userName }
}

extension User: Hashable {
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.algorithm == rhs.algorithm &&
            lhs.avatar == rhs.avatar &&
            lhs.userName == rhs.userName &&
            lhs.identicon == rhs.identicon &&
            lhs.userKeyID == rhs.userKeyID &&
            lhs.resultType == rhs.resultType &&
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
        hasher.combine(self.algorithm)
        hasher.combine(self.avatar)
        hasher.combine(self.userName)
        hasher.combine(self.identicon)
        hasher.combine(self.userKeyID)
        hasher.combine(self.resultType)
        hasher.combine(self.loginType)
        hasher.combine(self.loginState)
        hasher.combine(self.lastUsed)
        hasher.combine(self.exportDate)
        hasher.combine(self.maskPasswords)
        hasher.combine(self.biometricLock)
        hasher.combine(self.autofill)
        hasher.combine(self.autofillDecided)
        hasher.combine(self.sharing)
        hasher.combine(self.attacker)
        hasher.combine(self.file)
        hasher.combine(self.origin)
        hasher.combine(self.sites)
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
    func didLogin(user: User) {}

    func didLogout(user: User) {}

    func didChange(user: User, at change: PartialKeyPath<User>) {}
}
