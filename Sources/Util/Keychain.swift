//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import LocalAuthentication

public class Keychain {
    public static let shared = Keychain()

    private func keyQuery(for userName: String, algorithm: SpectreAlgorithm, context: LAContext) throws
        -> [CFString: Any] {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error
        ), error == nil
        else {
            throw AppError.issue(
                "Keychain unavailable", reason: "Keychain access control could not be created.",
                cause: error?.takeRetainedValue() as Error?
            )
        }

        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: [SpectreKeyPurpose.authentication.scope, algorithm.description]
                .compactMap { $0 }.joined(separator: "."),
            kSecAttrAccount: userName,
            kSecAttrAccessGroup: productGroup,
            kSecAttrAccessControl: accessControl,
            kSecUseDataProtectionKeychain: true,
            kSecUseAuthenticationContext: context,
        ]
    }

    public func keyStatus(for userName: String, algorithm: SpectreAlgorithm, context: LAContext)
        -> (present: Bool, available: Bool, status: OSStatus) {
        context.interactionNotAllowed = true
        guard var query = try? self.keyQuery(for: userName, algorithm: algorithm, context: context)
        else {
            return (present: false, available: false, status: errSecBadReq)
        }
        query[kSecReturnAttributes] = false
        query[kSecReturnData] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecItemNotFound
        else {
            return (present: false, available: false, status: status)
        }

        return (present: status != errSecItemNotFound, available: status == errSecSuccess, status: status)
    }

    public func deleteKey(for userName: String, algorithm: SpectreAlgorithm, context: LAContext) throws {
        let query = try self.keyQuery(for: userName, algorithm: algorithm, context: context)

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else { throw AppError.issue("Biometrics key not deleted", reason: userName, cause: status) }
    }

    public func loadKey(for userName: String, algorithm: SpectreAlgorithm, context: LAContext) throws
        -> UnsafePointer<SpectreUserKey> {
//        let spinner = await AlertController( title: "Biometrics Authentication",
//                                       message: "Please authenticate to access user key for:\n\(userName)",
//                                       content: UIActivityIndicatorView( style: .medium ) )
//        await spinner.show( dismissAutomatically: false )
//        defer { Task { @MainActor in spinner.dismiss() } }

        context.interactionNotAllowed = false
        var query = try self.keyQuery(for: userName, algorithm: algorithm, context: context)
        query[kSecReturnData] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess
        else { throw AppError.issue("Biometrics key denied", reason: userName, cause: status) }

        guard let data = result as? Data, data.count == MemoryLayout<SpectreUserKey>.size
        else { throw AppError.internal(reason: "Biometrics key not valid", details: userName) }

        let userKeyBytes = UnsafeMutablePointer<SpectreUserKey>.allocate(capacity: 1)
        data.withUnsafeBytes { userKeyBytes.initialize(to: $0.load(as: SpectreUserKey.self)) }
        return UnsafePointer(userKeyBytes)
    }

    public func saveKey(for userName: String, algorithm: SpectreAlgorithm, keyFactory: KeyFactory, context: LAContext) throws {
        let userKey = try keyFactory.newKey(for: algorithm)
        defer { userKey.deallocate() }

        let attributes: [CFString: Any] = [
            kSecValueData: Data(buffer: UnsafeBufferPointer(start: userKey, count: 1)),
            kSecAttrSynchronizable: false,
            kSecAttrLabel: "Key\(algorithm.description.uppercased()): \(userName)",
            kSecAttrDescription: "\(productName) user key (\(algorithm))",
        ]

        context.interactionNotAllowed = false
        let query  = try self.keyQuery(for: userName, algorithm: algorithm, context: context)
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes, uniquingKeysWith: { $1 }) as CFDictionary, nil)
        }
        guard status == errSecSuccess
        else { throw AppError.issue("Biometrics key not saved", reason: userName, cause: status) }
    }
}

extension Int32: @retroactive Error {}
extension OSStatus: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
            case errSecSuccess: "No error"
            case errSecUnimplemented: "Function or operation not implemented"
            case errSecDiskFull: "Disk Full error"
            case errSecIO: "I/O error"
            case errSecParam: "One or more parameters passed to a function were not valid"
            case errSecWrPerm: "Write permissions error"
            case errSecAllocate: "Failed to allocate memory"
            case errSecUserCanceled: "User canceled the operation"
            case errSecBadReq: "Bad parameter or invalid state for operation"
            case errSecInternalComponent: nil
            case errSecCoreFoundationUnknown: nil
            case errSecNotAvailable: "No keychain is available"
            case errSecReadOnly: "Read only error"
            case errSecAuthFailed: "Authorization/Authentication failed"
            case errSecNoSuchKeychain: "The keychain does not exist"
            case errSecInvalidKeychain: "The keychain is not valid"
            case errSecDuplicateKeychain: "A keychain with the same name already exists"
            case errSecDuplicateCallback: "The specified callback is already installed"
            case errSecInvalidCallback: "The specified callback is not valid"
            case errSecDuplicateItem: "The item already exists"
            case errSecItemNotFound: "The item cannot be found"
            case errSecBufferTooSmall: "The buffer is too small"
            case errSecDataTooLarge: "The data is too large"
            case errSecNoSuchAttr: "The attribute does not exist"
            case errSecInvalidItemRef: "The item reference is invalid"
            case errSecInvalidSearchRef: "The search reference is invalid"
            case errSecNoSuchClass: "The keychain item class does not exist"
            case errSecNoDefaultKeychain: "A default keychain does not exist"
            case errSecInteractionNotAllowed: "User interaction is not allowed"
            case errSecReadOnlyAttr: "The attribute is read only"
            case errSecWrongSecVersion: "The version is incorrect"
            case errSecKeySizeNotAllowed: "The key size is not allowed"
            case errSecNoStorageModule: "There is no storage module available"
            case errSecNoCertificateModule: "There is no certificate module available"
            case errSecNoPolicyModule: "There is no policy module available"
            case errSecInteractionRequired: "User interaction is required"
            case errSecDataNotAvailable: "The data is not available"
            case errSecDataNotModifiable: "The data is not modifiable"
            case errSecCreateChainFailed: "The attempt to create a certificate chain failed"
            case errSecACLNotSimple: "The access control list is not in standard simple form"
            case errSecPolicyNotFound: "The policy specified cannot be found"
            case errSecInvalidTrustSetting: "The specified trust setting is invalid"
            case errSecNoAccessForItem: "The specified item has no access control"
            case errSecInvalidOwnerEdit: "Invalid attempt to change the owner of this item"
            case errSecTrustNotAvailable: "No trust results are available"
            case errSecUnsupportedFormat: "Import/Export format unsupported"
            case errSecUnknownFormat: "Unknown format in import"
            case errSecKeyIsSensitive: "Key material must be wrapped for export"
            case errSecMultiplePrivKeys: "An attempt was made to import multiple private keys"
            case errSecPassphraseRequired: "Passphrase is required for import/export"
            case errSecInvalidPasswordRef: "The password reference was invalid"
            case errSecInvalidTrustSettings: "The Trust Settings Record was corrupted"
            case errSecNoTrustSettings: "No Trust Settings were found"
            case errSecPkcs12VerifyFailure: "MAC verification failed during PKCS12 Import"
            case errSecDecode: "Unable to decode the provided data"
            default: "Unknown status"
        }
    }

    public var failureReason: String? {
        switch self {
            case errSecSuccess: "errSecSuccess (\(self))"
            case errSecUnimplemented: "errSecUnimplemented (\(self))"
            case errSecDiskFull: "errSecDiskFull (\(self))"
            case errSecIO: "errSecIO (\(self))"
            case errSecParam: "errSecParam (\(self))"
            case errSecWrPerm: "errSecWrPerm (\(self))"
            case errSecAllocate: "errSecAllocate (\(self))"
            case errSecUserCanceled: "errSecUserCanceled (\(self))"
            case errSecBadReq: "errSecBadReq (\(self))"
            case errSecInternalComponent: "errSecInternalComponent (\(self))"
            case errSecCoreFoundationUnknown: "errSecCoreFoundationUnknown (\(self))"
            case errSecNotAvailable: "errSecNotAvailable (\(self))"
            case errSecReadOnly: "errSecReadOnly (\(self))"
            case errSecAuthFailed: "errSecAuthFailed (\(self))"
            case errSecNoSuchKeychain: "errSecNoSuchKeychain (\(self))"
            case errSecInvalidKeychain: "errSecInvalidKeychain (\(self))"
            case errSecDuplicateKeychain: "errSecDuplicateKeychain (\(self))"
            case errSecDuplicateCallback: "errSecDuplicateCallback (\(self))"
            case errSecInvalidCallback: "errSecInvalidCallback (\(self))"
            case errSecDuplicateItem: "errSecDuplicateItem (\(self))"
            case errSecItemNotFound: "errSecItemNotFound (\(self))"
            case errSecBufferTooSmall: "errSecBufferTooSmall (\(self))"
            case errSecDataTooLarge: "errSecDataTooLarge (\(self))"
            case errSecNoSuchAttr: "errSecNoSuchAttr (\(self))"
            case errSecInvalidItemRef: "errSecInvalidItemRef (\(self))"
            case errSecInvalidSearchRef: "errSecInvalidSearchRef (\(self))"
            case errSecNoSuchClass: "errSecNoSuchClass (\(self))"
            case errSecNoDefaultKeychain: "errSecNoDefaultKeychain (\(self))"
            case errSecInteractionNotAllowed: "errSecInteractionNotAllowed (\(self))"
            case errSecReadOnlyAttr: "errSecReadOnlyAttr (\(self))"
            case errSecWrongSecVersion: "errSecWrongSecVersion (\(self))"
            case errSecKeySizeNotAllowed: "errSecKeySizeNotAllowed (\(self))"
            case errSecNoStorageModule: "errSecNoStorageModule (\(self))"
            case errSecNoCertificateModule: "errSecNoCertificateModule (\(self))"
            case errSecNoPolicyModule: "errSecNoPolicyModule (\(self))"
            case errSecInteractionRequired: "errSecInteractionRequired (\(self))"
            case errSecDataNotAvailable: "errSecDataNotAvailable (\(self))"
            case errSecDataNotModifiable: "errSecDataNotModifiable (\(self))"
            case errSecCreateChainFailed: "errSecCreateChainFailed (\(self))"
            case errSecACLNotSimple: "errSecACLNotSimple (\(self))"
            case errSecPolicyNotFound: "errSecPolicyNotFound (\(self))"
            case errSecInvalidTrustSetting: "errSecInvalidTrustSetting (\(self))"
            case errSecNoAccessForItem: "errSecNoAccessForItem (\(self))"
            case errSecInvalidOwnerEdit: "errSecInvalidOwnerEdit (\(self))"
            case errSecTrustNotAvailable: "errSecTrustNotAvailable (\(self))"
            case errSecUnsupportedFormat: "errSecUnsupportedFormat (\(self))"
            case errSecUnknownFormat: "errSecUnknownFormat (\(self))"
            case errSecKeyIsSensitive: "errSecKeyIsSensitive (\(self))"
            case errSecMultiplePrivKeys: "errSecMultiplePrivKeys (\(self))"
            case errSecPassphraseRequired: "errSecPassphraseRequired (\(self))"
            case errSecInvalidPasswordRef: "errSecInvalidPasswordRef (\(self))"
            case errSecInvalidTrustSettings: "errSecInvalidTrustSettings (\(self))"
            case errSecNoTrustSettings: "errSecNoTrustSettings (\(self))"
            case errSecPkcs12VerifyFailure: "errSecPkcs12VerifyFailure (\(self))"
            case errSecDecode: "errSecDecode (\(self))"
            default: "unknown (\(self))"
        }
    }
}
