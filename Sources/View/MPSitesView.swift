//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AlignedCollectionViewFlowLayout

class MPSitesView: UICollectionView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    var user: MPUser? {
        didSet {
            self.reloadData()
        }
    }

    // MARK: - Life

    init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        self.registerCell( SiteCell.self )
        self.delegate = self
        self.dataSource = self
        self.backgroundColor = .clear
        self.isOpaque = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
                    -> Int {
        return self.user?.sites.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
                    -> UICollectionViewCell {
        let cell = SiteCell.dequeue( from: collectionView, indexPath: indexPath )
        cell.site = self.user?.sites[indexPath.item]

        return cell
    }

    // MARK: - UICollectionViewDelegate

    // MARK: - UICollectionViewDelegateFlowLayout

    // MARK: - Types

    class Layout: AlignedCollectionViewFlowLayout {
        init() {
            super.init( horizontalAlignment: .left, verticalAlignment: .center )

            self.minimumLineSpacing = 10
            self.minimumInteritemSpacing = 10
            self.sectionInset = UIEdgeInsetsMake( 8, 8, 8, 8 )

            if #available( iOS 10.0, * ) {
                self.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
            }
            else {
                self.estimatedItemSize = CGSize(
                        width: UIScreen.main.bounds.size.width - self.sectionInset.left - self.sectionInset.right, height: 50 )
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class SiteCell: AutoLayoutCollectionViewCell, MPSiteObserver {
        var site: MPSite? {
            didSet {
                if let site = self.site {
                    site.observers.register( self ).siteDidChange()
                }
            }
        }
        override var bounds:        CGRect {
            didSet {
                self.contentView.layer.shadowPath = UIBezierPath( roundedRect: self.bounds, cornerRadius: 4 ).cgPath
            }
        }
        override var isSelected:    Bool {
            didSet {
                if oldValue != self.isSelected {
                    self.invalidateLayout( animated: true )

                    if !self.isSelected {
                        self.isExpanded = false
                    }
                }
            }
        }
        override var isHighlighted: Bool {
            didSet {
                if oldValue != self.isHighlighted {
                    self.invalidateLayout( animated: true )
                }
            }
        }
        var isExpanded: Bool = false {
            didSet {
                if oldValue != self.isExpanded {
                    self.invalidateLayout( animated: true )
                }
            }
        }

        let backgroundView  = UIView()
        let indicatorView  = UIView()
        let nameLabel       = UILabel()
        let passwordLabel   = UILabel()
        let configureButton = UIButton( type: .custom )

        var selectedConfiguration:    ViewConfiguration!
        var highlightedConfiguration: ViewConfiguration!
        var expandedConfiguration:    ViewConfiguration!

        // MARK: - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(frame: CGRect) {
            super.init( frame: frame )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true
            self.fullWidth = true;

            self.contentView.layer.shadowRadius = 5
            self.contentView.layer.shadowOpacity = 1
            self.contentView.layer.shadowColor = UIColor( white: 0, alpha: 0.6 ).cgColor
            self.contentView.layer.masksToBounds = true
            self.contentView.clipsToBounds = true
            self.layer.masksToBounds = true
            self.clipsToBounds = true

            self.backgroundView.backgroundColor = UIColor( white: 0, alpha: 0.6 )
            self.backgroundView.layer.cornerRadius = 4
            self.backgroundView.layer.shadowOffset = .zero
            self.backgroundView.layer.shadowRadius = 5
            self.backgroundView.layer.shadowOpacity = 0
            self.backgroundView.layer.shadowColor = UIColor.white.cgColor
            self.backgroundView.layer.borderWidth = 1
            self.backgroundView.layer.borderColor = UIColor( white: 0.15, alpha: 0.6 ).cgColor

            self.indicatorView.backgroundColor = UIColor( white: 0, alpha: 0.6 )
            self.indicatorView.layer.cornerRadius = 4
            self.indicatorView.layer.borderWidth = 1
            self.indicatorView.layer.borderColor = UIColor( white: 0, alpha: 1 ).cgColor

            self.nameLabel.font = UIFont( name: "Futura-CondensedMedium", size: 22 )
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = UIColor.lightText
            self.nameLabel.shadowColor = .black

            self.passwordLabel.text = "Jaji9,GowzLanr"
            self.passwordLabel.font = UIFont( name: "SourceCodePro-Black", size: 28 )
            self.passwordLabel.textAlignment = .center
            self.passwordLabel.textColor = UIColor( red: 0.4, green: 0.8, blue: 1, alpha: 1 )
            self.passwordLabel.shadowColor = .black

            self.configureButton.setImage( UIImage( named: "icon_tools" ), for: .normal )
            self.configureButton.alpha = 0.1
            self.configureButton.addTargetBlock( { _, _ in self.isExpanded = true }, for: .touchUpInside )

            // - Hierarchy
            self.contentView.addSubview( self.backgroundView )
            self.backgroundView.addSubview( self.nameLabel )
            self.backgroundView.addSubview( self.passwordLabel )
            self.backgroundView.addSubview( self.configureButton )

            // - Layout
            self.contentView.translatesAutoresizingMaskIntoConstraints = false

            ViewConfiguration( view: self.backgroundView )
                    .addConstrainedInSuperview().activate()

            ViewConfiguration( view: self.nameLabel )
                    .add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                    .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .add { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    .activate()

            ViewConfiguration( view: self.passwordLabel )
                    .add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                    .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .activate()

            ViewConfiguration( view: self.configureButton )
                    .add { $0.layoutMarginsGuide.topAnchor.constraint( lessThanOrEqualTo: $1.topAnchor ) }
                    .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .add { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    .activate()

            self.highlightedConfiguration = ViewConfiguration()
                    .add( ViewConfiguration( view: self.backgroundView ) { active, inactive in
                        inactive.add( 0, forKey: "layer.shadowOpacity" )
                        active.add( 0.7, forKey: "layer.shadowOpacity" )
                    } )
            self.selectedConfiguration = ViewConfiguration()
                    .add( ViewConfiguration( view: self.passwordLabel ) { active, inactive in
                        inactive.add( true, forKey: "hidden" )
                        inactive.add { $0.topAnchor.constraint( equalTo: $1.bottomAnchor ) }
                        active.add( false, forKey: "hidden" )
                        active.add { $0.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                        active.add { self.nameLabel.topAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    } )
                    .add( ViewConfiguration( view: self.nameLabel ) { active, inactive in
                        inactive.add( 22, forKey: "fontSize" )
                        active.add( 12, forKey: "fontSize" )
                    } )
            self.expandedConfiguration = ViewConfiguration()
        }

        override func updateConstraints() {
            super.updateConstraints()

            self.selectedConfiguration.activated = self.isSelected
            self.highlightedConfiguration.activated = self.isHighlighted
            self.expandedConfiguration.activated = self.isExpanded
        }

        // MARK: - MPSiteObserver

        func siteDidChange() {
            PearlMainQueue {
                self.nameLabel.text = self.site?.siteName
                self.indicatorView.backgroundColor = self.site?.color.withAlphaComponent( 0.85 )
            }
        }
    }
}
