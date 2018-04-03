//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

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
                .addConstraintedInSuperview()
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
        cell.indexPath = indexPath
        cell.site = self.user!.sites[indexPath.item]

        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        collectionView.setCollectionViewLayout( Layout(), animated: true )
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
//        collectionView.setCollectionViewLayout( Layout(), animated: true )
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath)
                    -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout
        else { fatalError( "unexpected collectionView layout: \(collectionViewLayout)" ) }

        let selected      = collectionView.indexPathsForSelectedItems?.contains( indexPath ) ?? false
        let columns       = selected ? 1: 2
        var availableSize = collectionView.bounds.size
        availableSize.width -= flowLayout.sectionInset.left + flowLayout.sectionInset.right
        availableSize.width -= flowLayout.minimumInteritemSpacing * CGFloat( columns - 1 )

        return CGSize( width: availableSize.width / CGFloat( columns ), height: selected ? 200: 100 )
    }

    // MARK: - Types

    class Layout: UICollectionViewFlowLayout {
        override init() {
            super.init()

            self.sectionInset = UIEdgeInsetsMake( 8, 8, 8, 8 )
            self.minimumInteritemSpacing = 8
            self.minimumLineSpacing = 8
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class SiteCell: UICollectionViewCell {
        var indexPath: IndexPath?
        var site:      MPSite! {
            didSet {
                self.setNeedsLayout()
            }
        }
        override var isSelected: Bool {
            didSet {
                self.setNeedsLayout()
            }
        }

        let effectView = UIVisualEffectView( effect: nil )
        let tagView    = UIView()
        let nameLabel  = UILabel()

        var tagConfiguration: ViewConfiguration!

        // MARK: - Life

        override init(frame: CGRect) {
            super.init( frame: frame )

            self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = .white

            self.contentView.addSubview( self.effectView )
            self.effectView.contentView.addSubview( self.tagView )
            self.effectView.contentView.addSubview( self.nameLabel )

            self.tagView.layer.masksToBounds = true

            ViewConfiguration( view: self.effectView )
                    .addConstraintedInSuperview()
                    .activate()
            self.tagConfiguration = ViewConfiguration( view: self.tagView ) { active, inactive in
                active.addConstraintedInSuperview()
                inactive.addConstraintedInSuperview( forAttributes: [ .alignAllTop, .alignAllBottom ] )
                inactive.add { $0.leadingAnchor.constraint( equalTo: $1.centerXAnchor ) }
                inactive.add { $0.heightAnchor.constraint( equalTo: $1.heightAnchor ) }
                inactive.add { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
            }
            ViewConfiguration( view: self.nameLabel )
                    .addConstraintedInSuperview()
                    .activate()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            self.nameLabel.text = self.site.siteName
//            self.nameLabel.text = "\(self.indexPath!.item): \(self.site.siteName)"
            let color = UIColor( red: CGFloat( drand48() ), green: CGFloat( drand48() ), blue: CGFloat( drand48() ), alpha: 1 )
            self.window!.layoutIfNeeded()
            UIView.animate( withDuration: 3, delay: 0, options: [ .allowAnimatedContent, .beginFromCurrentState ], animations: {
                self.effectView.effect = self.isSelected ? UIBlurEffect( style: .dark ): nil
                self.tagConfiguration.activated = self.isSelected
                self.tagView.layer.cornerRadius = self.tagView.bounds.size.height / 2
                self.tagView.backgroundColor = color
                self.window!.layoutIfNeeded()
            }, completion: nil )
        }
    }
}
