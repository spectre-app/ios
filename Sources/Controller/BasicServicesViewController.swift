//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class BasicServicesViewController: MPUserViewController, UITextFieldDelegate, MPServicesViewObserver, MPDetailViewController {
    internal lazy var topContainer = MPEffectView( content: self.searchField )
    internal let searchField       = UITextField()
    internal let servicesTableView = MPServicesTableView()
    var isContentScrollable = true

    // MARK: --- State ---

    override var user: MPUser? {
        didSet {
            self.servicesTableView.user = self.user
        }
    }

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.searchField.attributedPlaceholder = NSAttributedString( string: "Service Name" )
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        // Need to lay out before setting initial content offset to ensure top container inset is taken into account.
        self.view.layoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset services content's top inset to make space for the top container.
        self.servicesTableView.contentInset.top =
                max( 0, self.servicesTableView.convert( self.topContainer.bounds.bottom, from: self.topContainer ).y
                        - (self.servicesTableView.bounds.origin.y + self.servicesTableView.safeAreaInsets.top)
                        - 8 )
    }

    // MARK: --- MPServicesViewObserver ---

    func serviceWasActivated(service: MPService, withPurpose purpose: MPKeyPurpose) {
        if service.isNew {
            service.user.services.append( service )
        }

        let event = MPTracker.shared.begin( named: "service #copy" )
        service.result( keyPurpose: purpose ).copy( from: self.view ).then {
            do {
                let (operation, token) = try $0.get()
                event.end(
                        [ "result": $0.name,
                          "from": "cell",
                          "counter": "\(operation.counter)",
                          "purpose": "\(operation.purpose)",
                          "type": "\(operation.type)",
                          "algorithm": "\(operation.algorithm)",
                          "entropy": MPAttacker.entropy( type: operation.type ) ?? MPAttacker.entropy( string: token ) ?? 0,
                        ] )
            }
            catch {
                event.end( [ "result": $0.name ] )
            }
        }
    }

    func serviceDetailsAction(service: MPService) {
    }

    // MARK: --- UITextFieldDelegate ---
}
