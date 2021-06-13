//==============================================================================
// Created by Maarten Billemont on 2019-06-26.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class ExportViewController: BaseUserViewController, UIPopoverPresentationControllerDelegate {
    let titleLabel    = UILabel()
    let subtitleLabel = UILabel()
    let messageLabel  = UILabel()
    let formatControl = UISegmentedControl( items: SpectreFormat.allCases.compactMap { $0.description } )
    let revealControl = UISegmentedControl( items: [ "Readable", "Secure" ] )
    let exportButton  = EffectButton( track: .subject( "export", action: "export" ), title: "Export User" )
    lazy var contentView = UIStackView( arrangedSubviews: [
        self.titleLabel,
        self.subtitleLabel,
        self.messageLabel,
        self.formatControl,
        self.revealControl,
        self.exportButton,
    ] )

    override var user: User? {
        didSet {
            DispatchQueue.main.perform {
                self.subtitleLabel.text = self.user?.userName
            }
        }
    }
    var format:   SpectreFormat {
        SpectreFormat.allCases[self.formatControl.selectedSegmentIndex]
    }
    var redacted: Bool {
        self.revealControl.selectedSegmentIndex == 1
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(user: User) {
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
        self.formatControl.selectedSegmentIndex = SpectreFormat.allCases.firstIndex( of: SpectreFormat.default ) ?? -1
        self.revealControl.selectedSegmentIndex = 1

        self.exportButton.action( for: .primaryActionTriggered ) { [unowned self] in
            guard let user = self.user
            else { return }

            trc( "Requested export of %@, format: %@, redacted: %d", user, self.format, self.redacted )

            let item       = Marshal.ActivityItem( user: user, format: self.format, redacted: self.redacted )
            let controller = UIActivityViewController( activityItems: [ item, item.text() ], applicationActivities: nil )
            controller.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
                pii( "Export activity completed: %d, error: %@", completed, activityError )

                item.activityViewController( controller, completed: completed, forActivityType: activityType,
                                             returnedItems: returnedItems, activityError: activityError )
                self.dismiss( animated: true )
            }
            controller.popoverPresentationController?.sourceView = self.exportButton
            controller.popoverPresentationController?.sourceRect = self.exportButton.bounds
            self.present( controller, animated: true )
        }

        self.contentView.axis = .vertical
        self.contentView.spacing = 8

        // - Hierarchy
        self.view.addSubview( self.contentView )

        // - Layout
        LayoutConfiguration( view: self.contentView )
                .constrain( as: .box, margin: true ).activate()
    }

    // MARK: UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
