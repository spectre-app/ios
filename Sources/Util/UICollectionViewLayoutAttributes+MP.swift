//
// Created by Maarten Billemont on 2020-08-18.
// Copyright (c) 2020 Lyndir. All rights reserved.
//

import Foundation

extension UICollectionViewLayoutAttributes {
    public convenience init(forCellWith indexPath: IndexPath, init i: (UICollectionViewLayoutAttributes) -> ()) {
        self.init( forCellWith: indexPath )
        i( self )
    }

    public convenience init(forSupplementaryViewOfKind elementKind: String, with indexPath: IndexPath, init i: (UICollectionViewLayoutAttributes) -> ()) {
        self.init( forSupplementaryViewOfKind: elementKind, with: indexPath )
        i( self )
    }

    public convenience init(forDecorationViewOfKind decorationViewKind: String, with indexPath: IndexPath, init i: (UICollectionViewLayoutAttributes) -> ()) {
        self.init( forDecorationViewOfKind: decorationViewKind, with: indexPath )
        i( self )
    }
}
