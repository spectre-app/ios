//
// Created by Maarten Billemont on 2021-08-05.
// Copyright (c) 2021 Lyndir. All rights reserved.
//

import Foundation
import SafariServices
import StoreKit

enum Action: String, CaseIterable {
    case `import`, web, review, store, update

    static func open(url: URL, in viewController: UIViewController) -> Bool {
        guard let components = URLComponents( url: url, resolvingAgainstBaseURL: false ), components.scheme == "spectre"
        else { return false }

        return self.allCases.first { $0.rawValue == components.path }?.open( components: components, in: viewController ) ?? false
    }

    private func open(components: URLComponents, in viewController: UIViewController) -> Bool {
        switch self {
            case .import:
                // spectre:import?data=<export>
                guard let data = components.queryItems?.first( where: { $0.name == "data" } )?.value?.data( using: .utf8 )
                else {
                    wrn( "Import URL missing data parameter. [>PII]" )
                    pii( "[>] URL: %@", components.url )
                    return false
                }

                Marshal.shared.import( data: data, viewController: viewController ).then {
                    if case .failure(let error) = $0 {
                        mperror( title: "Couldn't import user", error: error )
                    }
                }
                return true

            case .web:
                // spectre:web?url=<url>
                guard components.verifySignature()
                else {
                    wrn( "Untrusted. [>PII]" )
                    pii( "[>] URL: %@", components.url )
                    return false
                }
                let openString = components.queryItems?.first( where: { $0.name == "url" } )?.value ?? "https://spectre.app"
                guard let openURL = URL( string: openString )
                else {
                    wrn( "Cannot open malformed URL. [>PII]" )
                    pii( "[>] Open URL: %@", openString )
                    return false
                }

                viewController.present( SFSafariViewController( url: openURL ), animated: true )
                return true

            case .review:
                // spectre:review
                guard components.verifySignature()
                else {
                    wrn( "Untrusted: %@", components.url )
                    return false
                }

                SKStoreReviewController.requestReview()
                return true

            case .store:
                // spectre:store[?id=<appleid>]
                guard components.verifySignature()
                else {
                    wrn( "Untrusted. [>PII]" )
                    pii( "[>] URL: %@", components.url )
                    return false
                }

                let id = (components.queryItems?.first( where: { $0.name == "id" } )?.value as NSString?)?.integerValue
                AppStore.shared.presentStore( appleID: id, in: viewController )
                return true

            case .update:
                // spectre:update[?id=<appleid>[&build=<version>]]
                guard components.verifySignature()
                else {
                    wrn( "Untrusted. [>PII]" )
                    pii( "[>] URL: %@", components.url )
                    return false
                }

                let id = (components.queryItems?.first( where: { $0.name == "id" } )?.value as NSString?)?.integerValue
                let build = components.queryItems?.first( where: { $0.name == "build" } )?.value
                AppStore.shared.isUpToDate( appleID: id, buildVersion: build ).then {
                    do {
                        let result = try $0.get()
                        if result.upToDate {
                            AlertController( title: "Your \(productName) app is up-to-date!", message: result.buildVersion,
                                             details: "build[\(result.buildVersion)] > store[\(result.storeVersion)]" )
                                    .show()
                        }
                        else {
                            inf( "%@ is outdated: build[%@] < store[%@]", productName, result.buildVersion, result.storeVersion )
                            AppStore.shared.presentStore( in: viewController )
                        }
                    }
                    catch {
                        mperror( title: "Couldn't check for updates", error: error )
                    }
                }
                return true
        }
    }
}
