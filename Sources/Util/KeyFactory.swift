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

private let keyQueue     = DispatchQueue( label: "\(productName): Key Factory", qos: .utility )
private var keyFactories = [ String: KeyFactory ]()

private func keyFactoryProvider(_ algorithm: SpectreAlgorithm, _ userName: UnsafePointer<CChar>?) -> UnsafePointer<SpectreUserKey>? {
    keyQueue.await {
        do {
            return try String.valid( userName ).flatMap { keyFactories[$0] }?.newKey( for: algorithm ).await()
        }
        catch {
            wrn( "Key Unavailable: %@", error )
            return nil
        }
    }
}

public class KeyFactory {
    private var userKeysCache = [ SpectreAlgorithm: UnsafePointer<SpectreUserKey> ]()
    public let  userName: String

    // MARK: - Life

    init(userName: String) {
        self.userName = userName
    }

    deinit {
        self.invalidate()
    }

    // MARK: - Interface

    public func provide() -> Promise<SpectreKeyProvider> {
        keyQueue.promise {
            keyFactories[self.userName] = self
            return keyFactoryProvider
        }
    }

    public func invalidate() {
        keyQueue.await {
            self.userKeysCache.forEach { $1.deallocate() }
            self.userKeysCache.removeAll()
        }
    }

    public func authenticatedIdentifier(for algorithm: SpectreAlgorithm) -> Promise<String?> {
        self.getKey( for: algorithm ).promise( on: keyQueue ) {
            withUnsafeBytes( of: $0.pointee.bytes ) {
                $0.bindMemory( to: UInt8.self ).digest()?.hex()
            }
        }
    }

    public func newKey(for algorithm: SpectreAlgorithm) -> Promise<UnsafePointer<SpectreUserKey>> {
        self.getKey( for: algorithm ).promise( on: keyQueue ) { userKey in
            // Create a copy of the user key to be consumed by the caller.
            let providedUserKey = UnsafeMutablePointer<SpectreUserKey>.allocate( capacity: 1 )
            providedUserKey.initialize( from: userKey, count: 1 )
            return UnsafePointer<SpectreUserKey>( providedUserKey )
        }
    }

    // MARK: - Private

    private func getKey(for algorithm: SpectreAlgorithm) -> Promise<UnsafePointer<SpectreUserKey>> {
        keyQueue.promising {
                    // Try to resolve the user key from the cache.
                    if let cachedKey = self.userKeysCache[algorithm] {
                        return Promise( .success( cachedKey ) )
                    }

                    // Try to produce the user key in the factory.
                    return self.createKey( for: algorithm )
                }
                .success( on: keyQueue, self.cacheKey )
    }

    fileprivate func cacheKey(_ key: UnsafePointer<SpectreUserKey>) {
        keyQueue.await {
            self.userKeysCache[key.pointee.algorithm] = key
        }
    }

    fileprivate func createKey(for algorithm: SpectreAlgorithm) -> Promise<UnsafePointer<SpectreUserKey>> {
        Promise( .failure( AppError.internal( cause: "This key factory does not support key creation" ) ) )
    }
}

public class SecretKeyFactory: KeyFactory {
    private let userSecret: String

    // MARK: - Life

    public init(userName: String, userSecret: String) {
        self.userSecret = userSecret
        super.init( userName: userName )
    }

    // MARK: - Interface

    public var metadata: (length: Int, entropy: Int, identicon: SpectreIdenticon) {
        (length: self.userSecret.count,
         entropy: Attacker.entropy( string: self.userSecret ) ?? -1,
         identicon: spectre_identicon( self.userName, self.userSecret ))
    }

    public func toKeychain() -> Promise<KeychainKeyFactory> {
        KeychainKeyFactory( userName: self.userName ).unlock().promising { keychainKeyFactory in
            keychainKeyFactory.saveKeys( SpectreAlgorithm.allCases.map { self.newKey( for: $0 ) } )
                              .promise { _ in keychainKeyFactory }
        }
    }

    // MARK: - Private

    fileprivate override func createKey(for algorithm: SpectreAlgorithm) -> Promise<UnsafePointer<SpectreUserKey>> {
        DispatchQueue.api.promise {
            guard let userKey = spectre_user_key( self.userName, self.userSecret, algorithm )
            else { throw AppError.internal( cause: "Couldn't allocate a user key" ) }

            return userKey
        }
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

            case .faceID:
                return .biometricFace

            @unknown default:
                wrn( "Unsupported biometry type: %@", context.biometryType )
                return .biometricNone
        }
    }()

    public var expiry: TimeInterval? {
        didSet {
            (self._context = self._context)
        }
    }

    private var _context:         LAContext? {
        didSet {
            if let expiry = self.expiry, self._context != nil {
                self._contextValidity = Date() + expiry
            }
            else {
                self._contextValidity = nil
            }
        }
    }
    private var _contextValidity: Date?
    private var isContextValid:   Bool {
        if let validity = self._contextValidity {
            return validity > Date()
        }

        return true
    }
    private var context:          LAContext {
        if let context = self._context, self.isContextValid {
            return context
        }

        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 3
        context.localizedReason = "Unlock \(self.userName)"
        context.localizedFallbackTitle = "Use Personal Secret"
        self._context = context

        return context
    }

    // MARK: - Life

    public override init(userName: String) {
        super.init( userName: userName )
    }

    // MARK: - Interface

    public func isKeyPresent(for algorithm: SpectreAlgorithm) -> Bool {
        Keychain.keyStatus( for: self.userName, algorithm: algorithm, context: self.context ).present
    }

    public func isKeyAvailable(for algorithm: SpectreAlgorithm) -> Bool {
        Keychain.keyStatus( for: self.userName, algorithm: algorithm, context: self.context ).available
    }

    public func purgeKeys() {
        for algorithm in SpectreAlgorithm.allCases {
            Keychain.deleteKey( for: self.userName, algorithm: algorithm )
            inf( "Purged keychain key: %@, v%d", self.userName, algorithm.rawValue )
        }

        self.invalidate()
    }

    // MARK: - Life

    public override func invalidate() {
        keyQueue.await { self._context?.invalidate() }

        super.invalidate()
    }

    public func unlock() -> Promise<KeychainKeyFactory> {
        let promise = Promise<KeychainKeyFactory>()

        self.context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlocking \(self.userName)" ) { result, error in
            if let error = error {
                promise.finish( .failure( error ) )
            }
            else if !result {
                promise.finish( .failure( AppError.internal( cause: "Biometrics authentication denied", details: self.userName ) ) )
            }
            else {
                promise.finish( .success( self ) )
            }
        }

        return promise
    }

    // MARK: - Private

    fileprivate override func createKey(for algorithm: SpectreAlgorithm) -> Promise<UnsafePointer<SpectreUserKey>> {
        Keychain.loadKey( for: self.userName, algorithm: algorithm, context: self.context )
    }

    fileprivate func saveKeys(_ keys: [Promise<UnsafePointer<SpectreUserKey>>]) -> Promise<Void> {
        keyQueue.promising {
            keys.map {
                $0.success( self.cacheKey ).promising {
                    Keychain.saveKey( for: self.userName, algorithm: $0.pointee.algorithm, keyFactory: self, context: self.context )
                }
            }
            .flatten().promise { _ in }.success {
                inf( "Saved keychain keys for: %@", self.userName )
            }
        }
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
