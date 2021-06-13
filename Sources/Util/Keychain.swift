//==============================================================================
// Created by Maarten Billemont on 2019-10-03.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit
import LocalAuthentication

public class Keychain {
    private static func keyQuery(for userName: String, algorithm: SpectreAlgorithm, context: LAContext?) throws
                    -> [CFString: Any] {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error ), error == nil
        else { throw AppError.issue( error?.takeRetainedValue() as Error?, title: "Keychain Unavailable", details: "Keychain access control could not be created." ) }

        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: [ SpectreKeyPurpose.authentication.scope, algorithm.description ]
                    .compactMap { $0 }.joined( separator: "." ),
            kSecAttrAccount: userName,
            kSecAttrAccessGroup: productGroup,
            kSecAttrAccessControl: accessControl,
            kSecUseOperationPrompt: "Access \(userName)'s user key.",
        ]
        if #available( iOS 13, * ) {
            query[kSecUseDataProtectionKeychain] = true
        }

        if let context = context {
            var error: NSError?
            guard context.canEvaluatePolicy( .deviceOwnerAuthenticationWithBiometrics, error: &error ), error == nil
            else { throw AppError.issue( error, title: "Biometrics Unavailable", details: "Biometrics authentication is not available at this time." ) }

            query[kSecUseAuthenticationContext] = context
        }

        return query
    }

    public static func keyStatus(for userName: String, algorithm: SpectreAlgorithm, context: LAContext?)
                    -> (present: Bool, available: Bool, status: OSStatus) {
        guard var query = try? self.keyQuery( for: userName, algorithm: algorithm, context: context )
        else {
            return (present: false, available: false, status: errSecBadReq)
        }
        query[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail
        query[kSecReturnAttributes] = false
        query[kSecReturnData] = false

        let status = SecItemCopyMatching( query as CFDictionary, nil )
        guard status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecItemNotFound
        else {
            return (present: false, available: false, status: status)
        }

        return (present: status != errSecItemNotFound, available: status == errSecSuccess, status: status)
    }

    @discardableResult
    public static func deleteKey(for userName: String, algorithm: SpectreAlgorithm)
                    -> Promise<Void> {
        DispatchQueue.api.promise {
            let query = try self.keyQuery( for: userName, algorithm: algorithm, context: nil )

            let status = SecItemDelete( query as CFDictionary )
            guard status == errSecSuccess || status == errSecItemNotFound
            else { throw AppError.issue( status, title: "Biometrics Key Not Deleted", details: userName ) }
        }
    }

    public static func loadKey(for userName: String, algorithm: SpectreAlgorithm, context: LAContext)
                    -> Promise<UnsafePointer<SpectreUserKey>> {
        let spinner = AlertController( title: "Biometrics Authentication",
                                       message: "Please authenticate to access user key for:\n\(userName)",
                                       content: UIActivityIndicatorView( style: .white ) )
        spinner.show( dismissAutomatically: false )

        return DispatchQueue.api.promise {
            var query = try self.keyQuery( for: userName, algorithm: algorithm, context: context )
            query[kSecReturnData] = true

            var result: CFTypeRef?
            let status = SecItemCopyMatching( query as CFDictionary, &result )
            guard status == errSecSuccess
            else { throw AppError.issue( status, title: "Biometrics Key Denied", details: userName ) }

            guard let data = result as? Data, data.count == MemoryLayout<SpectreUserKey>.size
            else { throw AppError.internal( cause: "Biometrics Key Not Valid", details: userName ) }

            let userKeyBytes = UnsafeMutablePointer<SpectreUserKey>.allocate( capacity: 1 )
            data.withUnsafeBytes { userKeyBytes.initialize( to: $0.load( as: SpectreUserKey.self ) ) }
            return UnsafePointer( userKeyBytes )
        }.finally {
            spinner.dismiss()
        }
    }

    @discardableResult
    public static func saveKey(for userName: String, algorithm: SpectreAlgorithm, keyFactory: KeyFactory, context: LAContext)
                    -> Promise<Void> {
        keyFactory.newKey( for: algorithm ).promise( on: .api ) { userKey in
            defer { userKey.deallocate() }

            let attributes: [CFString: Any] = [
                kSecValueData: Data( buffer: UnsafeBufferPointer( start: userKey, count: 1 ) ),
                kSecAttrSynchronizable: false,
                kSecAttrLabel: "Key\(algorithm.description.uppercased()): \(userName)",
                kSecAttrDescription: "\(productName) user key (\(algorithm))",
            ]

            let query  = try self.keyQuery( for: userName, algorithm: algorithm, context: context )
            var status = SecItemUpdate( query as CFDictionary, attributes as CFDictionary )
            if status == errSecItemNotFound {
                status = SecItemAdd( query.merging( attributes, uniquingKeysWith: { $1 } ) as CFDictionary, nil )
            }
            guard status == errSecSuccess
            else { throw AppError.issue( status, title: "Biometrics Key Not Saved", details: userName ) }
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
