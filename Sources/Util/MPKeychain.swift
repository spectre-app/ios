//
// Created by Maarten Billemont on 2019-10-03.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit
import LocalAuthentication

public class MPKeychain {
    private static func userQuery(for fullName: String, algorithm: MPAlgorithmVersion, biometrics: Bool, context: LAContext? = nil) throws
                    -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "\(String( validate: mpw_purpose_scope( .authentication ) )!).\(algorithm)",
            kSecAttrAccount: fullName,
            kSecUseOperationPrompt: "Access \(fullName)'s master key.",
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
                throw MPError.issue( error, title: "Biometrics Not Supported", details: "Could not create biometric access controls on this device." )
            }
            else {
                throw MPError.internal( details: "Unexpected issue creating biometric access controls." )
            }
        }

        return query
    }

    @discardableResult
    public static func saveKey(for fullName: String, algorithm: MPAlgorithmVersion, keyFactory: MPKeyFactory, biometrics: Bool, context: LAContext)
                    -> Promise<Void> {
        DispatchQueue.mpw.promise {
            assert( !Thread.isMainThread, "Keychain authentication from main thread might lead to deadlocks." )

            let query = try self.userQuery( for: fullName, algorithm: algorithm, biometrics: biometrics, context: context )
            guard let masterKey = keyFactory.newMasterKey( algorithm: algorithm )
            else { throw MPError.internal( details: "Cannot save master key since key provider cannot provide one." ) }
            defer { masterKey.deallocate() }

            let update: [CFString: Any] = [
                kSecValueData: Data( bytes: masterKey, count: MPMasterKeySize ),
                kSecAttrSynchronizable: false,
                kSecAttrLabel: "Key\(algorithm.description.uppercased()): \(fullName)",
                kSecAttrDescription: "\(productName) master key (\(algorithm))",
            ]

            var status = SecItemUpdate( query as CFDictionary, update as CFDictionary )
            if status == errSecItemNotFound {
                status = SecItemAdd( query.merging( update, uniquingKeysWith: { $1 } ) as CFDictionary, nil )
            }

            if status != errSecSuccess {
                throw MPError.issue( status, title: "Biometrics Denied Saving Key" )
            }
        }
    }

    @discardableResult
    public static func deleteKey(for fullName: String, algorithm: MPAlgorithmVersion, biometrics: Bool)
                    -> Promise<Void> {
        DispatchQueue.mpw.promise {
            let query  = try self.userQuery( for: fullName, algorithm: algorithm, biometrics: biometrics )
            let status = SecItemDelete( query as CFDictionary )
            if status != errSecSuccess, status != errSecItemNotFound {
                throw MPError.issue( status, title: "Biometrics Denied Deleting Key" )
            }
        }
    }

    public static func hasKey(for fullName: String, algorithm: MPAlgorithmVersion, biometrics: Bool)
                    -> Bool {
        guard var query = try? self.userQuery( for: fullName, algorithm: algorithm, biometrics: biometrics )
        else { return false }
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail

        let status = SecItemCopyMatching( query as CFDictionary, nil )
        if status == errSecSuccess || status == errSecInteractionNotAllowed {
            return true
        }

        if status != errSecItemNotFound {
            wrn( "Issue looking for master key in keychain: %@", status )
        }

        return false
    }

    public static func loadKey(for fullName: String, algorithm: MPAlgorithmVersion, biometrics: Bool, context: LAContext) throws
                    -> Promise<MPMasterKey> {
        DispatchQueue.mpw.promise {
            assert( !Thread.isMainThread, "Keychain authentication from main thread might lead to deadlocks." )

            var query = try self.userQuery( for: fullName, algorithm: algorithm, biometrics: biometrics, context: context )
            query[kSecReturnData] = true

            let spinner = MPAlert( title: "Biometrics Authentication", message: "Please authenticate to access master key for:\n\(fullName)",
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

            throw MPError.issue( status, title: "Biometrics Denied Accessing Key" )
        }
    }
}

extension OSStatus: Error {
    var localizedDescription: String {
        switch self {
            case errSecSuccess:
                return "\(self): errSecSuccess: (No error)"
            case errSecUnimplemented:
                return "\(self): errSecUnimplemented: (Function or operation not implemented)"
            case errSecDiskFull:
                return "\(self): errSecDiskFull: (Disk Full error)"
            case errSecIO:
                return "\(self): errSecIO: (I/O error)"
            case errSecParam:
                return "\(self): errSecParam: (One or more parameters passed to a function were not valid)"
            case errSecWrPerm:
                return "\(self): errSecWrPerm: (Write permissions error)"
            case errSecAllocate:
                return "\(self): errSecAllocate: (Failed to allocate memory)"
            case errSecUserCanceled:
                return "\(self): errSecUserCanceled: (User canceled the operation)"
            case errSecBadReq:
                return "\(self): errSecBadReq: (Bad parameter or invalid state for operation)"
            case errSecInternalComponent:
                return "\(self): errSecInternalComponent"
            case errSecCoreFoundationUnknown:
                return "\(self): errSecCoreFoundationUnknown"
            case errSecNotAvailable:
                return "\(self): errSecNotAvailable: (No keychain is available)"
            case errSecReadOnly:
                return "\(self): errSecReadOnly: (Read only error)"
            case errSecAuthFailed:
                return "\(self): errSecAuthFailed: (Authorization/Authentication failed)"
            case errSecNoSuchKeychain:
                return "\(self): errSecNoSuchKeychain: (The keychain does not exist)"
            case errSecInvalidKeychain:
                return "\(self): errSecInvalidKeychain: (The keychain is not valid)"
            case errSecDuplicateKeychain:
                return "\(self): errSecDuplicateKeychain: (A keychain with the same name already exists)"
            case errSecDuplicateCallback:
                return "\(self): errSecDuplicateCallback: (The specified callback is already installed)"
            case errSecInvalidCallback:
                return "\(self): errSecInvalidCallback: (The specified callback is not valid)"
            case errSecDuplicateItem:
                return "\(self): errSecDuplicateItem: (The item already exists)"
            case errSecItemNotFound:
                return "\(self): errSecItemNotFound: (The item cannot be found)"
            case errSecBufferTooSmall:
                return "\(self): errSecBufferTooSmall: (The buffer is too small)"
            case errSecDataTooLarge:
                return "\(self): errSecDataTooLarge: (The data is too large)"
            case errSecNoSuchAttr:
                return "\(self): errSecNoSuchAttr: (The attribute does not exist)"
            case errSecInvalidItemRef:
                return "\(self): errSecInvalidItemRef: (The item reference is invalid)"
            case errSecInvalidSearchRef:
                return "\(self): errSecInvalidSearchRef: (The search reference is invalid)"
            case errSecNoSuchClass:
                return "\(self): errSecNoSuchClass: (The keychain item class does not exist)"
            case errSecNoDefaultKeychain:
                return "\(self): errSecNoDefaultKeychain: (A default keychain does not exist)"
            case errSecInteractionNotAllowed:
                return "\(self): errSecInteractionNotAllowed: (User interaction is not allowed)"
            case errSecReadOnlyAttr:
                return "\(self): errSecReadOnlyAttr: (The attribute is read only)"
            case errSecWrongSecVersion:
                return "\(self): errSecWrongSecVersion: (The version is incorrect)"
            case errSecKeySizeNotAllowed:
                return "\(self): errSecKeySizeNotAllowed: (The key size is not allowed)"
            case errSecNoStorageModule:
                return "\(self): errSecNoStorageModule: (There is no storage module available)"
            case errSecNoCertificateModule:
                return "\(self): errSecNoCertificateModule: (There is no certificate module available)"
            case errSecNoPolicyModule:
                return "\(self): errSecNoPolicyModule: (There is no policy module available)"
            case errSecInteractionRequired:
                return "\(self): errSecInteractionRequired: (User interaction is required)"
            case errSecDataNotAvailable:
                return "\(self): errSecDataNotAvailable: (The data is not available)"
            case errSecDataNotModifiable:
                return "\(self): errSecDataNotModifiable: (The data is not modifiable)"
            case errSecCreateChainFailed:
                return "\(self): errSecCreateChainFailed: (The attempt to create a certificate chain failed)"
            case errSecACLNotSimple:
                return "\(self): errSecACLNotSimple: (The access control list is not in standard simple form)"
            case errSecPolicyNotFound:
                return "\(self): errSecPolicyNotFound: (The policy specified cannot be found)"
            case errSecInvalidTrustSetting:
                return "\(self): errSecInvalidTrustSetting: (The specified trust setting is invalid)"
            case errSecNoAccessForItem:
                return "\(self): errSecNoAccessForItem: (The specified item has no access control)"
            case errSecInvalidOwnerEdit:
                return "\(self): errSecInvalidOwnerEdit: (Invalid attempt to change the owner of this item)"
            case errSecTrustNotAvailable:
                return "\(self): errSecTrustNotAvailable: (No trust results are available)"
            case errSecUnsupportedFormat:
                return "\(self): errSecUnsupportedFormat: (Import/Export format unsupported)"
            case errSecUnknownFormat:
                return "\(self): errSecUnknownFormat: (Unknown format in import)"
            case errSecKeyIsSensitive:
                return "\(self): errSecKeyIsSensitive: (Key material must be wrapped for export)"
            case errSecMultiplePrivKeys:
                return "\(self): errSecMultiplePrivKeys: (An attempt was made to import multiple private keys)"
            case errSecPassphraseRequired:
                return "\(self): errSecPassphraseRequired: (Passphrase is required for import/export)"
            case errSecInvalidPasswordRef:
                return "\(self): errSecInvalidPasswordRef: (The password reference was invalid)"
            case errSecInvalidTrustSettings:
                return "\(self): errSecInvalidTrustSettings: (The Trust Settings Record was corrupted)"
            case errSecNoTrustSettings:
                return "\(self): errSecNoTrustSettings: (No Trust Settings were found)"
            case errSecPkcs12VerifyFailure:
                return "\(self): errSecPkcs12VerifyFailure: (MAC verification failed during PKCS12 Import)"
            case errSecDecode:
                return "\(self): errSecDecode: (Unable to decode the provided data)"
            default:
                return "\(self): Unknown status"
        }
    }
}
