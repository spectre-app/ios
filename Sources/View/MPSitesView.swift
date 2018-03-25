//
// Created by Maarten Billemont on 2018-03-25.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitesView: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
    var user: MPUser? {
        willSet {
        }
        didSet {
        }
    }

    let collectionView = UICollectionView( frame: .zero, collectionViewLayout: Layout() )

    // MARK: - Life

    override init(frame: CGRect) {
        super.init( frame: frame )

        self.collectionView.delegate = self
        self.collectionView.dataSource = self

        self.addSubview( self.collectionView )

        ViewConfiguration( view: self.collectionView )
                .add { $0.topAnchor.constraint( equalTo: self.layoutMarginsGuide.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.layoutMarginsGuide.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.layoutMarginsGuide.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.layoutMarginsGuide.bottomAnchor ) }
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.user?.sites.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return SiteCell( site: self.user!.sites[indexPath.item] )
    }

    class SiteCell: UICollectionViewCell {
        let site: MPSite

        // MARK: - Life

        init(site: MPSite) {
            self.site = site

            super.init( frame: .zero )
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError( "init(coder:) is not supported for this class" )
        }
    }

    class Layout: UICollectionViewLayout {
    }
}
