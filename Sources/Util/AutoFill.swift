//
// Copyright (c) 2011-2025 Maarten Billemont. Spectre is free software licensed under the GNU GPLv3.
//

import AuthenticationServices
import OrderedCollections

final actor AutoFill {
    static let shared = AutoFill()

    private let semaphore = DispatchQueue(label: "\(productName): AutoFill", qos: .utility)
    private var credentials: Set<Credential> {
        didSet {
            guard oldValue != self.credentials
            else { return }

            Task {
                let state = await ASCredentialIdentityStore.shared.state()
                // If extension is disabled credentials in the store got purged by the system: reflect that in our cache.
                guard state.isEnabled
                else {
                    dbg("autofill: clearing")
                    do {
                        try await ASCredentialIdentityStore.shared.removeAllCredentialIdentities()
                    }
                    catch {
                        err("Cannot clear autofill credentials", data: error)
                    }
                    UserDefaults.shared.removeObject(forKey: "autofill.credentials")
                    self.credentials.removeAll()
                    return
                }

                if !state.supportsIncrementalUpdates {
                    let allCredentials = self.credentials
                    dbg("autofill: replacing: \(allCredentials.count)")
                    do {
                        try await ASCredentialIdentityStore.shared.replaceCredentialIdentities(allCredentials.flatMap(\.identities))
                    }
                    catch {
                        err("Cannot reset autofill credentials", data: allCredentials, error)
                    }
                    return
                }
                else {
                    let expiredCredentials = oldValue.subtracting(self.credentials)
                    if !expiredCredentials.isEmpty {
                        dbg("autofill: removing: \(expiredCredentials.count)")
                        do {
                            try await ASCredentialIdentityStore.shared.removeCredentialIdentities(expiredCredentials.flatMap(\.identities))
                        }
                        catch {
                            err("Cannot purge autofill credentials", data: expiredCredentials, error)
                        }
                    }

                    let insertedCredentials = self.credentials.subtracting(oldValue)
                    if !insertedCredentials.isEmpty {
                        dbg("autofill: inserting: \(insertedCredentials.count)")
                        do {
                            try await ASCredentialIdentityStore.shared.saveCredentialIdentities(insertedCredentials.flatMap(\.identities))
                        }
                        catch {
                            err("Cannot save autofill credentials", data: insertedCredentials, error)
                        }
                    }
                }

                UserDefaults.shared.set(self.credentials.map(\.dictionary), forKey: "autofill.credentials")
            }
        }
    }

    init() {
        self.credentials = Set(
            UserDefaults.shared.array(forKey: "autofill.credentials")?.compactMap {
                Credential(dictionary: $0 as? [String: Any])
            } ?? [])

        Task.detached {
            await self.restoreCredentials()
        }
    }

    private func restoreCredentials() async {
        let state = await ASCredentialIdentityStore.shared.state()

        guard state.isEnabled
        else {
            dbg("autofill: clearing")
            UserDefaults.shared.removeObject(forKey: "autofill.credentials")
            self.credentials.removeAll()
            return
        }

        let allCredentials = self.credentials
        dbg("autofill: replacing: \(allCredentials.count)")
        // swiftlint:disable:next statement_position - FIXME: https://github.com/realm/SwiftLint/issues/4632
        do { try await ASCredentialIdentityStore.shared.replaceCredentialIdentities(allCredentials.flatMap(\.identities)) }
        catch { err("Cannot restore autofill credentials", data: allCredentials, error) }
    }

    func seed(_ suppliers: some Sequence<CredentialSupplier>) {
        self.credentials = Set(suppliers.flatMap { $0.credentials ?? [] })
    }

    func update(for supplier: CredentialSupplier) {
        self.credentials = self.credentials.filter { !$0.isSupplied(by: supplier) }.union(supplier.credentials ?? [])
    }

    // MARK: - Types

    struct Credential: Hashable, CustomDebugStringConvertible {
        let userRank: Int
        let userName: String
        let siteName: String
        private let variants: OrderedSet<String>

        var debugDescription: String {
            "<Credential: \(self.userName) :: \(self.siteName) -> \(self.variants)>"
        }

        init(supplier: CredentialSupplier, siteName: String, url: String?, domains: some Collection<String>) {
            self.userRank = supplier.credentialOwnerRank
            self.userName = supplier.credentialOwnerName
            self.siteName = siteName
            self.variants = .init(
                siteName.variantNames
                    .union(url?.variantNames ?? [])
                    .union(domains.flatMap(\.variantNames))
                    .sorted(),
            )
        }

        init?(dictionary: [String: Any]?) {
            guard let rank = dictionary?["rank"] as? Int, let user = dictionary?["user"] as? String,
                  let site = dictionary?["site"] as? String
            else { return nil }

            self.userRank = rank
            self.userName = user
            self.siteName = site
            self.variants = .init(dictionary?["variants"] as? [String] ?? [])
        }

        func isSupplied(by supplier: CredentialSupplier) -> Bool {
            self.userName == supplier.credentialOwnerName
        }

        func matchesService(name: String) -> Bool {
            name.variantNames.contains {
                self.variants.contains($0)
            }
        }

        var identities: [ASCredentialIdentity] {
            self.variants.map {
                using(
                    ASPasswordCredentialIdentity(
                        serviceIdentifier: ASCredentialServiceIdentifier(identifier: $0, type: $0.contains("://") ? .URL : .domain),
                        user: self.userName, recordIdentifier: self.userName,
                    ),
                ) { $0.rank = self.userRank }
            }
        }

        var dictionary: [String: Any] {
            [
                "rank": self.userRank,
                "user": self.userName,
                "site": self.siteName,
                "variants": Array(self.variants),
            ]
        }

        // MARK: - Hashable

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.userRank)
            hasher.combine(self.userName)
            hasher.combine(self.siteName)
            hasher.combine(self.variants)
        }

        static func == (lhs: Credential, rhs: Credential) -> Bool {
            lhs.userRank == rhs.userRank && lhs.userName == rhs.userName && lhs.siteName == rhs.siteName && lhs.variants == rhs.variants
        }
    }
}

protocol CredentialSupplier {
    var credentialOwnerName: String { get }
    var credentialOwnerRank: Int { get }
    var credentials: [AutoFill.Credential]? { get }
}

extension CredentialSupplier {
    func credential(for serviceIdentifier: ASCredentialServiceIdentifier) -> AutoFill.Credential? {
        self.credentials?.first {
            $0.matchesService(name: serviceIdentifier.identifier)
        }
    }
}
