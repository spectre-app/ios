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
            var error: Unmanaged<CFError>?
            if let accessControl = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error ), error == nil {
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
            guard let masterKey = keyFactory.newKey( for: algorithm )
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
        let context = LAContext()
        context.interactionNotAllowed = true
        guard var query = try? self.userQuery( for: fullName, algorithm: algorithm, biometrics: biometrics, context: context )
        else { return false }
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail

        // TODO: Can lock up evaluating LAContext
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

            let spinner = MPAlert(
                    title: "Biometrics Authentication", message: "Please authenticate to access master key for:\n\(fullName)",
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

extension OSStatus: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case errSecSuccess:
                return "No error"
            case errSecUnimplemented:
                return "Function or operation not implemented"
            case errSecDiskFull:
                return "Disk Full error"
            case errSecIO:
                return "I/O error"
            case errSecParam:
                return "One or more parameters passed to a function were not valid"
            case errSecWrPerm:
                return "Write permissions error"
            case errSecAllocate:
                return "Failed to allocate memory"
            case errSecUserCanceled:
                return "User canceled the operation"
            case errSecBadReq:
                return "Bad parameter or invalid state for operation"
            case errSecInternalComponent:
                return nil
            case errSecCoreFoundationUnknown:
                return nil
            case errSecNotAvailable:
                return "No keychain is available"
            case errSecReadOnly:
                return "Read only error"
            case errSecAuthFailed:
                return "Authorization/Authentication failed"
            case errSecNoSuchKeychain:
                return "The keychain does not exist"
            case errSecInvalidKeychain:
                return "The keychain is not valid"
            case errSecDuplicateKeychain:
                return "A keychain with the same name already exists"
            case errSecDuplicateCallback:
                return "The specified callback is already installed"
            case errSecInvalidCallback:
                return "The specified callback is not valid"
            case errSecDuplicateItem:
                return "The item already exists"
            case errSecItemNotFound:
                return "The item cannot be found"
            case errSecBufferTooSmall:
                return "The buffer is too small"
            case errSecDataTooLarge:
                return "The data is too large"
            case errSecNoSuchAttr:
                return "The attribute does not exist"
            case errSecInvalidItemRef:
                return "The item reference is invalid"
            case errSecInvalidSearchRef:
                return "The search reference is invalid"
            case errSecNoSuchClass:
                return "The keychain item class does not exist"
            case errSecNoDefaultKeychain:
                return "A default keychain does not exist"
            case errSecInteractionNotAllowed:
                return "User interaction is not allowed"
            case errSecReadOnlyAttr:
                return "The attribute is read only"
            case errSecWrongSecVersion:
                return "The version is incorrect"
            case errSecKeySizeNotAllowed:
                return "The key size is not allowed"
            case errSecNoStorageModule:
                return "There is no storage module available"
            case errSecNoCertificateModule:
                return "There is no certificate module available"
            case errSecNoPolicyModule:
                return "There is no policy module available"
            case errSecInteractionRequired:
                return "User interaction is required"
            case errSecDataNotAvailable:
                return "The data is not available"
            case errSecDataNotModifiable:
                return "The data is not modifiable"
            case errSecCreateChainFailed:
                return "The attempt to create a certificate chain failed"
            case errSecACLNotSimple:
                return "The access control list is not in standard simple form"
            case errSecPolicyNotFound:
                return "The policy specified cannot be found"
            case errSecInvalidTrustSetting:
                return "The specified trust setting is invalid"
            case errSecNoAccessForItem:
                return "The specified item has no access control"
            case errSecInvalidOwnerEdit:
                return "Invalid attempt to change the owner of this item"
            case errSecTrustNotAvailable:
                return "No trust results are available"
            case errSecUnsupportedFormat:
                return "Import/Export format unsupported"
            case errSecUnknownFormat:
                return "Unknown format in import"
            case errSecKeyIsSensitive:
                return "Key material must be wrapped for export"
            case errSecMultiplePrivKeys:
                return "An attempt was made to import multiple private keys"
            case errSecPassphraseRequired:
                return "Passphrase is required for import/export"
            case errSecInvalidPasswordRef:
                return "The password reference was invalid"
            case errSecInvalidTrustSettings:
                return "The Trust Settings Record was corrupted"
            case errSecNoTrustSettings:
                return "No Trust Settings were found"
            case errSecPkcs12VerifyFailure:
                return "MAC verification failed during PKCS12 Import"
            case errSecDecode:
                return "Unable to decode the provided data"
            default:
                return "Unknown status"
        }
    }

    public var failureReason: String? {
        switch self {
            case errSecSuccess:
                return "errSecSuccess (\(self))"
            case errSecUnimplemented:
                return "errSecUnimplemented (\(self))"
            case errSecDiskFull:
                return "errSecDiskFull (\(self))"
            case errSecIO:
                return "errSecIO (\(self))"
            case errSecParam:
                return "errSecParam (\(self))"
            case errSecWrPerm:
                return "errSecWrPerm (\(self))"
            case errSecAllocate:
                return "errSecAllocate (\(self))"
            case errSecUserCanceled:
                return "errSecUserCanceled (\(self))"
            case errSecBadReq:
                return "errSecBadReq (\(self))"
            case errSecInternalComponent:
                return "errSecInternalComponent (\(self))"
            case errSecCoreFoundationUnknown:
                return "errSecCoreFoundationUnknown (\(self))"
            case errSecNotAvailable:
                return "errSecNotAvailable (\(self))"
            case errSecReadOnly:
                return "errSecReadOnly (\(self))"
            case errSecAuthFailed:
                return "errSecAuthFailed (\(self))"
            case errSecNoSuchKeychain:
                return "errSecNoSuchKeychain (\(self))"
            case errSecInvalidKeychain:
                return "errSecInvalidKeychain (\(self))"
            case errSecDuplicateKeychain:
                return "errSecDuplicateKeychain (\(self))"
            case errSecDuplicateCallback:
                return "errSecDuplicateCallback (\(self))"
            case errSecInvalidCallback:
                return "errSecInvalidCallback (\(self))"
            case errSecDuplicateItem:
                return "errSecDuplicateItem (\(self))"
            case errSecItemNotFound:
                return "errSecItemNotFound (\(self))"
            case errSecBufferTooSmall:
                return "errSecBufferTooSmall (\(self))"
            case errSecDataTooLarge:
                return "errSecDataTooLarge (\(self))"
            case errSecNoSuchAttr:
                return "errSecNoSuchAttr (\(self))"
            case errSecInvalidItemRef:
                return "errSecInvalidItemRef (\(self))"
            case errSecInvalidSearchRef:
                return "errSecInvalidSearchRef (\(self))"
            case errSecNoSuchClass:
                return "errSecNoSuchClass (\(self))"
            case errSecNoDefaultKeychain:
                return "errSecNoDefaultKeychain (\(self))"
            case errSecInteractionNotAllowed:
                return "errSecInteractionNotAllowed (\(self))"
            case errSecReadOnlyAttr:
                return "errSecReadOnlyAttr (\(self))"
            case errSecWrongSecVersion:
                return "errSecWrongSecVersion (\(self))"
            case errSecKeySizeNotAllowed:
                return "errSecKeySizeNotAllowed (\(self))"
            case errSecNoStorageModule:
                return "errSecNoStorageModule (\(self))"
            case errSecNoCertificateModule:
                return "errSecNoCertificateModule (\(self))"
            case errSecNoPolicyModule:
                return "errSecNoPolicyModule (\(self))"
            case errSecInteractionRequired:
                return "errSecInteractionRequired (\(self))"
            case errSecDataNotAvailable:
                return "errSecDataNotAvailable (\(self))"
            case errSecDataNotModifiable:
                return "errSecDataNotModifiable (\(self))"
            case errSecCreateChainFailed:
                return "errSecCreateChainFailed (\(self))"
            case errSecACLNotSimple:
                return "errSecACLNotSimple (\(self))"
            case errSecPolicyNotFound:
                return "errSecPolicyNotFound (\(self))"
            case errSecInvalidTrustSetting:
                return "errSecInvalidTrustSetting (\(self))"
            case errSecNoAccessForItem:
                return "errSecNoAccessForItem (\(self))"
            case errSecInvalidOwnerEdit:
                return "errSecInvalidOwnerEdit (\(self))"
            case errSecTrustNotAvailable:
                return "errSecTrustNotAvailable (\(self))"
            case errSecUnsupportedFormat:
                return "errSecUnsupportedFormat (\(self))"
            case errSecUnknownFormat:
                return "errSecUnknownFormat (\(self))"
            case errSecKeyIsSensitive:
                return "errSecKeyIsSensitive (\(self))"
            case errSecMultiplePrivKeys:
                return "errSecMultiplePrivKeys (\(self))"
            case errSecPassphraseRequired:
                return "errSecPassphraseRequired (\(self))"
            case errSecInvalidPasswordRef:
                return "errSecInvalidPasswordRef (\(self))"
            case errSecInvalidTrustSettings:
                return "errSecInvalidTrustSettings (\(self))"
            case errSecNoTrustSettings:
                return "errSecNoTrustSettings (\(self))"
            case errSecPkcs12VerifyFailure:
                return "errSecPkcs12VerifyFailure (\(self))"
            case errSecDecode:
                return "errSecDecode (\(self))"
            default:
                return "unknown (\(self))"
        }
    }
}
