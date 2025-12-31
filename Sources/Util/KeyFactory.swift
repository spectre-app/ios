//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import LocalAuthentication

public class UserKey {
    public let userName: String

    private let key: UnsafePointer<SpectreUserKey>

    public init(key: UnsafePointer<SpectreUserKey>, for userName: String) {
        self.key = key
        self.userName = userName
    }
    deinit {
        self.key.deallocate()
    }

    public var algorithm: SpectreAlgorithm {
        self.key.pointee.algorithm
    }

    public var keyID: SpectreKeyID {
        self.key.pointee.keyID
    }

    public func data() -> Data {
        Data(buffer: UnsafeBufferPointer(start: self.key, count: 1))
    }

    fileprivate func copy() -> UnsafePointer<SpectreUserKey> {
        let providedUserKey = UnsafeMutablePointer<SpectreUserKey>.allocate(capacity: 1)
        providedUserKey.initialize(from: self.key, count: 1)
        return UnsafePointer<SpectreUserKey>(providedUserKey)
    }

    public func digest() -> Data? {
        return withUnsafeBytes(of: self.key.pointee.bytes) {
            $0.bindMemory(to: UInt8.self).digest()
        }
    }

    public func matches(keyID: SpectreKeyID) throws -> Bool {
        guard self.keyID.isValid
        else { throw AppError.internal(reason: "Could not determine key ID for authentication key", details: self.userName) }

        return self.keyID == keyID
    }

    public func result(for name: String, counter: SpectreCounter,
                       keyPurpose: SpectreKeyPurpose, keyContext: String?,
                       resultType: SpectreResultType, resultParam: String?,
                       algorithm: SpectreAlgorithm)
        throws -> String {
        guard let result = String.valid(
            spectre_site_result(self.key, name, resultType, resultParam, counter, keyPurpose, keyContext), consume: true
        )
        else { throw AppError.internal(reason: "Cannot calculate result", details: self.userName) }

        return result
    }

    public func state(for name: String, counter: SpectreCounter,
                      keyPurpose: SpectreKeyPurpose, keyContext: String?,
                      resultType: SpectreResultType, resultParam: String?,
                      algorithm: SpectreAlgorithm)
        throws -> String {
        guard let result = String.valid(
            spectre_site_state(self.key, name, resultType, resultParam, counter, keyPurpose, keyContext), consume: true
        )
        else { throw AppError.internal(reason: "Cannot calculate result", details: self.userName) }

        return result
    }
}

public class KeyFactory: Hashable {
    public let  userName: String

    fileprivate let keyState = KeyState()
    fileprivate class KeyState {
        private var keys = [SpectreAlgorithm: UserKey]()

        fileprivate func find(for algorithm: SpectreAlgorithm) -> UserKey? {
            self.keys[algorithm]
        }

        fileprivate func save(_ getKey: UserKey) {
            self.keys[getKey.algorithm] = getKey
        }

        fileprivate func clear() {
            self.keys.removeAll()
        }
    }

    // MARK: - Life

    init(userName: String) {
        self.userName = userName
        LeakRegistry.shared.register(self)
    }

    // MARK: - Hashable

    public static func == (lhs: KeyFactory, rhs: KeyFactory) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    // MARK: - Interface

    private static var allFactories = SingleLockBox(value: [String: WeakBox<KeyFactory>]())
    public func provide() -> SpectreKeyProvider {
        KeyFactory.allFactories.using { $0[self.userName] = WeakBox(object: self) }

        return { algorithm, userName in
            unsafelyAwait { () -> UnsafeSpectrePointer<SpectreUserKey>? in
                do {
                    if let key = String.valid(userName).flatMap({ userName in
                        KeyFactory.allFactories.use { $0[userName]?.object }
                    }) {
                        return UnsafeSpectrePointer(pointer: try await key.getKey(for: algorithm).copy())
                    }
                }
                catch {
                    wrn("Key Unavailable", data: error)
                }

                return nil
            }?.pointer
        }
    }

    public func authenticatedIdentifier(for algorithm: SpectreAlgorithm) async throws -> String? {
        try await self.getKey(for: algorithm).digest()?.hex()
    }

    public func getKey(for algorithm: SpectreAlgorithm) async throws -> UserKey {
        // Try to resolve the user key from the cache.
        if let cachedKey = self.keyState.find(for: algorithm) {
            return cachedKey
        }

        // Try to produce the user key in the factory.
        let userKey = try await self.createKey(for: algorithm)
        self.keyState.save(userKey)
        return userKey
    }

    // MARK: - Private

    fileprivate func createKey(for algorithm: SpectreAlgorithm) async throws -> UserKey {
        throw AppError.internal(reason: "This key factory does not support key creation")
    }
}

public class SecretKeyFactory: KeyFactory {
    private let userSecret: String

    // MARK: - Life

    public init(userName: String, userSecret: String) {
        self.userSecret = userSecret
        self.metadata = (
            length: self.userSecret.count,
            entropy: Attacker.entropy(string: userSecret) ?? -1,
            identicon: spectre_identicon(userName, self.userSecret)
        )
        super.init(userName: userName)
    }

    // MARK: - Interface

    public let metadata: (length: Int, entropy: Int, identicon: SpectreIdenticon)

    public func toKeychain() async throws -> KeychainKeyFactory {
        let keychainKeyFactory = try await KeychainKeyFactory(userName: self.userName).unlock()

        try await withThrowingTaskGroup(of: UserKey.self) { group in
            for algorithm in SpectreAlgorithm.allCases {
                group.addTask { try await self.getKey(for: algorithm) }
            }
            try await keychainKeyFactory.saveKeys(group)
        }

        return keychainKeyFactory
    }

    // MARK: - Private

    override fileprivate func createKey(for algorithm: SpectreAlgorithm) async throws -> UserKey {
        guard let userKey = await Spectre.shared.user_key(
            userName: self.userName, userSecret: self.userSecret, algorithmVersion: algorithm
        )
        else { throw AppError.internal(reason: "Couldn't allocate a user key") }

        return UserKey(key: userKey, for: self.userName)
    }
}

public class KeychainKeyFactory: KeyFactory {
    public static let factor: Factor = {
        var error: NSError?
        defer {
            if let error {
                wrn("Biometrics unavailable.", data: error)
            }
        }

        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        else { return .biometricNone }

        switch context.biometryType {
            case .none:
                return .biometricNone

            case .touchID:
                return .biometricTouch

            case .faceID, .opticID:
                return .biometricFace

            @unknown default:
                wrn("Unsupported biometry type.", data: context.biometryType)
                return .biometricNone
        }
    }()

    private let keychainState: RecursiveLockBox<KeychainState>
    private class KeychainState {
        private let userName: String
        private var currentContext: LAContext? {
            didSet {
                self.contextValidity = self.contextExpiry.flatMap { Date() + $0 }
            }
        }

        private var contextExpiry:   TimeInterval? {
            didSet {
                self.contextValidity = self.contextExpiry.flatMap { Date() + $0 }
            }
        }

        private var contextValidity: Date?
        private var isContextValid:   Bool {
            guard let validity = self.contextValidity
            else { return true }

            return validity > Date()
        }

        var context: LAContext {
            if let context = self.currentContext, self.isContextValid, context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
                return context
            }

            let context = LAContext()
            context.touchIDAuthenticationAllowableReuseDuration = 3
            context.localizedReason = "Unlock \(self.userName)"
            context.localizedFallbackTitle = "Use Personal Secret"
            self.currentContext = context

            return context
        }

        init(userName: String, expiry: TimeInterval?) {
            self.userName = userName
            self.contextExpiry = expiry
        }

        deinit {
            self.currentContext?.invalidate()
        }

        fileprivate func clear() {
            self.currentContext?.invalidate()
        }
    }

    // MARK: - Life

    public init(userName: String, expiry: TimeInterval? = nil) {
        self.keychainState = .init(value: KeychainState(userName: userName, expiry: expiry))
        super.init(userName: userName)
    }

    // MARK: - Interface

    public func isKeyPresent(for algorithm: SpectreAlgorithm) -> Bool {
        Keychain.shared.keyStatus(for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context }).present
    }

    public func isKeyAvailable(for algorithm: SpectreAlgorithm) -> Bool {
        Keychain.shared.keyStatus(for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context }).available
    }

    public func purgeKeys() async throws {
        for algorithm in SpectreAlgorithm.allCases {
            try await Keychain.shared.deleteKey(for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context })
            dbg("Purged keychain key: \(self.userName), v\(algorithm.rawValue)")
        }

        self.keychainState.use { $0.clear() }
        self.keyState.clear()
    }

    // MARK: - Life

    public func unlock() async throws -> KeychainKeyFactory {
        let context = self.keychainState.use { $0.context }

        guard try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: context.localizedReason)
        else { throw AppError.internal(reason: "Biometrics authentication denied", details: self.userName) }

        return self
    }

    // MARK: - Private

    override fileprivate func createKey(for algorithm: SpectreAlgorithm) async throws -> UserKey {
        UserKey(
            key: try await Keychain.shared.loadKey(
                for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context }
            ),
            for: self.userName
        )
    }

    fileprivate func saveKeys(_ keys: ThrowingTaskGroup<UserKey, Error>) async throws {
        for try await key in keys {
            self.keyState.save(key)
            try await Keychain.shared.saveKey(
                for: self.userName, algorithm: key.algorithm,
                keyFactory: self, context: self.keychainState.use { $0.context }
            )
        }
        dbg("Saved keychain keys for: \(self.userName)")
    }

    // MARK: - Types

    public enum Factor: CustomStringConvertible {
        case biometricTouch, biometricFace, biometricNone

        public var description: String {
            switch self {
                case .biometricTouch: "TouchID"
                case .biometricFace: "FaceID"
                case .biometricNone: "none"
            }
        }

        public var biometry: String {
            switch self {
                case .biometricTouch: "fingerprints"
                case .biometricFace: "appearance"
                case .biometricNone: "biometrics"
            }
        }

        var iconName: String? {
            switch self {
                case .biometricTouch: "touchid"
                case .biometricFace: "faceid"
                case .biometricNone: nil
            }
        }
    }
}
