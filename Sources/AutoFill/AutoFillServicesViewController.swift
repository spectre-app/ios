//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillServicesViewController: BasicServicesViewController {

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
        self.servicesTableView.preferredFilter = { service in
            allServiceIdentifiers.contains( where: {
                let serviceIdentifier = URL( string: $0.identifier )?.host ?? $0.identifier
                return serviceIdentifier.contains( service.serviceName ) || service.serviceName.contains( serviceIdentifier )
            } )
        }
        self.servicesTableView.preferredService = allServiceIdentifiers.first.flatMap { URL( string: $0.identifier )?.host ?? $0.identifier }
        self.servicesTableView.serviceActions = [
            .init( tracking: nil, title: "", icon: "", appearance: [ .cell ], action: { _, _, _ in } ),
            .init( tracking: .subject( "services.service", action: "fill" ), title: "Fill", icon: "", appearance: [ .cell, .menu ] ) { service, mode, appearance in
                switch appearance {
                    case .cell:
                        self.completeRequest( service: service, trackingFrom: "service>cell" )
                    case .menu:
                        self.completeRequest( service: service, trackingFrom: "service>cell>menu" )
                }
            },
        ]
    }

    // MARK: --- Private ---

    func completeRequest(service: MPService, trackingFrom: String) {
        let event = MPTracker.shared.begin( track: .subject( "service", action: "use" ) )
        if let extensionContext = self.extensionContext as? ASCredentialProviderExtensionContext {
            service.result( keyPurpose: .identification ).token.and( service.result( keyPurpose: .authentication ).token ).then {
                do {
                    let (login, password) = try $0.get()
                    service.use()
                    event.end(
                            [ "result": $0.name,
                              "from": trackingFrom,
                              "action": "fill",
                              "counter": "\(service.counter)",
                              "purpose": "\(MPKeyPurpose.identification)",
                              "type": "\(service.resultType)",
                              "algorithm": "\(service.algorithm)",
                              "entropy": MPAttacker.entropy( type: service.resultType ) ?? MPAttacker.entropy( string: password ) ?? 0,
                            ] )

                    extensionContext.completeRequest( withSelectedCredential: ASPasswordCredential( user: login, password: password )
                    ) { _ in
                        do {
                            let _ = try service.user.save().await()
                        }
                        catch {
                            mperror( title: "Couldn't save user.", error: error )
                        }
                    }
                }
                catch {
                    mperror( title: "Couldn't compute service result.", error: error )
                    event.end( [ "result": $0.name, "from": trackingFrom, "error": error.localizedDescription ] )
                }
            }
        }
    }
}
