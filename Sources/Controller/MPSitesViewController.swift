//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate,
                             MPSiteHeaderObserver, MPDetailsObserver, MPSitesViewObserver, MPUserObserver {
    private lazy var topContainer     = MPButton( content: self.searchField )
    private lazy var detailRecognizer = UITapGestureRecognizer( target: self, action: #selector( shouldDismissDetails ) )
    private let searchField             = UITextField()
    private let userButton              = UIButton( type: .custom )
    private let sitesTableView          = MPSitesTableView()
    private let siteHeaderView          = MPSiteHeaderView()
    private let siteHeaderConfiguration = LayoutConfiguration()
    private let detailContainer         = UIScrollView()
    private let detailContentView       = MPUntouchableView()
    private let detailConfiguration     = LayoutConfiguration()
    private var detailController: AnyMPDetailsViewController?

    var user: MPUser? {
        willSet {
            self.user?.observers.unregister( observer: self )
        }
        didSet {
            self.user?.observers.register( observer: self )
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

        self.searchField.textColor = MPTheme.global.color.body.get()
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
            if let user = self.user {
                self.showDetails( forUser: user )
            }
        }
        self.userButton.setImage( UIImage( named: "icon_user" ), for: .normal )
        self.userButton.sizeToFit()

        self.siteHeaderView.observers.register( observer: self )

        self.sitesTableView.observers.register( observer: self )
        self.sitesTableView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesTableView.contentInsetAdjustmentBehavior = .never
        }

        self.detailContainer.backgroundColor = MPTheme.global.color.shade.get()
        self.detailContainer.addGestureRecognizer( self.detailRecognizer )
        self.detailContainer.delegate = self
        self.detailRecognizer.delegate = self

        // - Hierarchy
        self.detailContainer.addSubview( self.detailContentView )
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.siteHeaderView )
        self.view.addSubview( self.detailContainer )
        self.view.addSubview( self.topContainer )

        // - Layout
        LayoutConfiguration( view: self.siteHeaderView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .activate()

        LayoutConfiguration( view: self.sitesTableView )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.siteHeaderView.bottomAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()

        LayoutConfiguration( view: self.detailContainer )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: self.sitesTableView.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: self.sitesTableView.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ) }
                .activate()

        LayoutConfiguration( view: self.detailContentView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .constrainTo { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .activate()

        LayoutConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .withPriority( UILayoutPriority( 500 ) ),
                        $1.topAnchor.constraint( greaterThanOrEqualTo: self.siteHeaderView.layoutMarginsGuide.bottomAnchor )
                                    .withPriority( UILayoutPriority( 510 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.detailContentView.topAnchor )
                                       .withPriority( UILayoutPriority( 520 ) ),
                        $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor, constant: 8 ),
                        $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor, constant: -8 ),
                        $1.heightAnchor.constraint( equalToConstant: 50 ),
                    ]
                }
                .activate()

        self.siteHeaderConfiguration
                .apply( LayoutConfiguration( view: self.siteHeaderView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: true )
                .apply( LayoutConfiguration( view: self.sitesTableView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }, active: false )

        self.detailConfiguration
                .apply( LayoutConfiguration( view: self.detailContainer )
                                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.sitesTableView.bottomAnchor ) }, active: true )
                .apply( LayoutConfiguration( view: self.detailContainer )
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
        self.detailContainer.contentInset = UIEdgeInsets(
                top: max( CGRectGetBottom( self.topContainer.bounds ).y + 8,
                          self.detailContainer.bounds.size.height - self.detailContentView.frame.size.height ),
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

    func showDetails(forSite site: MPSite) {
        self.showDetails( MPSiteDetailsViewController( model: site ) )
    }

    func showDetails(forUser user: MPUser) {
        self.showDetails( MPUserDetailsViewController( model: user ) )
    }

    func showDetails(_ detailController: AnyMPDetailsViewController) {
        self.hideDetails {
            self.detailController = detailController

            if let detailController = self.detailController {
                detailController.observers.register( observer: self )
                self.addChildViewController( detailController )
                detailController.beginAppearanceTransition( false, animated: true )
                self.detailContentView.addSubview( detailController.view )
                LayoutConfiguration( view: detailController.view ).constrainToMarginsOfOwner().activate()
                UIView.animate( withDuration: 0.382, animations: {
                    self.searchField.resignFirstResponder() // TODO: Move to somewhere more generic
                    self.detailConfiguration.activate()
                }, completion: { finished in
                    detailController.endAppearanceTransition()
                    detailController.didMove( toParentViewController: self )
                } )
            }
        }
    }

    func hideDetails(completion: (() -> Void)? = nil) {
        DispatchQueue.main.perform {
            if let detailController = self.detailController {
                detailController.willMove( toParentViewController: nil )
                detailController.beginAppearanceTransition( false, animated: true )
                UIView.animate( withDuration: 0.382, animations: {
                    self.detailConfiguration.deactivate()
                }, completion: { finished in
                    detailController.view.removeFromSuperview()
                    detailController.endAppearanceTransition()
                    detailController.removeFromParentViewController()
                    detailController.observers.unregister( observer: self )
                    self.detailController = nil
                    completion?()
                } )
            }
            else {
                completion?()
            }
        }
    }

    // MARK: --- MPSiteHeaderObserver ---

    func shouldOpenDetails(forSite site: MPSite) {
        self.showDetails( forSite: site )
    }

    // MARK: --- MPSiteDetailObserver ---

    func shouldDismissDetails() {
        self.hideDetails()
    }

    // MARK: --- MPSitesViewObserver ---

    func siteWasSelected(selectedSite: MPSite?) {
        DispatchQueue.main.perform {
            UIView.animate( withDuration: 1, animations: {
                if let selectedSite = selectedSite {
                    self.siteHeaderView.site = selectedSite
                }
                else {
                    self.hideDetails()
                    self.searchField.text = nil
                    self.sitesTableView.query = nil
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
        if gestureRecognizer == self.detailRecognizer {
            return touch.view == gestureRecognizer.view
        }

        return true
    }

    // MARK: --- UIScrollViewDelegate ---

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == self.detailContainer,
           scrollView.contentInset.top + scrollView.contentOffset.y < -80 {
            self.shouldDismissDetails()
        }
    }

    // MARK: --- UITextFieldDelegate ---

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.shouldDismissDetails()
    }
}
