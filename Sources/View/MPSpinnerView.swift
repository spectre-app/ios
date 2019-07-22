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
    public var selectedItem: Int? {
        return self.indexPathsForSelectedItems?.first?.item
    }
    public override var safeAreaInsets: UIEdgeInsets {
        return .zero
    }

    // MARK: --- Life ---

    public init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        if #available( iOS 11.0, * ) {
            self.contentInsetAdjustmentBehavior = .never
            self.insetsLayoutMarginsFromSafeArea = false
        }
        self.isPagingEnabled = true
        self.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( didTap ) ) )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Private ---

    @objc
    private func didTap(recognizer: UITapGestureRecognizer) {
        if self.selectedItem != nil {
            self.selectItem( at: nil, animated: true, scrollPosition: .centeredVertically )
        }
        else {
            self.selectItem( at: IndexPath( item: self.scrolledItem, section: 0 ), animated: true, scrollPosition: .centeredVertically )
        }
    }

    // MARK: --- Types ---

    internal class Layout: UICollectionViewLayout {
        internal var itemCount         = 0
        internal var itemAttributes    = [ Int: UICollectionViewLayoutAttributes ]()
        internal var oldBounds: CGRect?
        internal var itemOldAttributes = [ Int: UICollectionViewLayoutAttributes ]()
        internal var contentSize       = CGSize.zero

        override var collectionViewContentSize: CGSize {
            return self.contentSize
        }

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout( with: context )

            if context.invalidateEverything || context.invalidateDataSourceCounts {
                self.itemAttributes.removeAll()
                self.itemCount = self.collectionView?.numberOfItems( inSection: 0 ) ?? 0
            }
            else if let invalidatedItemIndexPaths = context.invalidatedItemIndexPaths {
                invalidatedItemIndexPaths.forEach { self.itemAttributes.removeValue( forKey: $0.item ) }
            }
        }

        override func prepare() {
            super.prepare()

            guard let collectionView = self.collectionView
            else {
                return
            }

            self.contentSize = CGSize( width: collectionView.bounds.width, height: collectionView.bounds.height * CGFloat( self.itemCount ) )
            self.layout( items: &self.itemAttributes, inBounds: collectionView.bounds )
        }

        func layout(items: inout [Int: UICollectionViewLayoutAttributes], inBounds bounds: CGRect) {
            let scan = bounds.origin.y / bounds.size.height
            for item in 0..<self.itemCount {
                var offset       = CGFloat.zero, scale = CGFloat.zero, alpha = CGFloat.zero
                let itemDistance = scan - CGFloat( item )
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

                let attributes = items[item] ?? UICollectionViewLayoutAttributes( forCellWith: IndexPath( item: item, section: 0 ) )
                if attributes.size == .zero {
                    attributes.size = bounds.size
                }
                attributes.center = bounds.center
                attributes.zIndex = -item
                attributes.alpha = alpha
                attributes.isHidden = alpha == 0
                attributes.transform = CGAffineTransform( translationX: 0, y: offset ).scaledBy( x: scale, y: scale )
                items[item] = attributes
            }
        }

        override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
            if let oldBounds = self.oldBounds {
                let targetBounds = self.collectionView?.bounds ?? .zero
                let scan         = oldBounds.origin.y / oldBounds.size.height
                return CGPoint( x: oldBounds.origin.x, y: scan * targetBounds.height )
            }

            return proposedContentOffset
        }

        override func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
            super.prepare( forAnimatedBoundsChange: oldBounds )

            self.oldBounds = oldBounds
            self.itemOldAttributes = self.itemAttributes.mapValues { $0.copy() as! UICollectionViewLayoutAttributes }
            self.layout( items: &self.itemOldAttributes, inBounds: oldBounds )
        }

        override func finalizeAnimatedBoundsChange() {
            super.finalizeAnimatedBoundsChange()

            self.oldBounds = nil
            self.itemOldAttributes.removeAll()
        }

        override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            return self.itemOldAttributes[itemIndexPath.item]
        }

        override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            return self.itemAttributes[itemIndexPath.item]
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            guard let collectionView = self.collectionView
            else {
                return nil
            }

            let fromItem = Int( rect.minY / collectionView.bounds.height ), toItem = Int( rect.maxY / collectionView.bounds.height )
            return (fromItem...toItem).compactMap {
                return $0 < 0 || $0 > self.itemCount - 1 ? nil: self.itemAttributes[$0]
            }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            return self.itemAttributes[indexPath.item]
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            return true
        }

        override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
            if let currentAttributes = self.itemAttributes[originalAttributes.indexPath.item],
               currentAttributes.size.height != preferredAttributes.size.height {
                currentAttributes.size.height = preferredAttributes.size.height
                return true
            }

            return false
        }
    }
}
