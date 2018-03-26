//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesView: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
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
                .add { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.user?.sites.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = SiteCell.dequeue( from: collectionView, indexPath: indexPath )
        cell.indexPath = indexPath
        cell.site = self.user!.sites[indexPath.item]

        return cell
    }

    class SiteCell: UICollectionViewCell {
        var indexPath: IndexPath?
        var site:      MPSite! {
            didSet {
                self.nameLabel.text = self.site.siteName
//                self.nameLabel.text = "\(self.indexPath!.item): \(self.site.siteName)"
            }
        }

        let nameLabel = UILabel()

        // MARK: - Life

        override init(frame: CGRect) {
            super.init( frame: frame )

            self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: UIFont.labelFontSize )
            self.nameLabel.textAlignment = .center
            self.nameLabel.textColor = .white

            self.contentView.addSubview( self.nameLabel )

            ViewConfiguration( view: self.nameLabel )
                    .add { $0.topAnchor.constraint( equalTo: $1.topAnchor ) }
                    .add { $0.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                    .add { $0.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                    .add { $0.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                    .activate()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
            super.apply( layoutAttributes )

            if let layoutAttributes = layoutAttributes as? LayoutAttributes {
                self.nameLabel.alpha = 1 / sqrt( CGFloat( layoutAttributes.band ) )
                self.nameLabel.font = self.nameLabel.font.withSize( UIFont.labelFontSize * layoutAttributes.scale )
            }
        }
    }

    class Layout: UICollectionViewLayout {
        var itemSize = CGFloat( 0 )
        var items    = [ IndexPath: LayoutAttributes ]()
        var bounds   = CGRect.zero

        // MARK: - Life

        override func prepare() {
            super.prepare()

            let viewSize = self.collectionView?.bounds.size ?? .zero
            self.itemSize = min( viewSize.width / 2, viewSize.height / 2 )
            self.items.removeAll()

            let section = 0
            guard self.collectionView?.numberOfSections ?? 0 > section
            else { return }

            let items    = self.collectionView?.numberOfItems( inSection: section ) ?? 0
            var band     = 1

            self.bounds = CGRect.zero
            for item in 0..<items {
                let indexPath = IndexPath( item: item, section: section )
                let attr      = LayoutAttributes( forCellWith: indexPath )
                attr.band = band
                attr.scale = 1 / sqrt( CGFloat( band ) )

                let size = self.itemSize * attr.scale
                attr.size = CGSize( width: size, height: size )
                let x = (Double( item - 1 ) * .pi) / pow( 2.0, Double( band ) )
                attr.center = CGPoint(
                        x: CGFloat( band - 1 ) * size * CGFloat( sin( x ) ),
                        y: CGFloat( band - 1 ) * size * CGFloat( -cos( x ) ) )
                attr.zIndex = -item
                self.items[indexPath] = attr

                self.bounds = self.bounds.union( CGRectFromCenterWithSize( attr.center, viewSize ) )

                // TODO: Make band calculation less procedural and fucked up.
                let y = (Double( item ) * .pi) / pow( 2.0, Double( band ) )
                if y / (2 * .pi) == (y / (2 * .pi)).rounded( .down ) {
                    band += 1
                }
            }

            self.bounds.origin = .zero
            let center = CGRectGetCenter( self.bounds )
            for item in self.items.values {
                item.center.x += center.x
                item.center.y += center.y
            }
        }

        override var collectionViewContentSize: CGSize {
            return self.bounds.size
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            return [ LayoutAttributes ]( self.items.values )
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> LayoutAttributes? {
            return self.items[indexPath]
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            return true
        }
    }

    class LayoutAttributes: UICollectionViewLayoutAttributes {
        var band:  Int     = 0
        var scale: CGFloat = 1

        override func copy(with zone: NSZone? = nil) -> Any {
            let copy = super.copy( with: zone ) as! LayoutAttributes
            copy.band = self.band
            copy.scale = self.scale
            return copy
        }
    }
}
