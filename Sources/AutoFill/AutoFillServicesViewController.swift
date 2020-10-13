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
        self.servicesTableView.actionIcon = ""
        self.servicesTableView.preferredFilter = { service in
            allServiceIdentifiers.contains( where: {
                var serviceIdentifier = $0.identifier
                if case .URL = $0.type, let url = URL( string: $0.identifier ),
                   let host = url.host {
                    serviceIdentifier = host
                }

                return serviceIdentifier.contains( service.serviceName ) || service.serviceName.contains( serviceIdentifier )
            } )
        }
    }

    // MARK: --- MPServicesViewObserver ---

    override func serviceDetailsAction(service: MPService) {
        super.serviceDetailsAction( service: service )

        MPFeedback.shared.play( .activate )

        if let extensionContext = self.extensionContext as? ASCredentialProviderExtensionContext {
            service.result( keyPurpose: .identification ).token.and( service.result( keyPurpose: .authentication ).token ).then {
                do {
                    let (login, password) = try $0.get()
                    extensionContext.completeRequest( withSelectedCredential: ASPasswordCredential( user: login, password: password ) )
                }
                catch {
                    mperror( title: "Couldn't compute service result.", error: error )
                }
            }
        }
    }
}
