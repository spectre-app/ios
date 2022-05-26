// =============================================================================
// Created by Maarten Billemont on 2020-09-20.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import AuthenticationServices

final class AutoFill {
    public static let shared = AutoFill()

    private let semaphore = DispatchQueue( label: "\(productName): AutoFill", qos: .utility )
    private var credentials: Set<Credential> {
        didSet {
            guard oldValue != self.credentials
            else { return }

            ASCredentialIdentityStore.shared.getState { state in
                self.semaphore.await { [unowned self] in
                    // If extension is disabled credentials in the store got purged by the system: reflect that in our cache.
                    guard state.isEnabled
                    else {
                        // dbg( "autofill: clearing" )
                        ASCredentialIdentityStore.shared.removeAllCredentialIdentities()
                        UserDefaults.shared.removeObject( forKey: "autofill.credentials" )
                        self.credentials.removeAll()
                        return
                    }

                    if !state.supportsIncrementalUpdates {
                        let allCredentials = self.credentials.flatMap { $0.identities() }
                        // dbg( "autofill: replacing:\n%@", allCredentials )
                        ASCredentialIdentityStore.shared.replaceCredentialIdentities( with: allCredentials ) { success, error in
                            if !success || error != nil {
                                mperror( title: "Cannot reset autofill credentials", details: allCredentials, error: error )
                            }
                        }
                        return
                    }
                    else {
                        let expiredCredentials = oldValue.subtracting( self.credentials ).flatMap { $0.identities() }
                        if !expiredCredentials.isEmpty {
                            // dbg( "autofill: removing:\n%@", expiredCredentials )
                            ASCredentialIdentityStore.shared.removeCredentialIdentities( expiredCredentials ) { success, error in
                                if !success || error != nil {
                                    mperror( title: "Cannot purge autofill credentials", details: expiredCredentials, error: error )
                                }
                            }
                        }

                        let insertedCredentials = self.credentials.subtracting( oldValue ).flatMap { $0.identities() }
                        if !insertedCredentials.isEmpty {
                            // dbg( "autofill: inserting:\n%@", insertedCredentials )
                            ASCredentialIdentityStore.shared.saveCredentialIdentities( insertedCredentials ) { success, error in
                                if !success || error != nil {
                                    mperror( title: "Cannot save autofill credentials", details: insertedCredentials, error: error )
                                }
                            }
                        }
                    }

                    UserDefaults.shared.set( self.credentials.map { $0.dictionary() }, forKey: "autofill.credentials" )
                }
            }
        }
    }

    init() {
        self.credentials = Set<Credential>( UserDefaults.shared.array( forKey: "autofill.credentials" )?.compactMap( {
            Credential( dictionary: $0 as? [String: String] )
        } ) ?? [] )

        ASCredentialIdentityStore.shared.getState { state in
            self.semaphore.await { [unowned self] in
                guard state.isEnabled
                else {
                    // dbg( "autofill: clearing" )
                    ASCredentialIdentityStore.shared.removeAllCredentialIdentities()
                    UserDefaults.shared.removeObject( forKey: "autofill.credentials" )
                    self.credentials.removeAll()
                    return
                }

                let allCredentials = self.credentials.flatMap { $0.identities() }
                // dbg( "autofill: replacing:\n%@", allCredentials )
                ASCredentialIdentityStore.shared.replaceCredentialIdentities( with: allCredentials ) { success, error in
                    if !success || error != nil {
                        mperror( title: "Cannot reset autofill credentials", details: allCredentials, error: error )
                    }
                }
            }
        }
    }

    public func seed<S: Sequence>(_ suppliers: S) where S.Element == CredentialSupplier {
        self.semaphore.await { [unowned self] in
            self.credentials = Set( suppliers.flatMap { $0.credentials ?? [] } )
        }
    }

    public func update(for supplier: CredentialSupplier) {
        self.semaphore.await { [unowned self] in
            self.credentials = self.credentials.filter { !$0.isSupplied( by: supplier ) }.union((supplier.credentials ?? []))
        }
    }

    // MARK: - Types

    class Credential: Hashable, CustomDebugStringConvertible {
        let userName: String
        let siteName: String
        let variants: [String]?

        var debugDescription: String {
            "<Credential: \(self.userName) :: \(self.siteName)>"
        }

        init(supplier: CredentialSupplier, siteName: String, url: String?) {
            self.userName = supplier.credentialOwner
            self.siteName = siteName

            var variants = Set<String>( [ siteName.domainName( .host ), siteName.domainName( .topPrivate ) ] )
            if let url = url {
                variants.formUnion( [ url, url.domainName( .host ), url.domainName( .topPrivate ) ] )
            }
            variants.remove( siteName )
            self.variants = Array( variants )
            LeakRegistry.shared.register( self )
        }

        init?(dictionary: [String: Any?]?) {
            guard let user = dictionary?["user"] as? String, let site = dictionary?["site"] as? String
            else { return nil }

            self.userName = user
            self.siteName = site
            self.variants = dictionary?["variants"] as? [String]
            LeakRegistry.shared.register( self )
        }

        func isSupplied(by supplier: CredentialSupplier) -> Bool {
            self.userName == supplier.credentialOwner
        }

        func identities() -> [ASPasswordCredentialIdentity] {
            var identities = [ ASPasswordCredentialIdentity(
                    serviceIdentifier: ASCredentialServiceIdentifier( identifier: self.siteName, type: .domain ),
                    user: self.userName, recordIdentifier: self.userName ) ]
            if let variants = self.variants {
                identities.append( contentsOf: variants.map {
                    ASPasswordCredentialIdentity(
                            serviceIdentifier: ASCredentialServiceIdentifier( identifier: $0, type: $0.contains( "://" ) ? .URL : .domain ),
                            user: self.userName, recordIdentifier: self.userName )
                } )
            }
            return identities
        }

        func dictionary() -> [String: Any?] {
            [
                "user": self.userName,
                "site": self.siteName,
                "variants": self.variants,
            ]
        }

        // MARK: - Hashable

        func hash(into hasher: inout Hasher) {
            hasher.combine( self.userName )
            hasher.combine( self.siteName )
            hasher.combine( self.variants )
        }

        static func == (lhs: Credential, rhs: Credential) -> Bool {
            lhs.userName == rhs.userName && lhs.siteName == rhs.siteName && lhs.variants == rhs.variants
        }
    }
}

protocol CredentialSupplier {
    var credentialOwner: String { get }
    var credentials:     [AutoFill.Credential]? { get }
}

extension CredentialSupplier {
    func credential(for serviceIdentifier: ASCredentialServiceIdentifier) -> AutoFill.Credential? {
        self.credentials?.first {
            $0.identities().contains { $0.serviceIdentifier.identifier == serviceIdentifier.identifier }
        }
    }
}
