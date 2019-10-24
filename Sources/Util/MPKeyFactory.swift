//
// Created by Maarten Billemont on 2019-10-10.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import LocalAuthentication

private var masterKeyFactories = [ String: MPKeyFactory ]()

public class MPKeyFactory {
    public let fullName: String

    init(fullName: String) {
        self.fullName = fullName
    }

    public func provide() -> MPMasterKeyProvider {
        DispatchQueue.mpw.await {
            masterKeyFactories[self.fullName] = self
        }
        return __masterKeyProvider
    }

    public func newMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        nil
    }
}

public class MPPasswordKeyFactory: MPKeyFactory {
    private let masterPassword: String
    private var masterKeys = [ MPAlgorithmVersion: MPMasterKey ]()

    public init(fullName: String, masterPassword: String) {
        self.masterPassword = masterPassword
        super.init( fullName: fullName )
    }

    deinit {
        for (_, masterKey) in self.masterKeys {
            masterKey.deallocate()
        }
    }

    public override func newMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        guard let masterKey = self.masterKeys[algorithm] ?? mpw_master_key( self.fullName, self.masterPassword, algorithm )
        else { return nil }

        self.masterKeys[algorithm] = masterKey
        let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
        providedMasterKey.initialize( from: masterKey, count: MPMasterKeySize )
        return UnsafePointer<UInt8>( providedMasterKey )
    }

    public func toKeychain() -> Promise<MPKeyFactory?> {
        let keychainKeyFactory = MPKeychainKeyFactory( fullName: self.fullName )
        return keychainKeyFactory.saveMasterKeys( from: self.masterPassword ).then { (success: Bool) -> MPKeyFactory? in
            success ? keychainKeyFactory: nil
        }
    }
}

public class MPBufferKeyFactory: MPKeyFactory {
    private let masterKey: MPMasterKey
    private let algorithm: MPAlgorithmVersion

    public init(fullName: String, masterKey: MPMasterKey, algorithm: MPAlgorithmVersion) {
        self.masterKey = masterKey
        self.algorithm = algorithm
        super.init( fullName: fullName )
    }

    deinit {
        self.masterKey.deallocate()
    }

    public override func newMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        guard self.algorithm == algorithm
        else { return nil }

        let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
        providedMasterKey.initialize( from: self.masterKey, count: MPMasterKeySize )
        return UnsafePointer<UInt8>( providedMasterKey )
    }
}

public class MPKeychainKeyFactory: MPKeyFactory {
    public let  context    = LAContext()
    private var masterKeys = [ MPAlgorithmVersion: MPMasterKey ]()

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

    deinit {
        for (_, masterKey) in self.masterKeys {
            masterKey.deallocate()
        }
    }

    public override func newMasterKey(algorithm: MPAlgorithmVersion) -> MPMasterKey? {
        guard let masterKey = self.masterKeys[algorithm] ??
                (try? MPKeychain.loadKey( for: self.fullName, algorithm: algorithm, context: self.context ).await())
        else { return nil }

        self.masterKeys[algorithm] = masterKey
        let providedMasterKey = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
        providedMasterKey.initialize( from: masterKey, count: MPMasterKeySize )
        return UnsafePointer<UInt8>( providedMasterKey )
    }

    func saveMasterKeys(from masterPassword: String) -> Promise<Bool> {
        DispatchQueue.mpw.promise { () -> Bool in
            for algorithm in MPAlgorithmVersion.allCases {
                if let masterKey = mpw_master_key( self.fullName, masterPassword, algorithm ) {
                    let keyFactory = MPBufferKeyFactory( fullName: self.fullName, masterKey: masterKey, algorithm: algorithm )
                    if !(try MPKeychain.saveKey( for: self.fullName, algorithm: algorithm, keyFactory: keyFactory, context: self.context )
                                       .await()) {
                        mperror( title: "Couldn't save master key in keychain." )
                        return false
                    }
                }
            }

            return true
        }
    }
}

private func __masterKeyProvider(_ algorithm: MPAlgorithmVersion, _ fullName: UnsafePointer<CChar>?) -> MPMasterKey? {
    DispatchQueue.mpw.await {
        String( safeUTF8: fullName ).flatMap { masterKeyFactories[$0] }?.newMasterKey( algorithm: algorithm )
    }
}
