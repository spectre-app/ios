//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import LocalAuthentication

public class KeyFactory: Hashable {
    public let  userName: String

    fileprivate let keyState = SingleLockBox(value: KeyState())
    fileprivate class KeyState {
        private var keys = [SpectreAlgorithm: UnsafePointer<SpectreUserKey>]()

        deinit {
            self.keys.forEach { $1.deallocate() }
            self.keys.removeAll()
        }

        fileprivate func find(for algorithm: SpectreAlgorithm) -> UnsafePointer<SpectreUserKey>? {
            self.keys[algorithm]
        }

        fileprivate func save(_ newKey: UnsafePointer<SpectreUserKey>) {
            if let oldKey = self.keys[newKey.pointee.algorithm], oldKey != newKey {
                oldKey.deallocate()
            }

            self.keys[newKey.pointee.algorithm] = newKey
        }

        fileprivate func clear() {
            self.keys.forEach { $1.deallocate() }
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

    private static let allFactories = SingleLockBox(value: [String: WeakBox<KeyFactory>]())
    public func provide() -> SpectreKeyProvider {
        KeyFactory.allFactories.use { $0[self.userName] = WeakBox(self) }

        return { algorithm, userName in
            do {
                return try String.valid(userName).flatMap { userName in
                    KeyFactory.allFactories.use { $0[userName]?.value }
                }?.newKey(for: algorithm)
            }
            catch {
                wrn("Key Unavailable", data: error)
                return nil
            }
        }
    }

    public func authenticatedIdentifier(for algorithm: SpectreAlgorithm) throws -> String? {
        let userKey = try self.getKey(for: algorithm)

        return withUnsafeBytes(of: userKey.pointee.bytes) {
            $0.bindMemory(to: UInt8.self).digest()?.hex()
        }
    }

    public func newKey(for algorithm: SpectreAlgorithm) throws -> UnsafePointer<SpectreUserKey> {
        let userKey = try self.getKey(for: algorithm)

        // Create a copy of the user key to be consumed by the caller.
        let providedUserKey = UnsafeMutablePointer<SpectreUserKey>.allocate(capacity: 1)
        providedUserKey.initialize(from: userKey, count: 1)
        return UnsafePointer<SpectreUserKey>(providedUserKey)
    }

    // MARK: - Private

    private func getKey(for algorithm: SpectreAlgorithm) throws -> UnsafePointer<SpectreUserKey> {
        // Try to resolve the user key from the cache.
        if let cachedKey = self.keyState.use({ $0.find(for: algorithm) }) {
            return cachedKey
        }

        // Try to produce the user key in the factory.
        let userKey = try self.createKey(for: algorithm)
        self.keyState.use { $0.save(userKey) }
        return userKey
    }

    fileprivate func createKey(for algorithm: SpectreAlgorithm) throws -> UnsafePointer<SpectreUserKey> {
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

        try await withThrowingTaskGroup(of: UnsafePointer<SpectreUserKey>.self) { group in
            for algorithm in SpectreAlgorithm.allCases {
                group.addTask { try self.newKey(for: algorithm) }
            }
            try await keychainKeyFactory.saveKeys(group)
        }

        return keychainKeyFactory
    }

    // MARK: - Private

    override fileprivate func createKey(for algorithm: SpectreAlgorithm) throws -> UnsafePointer<SpectreUserKey> {
        guard let userKey = Spectre.shared.use({
            $0.user_key(userName: self.userName, userSecret: self.userSecret, algorithmVersion: algorithm)
        })
        else { throw AppError.internal(reason: "Couldn't allocate a user key") }

        return userKey
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
            try Keychain.shared.deleteKey(for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context })
            dbg("Purged keychain key: \(self.userName), v\(algorithm.rawValue)")
        }

        self.keychainState.use { $0.clear() }
        self.keyState.use { $0.clear() }
    }

    // MARK: - Life

    public func unlock() async throws -> KeychainKeyFactory {
        let context = self.keychainState.use { $0.context }

        guard try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: context.localizedReason)
        else { throw AppError.internal(reason: "Biometrics authentication denied", details: self.userName) }

        return self
    }

    // MARK: - Private

    override fileprivate func createKey(for algorithm: SpectreAlgorithm) throws -> UnsafePointer<SpectreUserKey> {
        try Keychain.shared.loadKey(for: self.userName, algorithm: algorithm, context: self.keychainState.use { $0.context })
    }

    fileprivate func saveKeys(_ keys: ThrowingTaskGroup<UnsafePointer<SpectreUserKey>, Error>) async throws {
        for try await key in keys {
            self.keyState.use { $0.save(key) }
            try Keychain.shared.saveKey(
                for: self.userName, algorithm: key.pointee.algorithm,
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
