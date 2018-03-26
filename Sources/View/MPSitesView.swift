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
                .add { $0.topAnchor.constraint( equalTo: self.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.bottomAnchor ) }
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
                    .add { $0.topAnchor.constraint( equalTo: self.contentView.topAnchor ) }
                    .add { $0.leadingAnchor.constraint( equalTo: self.contentView.leadingAnchor ) }
                    .add { $0.trailingAnchor.constraint( equalTo: self.contentView.trailingAnchor ) }
                    .add { $0.bottomAnchor.constraint( equalTo: self.contentView.bottomAnchor ) }
                    .activate()
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
            super.apply( layoutAttributes )

            if let layoutAttributes = layoutAttributes as? LayoutAttributes {
                self.nameLabel.alpha = 1 / sqrt( CGFloat( layoutAttributes.band ) )
            }
        }
    }

    class Layout: UICollectionViewLayout {
        var itemSize = CGFloat( 0 )
        var items    = [ IndexPath: LayoutAttributes ]()

        // MARK: - Life

        override func prepare() {
            super.prepare()

            self.itemSize = min( self.collectionViewContentSize.width / 2, self.collectionViewContentSize.height / 2 )
            self.items.removeAll()

            let section = 0
            guard self.collectionView?.numberOfSections ?? 0 > section
            else { return }

            let center = CGPoint(
                    x: self.collectionViewContentSize.width / 2,
                    y: self.collectionViewContentSize.height / 2 )

            let items = self.collectionView?.numberOfItems( inSection: section ) ?? 0
            var band  = 1
            for item in 0..<items {
                let indexPath = IndexPath( item: item, section: section )
                let attr      = LayoutAttributes( forCellWith: indexPath )
                let size      = self.itemSize / sqrt( CGFloat( band ) )
                attr.band = band
                attr.size = CGSize( width: size, height: size )
                attr.center = center
                let x = (Double( item - 1 ) * .pi) / pow( 2.0, Double( band ) )
                attr.center.x += CGFloat( band - 1 ) * size * CGFloat( sin( x ) )
                attr.center.y -= CGFloat( band - 1 ) * size * CGFloat( cos( x ) )
                attr.zIndex = -item
                self.items[indexPath] = attr

                // TODO: Make band calculation less procedural and fucked up.
                let y = (Double( item ) * .pi) / pow( 2.0, Double( band ) )
                if y / (2 * .pi) == (y / (2 * .pi)).rounded( .down ) {
                    band += 1
                }
            }
        }

        override var collectionViewContentSize: CGSize {
            return self.collectionView?.bounds.size ?? .zero
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
        var band : Int = 0

        override func copy(with zone: NSZone? = nil) -> Any {
            var copy = super.copy(with: zone) as! LayoutAttributes
            copy.band = self.band
            return copy
        }
    }
}
