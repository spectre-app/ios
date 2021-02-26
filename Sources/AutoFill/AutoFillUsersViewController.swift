//
//  AutoFillUsersViewController.swift
//  Spectre
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import AuthenticationServices

class AutoFillUsersViewController: BaseUsersViewController {
    private let emptyView = UIScrollView()
    private lazy var cancelButton = EffectButton( track: .subject( "users", action: "cancel" ),
                                                  image: .icon( "" ), border: 0, background: false, square: true ) { _, _ in
        self.extensionContext?.cancelRequest( withError: ASExtensionError( .userCanceled, "Cancel button pressed." ) )
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override init() {
        super.init()

        self.userFilesDidChange( AutoFillModel.shared.userFiles )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        let messageLabel = UILabel()
        messageLabel => \.font => Theme.current.font.callout
        messageLabel => \.textColor => Theme.current.color.secondary
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.text =
                """
                To begin, activate the AutoFill setting for the Spectre user you want to use.
                """

        let step1Title = UILabel()
        step1Title => \.font => Theme.current.font.headline
        step1Title.numberOfLines = 0
        step1Title.textAlignment = .center
        step1Title.text = "1. Open Spectre"
        let step1Image = EffectButton( image: UIImage( named: "icon" ), background: false, square: true, circular: false, rounding: 22 )
        step1Image.padded = false
        LayoutConfiguration( view: step1Image )
                .constrain { $1.widthAnchor.constraint( equalToConstant: 60 ) }
                .activate()

        let step2Title = UILabel()
        step2Title => \.font => Theme.current.font.headline
        step2Title.numberOfLines = 0
        step2Title.textAlignment = .center
        step2Title.text = "2. Sign into your user"
        let step2Image = EffectButton( image: UIImage( named: "avatar-0" ), border: 0, background: false, square: true, circular: false )
        step2Image.padded = false
        LayoutConfiguration( view: step2Image )
                .constrain { $1.widthAnchor.constraint( equalToConstant: 60 ) }
                .activate()

        let step3Title = UILabel()
        step3Title => \.font => Theme.current.font.headline
        step3Title.numberOfLines = 0
        step3Title.textAlignment = .center
        step3Title.text = "3. Tap your user initials"
        let step3Image = EffectButton( title: "RLM" )

        let step4Title = UILabel()
        step4Title => \.font => Theme.current.font.headline
        step4Title.numberOfLines = 0
        step4Title.textAlignment = .center
        step4Title.text = "4. Turn on AutoFill for the user"
        let step4Image = EffectToggleButton( action: { _ in nil } )
        step4Image.image = .icon( "" )
        step4Image.isSelected = true

        let emptyStack = UIStackView()
        emptyStack.axis = .vertical
        emptyStack.spacing = 12
        emptyStack.alignment = .center
        emptyStack.addArrangedSubview( MarginView() )
        emptyStack.addArrangedSubview( messageLabel )
        emptyStack.addArrangedSubview( MarginView() )
        emptyStack.addArrangedSubview( step1Title )
        emptyStack.addArrangedSubview( step1Image )
        emptyStack.addArrangedSubview( MarginView() )
        emptyStack.addArrangedSubview( step2Title )
        emptyStack.addArrangedSubview( step2Image )
        emptyStack.addArrangedSubview( MarginView() )
        emptyStack.addArrangedSubview( step3Title )
        emptyStack.addArrangedSubview( step3Image )
        emptyStack.addArrangedSubview( MarginView() )
        emptyStack.addArrangedSubview( step4Title )
        emptyStack.addArrangedSubview( step4Image )
        emptyStack.addArrangedSubview( MarginView() )

        // - Hierarchy
        self.emptyView.addSubview( emptyStack )
        self.view.insertSubview( self.emptyView, belowSubview: self.detailsHost.view )
        self.view.insertSubview( self.cancelButton, belowSubview: self.detailsHost.view )

        // - Layout
        LayoutConfiguration( view: emptyStack )
                .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .constrain( as: .center, to: self.emptyView.contentLayoutGuide )
                .activate()
        LayoutConfiguration( view: self.emptyView )
                .constrain { $1.view!.contentLayoutGuide.heightAnchor.constraint( greaterThanOrEqualTo: $0.heightAnchor ) }
                .constrain( as: .box ).activate()
        LayoutConfiguration( view: self.cancelButton )
                .constrain( as: .bottomCenter, margin: true ).activate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        if let userName = AutoFillModel.shared.context.credentialIdentity?.user {
            self.usersSpinner.requestSelection( at: self.fileSource.indexPath( where: { $0?.userName == userName } ) )
        }
        else if self.fileSource.count() == 1, let only = self.fileSource.elements().first( where: { _ in true } )?.indexPath {
            self.usersSpinner.requestSelection( at: only )
        }
    }

    // MARK: --- MarshalObserver ---

    override func userFilesDidChange(_ userFiles: [Marshal.UserFile]) {
        self.fileSource.update( [ userFiles.filter( { $0.autofill } ).sorted() ] )

        DispatchQueue.main.perform {
            self.emptyView.isHidden = !self.fileSource.isEmpty
        }
    }

    // MARK: --- Types ---

    override func login(user: User) {
        super.login( user: user )

        self.detailsHost.show( AutoFillSitesViewController( user: user ), sender: self )
    }
}
