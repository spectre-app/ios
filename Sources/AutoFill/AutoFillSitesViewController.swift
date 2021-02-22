//
//  MPUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillSitesViewController: BasicSitesViewController {

    // MARK: --- Life ---

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
        self.sitesTableView.preferredSite = allServiceIdentifiers.first.flatMap { URL( string: $0.identifier )?.host ?? $0.identifier }
        self.sitesTableView.siteActions = [
            .init( tracking: nil, title: "", icon: "", appearance: [ .cell ], action: { _, _, _ in } ),
            .init( tracking: .subject( "sites.site", action: "fill" ),
                   title: "Fill", icon: "", appearance: [ .cell, .menu ] ) { [unowned self] site, mode, appearance in
                switch appearance {
                    case .cell:
                        self.completeRequest( site: site, trackingFrom: "site>cell" )
                    case .menu:
                        self.completeRequest( site: site, trackingFrom: "site>cell>menu" )
                }
            },
        ]
    }

    // MARK: --- Private ---

    func completeRequest(site: MPSite, trackingFrom: String) {
        let event = MPTracker.shared.begin( track: .subject( "site", action: "use" ) )
        if let extensionContext = self.extensionContext as? ASCredentialProviderExtensionContext {
            site.result( keyPurpose: .identification ).token.and( site.result( keyPurpose: .authentication ).token ).then {
                do {
                    let (login, password) = try $0.get()
                    site.use()
                    event.end(
                            [ "result": $0.name,
                              "from": trackingFrom,
                              "action": "fill",
                              "counter": "\(site.counter)",
                              "purpose": "\(MPKeyPurpose.identification)",
                              "type": "\(site.resultType)",
                              "algorithm": "\(site.algorithm)",
                              "entropy": MPAttacker.entropy( type: site.resultType ) ?? MPAttacker.entropy( string: password ) ?? 0,
                            ] )

                    extensionContext.completeRequest( withSelectedCredential: ASPasswordCredential( user: login, password: password )
                    ) { _ in
                        do {
                            let _ = try site.user.save().await()
                        }
                        catch {
                            mperror( title: "Couldn't save user.", error: error )
                        }
                    }
                }
                catch {
                    mperror( title: "Couldn't compute site result.", error: error )
                    event.end( [ "result": $0.name, "from": trackingFrom, "error": error.localizedDescription ] )
                }
            }
        }
    }
}
