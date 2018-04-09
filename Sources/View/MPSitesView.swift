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
        cell.indexPath = indexPath
        cell.site = self.user!.sites[indexPath.item]

        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIView.animate( withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: {
            collectionView.performBatchUpdates( nil )
            collectionView.layoutIfNeeded()
        }, completion: nil )
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        UIView.animate( withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: {
            collectionView.performBatchUpdates( nil )
            collectionView.layoutIfNeeded()
        }, completion: nil )
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath)
                    -> CGSize {
        guard let flowLayout = collectionViewLayout as? Layout
        else { fatalError( "unexpected collectionView layout: \(collectionViewLayout)" ) }

        let selected      = collectionView.indexPathsForSelectedItems?.contains( indexPath ) ?? false
        let columns       = selected ? 1: 2
        var availableSize = collectionView.bounds.size
        availableSize.width -= flowLayout.sectionInset.left + flowLayout.sectionInset.right
        availableSize.width -= flowLayout.minimumInteritemSpacing * CGFloat( columns - 1 )

        return CGSize( width: availableSize.width / CGFloat( columns ), height: selected ? 200: 100 )
    }

    // MARK: - Types

    class Layout: AlignedCollectionViewFlowLayout {
        init() {
            super.init( horizontalAlignment: .left, verticalAlignment: .center )

            self.minimumInteritemSpacing = 8
            self.minimumLineSpacing = 8
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class SiteCell: UICollectionViewCell, MPSiteObserver {
        var indexPath: IndexPath?
        var site:      MPSite? {
            didSet {
                if let site = self.site {
                    site.observers.register( self ).siteDidChange()
                }
            }
        }
        override var isSelected: Bool {
            didSet {
                self.setNeedsLayout()
            }
        }

        let tagView   = UIView()
        let nameLabel = UILabel()

        var selectedConfiguration: ViewConfiguration!

        // MARK: - Life

        override init(frame: CGRect) {
            super.init( frame: frame )

            self.tagView.layer.cornerRadius = 4;
            self.tagView.layer.shadowOffset = .zero;
            self.tagView.layer.shadowRadius = 5;
            self.tagView.layer.shadowOpacity = 0;
            self.tagView.layer.shadowColor = UIColor.white.cgColor;
            self.tagView.layer.borderWidth = 1;
            self.tagView.layer.borderColor = UIColor( white: 0.15, alpha: 0.6 ).cgColor;

            self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = .white
            self.nameLabel.shadowColor = .black

            self.contentView.addSubview( self.tagView )
            self.contentView.addSubview( self.nameLabel )

            self.tagView.layer.masksToBounds = true

            self.selectedConfiguration = ViewConfiguration()
                    .add( ViewConfiguration( view: self.tagView ) { active, inactive in
                        inactive.add { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                        inactive.add { $0.layoutMarginsGuide.centerYAnchor.constraint( equalTo: $1.centerYAnchor ) }
                        inactive.add { $1.widthAnchor.constraint( equalTo: $1.heightAnchor ) }
                        inactive.add { $1.heightAnchor.constraint( equalToConstant: 40 ) }
                        inactive.add( 20, forKey: "layer.cornerRadius" )
                        active.addConstrainedInSuperview()
                        active.add( 8, forKey: "layer.cornerRadius" )
                    } )
                    .add( ViewConfiguration( view: self.nameLabel ) { active, inactive in
                        inactive.add { self.tagView.centerXAnchor.constraint( equalTo: $1.leadingAnchor ) }
                        inactive.add { self.tagView.centerYAnchor.constraint( equalTo: $1.centerYAnchor ) }
                        active.add { $0.centerXAnchor.constraint( equalTo: $1.centerXAnchor ) }
                        active.add { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    } )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            self.selectedConfiguration.activated = self.isSelected
        }

        // MARK: - MPSiteObserver
        func siteDidChange() {
            PearlMainQueue {
//          self.nameLabel.text = "\(self.indexPath!.item): \(self.site.siteName)"
                self.nameLabel.text = self.site?.siteName
                self.tagView.backgroundColor = self.site?.color
            }
        }
    }
}
