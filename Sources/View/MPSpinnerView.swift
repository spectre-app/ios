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
    public override var safeAreaInsets: UIEdgeInsets {
        .zero
    }

    // MARK: --- Life ---

    public init() {
        super.init( frame: .zero, collectionViewLayout: Layout() )

        self.isPagingEnabled = true
        self.insetsLayoutMarginsFromSafeArea = false
        self.contentInsetAdjustmentBehavior = .never
        self.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( didTap ) ) )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    @discardableResult
    public func requestSelection(item: Int?, inSection section: Int = 0,
                                 animated: Bool = UIView.areAnimationsEnabled, scrollPosition: ScrollPosition = .centeredVertically)
                    -> Bool {
        let selectPath = item.flatMap { IndexPath( item: $0, section: section ) }
        let selectedPath = self.indexPathsForSelectedItems?.first

        if let selectPath = selectPath, selectPath == selectedPath ||
                !(self.delegate?.collectionView?( self, shouldSelectItemAt: selectPath ) ?? true) {
            return false
        }
        if let selectedPath = selectedPath, selectedPath.item != selectPath?.item &&
                !(self.delegate?.collectionView?( self, shouldDeselectItemAt: selectedPath ) ?? true) {
            return false
        }

        self.selectItem( at: selectPath, animated: animated, scrollPosition: scrollPosition )

        if let selectedPath = selectedPath {
            self.delegate?.collectionView?( self, didDeselectItemAt: selectedPath )
        }
        if let selectPath = selectPath {
            self.delegate?.collectionView?( self, didSelectItemAt: selectPath )
        }

        return true
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
        internal var itemCount         = 0
        internal var bounds            = CGRect.zero, oldBounds = CGRect.zero
        internal var itemAttributes    = [ Int: UICollectionViewLayoutAttributes ]()
        internal var itemOldAttributes = [ Int: UICollectionViewLayoutAttributes ]()
        internal var contentSize       = CGSize.zero

        override var collectionViewContentSize: CGSize {
            self.contentSize
        }

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout( with: context )

            DispatchQueue.main.asyncAfter( deadline: .now() + .seconds( 2 ) ) { [weak self] in
                self?.collectionView?.flashScrollIndicators()
            }

            if context.invalidateEverything || context.invalidateDataSourceCounts {
                self.itemAttributes.removeAll()

                if let collectionView = self.collectionView {
                    self.bounds = collectionView.bounds
                    self.itemCount = collectionView.numberOfSections == 0 ? 0: collectionView.numberOfItems( inSection: 0 )
                }
            }
            else if let invalidatedItemIndexPaths = context.invalidatedItemIndexPaths {
                invalidatedItemIndexPaths.forEach { self.itemAttributes.removeValue( forKey: $0.item ) }
            }
        }

        override func prepare() {
            super.prepare()

            self.contentSize = CGSize( width: self.bounds.width, height: self.bounds.height * CGFloat( self.itemCount ) )
            self.layout( items: &self.itemAttributes, inBounds: self.bounds )
        }

        func layout(items: inout [Int: UICollectionViewLayoutAttributes], inBounds bounds: CGRect) {
            let scan = bounds.size.height > 0 ? bounds.origin.y / bounds.size.height: 0

            for item in 0..<self.itemCount {
                var offset       = CGFloat.zero, scale = CGFloat.zero, alpha = CGFloat.zero
                let itemDistance = scan - CGFloat( item )
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
            guard self.oldBounds.height > 0
            else { return proposedContentOffset }

            let scan = self.oldBounds.size.height > 0 ? self.oldBounds.origin.y / self.oldBounds.size.height: 0
            return CGPoint( x: self.oldBounds.origin.x, y: scan * self.bounds.height )
        }

        override func prepare(forAnimatedBoundsChange oldBounds: CGRect) {
            super.prepare( forAnimatedBoundsChange: oldBounds )

            self.oldBounds = oldBounds
            self.itemOldAttributes = self.itemAttributes.mapValues { $0.copy() as! UICollectionViewLayoutAttributes }
            self.layout( items: &self.itemOldAttributes, inBounds: oldBounds )
        }

        override func finalizeAnimatedBoundsChange() {
            super.finalizeAnimatedBoundsChange()

            self.oldBounds = .zero
            self.itemOldAttributes.removeAll()
        }

        override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.itemOldAttributes[itemIndexPath.item] ?? self.itemAttributes[itemIndexPath.item]
        }

        override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.itemAttributes[itemIndexPath.item]
        }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            guard self.bounds.height > 0
            else { return nil }

            let fromItem = Int( rect.minY / self.bounds.height ), toItem = Int( rect.maxY / self.bounds.height )
            return Range( fromItem...toItem ).clamped( to: 0..<self.itemCount ).compactMap { self.itemAttributes[$0] }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.itemAttributes[indexPath.item]
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            guard newBounds != self.bounds
            else { return false }

            self.bounds = newBounds
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
