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
class PagerView: UIView, UICollectionViewDelegate {
    private let collectionView: PagerCollectionView
    private let source:         DataSource<NoSections, UIView>
    private lazy var indicatorView = PagerIndicator( pagerView: self )

    // MARK: - State

    var pageIndicator = true

    public var page  = 0 {
        didSet {
            self.indicatorView.updateTask.request()
        }
    }
    public var pages = [ UIView ]() {
        didSet {
            if oldValue != self.pages {
                self.source.apply( [ .items: self.pages ] )
            }
            self.indicatorView.updateTask.request()
        }
    }

    // MARK: - Life

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    public init() {
        self.collectionView = .init()
        self.source = .init( collectionView: self.collectionView ) { collectionView, indexPath, item in
            using( PagerCell.dequeue( from: collectionView, indexPath: indexPath ) ) {
                $0.collectionView = collectionView
                $0.pageView = item
            }
        }
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
        LayoutConfiguration( view: self.collectionView )
                .constrain( as: .topBox )
                .activate()
        LayoutConfiguration( view: self.indicatorView )
                .constrain { $1.topAnchor.constraint( equalTo: self.collectionView.bottomAnchor, constant: 8 ) }
                .constrain( as: .bottomCenter, margin: true ).activate()
    }

    // MARK: - UICollectionViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.page = Int( CGFloat( self.pages.count - 1 ) * scrollView.contentOffset.x /
                         (scrollView.contentSize.width - scrollView.bounds.width) )
    }

    // MARK: - Types

    internal class PagerCollectionView: UICollectionView {

        // MARK: - State

        override var intrinsicContentSize: CGSize {
            CGSize( width: UIView.noIntrinsicMetric,
                    height: self.isHidden ? UIView.noIntrinsicMetric : self.collectionViewLayout.collectionViewContentSize.height )
        }

        // MARK: - Life

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

        // MARK: - State

        open override var collectionViewContentSize: CGSize {
            self.contentSize
        }

        // MARK: - Life

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

            let items = collectionView.numberOfSections == 0 ? 0 : collectionView.numberOfItems( inSection: 0 )
            if context.invalidateDataSourceCounts {
                for item in 0..<items {
                    let indexPath = IndexPath( item: item, section: 0 )
                    if !self.attributes.keys.contains( indexPath ) {
                        self.attributes[indexPath] = UICollectionViewLayoutAttributes( forCellWith: indexPath )
                        context.invalidateItems( at: [ indexPath ] )
                    }
                }
            }
            for indexPath in context.invalidateEverything ? Array( self.attributes.keys ) : context.invalidatedItemIndexPaths ?? [] {
                if let attrs = self.attributes[indexPath] {
                    attrs.size.width = self.pageSize.width
                    attrs.center = CGPoint( x: self.pageSize.width * (CGFloat( indexPath.item ) + 0.5), y: attrs.size.height / 2 )
                }
            }

            self.contentSize = CGSize( width: max( 1, self.pageSize.width * CGFloat( items ) ),
                                       height: self.attributes.values.reduce( 1 ) { max( $0, $1.frame.maxY ) } )
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect)
                -> Bool {
            newBounds.size.width != self.pageSize.width
        }

        override func invalidationContext(forBoundsChange newBounds: CGRect)
                -> UICollectionViewLayoutInvalidationContext {
            using( super.invalidationContext( forBoundsChange: newBounds ) ) {
                $0.invalidateItems( at: Array( self.attributes.keys ) )
                self.pageSize.width = newBounds.size.width
            }
        }

        open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                  withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes)
                -> Bool {
            originalAttributes.size.height != preferredAttributes.size.height
        }

        override func invalidationContext(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                          withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes)
                -> UICollectionViewLayoutInvalidationContext {
            self.attributes[originalAttributes.indexPath]?.size.height = preferredAttributes.size.height

            return using( super.invalidationContext( forPreferredLayoutAttributes: preferredAttributes,
                                                     withOriginalAttributes: originalAttributes ) ) {
                $0.invalidateItems( at: [ originalAttributes.indexPath ] )
            }
        }

        open override func layoutAttributesForElements(in rect: CGRect)
                -> [UICollectionViewLayoutAttributes]? {
            self.attributes.values.filter( { rect.intersects( $0.frame ) } ).compactMap { self.effectiveLayoutAttributes( for: $0 ) }
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath)
                -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[indexPath] )
        }

        open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath)
                -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[itemIndexPath] )
        }

        // MARK: - Private

        private func effectiveLayoutAttributes(for attributes: UICollectionViewLayoutAttributes?)
                -> UICollectionViewLayoutAttributes? {
            guard var attributes = attributes
            else { return nil }

            if attributes.size.height == 0 {
                attributes = attributes.copy() as! UICollectionViewLayoutAttributes // swiftlint:disable:this force_cast
                attributes.size.height = self.pageSize.height
            }

            return attributes
        }
    }

    enum Sections: Hashable {
        case pages
    }

    class PagerCell: UICollectionViewCell {
        unowned var collectionView: UICollectionView?
        var pageView: UIView? {
            didSet {
                self.contentView.subviews.filter { $0 != self.pageView }.forEach {
                    $0.removeFromSuperview()
                }
                if let pageView = self.pageView, pageView.superview != self.contentView {
                    self.contentView.addSubview( pageView )
                    LayoutConfiguration( view: pageView )
                            .constrain( as: .box ).activate()
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
            LayoutConfiguration( view: self.contentView )
                    .constrain( as: .box ).activate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            // Detect when the constraints in the page have changed such that it wants a larger page height.
            let fitting = self.systemLayoutSizeFitting( self.bounds.size )
            if self.bounds.size.height < fitting.height {
                self.collectionView?.collectionViewLayout.invalidateLayout()
            }
        }

        override func systemLayoutSizeFitting(
                _ targetSize: CGSize, withHorizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority)
                -> CGSize {
            super.systemLayoutSizeFitting(
                    targetSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: verticalFittingPriority )
        }
    }

    class PagerIndicator: UIView, Updatable {
        unowned let pagerView: PagerView
        let stackView = UIStackView()

        // - Life

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        init(pagerView: PagerView) {
            self.pagerView = pagerView
            super.init( frame: .zero )

            // - View
            self => \.backgroundColor => Theme.current.color.mute
            self.layoutMargins = .border( horizontal: 6, vertical: 4 )
            self.insetsLayoutMarginsFromSafeArea = false
            self.stackView.axis = .horizontal
            self.stackView.spacing = 4

            // - Hierarchy
            self.addSubview( self.stackView )

            // - Layout
            LayoutConfiguration( view: self.stackView )
                    .constrain( as: .box, margin: true ).activate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            self.layer.cornerRadius = min( self.bounds.size.width, self.bounds.size.height ) / 2
        }

        // - Updatable

        lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
            guard let self = self
            else { return }

            while self.stackView.arrangedSubviews.count > self.pagerView.pages.count {
                self.stackView.arrangedSubviews.first?.removeFromSuperview()
            }
            while self.stackView.arrangedSubviews.count < self.pagerView.pages.count {
                self.stackView.addArrangedSubview( PageIndicator() )
            }
            for (s, subview) in self.stackView.arrangedSubviews.enumerated() {
                subview.alpha = s == self.pagerView.page ? .on : .short
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
