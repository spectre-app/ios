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

    let imageButton = UIButton( type: .custom )
    let nameLabel   = UILabel()

    // MARK: - Life

    init() {
        super.init( frame: .zero )
        self.clipsToBounds = true

        self.imageButton.imageView?.contentMode = .scaleAspectFill
        self.imageButton.imageView?.layer.cornerRadius = 4
        self.imageButton.layer.shadowRadius = 20
        self.imageButton.layer.shadowOffset = .zero
        self.imageButton.layer.shadowOpacity = 0.3

        if #available( iOS 11.0, * ) {
            self.imageButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.imageButton.titleLabel?.font = UIFont.preferredFont( forTextStyle: .title1 )
        }
        self.nameLabel.textAlignment = .center
        self.nameLabel.textColor = .white

        // - Hierarchy
        self.addSubview( self.imageButton )
        self.addSubview( self.nameLabel )

        // - Layout
        ViewConfiguration( view: self.imageButton )
                .constrainTo { $0.topAnchor.constraint( lessThanOrEqualTo: $1.topAnchor, constant: 2 ) }
                .constrainTo { $0.leadingAnchor.constraint( lessThanOrEqualTo: $1.leadingAnchor ) }
                .constrainTo { $0.trailingAnchor.constraint( greaterThanOrEqualTo: $1.trailingAnchor ) }
                .constrainTo { $0.bottomAnchor.constraint( greaterThanOrEqualTo: $1.bottomAnchor, constant: -2 ) }
                .constrainTo { $0.centerXAnchor.constraint( equalTo: $1.centerXAnchor ) }
                .constrainTo { $0.centerYAnchor.constraint( equalTo: $1.centerYAnchor ) }
                .activate()
        ViewConfiguration( view: self.nameLabel )
                .constrainTo { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor, constant: 8 ) }
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
                self.imageButton.setImage( self.site?.image, for: .normal )
                self.imageButton.setTitle( self.site?.image == nil ? self.site?.siteName: nil, for: .normal )
//                self.nameLabel.text = self.site?.siteName
//                self.nameLabel.isHidden = self.site?.image != nil
            }
        }
    }
}
