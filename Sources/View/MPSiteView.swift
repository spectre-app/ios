//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteView: UIView, MPSiteObserver {
    var site: MPSite? {
        willSet {
            self.site?.observers.unregister( self )
        }
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
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = .zero
        self.layer.shadowRadius = 40

        self.siteButton.imageView?.layer.cornerRadius = 4
        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.imageView?.clipsToBounds = true
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
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
        ViewConfiguration( view: toolBar )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
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

                if let brightness = self.site?.color.brightness(), brightness < 0.1 {
                    self.siteButton.layer.shadowColor = UIColor.white.cgColor
                }
                else {
                    self.siteButton.layer.shadowColor = UIColor.black.cgColor
                }
            }
        }
    }
}
