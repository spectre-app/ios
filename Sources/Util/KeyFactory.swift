// =============================================================================
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import LocalAuthentication

private var keyFactories = [ String: WeakBox<KeyFactory> ]()

private func keyFactoryProvider(_ algorithm: SpectreAlgorithm, _ userName: UnsafePointer<CChar>?) -> UnsafePointer<SpectreUserKey>? {
    do {
        return try Task.unsafeAwait { try await String.valid( userName ).flatMap { keyFactories[$0]?.value }?.newKey( for: algorithm ) }
    }
    catch {
        wrn( "Key Unavailable: %@", error )
        return nil
    }
}

public class KeyFactory {
    public let  userName: String

    fileprivate let keyState = KeyState()
    fileprivate actor KeyState {
        private var keys = [ SpectreAlgorithm: UnsafePointer<SpectreUserKey> ]()

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
        LeakRegistry.shared.register( self )
    }

    // MARK: - Interface

    public func provide() -> SpectreKeyProvider {
        keyFactories[self.userName] = WeakBox( self )
        return keyFactoryProvider
    }

    public func authenticatedIdentifier(for algorithm: SpectreAlgorithm) async throws -> String? {
        let userKey = try await self.getKey( for: algorithm )

        return withUnsafeBytes( of: userKey.pointee.bytes ) {
            $0.bindMemory( to: UInt8.self ).digest()?.hex()
        }
    }

    public func newKey(for algorithm: SpectreAlgorithm) async throws -> UnsafePointer<SpectreUserKey> {
        let userKey = try await self.getKey( for: algorithm )

        // Create a copy of the user key to be consumed by the caller.
        let providedUserKey = UnsafeMutablePointer<SpectreUserKey>.allocate( capacity: 1 )
        providedUserKey.initialize( from: userKey, count: 1 )
        return UnsafePointer<SpectreUserKey>( providedUserKey )
    }

    // MARK: - Private

    private func getKey(for algorithm: SpectreAlgorithm) async throws -> UnsafePointer<SpectreUserKey> {
        // Try to resolve the user key from the cache.
        if let cachedKey = await self.keyState.find(for: algorithm) {
            return cachedKey
        }

        // Try to produce the user key in the factory.
        let userKey = try await self.createKey( for: algorithm )
        await self.keyState.save(userKey)
        return userKey
    }

    fileprivate func createKey(for algorithm: SpectreAlgorithm) async throws -> UnsafePointer<SpectreUserKey> {
        throw AppError.internal( cause: "This key factory does not support key creation" )
    }
}

public class SecretKeyFactory: KeyFactory {
    private let userSecret: String

    // MARK: - Life

    public init(userName: String, userSecret: String) {
        self.userSecret = userSecret
        self.metadata = (
                length: self.userSecret.count,
                entropy: Task.unsafeAwait { await Attacker.entropy( string: userSecret ) ?? -1 },
                identicon: spectre_identicon( userName, self.userSecret )
        )
        super.init( userName: userName )
    }

    // MARK: - Interface

    public let metadata: (length: Int, entropy: Int, identicon: SpectreIdenticon)

    public func toKeychain() async throws -> KeychainKeyFactory {
        let keychainKeyFactory = try await KeychainKeyFactory( userName: self.userName ).unlock()

        try await withThrowingTaskGroup(of: UnsafePointer<SpectreUserKey>.self) { group in
            for algorithm in SpectreAlgorithm.allCases {
                group.addTask { try await self.newKey( for: algorithm ) }
            }
            try await keychainKeyFactory.saveKeys( group )
        }

        return keychainKeyFactory
    }

    // MARK: - Private

    fileprivate override func createKey(for algorithm: SpectreAlgorithm) async throws -> UnsafePointer<SpectreUserKey> {
        guard let userKey = await Spectre.shared.user_key( userName: self.userName, userSecret: self.userSecret, algorithmVersion: algorithm )
        else { throw AppError.internal( cause: "Couldn't allocate a user key" ) }

        return userKey
    }
}

public class KeychainKeyFactory: KeyFactory {
    public static let factor: Factor = {
        var error: NSError?
        defer {
            if let error = error {
                wrn( "Biometrics unavailable: %@ [>PII]", error.localizedDescription )
                pii( "[>] Error: %@", error )
            }
        }

        let context = LAContext()
        guard context.canEvaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, error: &error )
        else { return .biometricNone }

        switch context.biometryType {
            case .none:
                return .biometricNone

            case .touchID:
                return .biometricTouch

            case .faceID, .opticID:
                return .biometricFace

            @unknown default:
                wrn( "Unsupported biometry type: %@", context.biometryType )
                return .biometricNone
        }
    }()

    private let keychainState: KeychainState
    private actor KeychainState {
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
        self.keychainState = KeychainState(userName: userName, expiry: expiry)
        super.init( userName: userName )
    }

    // MARK: - Interface

    public func isKeyPresent(for algorithm: SpectreAlgorithm) async -> Bool {
        await Keychain.shared.keyStatus( for: self.userName, algorithm: algorithm, context: self.keychainState.context ).present
    }

    public func isKeyAvailable(for algorithm: SpectreAlgorithm) async -> Bool {
        await Keychain.shared.keyStatus( for: self.userName, algorithm: algorithm, context: self.keychainState.context ).available
    }

    public func purgeKeys() async throws {
        for algorithm in SpectreAlgorithm.allCases {
            try await Keychain.shared.deleteKey( for: self.userName, algorithm: algorithm, context: self.keychainState.context )
            inf( "Purged keychain key: %@, v%d", self.userName, algorithm.rawValue )
        }

        await self.keychainState.clear()
        await self.keyState.clear()
    }

    // MARK: - Life

    public func unlock() async throws -> KeychainKeyFactory {
        let context = await self.keychainState.context

        guard try await context.evaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, localizedReason: context.localizedReason )
        else { throw AppError.internal( cause: "Biometrics authentication denied", details: self.userName ) }

        return self
    }

    // MARK: - Private

    fileprivate override func createKey(for algorithm: SpectreAlgorithm) async throws -> UnsafePointer<SpectreUserKey> {
        try await Keychain.shared.loadKey( for: self.userName, algorithm: algorithm, context: self.keychainState.context )
    }

    fileprivate func saveKeys(_ keys: ThrowingTaskGroup<UnsafePointer<SpectreUserKey>, Error>) async throws -> Void {
        for try await key in keys {
            await self.keyState.save(key)
            try await Keychain.shared.saveKey( for: self.userName, algorithm: key.pointee.algorithm,
                                               keyFactory: self, context: self.keychainState.context )
        }
        inf( "Saved keychain keys for: %@", self.userName )
    }

    // MARK: - Types

    public enum Factor: CustomStringConvertible {
        case biometricTouch, biometricFace, biometricNone

        public var description: String {
            switch self {
                case .biometricTouch:
                    return "TouchID"

                case .biometricFace:
                    return "FaceID"

                case .biometricNone:
                    return "none"
            }
        }

        public var biometry: String {
            switch self {
                case .biometricTouch:
                    return "fingerprints"

                case .biometricFace:
                    return "appearance"

                case .biometricNone:
                    return "biometrics"
            }
        }

        var iconName: String? {
            switch self {
                case .biometricTouch:
                    return "fingerprint"

                case .biometricFace:
                    return "face-viewfinder"

                case .biometricNone:
                    return nil
            }
        }
    }
}
