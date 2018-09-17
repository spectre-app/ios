//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPSiteView: UIView {
    var site: MPSite? {
        didSet {
            self.nameLabel.text = self.site?.siteName
        }
    }

    let nameLabel = UILabel()

    // MARK: - Life

    init() {
        super.init( frame: .zero )
        self.backgroundColor = UIColor( white: 0.1, alpha: 0.9 )

        self.nameLabel.font = UIFont.preferredFont( forTextStyle: .title1 )
        self.nameLabel.textColor = .white

        // - Hierarchy
        self.addSubview( self.nameLabel )

        // - Layout
        ViewConfiguration( view: self.nameLabel )
                .constrainTo { $0.layoutMarginsGuide.topAnchor.constraint( equalTo: $1.topAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.leadingAnchor.constraint( equalTo: $1.leadingAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.trailingAnchor.constraint( equalTo: $1.trailingAnchor ) }
                .constrainTo { $0.layoutMarginsGuide.bottomAnchor.constraint( equalTo: $1.bottomAnchor ) }
                .activate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }
}
