//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteHeaderView: UIView, MPSiteObserver {
    public var site: MPSite? {
        willSet {
            self.site?.observers.unregister( observer: self )
        }
        didSet {
            if let site = self.site {
                site.observers.register( observer: self ).siteDidChange( site )
            }
        }
    }

    private let siteButton     = UIButton( type: .custom )

    // MARK: --- Life ---

    init() {
        super.init( frame: .zero )

        // - View
        self.layoutMargins = UIEdgeInsets( top: 12, left: 12, bottom: 20, right: 12 )
        self.layer.shadowRadius = 40
        self.layer.shadowOpacity = 1
        self.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        self.layer.shadowOffset = .zero

        self.siteButton.imageView?.layer.cornerRadius = 4
        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.imageView?.clipsToBounds = true
        self.siteButton.titleLabel?.font = MPTheme.global.font.largeTitle.get()
        self.siteButton.layer.shadowRadius = 20
        self.siteButton.layer.shadowOpacity = 1
        self.siteButton.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        self.siteButton.layer.shadowOffset = .zero

        // - Hierarchy
        self.addSubview( self.siteButton )

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

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            UIView.performWithoutAnimation {
                self.backgroundColor = self.site?.color
                self.siteButton.setImage( self.site?.image, for: .normal )
                self.siteButton.setTitle( self.site?.image == nil ? self.site?.siteName: nil, for: .normal )

                if let brightness = self.site?.color?.brightness(), brightness > 0.8 {
                    self.siteButton.layer.shadowColor = MPTheme.global.color.glow.get()?.cgColor
                }
                else {
                    self.siteButton.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
                }

                self.layoutIfNeeded()
            }
        }
    }
}
