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

    let effectView              = UIVisualEffectView( effect: UIBlurEffect( style: .light ) )
    let closeButton             = MPButton( title: "╳" )
    let headingImageView        = MPImageView( image: UIImage( named: "icon_sliders" ) )
    let headingLabel            = UILabel()
    let contentView             = UIView()
    let tableView               = UITableView( frame: .zero, style: .plain )

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(site: MPSite) {
        super.init( nibName: nil, bundle: nil )
        self.modalPresentationStyle = .overCurrentContext

        defer {
            self.site = site
        }
    }

    override func viewDidLoad() {

        // - View
        self.effectView.contentView.layoutMargins = UIEdgeInsetsMake( 12, 12, 12, 12 )

        self.closeButton.button.addTarget( self, action: #selector( close ), for: .touchUpInside )

        self.headingLabel.textColor = .white
        self.headingLabel.shadowColor = .black
        self.headingImageView.preservesImageRatio = true
        if #available( iOS 11.0, * ) {
            self.headingLabel.font = UIFont.preferredFont( forTextStyle: .largeTitle )
        }
        else {
            self.headingLabel.font = UIFont.preferredFont( forTextStyle: .title1 )
        }
        self.headingLabel.font = UIFont.preferredFont( forTextStyle: .headline )

        let tableViewEffect = UIView( containing: self.tableView, withLayoutMargins: .zero )!
        tableViewEffect.layer.shadowRadius = 8
        tableViewEffect.layer.shadowOpacity = 0.382
        self.tableView.layer.cornerRadius = 8
        self.contentView.backgroundColor = UIColor( white: 0.9, alpha: 1 )
        self.contentView.layer.shadowOpacity = 1
        self.contentView.layer.shadowRadius = 80

        // - Hierarchy
        self.view.addSubview( self.effectView )
        self.effectView.contentView.addSubview( self.contentView )
        self.effectView.contentView.addSubview( self.closeButton )
        self.contentView.addSubview( self.headingImageView )
        self.contentView.addSubview( self.headingLabel )
        self.contentView.addSubview( tableViewEffect )

        // - Layout
        ViewConfiguration( view: self.effectView ).constrainToSuperview().activate()
        ViewConfiguration( view: self.contentView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor, multiplier: 0.618 ) }
                .activate()
        ViewConfiguration( view: self.headingLabel )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: self.tableView.leadingAnchor, constant: 8 ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: self.tableView.trailingAnchor, constant: -8 ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.tableView.topAnchor, constant: -8 ) }
                .activate()
        ViewConfiguration( view: self.headingImageView )
                .constrainTo { $1.trailingAnchor.constraint( equalTo: self.tableView.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: self.tableView.topAnchor, constant: 20 ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 96 ) }
                .activate()
        ViewConfiguration( view: tableViewEffect )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: -40 ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.layoutMarginsGuide.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.layoutMarginsGuide.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.layoutMarginsGuide.bottomAnchor ) }
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
            self.headingLabel.text = self.site?.siteName
            self.contentView.layer.shadowColor = self.site?.color.cgColor
        }
    }
}
