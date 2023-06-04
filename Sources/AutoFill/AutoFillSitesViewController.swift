// =============================================================================
// Created by Maarten Billemont on 2018-01-21.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import AuthenticationServices

class AutoFillSitesViewController: BaseSitesViewController {
    // MARK: - Life

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        defer {
            self.showCloseButton( track: .subject( "sites", action: "close" ) ) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            } longPressAction: {
                if AppConfig.shared.memoryProfiler {
                    AutoFillProviderController.shared?.reportLeaks()
                }
            }
        }

        var allServiceIdentifiers = [ ASCredentialServiceIdentifier ]()
        if let serviceIdentifier = AutoFillModel.shared.context.credentialIdentity?.serviceIdentifier {
            allServiceIdentifiers.append( serviceIdentifier )
        }
        if let serviceIdentifiers = AutoFillModel.shared.context.serviceIdentifiers {
            allServiceIdentifiers.append( contentsOf: serviceIdentifiers )
        }
        self.sitesTableView.preferredFilter = { site in
            allServiceIdentifiers.contains( where: {
                let serviceHost = URL( string: $0.identifier )?.host ?? $0.identifier
                return serviceHost.hasSuffix( site.siteName ) || site.siteName.hasSuffix( serviceHost )
            } )
        }
        self.sitesTableView.proposedSite = allServiceIdentifiers.first.flatMap {
            (URL( string: $0.identifier )?.host ?? $0.identifier).privateName
        }
        self.sitesTableView.siteActions = [
            .init( tracking: nil, title: "", icon: nil, appearance: [ .cell ], action: { _, _, _ in } ),
            .init( tracking: .subject( "sites.site", action: "fill" ),
                   title: "Fill", icon: .icon( "paper-plane-top" ), appearance: [ .cell, .menu, .primary ] ) {
                [unowned self] site, _, appearance in
                if site.url == nil,
                   let serviceURL = allServiceIdentifiers.filter( { $0.type == .URL } )
                                                         .compactMap( { URL( string: $0.identifier ) } ).first {
                    site.url = serviceURL.absoluteString
                }

                switch appearance {
                    case .cell:
                        self.completeRequest( site: site, trackingFrom: "site>cell" )
                    case .menu:
                        self.completeRequest( site: site, trackingFrom: "site>cell>menu" )
                    case .mode:
                        self.completeRequest( site: site, trackingFrom: "site>cell>mode" )
                    case .feature, .primary:
                        ()
                }
            },
        ]
    }

    // MARK: - Private

    func completeRequest(site: Site, trackingFrom: String) {
        Task {
            guard let extensionContext = self.extensionContext as? ASCredentialProviderExtensionContext
            else { return }

            let event = Tracker.shared.begin( track: .subject( "site", action: "use" ) )
            do {
                if let login = try await site.result( keyPurpose: .identification )?.task.value,
                   let password = try await site.result( keyPurpose: .authentication )?.task.value {
                    inf( "Autofilling manually: %@, for site: %@", login, site.siteName )
                    Feedback.shared.play( .activate )

                    site.use()
                    event.end(
                            [ "result": "success",
                              "from": trackingFrom,
                              "action": "fill",
                              "counter": "\(site.counter)",
                              "purpose": "\(SpectreKeyPurpose.identification)",
                              "type": "\(site.resultType)",
                              "algorithm": "\(site.algorithm)",
                              "entropy": await Attacker.entropy( type: site.resultType ) ??? (await Attacker.entropy( string: password )),
                            ] )

                    extensionContext.completeRequest( withSelectedCredential: .init( user: login, password: password ) ) { _ in
                        site.user?.save()
                    }
                }
            }
            catch {
                mperror( title: "Couldn't compute site result", error: error )
                event.end( [
                               "result": "failure",
                               "from": trackingFrom,
                               "action": "fill",
                               "error": error.localizedDescription,
                           ] )
            }
        }
    }
}
