//
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import LocalAuthentication

private var masterKeyFactories = [ String: MPKeyFactory ]()

private func __masterKeyProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> MPMasterKey? {
    DispatchQueue.mpw.await {
        String( safeUTF8: fullName ).flatMap { masterKeyFactories[$0] }?.newMasterKey( algorithm: algorithm )
    }
}

public class MPKeyFactory {
    private var masterKeysCache = [ MPAlgorithmVersion: MPMasterKey ]()
    public let  fullName: String

    // MARK: --- Life ---

    init(fullName: String) {
        self.fullName = fullName
    }

    deinit {
        self.flush()
    }

    // MARK: --- Interface ---

    public func provide() -> MPMasterKeyProvider {
        DispatchQueue.mpw.await {
            masterKeyFactories[self.fullName] = self
            return __masterKeyProvider
        }
    }

    public func flush() {
        DispatchQueue.mpw.await {
            self.masterKeysCache.forEach { $1.deallocate() }
            self.masterKeysCache.removeAll()
        }
    }

    public func newMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        DispatchQueue.mpw.await {
            guard let masterKey = self.getMasterKey( algorithm: algorithm )
            else { return nil }

            // Create a copy of the master key to be consumed by the caller.
            let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
            providedMasterKey.initialize( from: masterKey, count: MPMasterKeySize )
            return UnsafePointer<UInt8>( providedMasterKey )
        }
    }

    // MARK: --- Private ---

    private func getMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        DispatchQueue.mpw.await {
            // Try to resolve the master key from the cache.
            if let masterKey = self.masterKeysCache[algorithm] {
                return masterKey
            }

            // Try to produce the master key in the factory.
            if let masterKey = self.createMasterKey( algorithm: algorithm ) {
                self.setMasterKey( algorithm: algorithm, key: masterKey )
                return masterKey
            }

            return nil
        }
    }

    fileprivate func setMasterKey(algorithm: MPAlgorithmVersion, key: MPMasterKey) {
        DispatchQueue.mpw.await {
            self.masterKeysCache[algorithm] = key
        }
    }

    fileprivate func createMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
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

    public var identicon : MPIdenticon {
        DispatchQueue.mpw.await {
            mpw_identicon( self.fullName, self.masterPassword )
        }
    }

    public func toKeychain() -> Promise<MPKeychainKeyFactory> {
        MPKeychainKeyFactory( fullName: self.fullName ).saveMasterKeys( from: self.masterPassword )
    }

    // MARK: --- Private ---

    fileprivate override func createMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        mpw_master_key( self.fullName, self.masterPassword, algorithm )
    }
}

public class MPBufferKeyFactory: MPKeyFactory {
    private let algorithm: MPAlgorithmVersion

    // MARK: --- Life ---

    public init(fullName: String, masterKey: MPMasterKey, algorithm: MPAlgorithmVersion) {
        self.algorithm = algorithm
        super.init( fullName: fullName )

        self.setMasterKey( algorithm: algorithm, key: masterKey )
    }
}

public class MPKeychainKeyFactory: MPKeyFactory {
    public let context = LAContext()

    // MARK: --- Life ---

    public override init(fullName: String) {
        super.init( fullName: fullName )

        self.context.touchIDAuthenticationAllowableReuseDuration = 2
        if #available( iOS 11.0, * ) {
            self.context.localizedReason = "Authenticate for: \(fullName) [context]"
        }
        self.context.localizedFallbackTitle = "fallback"
        if #available( iOS 10.0, * ) {
            self.context.localizedCancelTitle = "cancel"
        }
    }

    // MARK: --- Interface ---

    public var factor: Factor {
        guard self.context.canEvaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, error: nil )
        else { return .none }

        guard #available( iOS 11.0, * )
        else { return .biometricTouch }

        switch self.context.biometryType {
            case .none:
                return .none

            case .touchID:
                return .biometricTouch

            case .faceID:
                return .biometricFace

            @unknown default:
                wrn( "Unsupported biometry type: %@", self.context.biometryType )
                return .none
        }
    }

    public func hasKey(algorithm: MPAlgorithmVersion) -> Bool {
        self.factor != .none && MPKeychain.hasKey( for: self.fullName, algorithm: algorithm, biometrics: true )
    }

    public func purgeKeys() {
        for algorithm in MPAlgorithmVersion.allCases {
            MPKeychain.deleteKey( for: self.fullName, algorithm: algorithm, biometrics: true )
        }
    }

    // MARK: --- Private ---

    fileprivate override func createMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        do {
            return try MPKeychain.loadKey( for: self.fullName, algorithm: algorithm, biometrics: true, context: self.context ).await()
        }
        catch {
            mperror( title: "Biometric Authentication Failed", error: error )
            return nil
        }
    }

    fileprivate func saveMasterKeys(from masterPassword: String) -> Promise<MPKeychainKeyFactory> {
        DispatchQueue.mpw.promised {
            var promise = Promise( .success( () ) )

            for algorithm in MPAlgorithmVersion.allCases {
                if let masterKey = mpw_master_key( self.fullName, masterPassword, algorithm ) {
                    self.setMasterKey( algorithm: algorithm, key: masterKey )

                    promise = promise.and(
                            MPKeychain.saveKey( for: self.fullName, algorithm: algorithm,
                                                keyFactory: self, biometrics: true, context: self.context ) )
                }
            }

            return promise.then { self }
        }
    }

    public enum Factor {
        case biometricTouch, biometricFace, none

        var icon: UIImage? {
            switch self {
                case .biometricTouch:
                    return UIImage( named: "icon_key" )

                case .biometricFace:
                    return UIImage( named: "icon_watched" )

                case .none:
                    return nil
            }
        }
    }
}
