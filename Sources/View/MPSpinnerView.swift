//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import Stellar

public class MPSpinnerView: UICollectionView {
    public var scrolledItem: Int {
        let currentOffset = self.contentOffset.y
        let maximumOffset = max( 0, self.contentSize.height - self.bounds.size.height )
        let scrolledItem  = maximumOffset > 0 ? CGFloat( self.numberOfItems( inSection: 0 ) - 1 ) * currentOffset / maximumOffset: 0
        return Int( scrolledItem.rounded( .toNearestOrAwayFromZero ) )
    }

    // MARK: --- Life ---

    public init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        self.isPagingEnabled = true
        self.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( didTap ) ) )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Private ---

    @objc
    private func didTap(recognizer: UITapGestureRecognizer) {
        if self.indexPathsForSelectedItems?.count ?? 0 > 0 {
            self.selectItem( at: nil, animated: true, scrollPosition: .centeredVertically )
        }
        else {
            self.selectItem( at: IndexPath( item: self.scrolledItem, section: 0 ), animated: true, scrollPosition: .centeredVertically )
        }
    }

    internal class Layout: UICollectionViewLayout {
        internal var items       = [ Int: UICollectionViewLayoutAttributes ]()
        internal var itemCount   = 0
        internal var itemSize    = CGSize.zero
        internal var contentSize = CGSize.zero
        override var collectionViewContentSize: CGSize {
            return self.contentSize
        }

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout( with: context )

            if context.invalidateEverything || context.invalidateDataSourceCounts {
                self.items.removeAll()
                self.contentSize = .zero
            }
            else {
                context.invalidatedItemIndexPaths?.forEach { self.items.removeValue( forKey: $0.item ) }
            }
        }

        override func prepare() {
            super.prepare()

            guard let collectionView = self.collectionView
            else {
                return
            }

            self.itemCount = collectionView.numberOfItems( inSection: 0 )
            self.itemSize = CGSize( width: collectionView.bounds.size.width, height: collectionView.bounds.size.height )
            self.contentSize = CGSize( width: self.itemSize.width, height: self.itemSize.height * CGFloat( self.itemCount ) )
            guard self.itemCount > 0, self.itemCount != self.items.count, self.itemSize.height > 0
            else {
                return
            }

            let currentOffset = collectionView.contentOffset.y
            let maximumOffset = self.contentSize.height - collectionView.bounds.size.height
            let scrolledItem  = maximumOffset > 0 ? CGFloat(self.itemCount - 1) * currentOffset / maximumOffset: 0

            for item in 0..<self.itemCount {
                guard self.items[item] == nil
                else {
                    continue
                }

                var offset       = CGFloat.zero, scale = CGFloat.zero, alpha = CGFloat.zero
                let itemDistance = scrolledItem - CGFloat( item )
                if itemDistance > 0 {
                    // subview shows before scanned item.
                    scale = pow( itemDistance * 0.2 + 1, 2 )
                    offset = -100 * pow( itemDistance, 2 )
                    alpha = max( 0, 1 - pow( itemDistance, 2 ) )
                }
                else {
                    // subview shows behind scanned item.
                    scale = 1 / pow( itemDistance * 0.2 - 1, 2 )
                    offset = 100 * pow( itemDistance * 0.5, 2 )
                    alpha = max( 0, 1 - pow( itemDistance * 0.8, 2 ) )
                }

                let attributes = UICollectionViewLayoutAttributes( forCellWith: IndexPath( item: item, section: 0 ) )
                attributes.size = self.itemSize
                attributes.center = collectionView.bounds.center
                attributes.zIndex = -item
                attributes.alpha = alpha
                attributes.isHidden = alpha == 0
                attributes.transform = CGAffineTransform( translationX: 0, y: offset ).scaledBy( x: scale, y: scale )
                self.items[item] = attributes
            }
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            guard self.itemSize.height > 0, self.itemCount > 0
            else {
                return nil
            }

            let fromItem = Int( rect.minY / self.itemSize.height ), toItem = Int( rect.maxY / self.itemSize.height )
            return (fromItem...toItem).compactMap {
                return $0 < 0 || $0 > self.itemCount - 1 ? nil: self.items[$0]
            }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            return self.items[indexPath.item]
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            return true
        }

        override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
            self.contentSize = .zero
            self.items.removeAll()
            return UICollectionViewLayoutInvalidationContext()
        }

        override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
            return true
        }

        override func invalidationContext(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutInvalidationContext {
            self.items[originalAttributes.indexPath.item] = preferredAttributes
            return UICollectionViewLayoutInvalidationContext()
        }
    }
}
