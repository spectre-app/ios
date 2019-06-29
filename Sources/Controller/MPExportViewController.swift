//
// Created by Maarten Billemont on 2019-06-26.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPExportViewController: MPUserViewController, UIPopoverPresentationControllerDelegate {
    let titleLabel   = UILabel()
    let messageLabel = UILabel()
    let formatControl = UISegmentedControl( items: MPMarshalFormat.allCases.compactMap { $0.name } )
    let revealControl = UISegmentedControl( items: [ "Reveal Passwords", "Secure Export" ] )
    let exportButton  = UIButton()
    lazy var contentView = UIStackView( arrangedSubviews: [
        self.titleLabel,
        self.messageLabel,
        self.formatControl,
        self.revealControl,
        self.exportButton,
    ] )

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init(user: MPUser?) {
        super.init( user: user )
        self.modalPresentationStyle = .popover
        self.popoverPresentationController?.delegate = self
        self.popoverPresentationController?.backgroundColor = MPTheme.global.color.shade.get()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleLabel.numberOfLines = 0
        self.titleLabel.font = MPTheme.global.font.title1.get()
        self.titleLabel.textAlignment = .center
        self.titleLabel.textColor = MPTheme.global.color.body.get()
        self.titleLabel.text = self.user?.fullName
        self.titleLabel.setContentHuggingPriority( .defaultHigh, for: .vertical )
        self.messageLabel.numberOfLines = 0
        self.messageLabel.font = MPTheme.global.font.body.get()
        self.messageLabel.textAlignment = .center
        self.messageLabel.textColor = MPTheme.global.color.secondary.get()
        self.messageLabel.text =
                """
                A secure export contains everything necessary to fully restore your user history.
                Reveal passwords is useful for printing or as an independent backup file.
                """
        self.exportButton.setTitle( "Export User", for: .normal )

        self.contentView.axis = .vertical
        self.contentView.spacing = 8

        self.view.addSubview( self.contentView )
        self.view.preservesSuperviewLayoutMargins = true

        LayoutConfiguration( view: self.contentView ).constrainToMarginsOfOwner().activate()
    }

    // MARK: UIPopoverPresentationControllerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
