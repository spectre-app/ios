//
// Created by Maarten Billemont on 2019-10-03.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public class MPKeychain {
    public static func userQuery(for fullName: String, biometrics: Bool) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "Saved Master Password",
            kSecAttrAccount: fullName,
            kSecAttrSynchronizable: false,
            kSecAttrIsSensitive: true,
            kSecAttrIsExtractable: false,
            kSecUseOperationPrompt: "Access \(fullName)'s master password.",
        ]
        if #available( iOS 13, * ) {
            query[kSecUseDataProtectionKeychain] = true
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
            }
            else {
                mperror( title: "Biometrics Unavailable", details: "Could not enable biometric access controls on this device." )
            }
        }

        return query
    }

    public static func saveKey(for fullName: String, masterKey: MPMasterKey) -> Bool {
        let masterKeyBytes = Data( bytes: masterKey, count: MPMasterKeySize )
        let query          = self.userQuery( for: fullName, biometrics: true )

        var status = SecItemUpdate( query as CFDictionary, [ kSecValueData: masterKeyBytes ] as CFDictionary )
        if (status == errSecItemNotFound) {
            var newItem = query
            newItem[kSecValueData] = masterKeyBytes
            status = SecItemAdd( newItem as CFDictionary, nil );
        }

        if (status != errSecSuccess) {
            mperror( title: "Keychain Error", context: query, details: "Couldn't add master key to the keychain:\n\(status.description)" );
        }

        return status == errSecSuccess;
    }

    public static func hasKey(for fullName: String) -> Bool {
        var query = self.userQuery( for: fullName, biometrics: true )
        query[kSecReturnAttributes] = true

        var cfResult: CFTypeRef?
        if SecItemCopyMatching( query as CFDictionary, &cfResult ) == errSecSuccess,
           let result = cfResult as? Dictionary<String, Any>, !result.isEmpty {
            return true
        }

        return false
    }

    public static func loadKey(for fullName: String) -> MPMasterKey? {
        var query = self.userQuery( for: fullName, biometrics: true )
        query[kSecReturnData] = true

        var cfResult: CFTypeRef?
        if SecItemCopyMatching( query as CFDictionary, &cfResult ) == errSecSuccess,
           let data = cfResult as? Data, data.count == MPMasterKeySize {
            let masterKeyBytes = UnsafeMutablePointer<UInt8>.allocate( capacity: MPMasterKeySize )
            masterKeyBytes.initialize( repeating: 0, count: MPMasterKeySize )
            data.copyBytes( to: masterKeyBytes, count: MPMasterKeySize )
            return MPMasterKey( masterKeyBytes )
        }

        return nil
    }
}

extension OSStatus {
    var description: String {
        switch self {
            case errSecSuccess:
                return "No error (errSecSuccess: \(self))."
            case errSecUnimplemented:
                return "Function or operation not implemented (errSecUnimplemented: \(self))."
            case errSecIO:
                return "I/O error (bummers) (errSecIO: \(self))."
            case errSecOpWr:
                return "file already open with with write permission (errSecOpWr: \(self))."
            case errSecParam:
                return "One or more parameters passed to the function were not valid (errSecParam: \(self))."
            case errSecAllocate:
                return "Failed to allocate memory (errSecAllocate: \(self))."
            case errSecUserCanceled:
                return "User canceled the operation (errSecUserCanceled: \(self))."
            case errSecBadReq:
                return "Bad parameter or invalid state for operation (errSecBadReq: \(self))."
            case errSecInternalComponent:
                return "[No documentation] (errSecInternalComponent: \(self))."
            case errSecNotAvailable:
                return "No keychain is available. You may need to restart your computer (errSecNotAvailable: \(self))."
            case errSecDuplicateItem:
                return "The specified item already exists in the keychain (errSecDuplicateItem: \(self))."
            case errSecItemNotFound:
                return "The specified item could not be found in the keychain (errSecItemNotFound: \(self))."
            case errSecInteractionNotAllowed:
                return "User interaction is not allowed (errSecInteractionNotAllowed: \(self))."
            case errSecDecode:
                return "Unable to decode the provided data (errSecDecode: \(self))."
            case errSecAuthFailed:
                return "The user name or passphrase you entered is not correct (errSecAuthFailed: \(self))."
            default:
                return "Unknown status (\(self))."
        }
    }
}
