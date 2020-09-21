//
// Created by Maarten Billemont on 2020-09-20.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import AuthenticationServices

final class AutoFill {
    public static let shared = AutoFill()

    private var credentials = Set<Credential>() {
        didSet {
            dbg( "didSet credentials:\n%@ =>\n%@", oldValue, self.credentials )

            ASCredentialIdentityStore.shared.getState { state in
                // If extension is disabled, API is unavailable.
                guard state.isEnabled
                else { return }

                let expiredCredentials = oldValue.subtracting( self.credentials ).map { $0.identity() }
                if !expiredCredentials.isEmpty {
                    dbg( "expire credentials:\n%@", expiredCredentials )
                    ASCredentialIdentityStore.shared.removeCredentialIdentities( expiredCredentials ) { success, error in
                        if !success || error != nil {
                            mperror( title: "Cannot purge autofill credentials.", details: expiredCredentials, error: error )
                        } else {
                            dbg( "expired credentials:\n%@", expiredCredentials )
                        }
                    }
                }

                let insertedCredentials = self.credentials.subtracting( oldValue ).map { $0.identity() }
                if !insertedCredentials.isEmpty {
                    dbg( "insert credentials:\n%@", insertedCredentials )
                    ASCredentialIdentityStore.shared.saveCredentialIdentities( insertedCredentials ) { success, error in
                        if !success || error != nil {
                            mperror( title: "Cannot save autofill credentials.", details: insertedCredentials, error: error )
                        } else {
                            dbg( "inserted credentials:\n%@", insertedCredentials )
                        }
                    }
                }
            }
        }
    }

    init() {
        ASCredentialIdentityStore.shared.removeAllCredentialIdentities()
    }

    public func seed<S: Sequence>(_ suppliers: S) where S.Element == CredentialSupplier {
        suppliers.forEach { self.update( for: $0 ) }
    }

    public func update(for supplier: CredentialSupplier) {
        let otherCredentials = self.credentials.filter { !$0.supplied( by: supplier ) }

        if let suppliedCredentials = supplier.credentials {
            self.credentials = otherCredentials.union( suppliedCredentials )
        }
        else {
            self.credentials = otherCredentials
        }
    }

    // MARK: --- Types ---

    class Credential: Hashable {
        let hostName: String
        let siteName: String

        init(supplier: CredentialSupplier, name: String) {
            self.hostName = supplier.credentialHost
            self.siteName = name
        }

        func supplied(by supplier: CredentialSupplier) -> Bool {
            self.hostName == supplier.credentialHost
        }

        func identity() -> ASPasswordCredentialIdentity {
            ASPasswordCredentialIdentity( serviceIdentifier: ASCredentialServiceIdentifier( identifier: self.siteName, type: .domain ),
                                          user: self.hostName, recordIdentifier: self.hostName )
        }

        // MARK: --- Hashable ---

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.hostName )
            hasher.combine( self.siteName )
        }

        static func ==(lhs: Credential, rhs: Credential) -> Bool {
            lhs.hostName == rhs.hostName && lhs.siteName == rhs.siteName
        }
    }
}

protocol CredentialSupplier {
    var credentialHost: String { get }
    var credentials:    [AutoFill.Credential]? { get }
}
