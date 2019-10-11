//
// Created by Maarten Billemont on 2019-10-03.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation
import LocalAuthentication

public class MPKeychain {
    private static func userQuery(for fullName: String, algorithm: MPAlgorithmVersion, biometrics: Bool, context: LAContext? = nil) -> [CFString: Any]? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "\(String( safeUTF8: mpw_purpose_scope( .authentication ) )!).\(algorithm)",
            kSecAttrAccount: fullName,
            kSecUseOperationPrompt: "Access \(fullName)'s master key (\(algorithm)). [query]",
        ]
        if #available( iOS 13, * ) {
            query[kSecUseDataProtectionKeychain] = true
        }
        if let context = context,
           context.canEvaluatePolicy( biometrics ? .deviceOwnerAuthenticationWithBiometrics: .deviceOwnerAuthentication, error: nil ) {
            query[kSecUseAuthenticationContext] = context
        }

        if biometrics {
            let flags: SecAccessControlCreateFlags
            if #available( iOS 11.3, * ) {
                flags = .biometryCurrentSet
            }
            else {
                flags = .touchIDCurrentSet
            }
            var error: Unmanaged<CFError>?
            if let accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, flags, &error ), error == nil {
                query[kSecAttrAccessControl] = accessControl
            }
            else if let error = error?.takeRetainedValue() {
                mperror( title: "Biometrics Not Supported", details: "Could not create biometric access controls on this device.", error: error )
                return nil
            }
            else {
                mperror( title: "Biometrics Unavailable", details: "Could not enable biometric access controls on this device." )
                return nil
            }
        }

        return query
    }

    @discardableResult
    public static func saveKey(for fullName: String, algorithm: MPAlgorithmVersion, keyFactory: MPKeyFactory, context: LAContext) -> Promise<Bool> {
        DispatchQueue.mpw.promise { () -> Bool in
            assert( !Thread.isMainThread, "Keychain authentication from main thread might lead to deadlocks." )

            guard let query = self.userQuery( for: fullName, algorithm: algorithm, biometrics: true, context: context )
            else { return false }
            guard let masterKey = keyFactory.newMasterKey( algorithm: algorithm )
            else { return false }
            defer { masterKey.deallocate() }

            let update: [CFString: Any] = [
                kSecValueData: Data( bytes: masterKey, count: MPMasterKeySize ),
                kSecAttrSynchronizable: false,
                kSecAttrLabel: "Key\(algorithm.description.uppercased()): \(fullName)",
                kSecAttrDescription: "\(productName) master key (\(algorithm))",
            ]

            let spinner = MPAlert( title: "Biometrics Authentication", message: "Please authenticate to access key for:\n\(fullName)",
                                   content: UIActivityIndicatorView( style: .white ) )
            spinner.show( dismissAutomatically: false )
            defer { spinner.dismiss() }

            var status = SecItemUpdate( query as CFDictionary, update as CFDictionary )
            if status == errSecItemNotFound {
                status = SecItemAdd( query.merging( update, uniquingKeysWith: { $1 } ) as CFDictionary, nil )
            }

            if status != errSecSuccess {
                mperror( title: "Keychain Error",
                         context: "Couldn't add master key to the keychain.",
                         details: status.description )
            }

            return status == errSecSuccess
        }
    }

    @discardableResult
    public static func deleteKey(for fullName: String, algorithm: MPAlgorithmVersion) -> Bool {
        DispatchQueue.mpw.await {
            guard let query = self.userQuery( for: fullName, algorithm: algorithm, biometrics: true )
            else { return false }

            return SecItemDelete( query as CFDictionary ) == errSecSuccess
        }
    }

    public static func hasKey(for fullName: String, algorithm: MPAlgorithmVersion) -> Bool {
        DispatchQueue.mpw.await {
            guard var query = self.userQuery( for: fullName, algorithm: algorithm, biometrics: true )
            else { return false }
            query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail

            var cfResult: CFTypeRef?
            let status = SecItemCopyMatching( query as CFDictionary, &cfResult )
            if status == errSecSuccess || status == errSecInteractionNotAllowed {
                return true
            }

            if status != errSecItemNotFound {
                mperror( title: "Keychain Error", context: "Couldn't check for master key in the keychain.", details: status.description )
            }

            return false
        }
    }

    public static func loadKey(for fullName: String, algorithm: MPAlgorithmVersion, context: LAContext) throws -> Promise<MPMasterKey> {
        DispatchQueue.mpw.promise { () -> MPMasterKey in
            assert( !Thread.isMainThread, "Keychain authentication from main thread might lead to deadlocks." )

            guard var query = self.userQuery( for: fullName, algorithm: algorithm, biometrics: true, context: context )
            else { throw MPError.internal( details: "Biometrics keychain unavailable." ) }
            query[kSecReturnData] = true

            let spinner = MPAlert( title: "Biometrics Authentication", message: "Please authenticate to access key for:\n\(fullName)",
                                   content: UIActivityIndicatorView( style: .white ) )
            spinner.show( dismissAutomatically: false )
            defer { spinner.dismiss() }

            var cfResult: CFTypeRef?
            let status = SecItemCopyMatching( query as CFDictionary, &cfResult )
            if status == errSecSuccess, let data = cfResult as? Data, data.count == MPMasterKeySize {
                let masterKeyBytes = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
                masterKeyBytes.initialize( repeating: 0, count: MPMasterKeySize )
                data.copyBytes( to: masterKeyBytes, count: MPMasterKeySize )
                return MPMasterKey( masterKeyBytes )
            }
            else {
                if status != errSecItemNotFound {
                    mperror( title: "Keychain Error", context: "Couldn't load master key from the keychain.", details: status.description )
                }

                throw MPError.internal( details: status.description )
            }
        }
    }
}

extension OSStatus {
    var description: String {
        switch self {
            case errSecSuccess:
                return "errSecSuccess: (No error)"
            case errSecUnimplemented:
                return "errSecUnimplemented: (Function or operation not implemented)"
            case errSecDiskFull:
                return "errSecDiskFull: (Disk Full error)"
            case errSecIO:
                return "errSecIO: (I/O error)"
            case errSecParam:
                return "errSecParam: (One or more parameters passed to a function were not valid)"
            case errSecWrPerm:
                return "errSecWrPerm: (Write permissions error)"
            case errSecAllocate:
                return "errSecAllocate: (Failed to allocate memory)"
            case errSecUserCanceled:
                return "errSecUserCanceled: (User canceled the operation)"
            case errSecBadReq:
                return "errSecBadReq: (Bad parameter or invalid state for operation)"
            case errSecInternalComponent:
                return "errSecInternalComponent"
            case errSecCoreFoundationUnknown:
                return "errSecCoreFoundationUnknown"
            case errSecNotAvailable:
                return "errSecNotAvailable: (No keychain is available)"
            case errSecReadOnly:
                return "errSecReadOnly: (Read only error)"
            case errSecAuthFailed:
                return "errSecAuthFailed: (Authorization/Authentication failed)"
            case errSecNoSuchKeychain:
                return "errSecNoSuchKeychain: (The keychain does not exist)"
            case errSecInvalidKeychain:
                return "errSecInvalidKeychain: (The keychain is not valid)"
            case errSecDuplicateKeychain:
                return "errSecDuplicateKeychain: (A keychain with the same name already exists)"
            case errSecDuplicateCallback:
                return "errSecDuplicateCallback: (The specified callback is already installed)"
            case errSecInvalidCallback:
                return "errSecInvalidCallback: (The specified callback is not valid)"
            case errSecDuplicateItem:
                return "errSecDuplicateItem: (The item already exists)"
            case errSecItemNotFound:
                return "errSecItemNotFound: (The item cannot be found)"
            case errSecBufferTooSmall:
                return "errSecBufferTooSmall: (The buffer is too small)"
            case errSecDataTooLarge:
                return "errSecDataTooLarge: (The data is too large)"
            case errSecNoSuchAttr:
                return "errSecNoSuchAttr: (The attribute does not exist)"
            case errSecInvalidItemRef:
                return "errSecInvalidItemRef: (The item reference is invalid)"
            case errSecInvalidSearchRef:
                return "errSecInvalidSearchRef: (The search reference is invalid)"
            case errSecNoSuchClass:
                return "errSecNoSuchClass: (The keychain item class does not exist)"
            case errSecNoDefaultKeychain:
                return "errSecNoDefaultKeychain: (A default keychain does not exist)"
            case errSecInteractionNotAllowed:
                return "errSecInteractionNotAllowed: (User interaction is not allowed)"
            case errSecReadOnlyAttr:
                return "errSecReadOnlyAttr: (The attribute is read only)"
            case errSecWrongSecVersion:
                return "errSecWrongSecVersion: (The version is incorrect)"
            case errSecKeySizeNotAllowed:
                return "errSecKeySizeNotAllowed: (The key size is not allowed)"
            case errSecNoStorageModule:
                return "errSecNoStorageModule: (There is no storage module available)"
            case errSecNoCertificateModule:
                return "errSecNoCertificateModule: (There is no certificate module available)"
            case errSecNoPolicyModule:
                return "errSecNoPolicyModule: (There is no policy module available)"
            case errSecInteractionRequired:
                return "errSecInteractionRequired: (User interaction is required)"
            case errSecDataNotAvailable:
                return "errSecDataNotAvailable: (The data is not available)"
            case errSecDataNotModifiable:
                return "errSecDataNotModifiable: (The data is not modifiable)"
            case errSecCreateChainFailed:
                return "errSecCreateChainFailed: (The attempt to create a certificate chain failed)"
            case errSecACLNotSimple:
                return "errSecACLNotSimple: (The access control list is not in standard simple form)"
            case errSecPolicyNotFound:
                return "errSecPolicyNotFound: (The policy specified cannot be found)"
            case errSecInvalidTrustSetting:
                return "errSecInvalidTrustSetting: (The specified trust setting is invalid)"
            case errSecNoAccessForItem:
                return "errSecNoAccessForItem: (The specified item has no access control)"
            case errSecInvalidOwnerEdit:
                return "errSecInvalidOwnerEdit: (Invalid attempt to change the owner of this item)"
            case errSecTrustNotAvailable:
                return "errSecTrustNotAvailable: (No trust results are available)"
            case errSecUnsupportedFormat:
                return "errSecUnsupportedFormat: (Import/Export format unsupported)"
            case errSecUnknownFormat:
                return "errSecUnknownFormat: (Unknown format in import)"
            case errSecKeyIsSensitive:
                return "errSecKeyIsSensitive: (Key material must be wrapped for export)"
            case errSecMultiplePrivKeys:
                return "errSecMultiplePrivKeys: (An attempt was made to import multiple private keys)"
            case errSecPassphraseRequired:
                return "errSecPassphraseRequired: (Passphrase is required for import/export)"
            case errSecInvalidPasswordRef:
                return "errSecInvalidPasswordRef: (The password reference was invalid)"
            case errSecInvalidTrustSettings:
                return "errSecInvalidTrustSettings: (The Trust Settings Record was corrupted)"
            case errSecNoTrustSettings:
                return "errSecNoTrustSettings: (No Trust Settings were found)"
            case errSecPkcs12VerifyFailure:
                return "errSecPkcs12VerifyFailure: (MAC verification failed during PKCS12 Import)"
            case errSecDecode:
                return "errSecDecode: (Unable to decode the provided data)"
            default:
                return "Unknown status (\(self))."
        }
    }
}
