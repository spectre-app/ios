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
    let revealControl = UISegmentedControl( items: [ "Reveal Passwords", "Secure Export" ] )
    let exportButton  = MPButton( title: "Export User" )
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
        self.popoverPresentationController?.delegate = self
        self.popoverPresentationController?.backgroundColor = MPTheme.global.color.shade.get()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleLabel.numberOfLines = 0
        self.titleLabel.font = MPTheme.global.font.title1.get()
        self.titleLabel.text = "Exporting"
        self.titleLabel.textAlignment = .center
        self.titleLabel.textColor = MPTheme.global.color.body.get()
        self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.font = MPTheme.global.font.title2.get()
        self.subtitleLabel.textAlignment = .center
        self.subtitleLabel.textColor = MPTheme.global.color.body.get()
        self.subtitleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.messageLabel.numberOfLines = 0
        self.messageLabel.font = MPTheme.global.font.caption1.get()
        self.messageLabel.textAlignment = .center
        self.messageLabel.textColor = MPTheme.global.color.secondary.get()
        self.messageLabel.text =
                """
                A "Secure Export" contains everything necessary to fully restore your user's history.

                "Reveal Passwords" is useful for creating a backup file that you can print or use independently of the app.
                """
        self.formatControl.selectedSegmentIndex = MPMarshalFormat.allCases.firstIndex( of: MPMarshalFormat.default ) ?? -1
        self.revealControl.selectedSegmentIndex = 1

        self.exportButton.button.addAction( for: .touchUpInside ) { _, _ in
            trc( "Requested export of \(self.user), format: \(self.format), redacted: \(self.redacted)" )
            let item       = MPMarshal.ActivityItem( user: self.user, format: self.format, redacted: self.redacted )
            let controller = UIActivityViewController( activityItems: [ item, item.text() ], applicationActivities: nil )
            controller.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
                trc( "Export activity completed: \(completed), error: \(activityError?.localizedDescription ?? "-")" )
                item.activityViewController( controller, completed: completed, forActivityType: activityType,
                                             returnedItems: returnedItems, activityError: activityError )
                self.dismiss( animated: true )
            }
            self.present( controller, animated: true )
        }

        self.contentView.axis = .vertical
        self.contentView.spacing = 8

        self.view.addSubview( self.contentView )
        self.view.preservesSuperviewLayoutMargins = true

        LayoutConfiguration( view: self.contentView ).constrainToMarginsOfOwner().activate()
    }

    // MARK: UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
