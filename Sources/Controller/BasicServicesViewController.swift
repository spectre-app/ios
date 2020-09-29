//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class BasicServicesViewController: MPUserViewController, UITextFieldDelegate, MPServicesViewObserver {
    internal lazy var topContainer = MPEffectView( content: self.searchField )
    internal let searchField       = UITextField()
    internal let servicesTableView = MPServicesTableView()

    override var user: MPUser {
        didSet {
            DispatchQueue.main.perform {
                self.servicesTableView.user = self.user
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
            self.servicesTableView.query = self.searchField.text
        }

        self.servicesTableView.observers.register( observer: self )
        self.servicesTableView.keyboardDismissMode = .onDrag
        self.servicesTableView.contentInsetAdjustmentBehavior = .always

        // - Hierarchy
        self.view.addSubview( self.servicesTableView )
        self.view.addSubview( self.topContainer )

        // - Layout
        LayoutConfiguration( view: self.servicesTableView )
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

        // Offset services content's top inset to make space for the top container.
        let top = self.servicesTableView.convert( self.topContainer.bounds.bottom, from: self.topContainer ).y - 8
        self.servicesTableView.contentInset.top = max( 0, top - self.servicesTableView.bounds.origin.y - self.servicesTableView.safeAreaInsets.top )
    }

    // MARK: --- MPServicesViewObserver ---

    func serviceWasSelected(service selectedSite: MPService?) {
        MPFeedback.shared.play( .activate )
    }

    func serviceDetailsAction(service: MPService) {
    }

    // MARK: --- UITextFieldDelegate ---
}
