//
// Created by Maarten Billemont on 2019-11-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UICollectionReusableView {
    static func dequeue<C: UICollectionReusableView>(from collectionView: UICollectionView, kind: String, indexPath: IndexPath, _ initializer: ((C) -> ())? = nil) -> Self {
        let cell = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! C

        if let initialize = initializer {
            initialize( cell )
        }

        return cell as! Self
    }
}

extension UICollectionViewCell {
    static func dequeue<C: UICollectionViewCell>(from collectionView: UICollectionView, indexPath: IndexPath, _ initializer: ((C) -> ())? = nil) -> Self {
        let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NSStringFromClass( self ), for: indexPath ) as! C

        if let initialize = initializer {
            initialize( cell )
        }

        return cell as! Self
    }
}

extension UICollectionView {

    func register(_ type: UICollectionViewCell.Type, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forCellWithReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forCellWithReuseIdentifier: NSStringFromClass( type ) )
        }
    }

    func register(_ type: UICollectionReusableView.Type, supplementaryKind kind: String, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forSupplementaryViewOfKind: kind, withReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forSupplementaryViewOfKind: kind, withReuseIdentifier: NSStringFromClass( type ) )
        }
    }

    func register(_ type: UICollectionReusableView.Type, decorationKind kind: String) {
        self.collectionViewLayout.register( type, forDecorationViewOfKind: kind )
    }

    func register(_ nib: UINib, decorationKind kind: String) {
        self.collectionViewLayout.register( nib, forDecorationViewOfKind: kind )
    }
}
