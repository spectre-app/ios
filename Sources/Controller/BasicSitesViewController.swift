//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class BasicSitesViewController: MPUserViewController, UITextFieldDelegate, MPDetailViewController {
    internal lazy var topContainer = MPEffectView( content: self.searchField )
    internal let searchField    = UITextField()
    internal let sitesTableView = MPSitesTableView()

    var isContentScrollable = true

    // MARK: --- State ---

    override var user: MPUser? {
        didSet {
            self.sitesTableView.user = self.user
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.searchField.attributedPlaceholder = NSAttributedString( string: "Site Domain" )
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
        self.searchField.action( for: [ .editingChanged, .editingDidBegin ] ) { [unowned self] in
            self.sitesTableView.query = self.searchField.text
        }

        self.sitesTableView.keyboardDismissMode = .interactive
        self.sitesTableView.contentInsetAdjustmentBehavior = .always

        // - Hierarchy
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.topContainer )

        // - Layout
        LayoutConfiguration( view: self.sitesTableView ).constrain( as: .box )
                                                        .activate()

        LayoutConfiguration( view: self.topContainer )
                .constrainAll {
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

        // Offset sites table's top inset to make space for the top container.
        self.sitesTableView.contentInset.top =
                max( 0, self.sitesTableView.convert( self.topContainer.bounds.bottom, from: self.topContainer ).y
                        - (self.sitesTableView.bounds.origin.y + self.sitesTableView.safeAreaInsets.top)
                        - 8 )
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
