//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController, UITextFieldDelegate, MPSiteHeaderObserver, MPSiteDetailObserver, MPSitesViewObserver {
    private lazy var topContainer = MPButton( content: self.searchField )
    private let searchField    = UITextField()
    private let userButton     = UIButton( type: .custom )
    private let sitesTableView = MPSitesTableView()
    private let siteHeaderView = MPSiteHeaderView()
    private let siteDetailView = UIView()

    private let siteHeaderConfiguration = ViewConfiguration()
    private let siteDetailConfiguration = ViewConfiguration()

    private var siteDetailController: MPSiteDetailViewController?

    var user: MPUser? {
        didSet {
            self.sitesTableView.user = self.user

            var userButtonTitle = ""
            self.user?.fullName.split( separator: " " ).forEach { word in userButtonTitle.append( word[word.startIndex] ) }
            self.userButton.setTitle( userButtonTitle.uppercased(), for: .normal )
            self.userButton.sizeToFit()
        }
    }

    // MARK: - Life

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
        self.searchField.addTarget( self, action: #selector( textFieldEditingChanged ), for: .editingChanged )

        self.userButton.setImage( UIImage( named: "icon_user" ), for: .normal )
        self.userButton.sizeToFit()

        self.siteHeaderView.observers.register( self )

        self.sitesTableView.observers.register( self )
        self.sitesTableView.keyboardDismissMode = .onDrag

        if #available( iOS 11.0, * ) {
            self.sitesTableView.contentInsetAdjustmentBehavior = .never
        }

        // - Hierarchy
        self.view.addSubview( self.sitesTableView )
        self.view.addSubview( self.siteHeaderView )
        self.view.addSubview( self.siteDetailView )
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

        ViewConfiguration( view: self.siteDetailView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: self.sitesTableView.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: self.sitesTableView.trailingAnchor ) }
                .activate()

        ViewConfiguration( view: self.topContainer )
                .constrainToAll {
                    [
                        $1.topAnchor.constraint( greaterThanOrEqualTo: $0.layoutMarginsGuide.topAnchor, constant: 8 ),
                        $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor, constant: 8 )
                                    .updatePriority( UILayoutPriority( 500 ) ),
                        $1.topAnchor.constraint( greaterThanOrEqualTo: self.siteHeaderView.layoutMarginsGuide.bottomAnchor )
                                    .updatePriority( UILayoutPriority( 510 ) ),
                        $1.bottomAnchor.constraint( lessThanOrEqualTo: self.siteDetailView.topAnchor )
                                       .updatePriority( UILayoutPriority( 520 ) ),
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
                .apply( ViewConfiguration( view: self.siteDetailView )
                                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.sitesTableView.bottomAnchor ) }, active: true )
                .apply( ViewConfiguration( view: self.siteDetailView )
                                .constrainTo { $1.topAnchor.constraint( equalTo: self.sitesTableView.bottomAnchor ) }, active: false )

        UILayoutGuide.installKeyboardLayoutGuide( in: self.view ) {
            [ $0.topAnchor.constraint( greaterThanOrEqualTo: self.sitesTableView.bottomAnchor ) ]
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Offset sites content's top margin to make space for the top container.
        let top = self.sitesTableView.convert( CGRectGetBottom( self.topContainer.bounds ), from: self.topContainer ).y
        self.sitesTableView.contentInset = UIEdgeInsets(
                top: max( 0, top - self.sitesTableView.bounds.origin.y ), left: 0, bottom: 0, right: 0 )

        // Offset detail view's top margin to make space for the top container.
//        self.siteDetailController?.tableView.contentInset = UIEdgeInsets(
//                top: CGRectGetBottom( self.siteDetailView.convert( self.topContainer.bounds, from: self.topContainer ) ).y,
//                left: 0, bottom: 0, right: 0 )
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Private

    func showSiteDetail(site: MPSite) {
        hideSiteDetail {
            self.siteDetailController = MPSiteDetailViewController( site: site )
            if let siteDetailController = self.siteDetailController {
                siteDetailController.observers.register( self )
                self.addChildViewController( siteDetailController )
                siteDetailController.beginAppearanceTransition( false, animated: true )
                self.siteDetailView.addSubview( siteDetailController.view )
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

    // MARK: - MPSiteHeaderObserver

    func siteWasActivated(activatedSite: MPSite) {
        PearlMainQueue {
            self.showSiteDetail( site: activatedSite )
        }
    }

    // MARK: - MPSiteDetailObserver

    func siteDetailShouldDismiss() {
        PearlMainQueue {
            self.hideSiteDetail()
        }
    }

    // MARK: - MPSitesViewObserver

    func siteWasSelected(selectedSite: MPSite?) {
        PearlMainQueue {
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

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.siteDetailShouldDismiss()
    }

    @objc
    func textFieldEditingChanged(_ textField: UITextField) {
        self.sitesTableView.query = self.searchField.text
    }
}
