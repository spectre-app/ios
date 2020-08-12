//
// Created by Maarten Billemont on 2019-06-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPExportViewController: MPUserViewController, UIPopoverPresentationControllerDelegate {
    let titleLabel    = UILabel()
    let subtitleLabel = UILabel()
    let messageLabel  = UILabel()
    let formatControl = UISegmentedControl( items: MPMarshalFormat.allCases.compactMap { $0.description } )
    let revealControl = UISegmentedControl( items: [ "Readable", "Secure" ] )
    let exportButton  = MPButton( identifier: "export #export", title: "Export User" )
    lazy var contentView = UIStackView( arrangedSubviews: [
        self.titleLabel,
        self.subtitleLabel,
        self.messageLabel,
        self.formatControl,
        self.revealControl,
        self.exportButton,
    ] )

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                self.subtitleLabel.text = self.user.fullName
            }
        }
    }
    var format:   MPMarshalFormat {
        MPMarshalFormat.allCases[self.formatControl.selectedSegmentIndex]
    }
    var redacted: Bool {
        self.revealControl.selectedSegmentIndex == 1
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(user: MPUser) {
        super.init( user: user )
        self.modalPresentationStyle = .popover
        self.popoverPresentationController!.delegate = self
        self.popoverPresentationController! => \.backgroundColor => Theme.current.color.shade
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.preservesSuperviewLayoutMargins = true

        self.titleLabel.numberOfLines = 0
        self.titleLabel => \.font => Theme.current.font.title1
        self.titleLabel.text = "Exporting"
        self.titleLabel.textAlignment = .center
        self.titleLabel => \.textColor => Theme.current.color.body
        self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel => \.font => Theme.current.font.title2
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel => \.textColor => Theme.current.color.body
        self.subtitleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.messageLabel.numberOfLines = 0
        self.messageLabel => \.font => Theme.current.font.caption1
        self.messageLabel.textAlignment = .center
        self.messageLabel => \.textColor => Theme.current.color.secondary
        self.messageLabel.text =
                """
                A "Secure Export" contains everything necessary to fully restore your user's history.

                "Reveal Passwords" is useful for creating a backup file that you can print or use independently of the app.
                """
        self.formatControl.selectedSegmentIndex = MPMarshalFormat.allCases.firstIndex( of: MPMarshalFormat.default ) ?? -1
        self.revealControl.selectedSegmentIndex = 1

        self.exportButton.button.action( for: .primaryActionTriggered ) { [unowned self] in
            trc( "Requested export of %@, format: %@, redacted: %d",
                 self.user, self.format, self.redacted )

            let item       = MPMarshal.ActivityItem( user: self.user, format: self.format, redacted: self.redacted )
            let controller = UIActivityViewController( activityItems: [ item, item.text() ], applicationActivities: nil )
            controller.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
                pii( "Export activity completed: %d, error: %@", completed, activityError )

                item.activityViewController( controller, completed: completed, forActivityType: activityType,
                                             returnedItems: returnedItems, activityError: activityError )
                self.dismiss( animated: true )
            }
            self.present( controller, animated: true )
        }

        self.contentView.axis = .vertical
        self.contentView.spacing = 8

        // - Hierarchy
        self.view.addSubview( self.contentView )

        // - Layout
        LayoutConfiguration( view: self.contentView )
                .constrain( margins: true )
                .activate()
    }

    // MARK: UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
