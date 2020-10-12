//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPServicesViewController: BasicServicesViewController {
    private let userButton  = MPButton( identifier: "services #user_settings" )
    private let detailsHost = MPDetailsHostController()

    override var user: MPUser? {
        didSet {
            DispatchQueue.main.perform {
                self.userButton.title = self.user?.fullName.name( style: .abbreviated )
                self.userButton.sizeToFit()
            }
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.userButton.isRound = true
        self.userButton.action( for: .primaryActionTriggered ) { [unowned self] in
            if let user = self.user {
                self.detailsHost.show( MPUserDetailsViewController( model: user ), sender: self )
            }
        }
        self.searchField.rightView = self.userButton

        // - Hierarchy
        self.addChild( self.detailsHost )
        self.view.insertSubview( self.detailsHost.view, belowSubview: self.topContainer )
        self.detailsHost.didMove( toParent: self )

        // - Layout
        LayoutConfiguration( view: self.detailsHost.view )
                .constrain()
                .constrainTo { _, _ in
                    self.detailsHost.contentView.topAnchor.constraint( greaterThanOrEqualTo: self.topContainer.bottomAnchor, constant: -8 )
                                                          .with( priority: UILayoutPriority( 520 ) )
                }
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Add space consumed by header and top container to details safe area.
        self.detailsHost.additionalSafeAreaInsets.top = self.topContainer.frame.maxY - self.view.safeAreaInsets.top
    }

    // MARK: --- MPServicesViewObserver ---

    override func serviceDetailsAction(service: MPService) {
        DispatchQueue.main.perform {
            self.detailsHost.show( MPServiceDetailsViewController( model: service ), sender: self )
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.detailsHost.hide()
    }
}
