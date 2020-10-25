//
// Created by Maarten Billemont on 2018-03-04.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

/**
 * A view that presents a collection of items with a single item at the centre.
 * The item the spinner has at its centre when at rest is the selected item.
 */
public class MPPagerView: UICollectionView, UICollectionViewDelegateFlowLayout {
    let pagerLayout = PagerLayout()

    // MARK: --- Life ---

    public init() {
        super.init( frame: .zero, collectionViewLayout: self.pagerLayout )

        self.isPagingEnabled = true
        self.delegate = self
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
        override init() {
            super.init()

            self.scrollDirection = .horizontal
        }

        required init?(coder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            self.itemSize = newBounds.size
            return true
        }
    }
}
