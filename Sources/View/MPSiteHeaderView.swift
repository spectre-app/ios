//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteHeaderView: UIView, MPSiteObserver {
    public let observers = Observers<MPSiteHeaderObserver>()
    public var site: MPSite? {
        willSet {
            self.site?.observers.unregister( self )
        }
        didSet {
            if let site = self.site {
                site.observers.register( self ).siteDidChange( site )
            }
        }
    }

    private let siteButton     = UIButton( type: .custom )
    private let settingsButton = MPButton( image: UIImage( named: "icon_sliders" ) )
    private let recoveryButton = MPButton( image: UIImage( named: "icon_btn_question" ) )
    private let keysButton     = MPButton( image: UIImage( named: "icon_key" ) )

    // MARK: --- Life ---

    init() {
        super.init( frame: .zero )

        // - View
        self.layoutMargins = UIEdgeInsets( top: 12, left: 12, bottom: 20, right: 12 )
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = .zero
        self.layer.shadowRadius = 40

        self.siteButton.imageView?.layer.cornerRadius = 4
        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.imageView?.clipsToBounds = true
        self.siteButton.layer.shadowRadius = 20
        self.siteButton.layer.shadowOffset = .zero
        self.siteButton.layer.shadowOpacity = 0.382
        if #available( iOS 11.0, * ) {
            self.siteButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.siteButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .title1 ).withSymbolicTraits( .traitBold )
        }

        let leadingToolBar = UIStackView( arrangedSubviews: [ self.settingsButton ] )
        leadingToolBar.axis = .vertical
        leadingToolBar.spacing = 12

        let trailingToolBar = UIStackView( arrangedSubviews: [ self.recoveryButton, self.keysButton ] )
        trailingToolBar.axis = .vertical
        trailingToolBar.spacing = 12

        self.settingsButton.button.addAction( for: .touchUpInside ) { _, _ in
            if let site = self.site {
                self.observers.notify { $0.siteOpenDetails( for: site ) }
            }
        }

        // - Hierarchy
        self.addSubview( self.siteButton )
        self.addSubview( leadingToolBar )
        self.addSubview( trailingToolBar )

        // - Layout
        LayoutConfiguration( view: self.siteButton )
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
        LayoutConfiguration( view: leadingToolBar )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .activate()
        LayoutConfiguration( view: trailingToolBar )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.layoutMarginsGuide.bottomAnchor ) }
                .activate()
        LayoutConfiguration( view: self )
                .constrainTo { $1.widthAnchor.constraint( equalTo: $1.heightAnchor, multiplier: 1.618 ) }
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            self.unanimated {
                self.backgroundColor = self.site?.color
                self.siteButton.setImage( self.site?.image, for: .normal )
                self.siteButton.setTitle( self.site?.image == nil ? self.site?.siteName: nil, for: .normal )

                if let brightness = self.site?.color?.brightness(), brightness < 0.1 {
                    self.siteButton.layer.shadowColor = UIColor.white.cgColor
                    self.settingsButton.darkBackground = true
                    self.recoveryButton.darkBackground = true
                    self.keysButton.darkBackground = true
                }
                else {
                    self.siteButton.layer.shadowColor = UIColor.black.cgColor
                    self.settingsButton.darkBackground = false
                    self.recoveryButton.darkBackground = false
                    self.keysButton.darkBackground = false
                }
            }
        }
    }
}

@objc
protocol MPSiteHeaderObserver {
    func siteOpenDetails(for site: MPSite)
}
