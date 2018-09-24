//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteDetailsViewController: UIViewController, MPSiteObserver {
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

    let backgroundImage  = UIImageView()
    let effectView       = UIVisualEffectView( effect: UIBlurEffect( style: .dark ) )
    let closeButton      = MPButton( title: "╳" )
    let headingImageView = AutoresizingImageView()
    let headingLabel     = UILabel()

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(site: MPSite) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.site = site
        }
    }

    override func viewDidLoad() {

        // - View
        self.backgroundImage.contentMode = .scaleAspectFill

        self.closeButton.darkBackground = true
        self.closeButton.effectBackground = false
        self.closeButton.layoutMargins = UIEdgeInsetsMake( 8, 8, 8, 8 )
        self.closeButton.button.addTarget( self, action: #selector( close ), for: .touchUpInside )

        self.headingImageView.image = UIImage( named: "icon_sliders" )
        self.headingLabel.textColor = .white
        self.headingLabel.textAlignment = .center
        if #available( iOS 11.0, * ) {
            self.headingLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.headingLabel.font = UIFont.preferredFont( forTextStyle: .title1 )
        }

        // - Hierarchy
        self.view.addSubview( self.backgroundImage )
        self.view.addSubview( self.effectView )
        self.effectView.contentView.addSubview( self.headingImageView )
        self.effectView.contentView.addSubview( self.headingLabel )
        self.effectView.contentView.addSubview( self.closeButton )

        // - Layout
        ViewConfiguration( view: self.backgroundImage ).constrainToSuperview().activate()
        ViewConfiguration( view: self.effectView ).constrainToSuperview().activate()
        ViewConfiguration( view: self.headingImageView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.layoutMarginsGuide.centerXAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 150 ) }
                .activate()
        ViewConfiguration( view: self.headingLabel )
                .constrainTo { $1.topAnchor.constraint( equalTo: self.headingImageView.bottomAnchor, constant: 8 ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .activate()
        ViewConfiguration( view: self.closeButton )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.layoutMarginsGuide.topAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .activate()
    }

    @objc
    func close() {
        self.dismiss( animated: true )
    }

    // MARK: - MPSiteObserver

    func siteDidChange() {
        PearlMainQueue {
            self.backgroundImage.image = self.site?.image
            self.backgroundImage.backgroundColor = self.site?.color
            self.headingLabel.text = self.site?.siteName
        }
    }
}
