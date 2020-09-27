//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class BasicSitesViewController: MPUserViewController, UITextFieldDelegate, MPSitesViewObserver {
    internal lazy var topContainer = MPEffectView( content: self.searchField )
    internal let searchField    = UITextField()
    internal let sitesTableView = MPSitesTableView()

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                self.sitesTableView.user = self.user
            }
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.searchField.attributedPlaceholder = NSAttributedString( string: "Site Name" )
        self.searchField => \.attributedPlaceholder => .font => Theme.current.font.body
        self.searchField => \.attributedPlaceholder => .foregroundColor => Theme.current.color.placeholder
        self.searchField => \.textColor => Theme.current.color.body
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.clearsOnBeginEditing = true
        self.searchField.keyboardAppearance = .dark
        self.searchField.keyboardType = .URL
        self.searchField.textContentType = .URL
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        self.searchField.returnKeyType = .done
        self.searchField.delegate = self
        self.searchField.action( for: .editingChanged ) { [unowned self] in
            self.sitesTableView.query = self.searchField.text
        }

        self.sitesTableView.observers.register( observer: self )
        self.sitesTableView.keyboardDismissMode = .onDrag
        self.sitesTableView.contentInsetAdjustmentBehavior = .always

        // - Hierarchy
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.topContainer )

        // - Layout
        LayoutConfiguration( view: self.sitesTableView )
                .constrain()
                .activate()

        LayoutConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .with( priority: UILayoutPriority( 500 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset sites content's top inset to make space for the top container.
        let top = self.sitesTableView.convert( self.topContainer.bounds.bottom, from: self.topContainer ).y - 8
        self.sitesTableView.contentInset.top = max( 0, top - self.sitesTableView.bounds.origin.y - self.sitesTableView.safeAreaInsets.top )
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(site selectedSite: MPSite?) {
        MPFeedback.shared.play( .activate )
    }

    func siteDetailsAction(site: MPSite) {
    }

    // MARK: --- UITextFieldDelegate ---
}
