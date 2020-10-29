//
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import LocalAuthentication

private let keyQueue     = DispatchQueue( label: "\(productName): Key Factory", qos: .utility )
private var keyFactories = [ String: MPKeyFactory ]()

private func keyFactoryProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> UnsafePointer<MPMasterKey>? {
    keyQueue.await {
        String.valid( fullName ).flatMap { keyFactories[$0] }?.newKey( for: algorithm )
    }
}

public class MPKeyFactory {
    private var masterKeysCache = [ MPAlgorithmVersion: UnsafePointer<MPMasterKey> ]()
    public let  fullName: String

    // MARK: --- Life ---

    init(fullName: String) {
        self.fullName = fullName
    }

    deinit {
        self.invalidate()
    }

    // MARK: --- Interface ---

    public func provide() -> Promise<MPMasterKeyProvider> {
        keyQueue.promise {
            keyFactories[self.fullName] = self
            return keyFactoryProvider
        }
    }

    public func invalidate() {
        keyQueue.await {
            self.masterKeysCache.forEach { $1.deallocate() }
            self.masterKeysCache.removeAll()
        }
    }

    public func newKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPMasterKey>? {
        guard let masterKey = self.getKey( for: algorithm )
        else { return nil }

        // Create a copy of the master key to be consumed by the caller.
        let providedMasterKey = UnsafeMutablePointer<MPMasterKey>.allocate( capacity: 1 )
        providedMasterKey.initialize( from: masterKey, count: 1 )
        return UnsafePointer<MPMasterKey>( providedMasterKey )
    }

    // MARK: --- Private ---

    private func getKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPMasterKey>? {
        keyQueue.await {
            // Try to resolve the master key from the cache.
            if let masterKey = self.masterKeysCache[algorithm] {
                return masterKey
            }

            // Try to produce the master key in the factory.
            if let masterKey = self.createKey( for: algorithm ) {
                self.setKey( masterKey, algorithm: algorithm )
                return masterKey
            }

            return nil
        }
    }

    fileprivate func setKey(_ key: UnsafePointer<MPMasterKey>, algorithm: MPAlgorithmVersion) {
        keyQueue.await {
            self.masterKeysCache[algorithm] = key
        }
    }

    fileprivate func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPMasterKey>? {
        nil
    }
}

public class MPPasswordKeyFactory: MPKeyFactory {
    private let masterPassword: String

    // MARK: --- Life ---

    public init(fullName: String, masterPassword: String) {
        self.masterPassword = masterPassword
        super.init( fullName: fullName )
    }

    // MARK: --- Interface ---

    public var identicon: MPIdenticon {
        mpw_identicon( self.fullName, self.masterPassword )
    }

    public func toKeychain() -> Promise<MPKeychainKeyFactory> {
        MPKeychainKeyFactory( fullName: self.fullName ).unlock().promising {
            $0.saveKeys( MPAlgorithmVersion.allCases.map( { ($0, self.newKey( for: $0 )) } ) )
        }
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPMasterKey>? {
        DispatchQueue.mpw.await {
            mpw_master_key( self.fullName, self.masterPassword, algorithm )
        }
    }
}

public class MPBufferKeyFactory: MPKeyFactory {
    private let algorithm: MPAlgorithmVersion

    // MARK: --- Life ---

    public init(fullName: String, masterKey: UnsafePointer<MPMasterKey>, algorithm: MPAlgorithmVersion) {
        self.algorithm = algorithm
        super.init( fullName: fullName )

        self.setKey( masterKey, algorithm: algorithm )
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
        context.localizedReason = "Unlock \(self.fullName)"
        context.localizedFallbackTitle = "Use Password"
        self._context = context

        return context
    }

    // MARK: --- Life ---

    public override init(fullName: String) {
        super.init( fullName: fullName )
    }

    // MARK: --- Interface ---

    public func hasKey(for algorithm: MPAlgorithmVersion) -> Bool {
        MPKeychain.hasKey( for: self.fullName, algorithm: algorithm )
    }

    public func purgeKeys() {
        for algorithm in MPAlgorithmVersion.allCases {
            MPKeychain.deleteKey( for: self.fullName, algorithm: algorithm )
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

        self.context.evaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlocking \(self.fullName)" ) { result, error in
            if let error = error {
                promise.finish( .failure( error ) )
            }
            else if !result {
                promise.finish( .failure( MPError.internal( cause: "Biometrics authentication denied.", details: self.fullName ) ) )
            }
            else {
                promise.finish( .success( self ) )
            }
        }

        return promise
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> UnsafePointer<MPMasterKey>? {
        do {
            return try MPKeychain.loadKey( for: self.fullName, algorithm: algorithm, context: self.context ).await()
        }
        catch {
            mperror( title: "Biometric Authentication Failed", error: error )
            return nil
        }
    }

    fileprivate func saveKeys(_ items: [(MPAlgorithmVersion, UnsafePointer<MPMasterKey>?)]) -> Promise<MPKeychainKeyFactory> {
        keyQueue.promising {
            var promise = Promise( .success( () ) )

            for item in items {
                if let key = item.1 {
                    self.setKey( key, algorithm: item.0 )
                    promise = promise.and(
                            MPKeychain.saveKey( for: self.fullName, algorithm: item.0, keyFactory: self, context: self.context ) )
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
