//
// Created by Maarten Billemont on 2020-09-20.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import AuthenticationServices

final class AutoFill {
    public static let shared = AutoFill()

    private let queue = DispatchQueue( label: "\(productName): AutoFill", qos: .utility )
    private var credentials: Set<Credential> {
        didSet {
            guard oldValue != self.credentials
            else { return }

            dbg( "didSet credentials:\n%@ =>\n%@", oldValue, self.credentials )
            ASCredentialIdentityStore.shared.getState { state in
                // If extension is disabled, API is unavailable.
                guard state.isEnabled
                else { return }

                self.queue.sync { [unowned self] in
                    let expiredCredentials = oldValue.subtracting( self.credentials ).map { $0.identity() }
                    if !expiredCredentials.isEmpty {
                        dbg( "expire credentials:\n%@", expiredCredentials )
                        ASCredentialIdentityStore.shared.removeCredentialIdentities( expiredCredentials ) { success, error in
                            if !success || error != nil {
                                mperror( title: "Cannot purge autofill credentials.", details: expiredCredentials, error: error )
                            }
                            else {
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
                            }
                            else {
                                dbg( "inserted credentials:\n%@", insertedCredentials )
                            }
                        }
                    }
                }
            }

            UserDefaults.shared.set( self.credentials.map { $0.dictionary() }, forKey: "autofill.credentials" )
        }
    }

    init() {
        self.credentials = Set<Credential>( UserDefaults.shared.array( forKey: "autofill.credentials" )?.compactMap( {
            Credential( dictionary: $0 as? [String: String] )
        } ) ?? [] )

        ASCredentialIdentityStore.shared.getState { state in
            if state.isEnabled {
                ASCredentialIdentityStore.shared.replaceCredentialIdentities( with: self.credentials.map { $0.identity() } )
            }
        }
    }

    public func seed<S: Sequence>(_ suppliers: S) where S.Element == CredentialSupplier {
        suppliers.forEach { self.update( for: $0 ) }
    }

    public func update(for supplier: CredentialSupplier) {
        self.queue.sync { [unowned self] in
            let otherCredentials = self.credentials.filter { !$0.supplied( by: supplier ) }

            if let suppliedCredentials = supplier.credentials {
                self.credentials = otherCredentials.union( suppliedCredentials )
            }
            else {
                self.credentials = otherCredentials
            }
        }
    }

    // MARK: --- Types ---

    class Credential: Hashable, CustomDebugStringConvertible {
        let userName: String
        let siteName: String

        var debugDescription: String {
            "<Credential: \(self.userName) :: \(self.siteName)>"
        }

        init(supplier: CredentialSupplier, name: String) {
            self.userName = supplier.credentialOwner
            self.siteName = name
        }

        init?(dictionary: [String: String]?) {
            guard let user = dictionary?["user"], let site = dictionary?["site"]
            else { return nil }

            self.userName = user
            self.siteName = site
        }

        func supplied(by supplier: CredentialSupplier) -> Bool {
            self.userName == supplier.credentialOwner
        }

        func identity() -> ASPasswordCredentialIdentity {
            ASPasswordCredentialIdentity( serviceIdentifier: ASCredentialServiceIdentifier( identifier: self.siteName, type: .domain ),
                                          user: self.userName, recordIdentifier: self.userName )
        }

        func dictionary() -> [String: String] {
            [
                "user": self.userName,
                "site": self.siteName,
            ]
        }

        // MARK: --- Hashable ---

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.userName )
            hasher.combine( self.siteName )
        }

        static func ==(lhs: Credential, rhs: Credential) -> Bool {
            lhs.userName == rhs.userName && lhs.siteName == rhs.siteName
        }
    }
}

protocol CredentialSupplier {
    var credentialOwner: String { get }
    var credentials:     [AutoFill.Credential]? { get }
}
