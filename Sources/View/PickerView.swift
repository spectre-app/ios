//
// Created by Maarten Billemont on 2020-11-02.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import UIKit

class PickerView: UICollectionView {
    let layout = PickerLayout()

    // MARK: --- State ---

    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric,
                height: self.isHidden ? UIView.noIntrinsicMetric: self.layout.collectionViewContentSize.height )
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( frame: UIScreen.main.bounds, collectionViewLayout: self.layout )

        self.backgroundColor = .clear
        self.register( Separator.self, decorationKind: "Separator" )
        self.insetsLayoutMarginsFromSafeArea = false
    }

    // MARK: --- Types ---

    class PickerLayout: UICollectionViewLayout {
        private let spacing     = CGFloat( 12 )
        private var initialSize = [ UICollectionView.ElementCategory: CGSize ]()
        private var attributes  = [ UICollectionView.ElementCategory: [ IndexPath: UICollectionViewLayoutAttributes ] ]()
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

            if context.invalidateDataSourceCounts {
                for section in 0..<collectionView.numberOfSections {
                    for item in 0..<collectionView.numberOfItems( inSection: section ) {
                        let indexPath = IndexPath( item: item, section: section )
                        if !(self.attributes[.cell]?.keys.contains( indexPath ) ?? false) {
                            self.attributes[.cell, default: .init()][indexPath] =
                                    UICollectionViewLayoutAttributes( forCellWith: indexPath )
                        }
                    }

                    if section < collectionView.numberOfSections - 1 {
                        let indexPath = IndexPath( item: 0, section: section )
                        if !(self.attributes[.decorationView]?.keys.contains( indexPath ) ?? false) {
                            self.attributes[.decorationView, default: .init()][indexPath] =
                                    UICollectionViewLayoutAttributes( forDecorationViewOfKind: "Separator", with: indexPath )
                        }
                    }
                }
            }

            let margins = collectionView.layoutMargins
            let contentHeight = margins.height + self.attributes.values.reduce( 1 ) { $1.values.reduce( $0 ) { max( $0, $1.size.height ) } }
            let separatorHeight = ((self.contentSize.height - margins.height) * .long).rounded( .towardZero )
            var offset          = margins.left
            for section in 0..<collectionView.numberOfSections {
                for item in 0..<collectionView.numberOfItems( inSection: section ) {
                    let indexPath = IndexPath( item: item, section: section )
                    if let attributes = self.attributes[.cell]?[indexPath] {
                        if attributes.frame.size.isEmpty, let initialSize = self.initialSize[attributes.representedElementCategory] {
                            attributes.frame.size = initialSize
                        }
                        attributes.frame.origin.x = offset
                        attributes.frame.origin.y = (contentHeight - attributes.frame.size.height) / 2
                        offset = attributes.frame.maxX + spacing
                    }
                }

                if section < collectionView.numberOfSections - 1 {
                    let indexPath = IndexPath( item: 0, section: section )
                    if let attributes = self.attributes[.decorationView]?[indexPath] {
                        if attributes.frame.size.isEmpty, let initialSize = self.initialSize[attributes.representedElementCategory] {
                            attributes.frame.size = initialSize
                        }
                        attributes.frame.size.height = separatorHeight
                        attributes.frame.origin.x = offset
                        attributes.frame.origin.y = (contentHeight - attributes.frame.size.height) / 2
                        offset = attributes.frame.maxX + spacing
                    }
                }
            }

            self.contentSize = CGSize( width: max( margins.width + 1, offset - spacing + margins.right ), height: contentHeight )
        }

        open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                  withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
            originalAttributes.size != preferredAttributes.size
        }

        override func invalidationContext(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutInvalidationContext {
            self.attributes[originalAttributes.representedElementCategory]?[originalAttributes.indexPath]?.size = preferredAttributes.size
            if !self.initialSize.keys.contains( originalAttributes.representedElementCategory ) {
                self.initialSize[originalAttributes.representedElementCategory] = preferredAttributes.size
            }

            return super.invalidationContext( forPreferredLayoutAttributes: preferredAttributes, withOriginalAttributes: originalAttributes )
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            self.attributes.values.flatMap( { $0.values } ).filter( { rect.intersects( $0.frame ) } )
                                  .compactMap { self.effectiveLayoutAttributes( for: $0 ) }
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[.cell]?[indexPath] )
        }

        open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[.cell]?[itemIndexPath] )
        }

        override func layoutAttributesForDecorationView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[.decorationView]?[indexPath] )
        }

        override func initialLayoutAttributesForAppearingDecorationElement(ofKind elementKind: String, at decorationIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.effectiveLayoutAttributes( for: self.attributes[.decorationView]?[decorationIndexPath] )
        }

        // MARK: --- Private ---

        private func effectiveLayoutAttributes(for attributes: UICollectionViewLayoutAttributes?) -> UICollectionViewLayoutAttributes? {
            guard let attributes = attributes
            else { return nil }

            if attributes.frame.size.isEmpty && !(attributes.indexPath.section == 0 && attributes.indexPath.item == 0) {
                return nil
            }

            return attributes
        }
    }

    class Separator: UICollectionReusableView {
        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override init(frame: CGRect) {
            super.init( frame: frame )

            self => \.backgroundColor => Theme.current.color.mute
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            CGSize( width: 1, height: targetSize.height )
        }
    }
}
