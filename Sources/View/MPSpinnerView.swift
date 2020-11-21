//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

/**
 * A view that presents a collection of items with a single item at the centre.
 * The item the spinner has at its centre when at rest is the selected item.
 */
public class MPSpinnerView: UICollectionView {
    public var scrolledItem: Int {
        let currentOffset = self.contentOffset.y
        let maximumOffset = max( 0, self.contentSize.height - self.bounds.size.height )
        let scrolledItem  = maximumOffset > 0 ? CGFloat( self.numberOfItems( inSection: 0 ) - 1 ) * currentOffset / maximumOffset: 0
        return Int( scrolledItem.rounded( .toNearestOrAwayFromZero ) )
    }
    public var selectedItem: Int? {
        get {
            self.indexPathsForSelectedItems?.first?.item
        }
        set {
            if newValue != self.indexPathsForSelectedItems?.first?.item {
                self.requestSelection( item: newValue )
            }
        }
    }

    // MARK: --- Life ---

    public init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        self.isPagingEnabled = true
        self.contentInsetAdjustmentBehavior = .never
        self.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( didTap ) ) )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- Private ---

    @objc
    private func didTap(recognizer: UITapGestureRecognizer) {
        if self.scrolledItem == self.selectedItem {
            self.requestSelection( item: nil )
        }
        else {
            self.requestSelection( item: self.scrolledItem )
        }
    }

    // MARK: --- Types ---

    internal class Layout: UICollectionViewLayout {
        var count      = 0
        var attributes = [ IndexPath: UICollectionViewLayoutAttributes ]()
        var bounds     = CGRect.zero
        var size       = CGSize.zero

        override var collectionViewContentSize: CGSize {
            self.size
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
            self.size = CGSize( width: 0, height: self.bounds.size.height * CGFloat( self.count ) )
            let scan = self.bounds.origin.y / self.bounds.size.height

            // Align attributes keys when indexPaths change.
            let attributes = self.attributes.values.filter { $0.indexPath.item < self.count }
            self.attributes.removeAll( keepingCapacity: true )
            for attrs in attributes {
                self.attributes[attrs.indexPath] = attrs
            }

            // Create new attributes.
            for i in 0..<self.count {
                let indexPath = IndexPath( item: i, section: 0 )

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
                    offset = -100 * pow( itemDistance, 2 )
                    scale = pow( itemDistance * 0.2 + 1, 2 )
                    alpha = max( 0, 1 - pow( itemDistance, 2 ) )
                }
                else {
                    // subview shows behind scanned item.
                    offset = 100 * pow( itemDistance * 0.5, 2 )
                    scale = 1 / pow( itemDistance * 0.2 - 1, 2 )
                    alpha = max( 0, 1 - pow( itemDistance * 0.8, 2 ) )
                }

                attrs.size = self.bounds.size
                attrs.center = self.bounds.center
                attrs.zIndex = -attrs.indexPath.item
                attrs.alpha = alpha
                attrs.isHidden = alpha == .off
                attrs.transform = CGAffineTransform( translationX: 0, y: offset ).scaledBy( x: scale, y: scale )
            }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.attributes[indexPath]
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            Array( self.attributes.values )
        }
    }
}
