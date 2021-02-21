//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

/**
 * A view that presents a collection of items with a single item at the centre.
 * The item the spinner has at its centre when at rest is the selected item.
 */
class MPPagerView: UIView, UICollectionViewDelegate {
    private let collectionView = PagerCollectionView()
    private lazy var source        = PagerSource( collectionView: self.collectionView, sectionsOfElements: [ self.pages ] )
    private lazy var indicatorView = PagerIndicator( pagerView: self )

    // MARK: --- State ---

    var pageIndicator = true

    public var page  = 0 {
        didSet {
            self.indicatorView.setNeedsUpdate()
        }
    }
    public var pages = [ UIView ]() {
        didSet {
            if self.collectionView.dataSource !== self.source {
                self.collectionView.dataSource = self.source
            }
            if oldValue != self.pages {
                self.source.update( [ self.pages ] )
            }
            self.indicatorView.setNeedsUpdate()
        }
    }

    // MARK: --- Life ---

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    public init() {
        super.init( frame: .zero )

        // - View
        self.backgroundColor = .clear
        self.insetsLayoutMarginsFromSafeArea = false
        self.collectionView.insetsLayoutMarginsFromSafeArea = false
        self.collectionView.preservesSuperviewLayoutMargins = true
        self.collectionView.backgroundColor = .clear
        self.collectionView.isPagingEnabled = true
        self.collectionView.delegate = self
        self.collectionView.register( PagerCell.self )

        // - Hierarchy
        self.addSubview( self.collectionView )
        self.addSubview( self.indicatorView )

        // - Layout
        LayoutConfiguration( view: self.indicatorView ).constrain( as: .bottomCenter, margin: true ).activate()
        LayoutConfiguration( view: self.collectionView ).constrain( as: .topBox )
                                                        .constrain { $1.bottomAnchor.constraint( equalTo: self.indicatorView.topAnchor ) }
                                                        .activate()
    }

    // MARK: --- UICollectionViewDelegate ---

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.page = Int( CGFloat( self.pages.count - 1 ) * scrollView.contentOffset.x /
                                 (scrollView.contentSize.width - scrollView.bounds.width) )
    }

    // MARK: --- Types ---

    internal class PagerCollectionView: UICollectionView {

        // MARK: --- State ---

        override var intrinsicContentSize: CGSize {
            CGSize( width: UIView.noIntrinsicMetric,
                    height: self.isHidden ? UIView.noIntrinsicMetric: self.collectionViewLayout.collectionViewContentSize.height )
        }

        // MARK: --- Life ---

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init() {
            super.init( frame: UIScreen.main.bounds, collectionViewLayout: PagerLayout() )
        }
    }

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
                self.pageSize.width = collectionView.bounds.size.width
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
            originalAttributes.size.height != preferredAttributes.size.height
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
                $0.collectonView = collectionView
                $0.pageView = self.element( at: indexPath )
            }
        }
    }

    class PagerCell: UICollectionViewCell {
        var collectonView: UICollectionView?
        var pageView: UIView? {
            didSet {
                self.contentView.subviews.filter { $0 != self.pageView }.forEach {
                    $0.removeFromSuperview()
                }
                if let pageView = self.pageView, pageView.superview != self.contentView {
                    self.contentView.addSubview( pageView )
                    LayoutConfiguration( view: pageView ).constrain( as: .box, margin: true ).activate()
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
            LayoutConfiguration( view: self.contentView ).constrain( as: .box ).activate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Detect when the constraints in the page have changed such that it wants a larger page height.
            let fitting = self.systemLayoutSizeFitting( self.bounds.size )
            if self.bounds.size.height < fitting.height {
                self.collectonView?.collectionViewLayout.invalidateLayout()
            }
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            super.systemLayoutSizeFitting(
                    targetSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: verticalFittingPriority )
        }
    }

    class PagerIndicator: UIView, Updatable {
        private lazy var updateTask = DispatchTask( update: self, animated: true )

        let pagerView: MPPagerView
        let stackView = UIStackView()

        // - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init(pagerView: MPPagerView) {
            self.pagerView = pagerView
            super.init( frame: .zero )

            // - View
            self => \.backgroundColor => Theme.current.color.mute
            self.layoutMargins = .border( horizontal: 6, vertical: 4 )
            self.stackView.axis = .horizontal
            self.stackView.spacing = 4

            // - Hierarchy
            self.addSubview( self.stackView )

            // - Layout
            LayoutConfiguration( view: self.stackView ).constrain( as: .box, margin: true ).activate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            self.layer.cornerRadius = min( self.bounds.size.width, self.bounds.size.height ) / 2
        }

        // - Updatable

        func setNeedsUpdate() {
            self.updateTask.request()
        }

        func update() {
            while self.stackView.arrangedSubviews.count > self.pagerView.pages.count {
                self.stackView.arrangedSubviews.first?.removeFromSuperview()
            }
            while self.stackView.arrangedSubviews.count < self.pagerView.pages.count {
                self.stackView.addArrangedSubview( PageIndicator() )
            }
            for (s, subview) in self.stackView.arrangedSubviews.enumerated() {
                subview.alpha = s == self.pagerView.page ? .on: .short
            }
        }
    }

    class PageIndicator: UIView {
        override var intrinsicContentSize: CGSize {
            CGSize( width: 8, height: 8 )
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            self.layer.cornerRadius = min( self.bounds.size.width, self.bounds.size.height ) / 2
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()

            self.backgroundColor = self.tintColor
        }
    }
}
