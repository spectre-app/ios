//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import Foundation

@Observable
class User: CustomStringConvertible, CredentialSupplier, SpectreOperand, Observed, UserObserver, SiteObserver, MarshalObserver {
    let observers = Observers<UserObserver>()

    var algorithm: SpectreAlgorithm {
        didSet {
            if oldValue != self.algorithm {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.algorithm) }
            }
        }
    }

    var avatar: Avatar {
        didSet {
            if oldValue != self.avatar {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.avatar) }
            }
        }
    }

    let userName: String
    var identicon: SpectreIdenticon {
        didSet {
            if oldValue != self.identicon {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.identicon) }
            }
        }
    }

    var userKeyID: SpectreKeyID {
        didSet {
            if !spectre_id_equals([oldValue], &self.userKeyID) {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.userKeyID) }
            }
        }
    }

    private(set) var userKeyFactory: KeyFactory? {
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

    var authenticatedIdentifier: String? {
        get async throws {
            try await self.userKeyFactory?.authenticatedIdentifier(for: self.algorithm)
        }
    }

    var resultType: SpectreResultType {
        didSet {
            if oldValue != self.resultType {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.resultType) }
            }
        }
    }

    var loginType: SpectreResultType {
        didSet {
            if oldValue != self.loginType {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.loginType) }
            }
        }
    }

    var loginState: String? {
        didSet {
            if oldValue != self.loginState {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.loginState) }
            }
        }
    }

    var lastUsed: Date {
        didSet {
            if oldValue != self.lastUsed {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.lastUsed) }
            }
        }
    }

    var exportDate: Date? {
        self.file?.spectre_get(path: "export", "date")
    }

    var maskPasswords = false {
        didSet {
            if oldValue != self.maskPasswords, !self.initializing,
               self.file?.spectre_set(self.maskPasswords, path: "user", "_ext_spectre", "maskPasswords") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.maskPasswords) }
            }
        }
    }

    var biometricLock = false {
        didSet {
            if oldValue != self.biometricLock, !self.initializing,
               self.file?.spectre_set(self.biometricLock, path: "user", "_ext_spectre", "biometricLock") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.biometricLock) }
            }

            self.updateBiometricKeyFactory()
        }
    }

    var autofill = false {
        didSet {
            if oldValue != self.autofill, !self.initializing,
               self.file?.spectre_set(self.autofill, path: "user", "_ext_spectre", "autofill") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.autofill) }

                Task.detached { await AutoFill.shared.update(for: self) }
            }
        }
    }

    var autofillDecided: Bool {
        (self.file?.spectre_get(path: "user", "_ext_spectre", "autofill") as Bool?) != nil
    }

    var sharing = false {
        didSet {
            if oldValue != self.sharing, !self.initializing,
               self.file?.spectre_set(self.sharing, path: "user", "_ext_spectre", "sharing") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.autofillDecided) }
            }
        }
    }

    var attacker: Attacker? {
        didSet {
            if oldValue != self.attacker, !self.initializing,
               self.file?.spectre_set(self.attacker?.description, path: "user", "_ext_spectre", "attacker") ?? true {
                self.dirty = true
                self.observers.notify { $0.didChange(user: self, at: \User.attacker) }
            }
        }
    }

    var file: UnsafeMutablePointer<SpectreMarshalledFile>?
    var origin: URL?

    var sites: [Site] = [] {
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

    var description: String {
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

    init(
        algorithm: SpectreAlgorithm? = nil, avatar: Avatar = .avatar_0, userName: String,
        identicon: SpectreIdenticon = SpectreIdenticonUnset, userKeyID: SpectreKeyID = .unset,
        resultType: SpectreResultType? = nil, loginType: SpectreResultType? = nil, loginState: String? = nil,
        lastUsed: Date = Date(), origin: URL? = nil,
        file: UnsafeMutablePointer<SpectreMarshalledFile>? = spectre_marshal_file(nil, nil, nil),
        initialize: (User) -> Void = { _ in },
    ) {
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
            let authKey = try await keyFactory.getKey(for: self.algorithm)

            if try !authKey.matches(keyID: self.userKeyID) {
                throw AppError.issue("Incorrect user key", reason: self)
            }
            self.userKeyFactory = keyFactory

            if !self.userKeyID.isValid {
                self.userKeyID = authKey.keyID
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
            guard self.userKeyFactory != nil
            else { return }

            try await self.save()
            self.userKeyFactory = nil
        }
    }

    func save(onlyIfDirty: Bool = true) async throws {
        assert(self.userKeyFactory != nil)

        if onlyIfDirty, !self.dirty {
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

    func use() {
        self.lastUsed = Date()
    }

    func result(
        for name: String? = nil, counter: SpectreCounter? = nil,
        keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
        resultType: SpectreResultType? = nil, resultParam: String? = nil,
        algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil,
    )
        -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .identification:
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam ?? self.loginState,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .recovery:
                return self.spectre_result(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                    task: Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    },
                )
        }
    }

    func state(
        for name: String? = nil, counter: SpectreCounter? = nil,
        keyPurpose: SpectreKeyPurpose = .authentication, keyContext: String? = nil,
        resultType: SpectreResultType? = nil, resultParam: String,
        algorithm: SpectreAlgorithm? = nil, operand: SpectreOperand? = nil,
    )
        -> SpectreOperation? {
        switch keyPurpose {
            case .authentication:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? self.resultType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .identification:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType?.nonEmpty ?? self.loginType, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            case .recovery:
                return self.spectre_state(
                    for: name ?? self.userName, counter: counter ?? .initial,
                    keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType ?? .templatePhrase, resultParam: resultParam,
                    algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                )

            @unknown default:
                return SpectreOperation(
                    siteName: name ?? self.userName, counter: counter ?? .initial, type: resultType ?? .none,
                    param: resultParam, purpose: keyPurpose, context: keyContext,
                    identity: self.userKeyID, algorithm: algorithm ?? self.algorithm, operand: operand ?? self,
                    task: Task.detached {
                        throw AppError.internal(reason: "Unsupported key purpose", details: keyPurpose)
                    },
                )
        }
    }

    private func spectre_result(
        for name: String, counter: SpectreCounter,
        keyPurpose: SpectreKeyPurpose, keyContext: String?,
        resultType: SpectreResultType, resultParam: String?,
        algorithm: SpectreAlgorithm, operand: SpectreOperand,
    )
        -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation(
            siteName: name, counter: counter, type: resultType,
            param: resultParam, purpose: keyPurpose, context: keyContext,
            identity: self.userKeyID, algorithm: algorithm, operand: operand,
            task: Task.detached {
                try await keyFactory.getKey(for: algorithm).result(
                    for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType, resultParam: resultParam, algorithm: algorithm,
                )
            },
        )
    }

    private func spectre_state(
        for name: String, counter: SpectreCounter,
        keyPurpose: SpectreKeyPurpose, keyContext: String?,
        resultType: SpectreResultType, resultParam: String?,
        algorithm: SpectreAlgorithm, operand: SpectreOperand,
    )
        -> SpectreOperation? {
        guard let keyFactory = self.userKeyFactory
        else { return nil }

        return SpectreOperation(
            siteName: name, counter: counter, type: resultType,
            param: resultParam, purpose: keyPurpose, context: keyContext,
            identity: self.userKeyID, algorithm: algorithm, operand: operand,
            task: Task.detached {
                try await keyFactory.getKey(for: algorithm).state(
                    for: name, counter: counter, keyPurpose: keyPurpose, keyContext: keyContext,
                    resultType: resultType, resultParam: resultParam, algorithm: algorithm,
                )
            },
        )
    }

    // MARK: - Types

    enum Avatar: UInt32, CaseIterable, Identifiable {
        case avatar_0, avatar_1, avatar_2, avatar_3, avatar_4, avatar_5, avatar_6, avatar_7, avatar_8, avatar_9,
             avatar_10, avatar_11, avatar_12, avatar_13, avatar_14, avatar_15, avatar_16, avatar_17, avatar_18

        static func random() -> Avatar {
            allCases.randomElement() ?? .avatar_0
        }

        mutating func previous() {
            self = Avatar.allCases[((Avatar.allCases.firstIndex(of: self) ?? -1) + Avatar.allCases.count - 1) % Avatar.allCases.count]
        }

        mutating func next() {
            self = Avatar.allCases[((Avatar.allCases.firstIndex(of: self) ?? -1) + Avatar.allCases.count + 1) % Avatar.allCases.count]
        }

        var imageName: String {
            "avatar-\(self.rawValue)"
        }
    }
}

extension User: Identifiable {
    var id: String { self.userName }
}

extension User: Hashable {
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.algorithm == rhs.algorithm && lhs.avatar == rhs.avatar && lhs.userName == rhs.userName && lhs.identicon == rhs.identicon
            && lhs.userKeyID == rhs.userKeyID && lhs.resultType == rhs.resultType && lhs.loginType == rhs.loginType
            && lhs.loginState == rhs.loginState && lhs.lastUsed == rhs.lastUsed && lhs.exportDate == rhs.exportDate
            && lhs.maskPasswords == rhs.maskPasswords && lhs.biometricLock == rhs.biometricLock && lhs.autofill == rhs.autofill
            && lhs.autofillDecided == rhs.autofillDecided && lhs.sharing == rhs.sharing && lhs.attacker == rhs.attacker
            && lhs.file == rhs.file && lhs.origin == rhs.origin && lhs.sites == rhs.sites
    }

    func hash(into hasher: inout Hasher) {
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
    static func < (lhs: User, rhs: User) -> Bool {
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
