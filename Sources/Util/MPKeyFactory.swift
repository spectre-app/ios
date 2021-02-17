//
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import LocalAuthentication

private let keyQueue     = DispatchQueue( label: "\(productName): Key Factory", qos: .utility )
private var keyFactories = [ String: MPKeyFactory ]()

private func keyFactoryProvider(_ algorithm: MPAlgorithmVersion, _ userName: UnsafePointer<CChar>?) -> UnsafePointer<MPUserKey>? {
    keyQueue.await {
        String.valid( userName ).flatMap { keyFactories[$0] }?.newKey( for: algorithm )
    }
}

public class MPKeyFactory {
    private var userKeysCache = [ MPAlgorithmVersion: UnsafePointer<MPUserKey> ]()
    public let  userName: String

    // MARK: --- Life ---

    init(userName: String) {
        self.userName = userName
    }

    deinit {
        self.invalidate()
    }

    // MARK: --- Interface ---

    public func provide() -> Promise<MPUserKeyProvider> {
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

    public func authenticatedIdentifier(for algorithm: MPAlgorithmVersion) -> Promise<String?> {
        keyQueue.promise {
            withUnsafeBytes( of: self.getKey( for: algorithm )?.pointee.bytes ) {
                $0.bindMemory( to: UInt8.self ).digest()?.hex()
            }
        }
    }

    public func newKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPUserKey>? {
        guard let userKey = self.getKey( for: algorithm )
        else { return nil }

        // Create a copy of the user key to be consumed by the caller.
        let providedUserKey = UnsafeMutablePointer<MPUserKey>.allocate( capacity: 1 )
        providedUserKey.initialize( from: userKey, count: 1 )
        return UnsafePointer<MPUserKey>( providedUserKey )
    }

    // MARK: --- Private ---

    private func getKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPUserKey>? {
        keyQueue.await {
            // Try to resolve the user key from the cache.
            if let userKey = self.userKeysCache[algorithm] {
                return userKey
            }

            // Try to produce the user key in the factory.
            if let userKey = self.createKey( for: algorithm ) {
                self.setKey( userKey, algorithm: algorithm )
                return userKey
            }

            return nil
        }
    }

    fileprivate func setKey(_ key: UnsafePointer<MPUserKey>, algorithm: MPAlgorithmVersion) {
        keyQueue.await {
            self.userKeysCache[algorithm] = key
        }
    }

    fileprivate func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPUserKey>? {
        nil
    }
}

public class MPSecretKeyFactory: MPKeyFactory {
    private let userSecret: String

    // MARK: --- Life ---

    public init(userName: String, userSecret: String) {
        self.userSecret = userSecret
        super.init( userName: userName )
    }

    // MARK: --- Interface ---

    public var identicon: MPIdenticon {
        mpw_identicon( self.userName, self.userSecret )
    }

    public func toKeychain() -> Promise<MPKeychainKeyFactory> {
        MPKeychainKeyFactory( userName: self.userName ).unlock().promising {
            $0.saveKeys( MPAlgorithmVersion.allCases.map( { ($0, self.newKey( for: $0 )) } ) )
        }
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPUserKey>? {
        DispatchQueue.mpw.await {
            mpw_user_key( self.userName, self.userSecret, algorithm )
        }
    }
}

public class MPBufferKeyFactory: MPKeyFactory {
    private let algorithm: MPAlgorithmVersion

    // MARK: --- Life ---

    public init(userName: String, userKey: UnsafePointer<MPUserKey>, algorithm: MPAlgorithmVersion) {
        self.algorithm = algorithm
        super.init( userName: userName )

        self.setKey( userKey, algorithm: algorithm )
    }
}

public class MPKeychainKeyFactory: MPKeyFactory {
    public static let factor: Factor = {
        var error: NSError?
        defer {
            if let error = error {
                wrn( "Biometrics unavailable: %@", error )
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
            if let expiry = self.expiry, _context != nil {
                self._contextValidity = Date() + expiry
            }
            else {
                self._contextValidity = nil
            }
        }
    }
    private var _contextValidity: Date?
    private var contextValid:     Bool {
        if let validity = self._contextValidity {
            return validity > Date()
        }

        return true
    }
    private var context:          LAContext {
        if let context = self._context, self.contextValid {
            return context
        }

        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 3
        context.localizedReason = "Unlock \(self.userName)"
        context.localizedFallbackTitle = "Use Personal Secret"
        self._context = context

        return context
    }

    // MARK: --- Life ---

    public override init(userName: String) {
        super.init( userName: userName )
    }

    // MARK: --- Interface ---

    public func hasKey(for algorithm: MPAlgorithmVersion) -> Bool {
        MPKeychain.hasKey( for: self.userName, algorithm: algorithm )
    }

    public func purgeKeys() {
        for algorithm in MPAlgorithmVersion.allCases {
            MPKeychain.deleteKey( for: self.userName, algorithm: algorithm )
        }

        self.invalidate()
    }

    // MARK: --- Life ---

    public override func invalidate() {
        keyQueue.await { self.context.invalidate() }

        super.invalidate()
    }

    public func unlock() -> Promise<MPKeychainKeyFactory> {
        let promise = Promise<MPKeychainKeyFactory>()

        self.context.evaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlocking \(self.userName)" ) { result, error in
            if let error = error {
                promise.finish( .failure( error ) )
            }
            else if !result {
                promise.finish( .failure( MPError.internal( cause: "Biometrics authentication denied.", details: self.userName ) ) )
            }
            else {
                promise.finish( .success( self ) )
            }
        }

        return promise
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPUserKey>? {
        do {
            return try MPKeychain.loadKey( for: self.userName, algorithm: algorithm, context: self.context ).await()
        }
        catch {
            mperror( title: "Biometric Authentication Failed", error: error )
            return nil
        }
    }

    fileprivate func saveKeys(_ items: [(MPAlgorithmVersion, UnsafePointer<MPUserKey>?)]) -> Promise<MPKeychainKeyFactory> {
        keyQueue.promising {
            var promise = Promise( .success( () ) )

            for item in items {
                if let key = item.1 {
                    self.setKey( key, algorithm: item.0 )
                    promise = promise.and(
                            MPKeychain.saveKey( for: self.userName, algorithm: item.0, keyFactory: self, context: self.context ) )
                }
            }

            return promise.promise { self }
        }
    }

    // MARK: --- Types ---

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

        var icon: UIImage? {
            switch self {
                case .biometricTouch:
                    return .icon( "" )

                case .biometricFace:
                    return .icon( "" )

                case .biometricNone:
                    return nil
            }
        }
    }
}
