//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import AlignedCollectionViewFlowLayout

class MPSitesView: UIView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    var user: MPUser? {
        willSet {
        }
        didSet {
        }
    }

    let collectionView = UICollectionView( frame: .zero, collectionViewLayout: Layout() )

    // MARK: - Life

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.collectionView.registerCell( SiteCell.self )
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.backgroundColor = .clear
        self.collectionView.isOpaque = false

        self.addSubview( self.collectionView )

        ViewConfiguration( view: self.collectionView )
                .addConstrainedInSuperview()
                .activate()
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

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        collectionView.collectionViewLayout.invalidateLayout()
//        collectionView.setCollectionViewLayout(Layout(), animated: true)
//        UIView.animate( withDuration: 2, delay: 0, options: .beginFromCurrentState, animations: {
//            collectionView.collectionViewLayout.invalidateLayout()
        collectionView.performBatchUpdates( {
//                let context = UICollectionViewFlowLayoutInvalidationContext()
//                context.invalidateFlowLayoutDelegateMetrics = true
//                context.invalidateFlowLayoutAttributes = true
//                collectionView.collectionViewLayout.invalidateLayout( with: context )
//                collectionView.setNeedsLayout()
        } )
//        collectionView.setNeedsUpdateConstraints()
//        collectionView.setNeedsLayout()
//        collectionView.setNeedsDisplay()
//        collectionView.layoutIfNeeded()
//            collectionView.performBatchUpdates( nil )
//            collectionView.reloadData()
//        }, completion: nil )
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
//        UIView.animate( withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: {
//            collectionView.collectionViewLayout.invalidateLayout()
//            collectionView.performBatchUpdates( nil )
//            collectionView.reloadData()
//            collectionView.layoutIfNeeded()
//        }, completion: nil )
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    // MARK: - Types

    class Layout: AlignedCollectionViewFlowLayout {
        init() {
            super.init( horizontalAlignment: .left, verticalAlignment: .center )

            self.sectionInset = UIEdgeInsetsMake( 8, 8, 8, 8 )
            self.minimumInteritemSpacing = 10
            self.minimumLineSpacing = 10
            if #available( iOS 10.0, * ) {
                self.estimatedItemSize = UICollectionViewFlowLayoutAutomaticSize
            }
            else {
                self.estimatedItemSize = CGSize(
                        width: UIScreen.main.bounds.size.width - self.sectionInset.left - self.sectionInset.right, height: 200 )
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class SiteCell: UICollectionViewCell, MPSiteObserver {
        var site: MPSite? {
            didSet {
                if let site = self.site {
                    site.observers.register( self ).siteDidChange()
                }
            }
        }
        override var bounds:     CGRect {
            didSet {
                self.contentView.layer.shadowPath = UIBezierPath( roundedRect: self.bounds, cornerRadius: 4 ).cgPath
            }
        }
        override var isSelected: Bool {
            didSet {
                self.setNeedsLayout()
            }
        }

        let contentButton   = UIView()
        let nameLabel       = UILabel()
        let passwordLabel   = UILabel()
        let configureButton = UIButton( type: .custom )

        var widthConstraint:       NSLayoutConstraint!
        var selectedConfiguration: ViewConfiguration!

        // MARK: - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(frame: CGRect) {
            super.init( frame: frame )

            // - View
            self.isOpaque = false
            self.clipsToBounds = true

            self.contentView.layer.shadowRadius = 5
            self.contentView.layer.shadowOpacity = 1
            self.contentView.layer.shadowColor = UIColor( white: 0, alpha: 0.6 ).cgColor
            self.contentView.layer.masksToBounds = true
            self.contentView.clipsToBounds = true
            self.layer.masksToBounds = true
            self.clipsToBounds = true

            self.contentButton.layer.cornerRadius = 4
            self.contentButton.layer.shadowOffset = .zero
            self.contentButton.layer.shadowRadius = 5
            self.contentButton.layer.shadowOpacity = 0
            self.contentButton.layer.shadowColor = UIColor.white.cgColor
            self.contentButton.layer.borderWidth = 1
            self.contentButton.layer.borderColor = UIColor( white: 0.15, alpha: 0.6 ).cgColor

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

            // - Hierarchy
            self.contentView.addSubview( self.contentButton )
            self.contentButton.addSubview( self.nameLabel )
            self.contentButton.addSubview( self.passwordLabel )
            self.contentButton.addSubview( self.configureButton )

            // - Layout
            self.contentView.translatesAutoresizingMaskIntoConstraints = false
            self.widthConstraint = self.contentView.widthAnchor.constraint( equalToConstant: UIScreen.main.bounds.width ).activate()

            ViewConfiguration( view: self.contentButton )
                    .addConstrainedInSuperview().activate()

            ViewConfiguration( view: self.nameLabel )
                    .add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                    .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .add { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    .activate()

            ViewConfiguration( view: self.configureButton )
                    .add { $0.layoutMarginsGuide.topAnchor.constraint( lessThanOrEqualTo: $1.topAnchor ) }
                    .add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .add { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    .activate()

            self.selectedConfiguration = ViewConfiguration()
                    .add( ViewConfiguration( view: self.contentButton ) { active, inactive in
                        inactive.add( 0, forKey: "layer.shadowOpacity" )
                        active.add( 0.7, forKey: "layer.shadowOpacity" )
                    } )
                    .add( ViewConfiguration( view: self.passwordLabel ) { active, inactive in
                        inactive.add( true, forKey: "hidden" )
                        active.add( false, forKey: "hidden" )
                        active.add { $0.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                        active.add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                        active.add { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                        active.add { self.nameLabel.topAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    } )
        }

        override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes)
                        -> UICollectionViewLayoutAttributes {

            // Stretch cell to collection view width.
            if let collectionView = UICollectionView.find( asSuperviewOf: self ),
               let collectionViewLayout = collectionView.collectionViewLayout as? Layout {
                self.widthConstraint.constant = collectionView.bounds.size.width
                        - collectionViewLayout.sectionInset.left - collectionViewLayout.sectionInset.right
            }

            // Determine size based on Auto Layout.
            let attr = super.preferredLayoutAttributesFitting( layoutAttributes )
            attr.size = self.systemLayoutSizeFitting( UILayoutFittingCompressedSize )

            return attr
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.selectedConfiguration.activated = self.isSelected
        }

        // MARK: - MPSiteObserver

        func siteDidChange() {
            PearlMainQueue {
                self.nameLabel.text = self.site?.siteName
                self.contentButton.backgroundColor = self.site?.color.withAlphaComponent( 0.2 )
            }
        }
    }
}
