//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate,
                             MPSiteHeaderObserver, MPSiteDetailObserver, MPSitesViewObserver, MPUserObserver {
    private lazy var topContainer         = MPButton( content: self.searchField )
    private lazy var siteDetailRecognizer = UITapGestureRecognizer( target: self, action: #selector( didDismissSiteDetail ) )
    private let searchField             = UITextField()
    private let userButton              = UIButton( type: .custom )
    private let sitesTableView          = MPSitesTableView()
    private let siteHeaderView          = MPSiteHeaderView()
    private let siteDetailContainer     = UIScrollView()
    private let siteDetailContentView   = UIView()
    private let siteHeaderConfiguration = ViewConfiguration()
    private let siteDetailConfiguration = ViewConfiguration()
    private var siteDetailController: MPSiteDetailViewController?

    var user: MPUser? {
        willSet {
            self.user?.observers.unregister( self )
        }
        didSet {
            self.user?.observers.register( self )
            self.sitesTableView.user = self.user

            var userButtonTitle = ""
            self.user?.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }

            DispatchQueue.main.perform {
                self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
                self.userButton.sizeToFit()
            }
        }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(user: MPUser) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.user = user
        }
    }

    override func viewDidLoad() {

        // - View
        self.topContainer.darkBackground = true

        self.searchField.textColor = .white
        self.searchField.rightView = self.userButton
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.rightViewMode = .unlessEditing
        self.searchField.keyboardAppearance = .dark
        self.searchField.keyboardType = .URL
        if #available( iOS 10.0, * ) {
            self.searchField.textContentType = .URL
        }
        self.searchField.autocapitalizationType = .none
        self.searchField.autocorrectionType = .no
        self.searchField.delegate = self
        self.searchField.addAction( for: .editingChanged ) { _, _ in
            self.sitesTableView.query = self.searchField.text
        }

        self.userButton.addAction( for: .touchUpInside ) { _, _ in
            self.user?.masterKey = nil
        }
        self.userButton.setImage( UIImage( named: "icon_user" ), for: .normal )
        self.userButton.sizeToFit()

        self.siteHeaderView.observers.register( self )

        self.sitesTableView.observers.register( self )
        self.sitesTableView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesTableView.contentInsetAdjustmentBehavior = .never
        }

        self.siteDetailContainer.backgroundColor = UIColor( white: 0, alpha: 0.382 )
        self.siteDetailContainer.addGestureRecognizer( self.siteDetailRecognizer )
        self.siteDetailRecognizer.delegate = self

        // - Hierarchy
        self.siteDetailContainer.addSubview( self.siteDetailContentView )
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.siteHeaderView )
        self.view.addSubview( self.siteDetailContainer )
        self.view.addSubview( self.topContainer )

        // - Layout
        ViewConfiguration( view: self.siteHeaderView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.sitesTableView )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.siteHeaderView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        ViewConfiguration( view: self.siteDetailContainer )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: self.sitesTableView.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: self.sitesTableView.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ) }
                .activate()

        ViewConfiguration( view: self.siteDetailContentView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .activate()

        ViewConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .withPriority( UILayoutPriority( 500 ) ),
                        $1.topAnchor.constraint( greaterThanOrEqualTo: self.siteHeaderView.layoutMarginsGuide.bottomAnchor )
                                    .withPriority( UILayoutPriority( 510 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.siteDetailContentView.topAnchor )
                                       .withPriority( UILayoutPriority( 520 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()

        self.siteHeaderConfiguration
                .apply( ViewConfiguration( view: self.siteHeaderView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: true )
                .apply( ViewConfiguration( view: self.sitesTableView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: false )

        self.siteDetailConfiguration
                .apply( ViewConfiguration( view: self.siteDetailContainer )
                                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.sitesTableView.bottomAnchor ) }, active: true )
                .apply( ViewConfiguration( view: self.siteDetailContainer )
                                .constrainTo { $1.topAnchor.constraint( equalTo: self.sitesTableView.bottomAnchor ) }, active: false )

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesTableView.bottomAnchor ) ]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset sites content's top inset to make space for the top container.
        let top = self.sitesTableView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y - 8
        self.sitesTableView.contentInset = UIEdgeInsets(
                top: max( 0, top - self.sitesTableView.bounds.origin.y ), left: 0, bottom: 0, right: 0 )

        // Offset detail view's top inset to make space for the top container.
        self.siteDetailContainer.contentInset = UIEdgeInsets(
                top: max( CGRectGetBottom( self.topContainer.bounds ).y + 8,
                          self.siteDetailContainer.bounds.size.height - self.siteDetailContentView.frame.size.height ),
                left: 0, bottom: 0, right: 0 )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: --- MPUserObserver ---

    func userDidLogin(_ user: MPUser) {
    }

    func userDidLogout(_ user: MPUser) {
        if user == self.user, let navigationController = self.navigationController {
            navigationController.setViewControllers( navigationController.viewControllers.filter { $0 != self }, animated: true )
        }
    }

    func userDidChange(_ user: MPUser) {
    }

    func userDidUpdateSites(_ user: MPUser) {
    }

    // MARK: --- Private ---

    @objc
    func didTapDismiss() {
        self.hideSiteDetail()
    }

    func showSiteDetail(for site: MPSite) {
        self.hideSiteDetail {
            self.siteDetailController = MPSiteDetailViewController( site: site )
            if let siteDetailController = self.siteDetailController {
                siteDetailController.observers.register( self )
                self.addChildViewController( siteDetailController )
                siteDetailController.beginAppearanceTransition( false, animated: true )
                self.siteDetailContentView.addSubview( siteDetailController.view )
                ViewConfiguration( view: siteDetailController.view ).constrainToMarginsOfSuperview().activate()
                UIView.animate( withDuration: 0.382, animations: {
                    self.searchField.resignFirstResponder() // TODO: Move to somewhere more generic
                    self.siteDetailConfiguration.activate()
                }, completion: { finished in
                    siteDetailController.endAppearanceTransition()
                    siteDetailController.didMove( toParentViewController: self )
                } )
            }
        }
    }

    @objc
    func didDismissSiteDetail() {
        self.hideSiteDetail( completion: nil )
    }

    func hideSiteDetail(completion: (() -> Void)? = nil) {
        if let siteDetailController = self.siteDetailController {
            siteDetailController.willMove( toParentViewController: nil )
            siteDetailController.beginAppearanceTransition( false, animated: true )
            UIView.animate( withDuration: 0.382, animations: {
                self.siteDetailConfiguration.deactivate()
            }, completion: { finished in
                siteDetailController.view.removeFromSuperview()
                siteDetailController.endAppearanceTransition()
                siteDetailController.removeFromParentViewController()
                siteDetailController.observers.unregister( self )
                self.siteDetailController = nil
                completion?()
            } )
        }
        else {
            completion?()
        }
    }

    // MARK: --- MPSiteHeaderObserver ---

    func siteOpenDetails(for site: MPSite) {
        DispatchQueue.main.perform {
            self.showSiteDetail( for: site )
        }
    }

    // MARK: --- MPSiteDetailObserver ---

    func siteDetailShouldDismiss() {
        DispatchQueue.main.perform {
            self.hideSiteDetail()
        }
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(selectedSite: MPSite?) {
        DispatchQueue.main.perform {
            UIView.animate( withDuration: 1, animations: {
                if let selectedSite = selectedSite {
                    self.siteHeaderView.site = selectedSite
                }
                else {
                    self.hideSiteDetail()
                }

                self.siteHeaderConfiguration.activated = selectedSite != nil;
            }, completion: { finished in
                if selectedSite == nil {
                    self.siteHeaderView.site = nil
                }
            } )
        }
    }

    // MARK: --- UIGestureRecognizerDelegate ---

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // siteDetailRecognizer shouldn't trigger on subviews
        if gestureRecognizer == self.siteDetailRecognizer {
            return touch.view == gestureRecognizer.view
        }

        return true
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.siteDetailShouldDismiss()
    }
}
