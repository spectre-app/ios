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
        self.backgroundView.mode = .panel
        self.backgroundView.layoutMargins.bottom = 40
        self.backgroundView.layer => \.shadowColor => Theme.current.color.shadow
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = .on
        self.backgroundView.layer.shadowOffset = .zero
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.masksToBounds = true

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
                return serviceHost.contains( site.siteName ) || site.siteName.contains( serviceHost )
            } )
        }
        self.sitesTableView.proposedSite = allServiceIdentifiers.first.flatMap {
            (URL( string: $0.identifier )?.host ?? $0.identifier).domainName( .topPrivate )
        }
        self.sitesTableView.siteActions = [
            .init( tracking: nil, title: "", icon: nil, appearance: [ .cell ], action: { _, _, _ in } ),
            .init( tracking: .subject( "sites.site", action: "fill" ),
                   title: "Fill", icon: .icon( "???" ), appearance: [ .cell, .menu ] ) { [unowned self] site, _, appearance in
                switch appearance {
                    case .cell:
                        self.completeRequest( site: site, trackingFrom: "site>cell" )
                    case .menu:
                        self.completeRequest( site: site, trackingFrom: "site>cell>menu" )
                    case .mode:
                        self.completeRequest( site: site, trackingFrom: "site>cell>mode" )
                    case .premium:
                        ()
                }
            },
        ]
    }

    // MARK: - Private

    func completeRequest(site: Site, trackingFrom: String) {
        guard let extensionContext = self.extensionContext as? ASCredentialProviderExtensionContext
        else { return }

        let event = Tracker.shared.begin( track: .subject( "site", action: "use" ) )
        site.result( keyPurpose: .identification ).token.and( site.result( keyPurpose: .authentication ).token ).then( on: .main ) {
            do {
                let (login, password) = try $0.get()
                site.use()
                event.end(
                        [ "result": $0.name,
                          "from": trackingFrom,
                          "action": "fill",
                          "counter": "\(site.counter)",
                          "purpose": "\(SpectreKeyPurpose.identification)",
                          "type": "\(site.resultType)",
                          "algorithm": "\(site.algorithm)",
                          "entropy": Attacker.entropy( type: site.resultType ) ?? Attacker.entropy( string: password ) ?? 0,
                        ] )

                extensionContext.completeRequest( withSelectedCredential: ASPasswordCredential( user: login, password: password ) ) { _ in
                    site.user.save( onlyIfDirty: true, await: true )
                }
            }
            catch {
                mperror( title: "Couldn't compute site result", error: error )
                event.end( [
                               "result": $0.name,
                               "from": trackingFrom,
                               "action": "fill",
                               "error": error.localizedDescription,
                           ] )
            }
        }
    }
}
