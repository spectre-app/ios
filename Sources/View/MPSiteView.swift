//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteView: UIView, MPSiteObserver {
    var site: MPSite? {
        didSet {
            if let site = self.site {
                site.observers.register( self ).siteDidChange()
            }
        }
    }

    let siteButton     = UIButton( type: .custom )
    let settingsButton = MPButton( image: UIImage( named: "icon_settings" ) )
    let recoveryButton = MPButton( image: UIImage( named: "icon_question" ) )
    let keysButton     = MPButton( image: UIImage( named: "icon_key" ) )

    // MARK: - Life

    init() {
        super.init( frame: .zero )
        self.clipsToBounds = true

        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.imageView?.layer.cornerRadius = 4
        self.siteButton.layer.shadowRadius = 20
        self.siteButton.layer.shadowOffset = .zero
        self.siteButton.layer.shadowOpacity = 0.3
        if #available( iOS 11.0, * ) {
            self.siteButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.siteButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .title1 )
        }

        let toolBar = UIStackView( arrangedSubviews: [ self.settingsButton, self.recoveryButton, self.keysButton ] )
        toolBar.isLayoutMarginsRelativeArrangement = true
        toolBar.layoutMargins = UIEdgeInsetsMake( 8, 8, 8, 8 )
        toolBar.axis = .vertical
        toolBar.spacing = 8

        // - Hierarchy
        self.addSubview( self.siteButton )
        self.addSubview( toolBar )

        // - Layout
        ViewConfiguration( view: self.siteButton )
                .constrainTo { $0.topAnchor.constraint( lessThanOrEqualTo: $1.topAnchor, constant: 2 ) }
                .constrainTo { $0.leadingAnchor.constraint( lessThanOrEqualTo: $1.leadingAnchor ) }
                .constrainTo { $0.trailingAnchor.constraint( greaterThanOrEqualTo: $1.trailingAnchor ) }
                .constrainTo { $0.bottomAnchor.constraint( greaterThanOrEqualTo: $1.bottomAnchor, constant: -2 ) }
                .constrainTo { $0.centerXAnchor.constraint( equalTo: $1.centerXAnchor ) }
                .constrainTo { $0.centerYAnchor.constraint( equalTo: $1.centerYAnchor ) }
                .activate()
        ViewConfiguration( view: toolBar )
                .constrainTo { $0.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.bottomAnchor.constraint( greaterThanOrEqualTo: $1.bottomAnchor ) }
                .activate()
        ViewConfiguration( view: self )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor, multiplier: 1.618 ) }
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - MPSiteObserver

    func siteDidChange() {
        PearlMainQueue {
            self.unanimate {
                self.backgroundColor = self.site?.color
                self.siteButton.setImage( self.site?.image, for: .normal )
                self.siteButton.setTitle( self.site?.image == nil ? self.site?.siteName: nil, for: .normal )
//                self.nameLabel.text = self.site?.siteName
//                self.nameLabel.isHidden = self.site?.image != nil
            }
        }
    }
}
