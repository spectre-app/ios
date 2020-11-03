//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

/**
 * A view that presents a collection of items with a single item at the centre.
 * The item the spinner has at its centre when at rest is the selected item.
 */
class MPPagerView: UICollectionView, UICollectionViewDelegateFlowLayout {
    private lazy var source = PagerSource( collectionView: self, sectionsOfElements: [ self.pages ] )
    private let layout = PagerLayout()

    // MARK: --- State ---

    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric,
                height: self.isHidden ? UIView.noIntrinsicMetric: self.layout.collectionViewContentSize.height )
    }

    public var pages = [ UIView ]() {
        didSet {
            if self.dataSource !== self.source {
                self.dataSource = self.source
            }
            if oldValue != self.pages {
                self.source.update( [ self.pages ] )
            }
        }
    }

    // MARK: --- Life ---

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    public init() {
        super.init( frame: UIScreen.main.bounds, collectionViewLayout: self.layout )

        self.isPagingEnabled = true
        self.backgroundColor = .clear
        self.insetsLayoutMarginsFromSafeArea = false
        self.preservesSuperviewLayoutMargins = true

        self.delegate = self
        self.register( PagerCell.self )
    }

    override func updateConstraints() {
        super.updateConstraints()

        // If any cells have become too small for their current constraints, force re-measuring of layout attributes.
        for cell in self.visibleCells {
            if cell.bounds.height < cell.systemLayoutSizeFitting( cell.bounds.size ).height {
                self.bounds.origin.x += 1
                self.bounds.origin.x -= 1
                break
            }
        }
    }

    // MARK: --- Types ---

    internal class PagerLayout: UICollectionViewLayout {
        private var pageSize    = CGSize.zero
        private var attributes  = [ IndexPath: UICollectionViewLayoutAttributes ]()
        private var contentSize = CGSize( width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric ) {
            didSet {
                if oldValue != self.contentSize {
                    self.collectionView?.invalidateIntrinsicContentSize()
                }
            }
        }

        // MARK: --- State ---

        open override var collectionViewContentSize: CGSize {
            self.contentSize
        }

        // MARK: --- Life ---

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout( with: context )

            guard let collectionView = self.collectionView
            else { return }

            if context.invalidateEverything {
                self.pageSize.width = collectionView.frame.size.width
            }
            if context.invalidateEverything || !(context.invalidatedItemIndexPaths ?? []).isEmpty {
                self.pageSize.height = self.attributes.reduce( 0, { max( $0, $1.value.size.height ) } )
            }

            if context.invalidateDataSourceCounts {
                for item in 0..<collectionView.numberOfItems( inSection: 0 ) {
                    let indexPath = IndexPath( item: item, section: 0 )
                    if !self.attributes.keys.contains( indexPath ) {
                        self.attributes[indexPath] = UICollectionViewLayoutAttributes( forCellWith: indexPath )
                        context.invalidateItems( at: [ indexPath ] )
                    }
                }
            }
            for indexPath in context.invalidateEverything ? Array( self.attributes.keys ): context.invalidatedItemIndexPaths ?? [] {
                if let attrs = self.attributes[indexPath] {
                    attrs.frame.size.width = self.pageSize.width
                    attrs.frame.origin = CGPoint( x: self.pageSize.width * CGFloat( indexPath.item ), y: 0 )
                }
            }

            self.contentSize = CGSize( width: max( 1, self.pageSize.width * CGFloat( collectionView.numberOfItems( inSection: 0 ) ) ),
                                       height: max( 1, self.pageSize.height ) )
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds.size.width != self.pageSize.width
        }

        override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
            using( super.invalidationContext( forBoundsChange: newBounds ) ) {
                $0.invalidateItems( at: Array( self.attributes.keys ) )
                self.pageSize.width = newBounds.size.width
            }
        }

        open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                  withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
            self.attributes[originalAttributes.indexPath]?.size.height != preferredAttributes.size.height
        }

        override func invalidationContext(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutInvalidationContext {
            self.attributes[originalAttributes.indexPath]?.size.height = preferredAttributes.size.height

            return using( super.invalidationContext( forPreferredLayoutAttributes: preferredAttributes, withOriginalAttributes: originalAttributes ) ) {
                $0.invalidateItems( at: [ originalAttributes.indexPath ] )
            }
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            self.attributes.values.filter( { rect.intersects( $0.frame ) } ).compactMap { self.effectiveLayoutAttributes( for: $0 ) }
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[indexPath] )
        }

        open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[itemIndexPath] )
        }

        // MARK: --- Private ---

        private func effectiveLayoutAttributes(for attributes: UICollectionViewLayoutAttributes?) -> UICollectionViewLayoutAttributes? {
            guard var attributes = attributes
            else { return nil }

            if attributes.frame.size.height == 0 {
                attributes = attributes.copy() as! UICollectionViewLayoutAttributes
                attributes.frame.size.height = self.pageSize.height
            }

            return attributes
        }
    }

    internal class PagerSource: DataSource<UIView> {
        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            using( PagerCell.dequeue( from: collectionView, indexPath: indexPath ) ) {
                $0.pageView = self.element( at: indexPath )
            }
        }
    }

    class PagerCell: UICollectionViewCell {
        var pageView: UIView? {
            didSet {
                self.contentView.subviews.filter { $0 != self.pageView }.forEach {
                    $0.removeFromSuperview()
                }
                if let pageView = self.pageView, pageView.superview != self.contentView {
                    self.contentView.addSubview( pageView )
                    LayoutConfiguration( view: pageView ).constrain( margins: true ).activate()
                }
            }
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(frame: CGRect) {
            super.init( frame: frame )

            self.insetsLayoutMarginsFromSafeArea = false
            self.preservesSuperviewLayoutMargins = true
            self.contentView.insetsLayoutMarginsFromSafeArea = false
            self.contentView.preservesSuperviewLayoutMargins = true
            self.contentView.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Detect when the constraints in the page change such that it wants a larger size.
            let fitting = self.systemLayoutSizeFitting( self.bounds.size )
            if self.bounds.size.height < fitting.height {
                OperationQueue.main.addOperation {
                    self.superview?.setNeedsUpdateConstraints()
                }
            }
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            super.systemLayoutSizeFitting(
                    targetSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: verticalFittingPriority )
        }
    }
}
