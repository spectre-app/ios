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

            ASCredentialIdentityStore.shared.getState { state in
                // If extension is disabled credentials in the store got purged by the system: reflect that in our cache.
                guard state.isEnabled
                else {
                    UserDefaults.shared.removeObject( forKey: "autofill.credentials" )
                    self.credentials.removeAll()
                    return
                }

                self.queue.sync { [unowned self] in
                    let expiredCredentials = oldValue.subtracting( self.credentials ).map { $0.identity() }
                    if !expiredCredentials.isEmpty {
                        ASCredentialIdentityStore.shared.removeCredentialIdentities( expiredCredentials ) { success, error in
                            if !success || error != nil {
                                mperror( title: "Cannot purge autofill credentials.", details: expiredCredentials, error: error )
                            }
                        }
                    }

                    let insertedCredentials = self.credentials.subtracting( oldValue ).map { $0.identity() }
                    if !insertedCredentials.isEmpty {
                        ASCredentialIdentityStore.shared.saveCredentialIdentities( insertedCredentials ) { success, error in
                            if !success || error != nil {
                                mperror( title: "Cannot save autofill credentials.", details: insertedCredentials, error: error )
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
        self.credentials = Set( suppliers.flatMap { $0.credentials ?? [] } )
    }

    public func update(for supplier: CredentialSupplier) {
        self.queue.sync { [unowned self] in
            var otherCredentials = self.credentials.filter { !$0.isSupplied( by: supplier ) }
            if let suppliedCredentials = supplier.credentials {
                otherCredentials.formUnion( suppliedCredentials )
            }

            self.credentials = otherCredentials
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

        func isSupplied(by supplier: CredentialSupplier) -> Bool {
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
