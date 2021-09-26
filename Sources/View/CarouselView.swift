// =============================================================================
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

/**
 * A view that presents a collection of items with a single item at the centre.
 * The item the spinner has at its centre when at rest is the selected item.
 */
class CarouselView: UICollectionView {
    var scrolledItem: Int {
        get {
            let currentOffset = self.contentOffset.x
            let maximumOffset = max( 0, self.contentSize.width - self.bounds.size.width )
            let scrolledItem  = maximumOffset > 0 ? CGFloat( self.numberOfItems( inSection: 0 ) - 1 ) * currentOffset / maximumOffset: 0
            return Int( scrolledItem.rounded( .toNearestOrAwayFromZero ) )
        }
        set {
            if !self.bounds.isEmpty, 0 < self.numberOfSections, newValue < self.numberOfItems( inSection: 0 ) {
                self.scrollToItem( at: IndexPath( item: newValue, section: 0 ), at: .centeredHorizontally, animated: true )
            }
        }
    }
    var selectedItem: Int? {
        get {
            self.indexPathsForSelectedItems?.first?.item
        }
        set {
            if newValue != self.indexPathsForSelectedItems?.first?.item {
                self.requestSelection( item: newValue )
            }
        }
    }

    // MARK: - State

    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric,
                height: self.isHidden ? UIView.noIntrinsicMetric: self.collectionViewLayout.collectionViewContentSize.height )
    }

    // MARK: - Life

    init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        self.isPagingEnabled = true
        self.contentInsetAdjustmentBehavior = .never
        self.addGestureRecognizer( UITapGestureRecognizer { [unowned self] _ in
            if self.scrolledItem == self.selectedItem {
                self.requestSelection( item: nil )
            }
            else {
                self.requestSelection( item: self.scrolledItem )
            }
        } )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - Types

    internal class Layout: UICollectionViewLayout {
        var count       = 0
        var attributes  = [ IndexPath: UICollectionViewLayoutAttributes ]()
        var bounds      = CGRect.zero
        var contentSize = CGSize( width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric ) {
            didSet {
                if oldValue != self.contentSize {
                    self.collectionView?.invalidateIntrinsicContentSize()
                }
            }
        }

        override var collectionViewContentSize: CGSize {
            self.contentSize
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds != self.bounds
        }

        override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
            self.bounds = newBounds
            return super.invalidationContext( forBoundsChange: newBounds )
        }

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout( with: context )

            if context.invalidateEverything || context.invalidateDataSourceCounts {
                DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) ) { [weak self] in
                    self?.collectionView?.flashScrollIndicators()
                }
            }
        }

        override func prepare() {
            super.prepare()

            self.bounds = self.collectionView?.bounds ?? .null
            self.count = self.collectionView?.numberOfSections == 0 ? 0: self.collectionView?.numberOfItems( inSection: 0 ) ?? 0
            let scan = self.bounds.isEmpty ? 0: self.bounds.origin.x / self.bounds.size.width

            // Align attributes keys when indexPaths change.
            let attributes = self.attributes.values.filter { $0.indexPath.item < self.count }
            self.attributes.removeAll( keepingCapacity: true )
            for attrs in attributes {
                self.attributes[attrs.indexPath] = attrs
            }

            // Create new attributes.
            for item in 0..<self.count {
                let indexPath = IndexPath( item: item, section: 0 )

                if !self.attributes.keys.contains( indexPath ) {
                    self.attributes[indexPath] = using( UICollectionViewLayoutAttributes( forCellWith: indexPath ) ) {
                        $0.size = self.bounds.size
                    }
                }
            }

            for attrs in self.attributes.values {
                let offset: CGFloat, scale: CGFloat, alpha: CGFloat
                let itemDistance = scan - CGFloat( attrs.indexPath.item )
                if itemDistance > 0 {
                    // subview shows before scanned item.
                    offset = -400 * pow( itemDistance * 0.5, 2 )
                    scale = 1 / pow( -itemDistance * 0.2 - 1, 2 )
                    alpha = max( 0, 1 - pow( itemDistance * 0.9, 2 ) )
                }
                else {
                    // subview shows behind scanned item.
                    offset = 400 * pow( itemDistance * 0.5, 2 )
                    scale = 1 / pow( itemDistance * 0.2 - 1, 2 )
                    alpha = max( 0, 1 - pow( itemDistance * 0.9, 2 ) )
                }

                attrs.size = self.bounds.size
                attrs.center = self.bounds.center
                attrs.zIndex = itemDistance == 0 ? 1: -1
                attrs.alpha = alpha
                attrs.isHidden = alpha == .off
                attrs.transform = CGAffineTransform( translationX: offset, y: 0 ).scaledBy( x: scale, y: scale )
            }

            self.contentSize = CGSize( width: self.bounds.size.width * CGFloat( self.count ),
                                       height: self.attributes.values.reduce( 1 ) { max( $0, $1.bounds.height ) } )
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            Array( self.attributes.values )
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.attributes[indexPath]
        }

        override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.attributes[itemIndexPath]
        }

        override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.attributes[itemIndexPath]
        }
    }
}
