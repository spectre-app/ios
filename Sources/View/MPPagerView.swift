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
    private let layout = PagerLayout()
    private lazy var source = PagerSource( collectionView: self, sectionsOfElements: [ self.pages ] )

    // MARK: --- State ---

    override var contentSize:          CGSize {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    override var intrinsicContentSize: CGSize {
        self.isHidden ? super.intrinsicContentSize: self.layout.collectionViewContentSize + self.adjustedContentInset.size
    }

    public var pages = [ UIView ]() {
        didSet {
            self.source.update( [ self.pages ] )
        }
    }

    // MARK: --- Life ---

    public init() {
        super.init( frame: UIScreen.main.bounds, collectionViewLayout: self.layout )

        self.isPagingEnabled = true
        self.backgroundColor = .clear
        self.contentInset = .vertical()
        self.contentInsetAdjustmentBehavior = .never
        self.layout.scrollDirection = .horizontal

        self.delegate = self
        self.dataSource = self.source
        self.register( PagerCell.self )
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

    // MARK: --- UICollectionViewDelegateFlowLayout ---

    // MARK: --- Types ---

    internal class PagerLayout: UICollectionViewFlowLayout {

        // MARK: --- Life ---

        override init() {
            super.init()

            self.minimumLineSpacing = 0
            self.minimumInteritemSpacing = 0
            self.sectionInset = .zero
        }

        required init?(coder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            if let collectionView = self.collectionView {
                let newItemSize = (collectionView.bounds.size - collectionView.adjustedContentInset.size)
                        .union( CGSize( width: 1, height: 1 ) )
//                self.itemSize = newItemSize
                self.estimatedItemSize = newItemSize
            }

            super.invalidateLayout( with: context )
        }

        // MARK: --- State ---

        override var collectionViewContentSize: CGSize {
            switch self.scrollDirection {
                case .vertical:
                    return CGSize( width: self.layoutAttributesForElements( in: .infinite )?.reduce( 1 ) {
                        max( $0, $1.size.width )
                    } ?? 1,
                                   height: super.collectionViewContentSize.height )

                case .horizontal:
                    return CGSize( width: super.collectionViewContentSize.width,
                                   height: self.layoutAttributesForElements( in: .infinite )?.reduce( 1 ) {
                                       max( $0, $1.size.height )
                                   } ?? 1 )

                @unknown default:
                    return super.collectionViewContentSize.union( CGSize( width: 1, height: 1 ) )
            }
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            true
        }
    }

    internal class PagerSource: DataSource<UIView> {
        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            using( PagerCell.dequeue( from: collectionView, indexPath: indexPath ) ) { cell in
                if let view = self.element( at: indexPath ) {
                    cell.contentView.subviews.filter { $0 != view }.forEach {
                        $0.removeFromSuperview()
                    }
                    if view.superview != cell.contentView {
                        cell.contentView.addSubview( view )
                        LayoutConfiguration( view: view ).constrain().activate()
                    }
                }
            }
        }
    }

    class PagerCell: UICollectionViewCell {
        override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
            if let scrollDirection = MPPagerView.find( superviewOf: self )?.layout.scrollDirection {
                switch scrollDirection {
                    case .vertical:
                        layoutAttributes.size = self.systemLayoutSizeFitting(
                                layoutAttributes.size, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .defaultHigh )

                    case .horizontal:
                        layoutAttributes.size = self.systemLayoutSizeFitting(
                                layoutAttributes.size, withHorizontalFittingPriority: .defaultHigh, verticalFittingPriority: .fittingSizeLevel )

                    @unknown default:
                        ()
                }
            }

            return layoutAttributes
        }
    }
}
