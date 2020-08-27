//
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import LocalAuthentication

private var keyFactories = [ String: MPKeyFactory ]()

private func keyFactoryProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> MPMasterKey? {
    DispatchQueue.mpw.await {
        String( validate: fullName ).flatMap { keyFactories[$0] }?.newKey( for: algorithm )
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
        self.invalidate()
    }

    // MARK: --- Interface ---

    public func provide() -> MPMasterKeyProvider {
        DispatchQueue.mpw.await {
            keyFactories[self.fullName] = self
            return keyFactoryProvider
        }
    }

    public func invalidate() {
        DispatchQueue.mpw.await {
            self.masterKeysCache.forEach { $1.deallocate() }
            self.masterKeysCache.removeAll()
        }
    }

    public func newKey(for algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        DispatchQueue.mpw.await {
            guard let masterKey = self.getKey( for: algorithm )
            else { return nil }

            // Create a copy of the master key to be consumed by the caller.
            let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
            providedMasterKey.initialize( from: masterKey, count: MPMasterKeySize )
            return UnsafePointer<UInt8>( providedMasterKey )
        }
    }

    // MARK: --- Private ---

    private func getKey(for algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        DispatchQueue.mpw.await {
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

    fileprivate func setKey(_ key: MPMasterKey, algorithm: MPAlgorithmVersion) {
        DispatchQueue.mpw.await {
            self.masterKeysCache[algorithm] = key
        }
    }

    fileprivate func createKey(for algorithm: MPAlgorithmVersion) -> MPMasterKey? {
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
        DispatchQueue.mpw.await {
            mpw_identicon( self.fullName, self.masterPassword )
        }
    }

    public func toKeychain() -> Promise<MPKeychainKeyFactory> {
        MPKeychainKeyFactory( fullName: self.fullName )
                .saveKeys( MPAlgorithmVersion.allCases.map( { ($0, self.newKey( for: $0 )) } ) )
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        mpw_master_key( self.fullName, self.masterPassword, algorithm )
    }
}

public class MPBufferKeyFactory: MPKeyFactory {
    private let algorithm: MPAlgorithmVersion

    // MARK: --- Life ---

    public init(fullName: String, masterKey: MPMasterKey, algorithm: MPAlgorithmVersion) {
        self.algorithm = algorithm
        super.init( fullName: fullName )

        self.setKey( masterKey, algorithm: algorithm )
    }
}

public class MPKeychainKeyFactory: MPKeyFactory {
    public static var factor: Factor = {
        var error : NSError?
        defer {
            if let error = error {
                wrn("Biometrics unavailable: %@", error)
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

    private let context = LAContext()

    // MARK: --- Life ---

    public override init(fullName: String) {
        super.init( fullName: fullName )

        self.context.touchIDAuthenticationAllowableReuseDuration = 3
        self.context.localizedReason = "Unlock \(fullName)"
        self.context.localizedFallbackTitle = "Use Password"
    }

    // MARK: --- Interface ---

    public func hasKey(for algorithm: MPAlgorithmVersion) -> Bool {
        MPKeychainKeyFactory.factor != .biometricNone && MPKeychain.hasKey( for: self.fullName, algorithm: algorithm )
    }

    public func unlock() -> Promise<Void> {
        let promise = Promise<Void>()

        self.context.evaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlocking \(self.fullName)" ) { result, error in
            if let error = error {
                promise.finish( .failure( error ) )
            }
            else if !result {
                promise.finish( .failure( MPError.internal( details: "Biometrics authentication denied." ) ) )
            }
            else {
                promise.finish( .success( () ) )
            }
        }

        return promise
    }

    public func purgeKeys() {
        for algorithm in MPAlgorithmVersion.allCases {
            MPKeychain.deleteKey( for: self.fullName, algorithm: algorithm )
        }
        self.invalidate()
    }

    // MARK: --- Life ---

    public override func invalidate() {
        DispatchQueue.mpw.await { self.context.invalidate() }

        super.invalidate()
    }

    // MARK: --- Private ---

    fileprivate override func createKey(for algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        do {
            return try MPKeychain.loadKey( for: self.fullName, algorithm: algorithm, context: self.context ).await()
        }
        catch {
            mperror( title: "Biometric Authentication Failed", error: error )
            return nil
        }
    }

    fileprivate func saveKeys(_ items: [(MPAlgorithmVersion, MPMasterKey?)]) -> Promise<MPKeychainKeyFactory> {
        DispatchQueue.mpw.promised {
            var promise = Promise( .success( () ) )

            for item in items {
                if let key = item.1 {
                    self.setKey( key, algorithm: item.0 )
                    promise = promise.and(
                            MPKeychain.saveKey( for: self.fullName, algorithm: item.0, keyFactory: self, context: self.context ) )
                }
            }

            return promise.then { self }
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
