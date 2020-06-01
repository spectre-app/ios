//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitePreviewController: UIViewController, MPSiteObserver {
    public var site: MPSite? {
        willSet {
            self.site?.observers.unregister( observer: self )
        }
        didSet {
            if let site = self.site {
                site.observers.register( observer: self ).siteDidChange( site )
            }

            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    private let siteButton = UIButton( type: .custom )

    // MARK: --- Life ---

    init(site: MPSite? = nil) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.site = site
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = UIEdgeInsets( top: 12, left: 12, bottom: 20, right: 12 )
        self.view.layer.shadowRadius = 40
        self.view.layer.shadowOpacity = 1
        self.view.layer & \.shadowColor <- Theme.current.color.shadow
        self.view.layer.shadowOffset = .zero

        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.imageView?.layer.cornerRadius = 4
        self.siteButton.imageView?.layer.masksToBounds = true
        self.siteButton.titleLabel! & \.font <- Theme.current.font.largeTitle
        self.siteButton.layer.shadowRadius = 20
        self.siteButton.layer.shadowOpacity = 1
        self.siteButton.layer & \.shadowColor <- Theme.current.color.shadow
        self.siteButton.layer.shadowOffset = .zero

        // - Hierarchy
        self.view.addSubview( self.siteButton )

        // - Layout
        LayoutConfiguration( view: self.siteButton )
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available( iOS 13, * ) {
            return self.site?.color?.brightness() ?? 0 > 0.8 ? .darkContent: .lightContent
        }
        else {
            return self.site?.color?.brightness() ?? 0 > 0.8 ? .default: .lightContent
        }
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            UIView.performWithoutAnimation {
                self.view.backgroundColor = self.site?.color
                self.siteButton.setImage( self.site?.image, for: .normal )
                self.siteButton.setTitle( self.site?.image == nil ? self.site?.siteName: nil, for: .normal )
                self.preferredContentSize = self.site?.image?.size ?? CGSize( width: 0, height: 200 )

                if let brightness = self.site?.color?.brightness(), brightness > 0.8 {
                    self.siteButton.layer.shadowColor = UIColor.darkGray.cgColor
                }
                else {
                    self.siteButton.layer.shadowColor = UIColor.lightGray.cgColor
                }

                self.view.layoutIfNeeded()
            }
        }
    }
}
