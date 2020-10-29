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

    override var intrinsicContentSize: CGSize {
        CGSize( width: UIView.noIntrinsicMetric, height: self.isHidden ? UIView.noIntrinsicMetric: self.layout.collectionViewContentSize.height )
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
        self.insetsLayoutMarginsFromSafeArea = false
        self.preservesSuperviewLayoutMargins = true

        self.delegate = self
        self.dataSource = self.source
        self.register( PagerCell.self )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: --- UICollectionViewDelegateFlowLayout ---

    // MARK: --- Types ---

    internal class PagerLayout: UICollectionViewLayout {
        private var attributes = [ IndexPath: UICollectionViewLayoutAttributes ]() {
            didSet {
                if oldValue != self.attributes {
                    self.collectionView?.invalidateIntrinsicContentSize()
                }
            }
        }
        var pageHeight: CGFloat {
            self.attributes.reduce( 0, { max( $0, $1.value.size.height ) } )
        }
        private var contentSize = CGSize( width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric ) {
            didSet {
                if oldValue != self.contentSize {
                    self.collectionView?.invalidateIntrinsicContentSize()
                }
            }
        }
        open override var collectionViewContentSize: CGSize {
            self.contentSize
        }

        // MARK: --- Life ---

        override init() {
            super.init()
        }

        required init?(coder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func prepare() {
            super.prepare()

            guard let collectionView = self.collectionView
            else { return }

            var page      = 0
            let pageWidth = max( 50, collectionView.frame.size.width ), pageHeight = max( 50, self.pageHeight )
            for section in 0..<collectionView.numberOfSections {
                for item in 0..<collectionView.numberOfItems( inSection: section ) {
                    let indexPath = IndexPath( item: item, section: section )
                    var attrs     = self.attributes[indexPath]
                    if attrs == nil {
                        attrs = using( UICollectionViewLayoutAttributes( forCellWith: indexPath ) ) {
                            $0.size.height = pageHeight
                        }
                        self.attributes[indexPath] = attrs
                    }
                    attrs?.size.width = pageWidth
                    attrs?.frame.origin = CGPoint( x: pageWidth * CGFloat( page ), y: 0 )

                    page += 1
                }
            }

            self.contentSize = CGSize( width: pageWidth * CGFloat( page ), height: pageHeight )
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds.size.width != self.collectionView?.frame.size.width
        }

        open override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
                                                  withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
            if let currentAttributes = self.attributes[originalAttributes.indexPath],
               currentAttributes.size.height != preferredAttributes.size.height {
                currentAttributes.size.height = preferredAttributes.size.height
                return true
            }

            return false
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            self.attributes.values.filter( { rect.intersects( $0.frame ) } )
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            self.attributes[indexPath]
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
        }

        override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
            super.systemLayoutSizeFitting( targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: verticalFittingPriority )
        }
    }
}
