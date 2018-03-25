//
// Created by Maarten Billemont on 2018-03-24.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit
import pop

class MPSitesViewController: UIViewController {
    private let user = MPUser( named: "Robert Lee Mitchell", avatar: .avatar_5 )

    private let nameLabel = UILabel()
    private let sitesView = MPSitesView()

    // MARK: - Life

    override func viewDidLoad() {
        self.nameLabel.font = UIFont( name: "Exo2.0-Regular", size: 34 )
        self.nameLabel.textAlignment = .center
        self.nameLabel.textColor = .white
        self.nameLabel.numberOfLines = 0

        self.view.addSubview( self.nameLabel )
        self.view.addSubview( self.sitesView )

        ViewConfiguration( view: self.sitesView )
                .add { $0.topAnchor.constraint( equalTo: self.view.layoutMarginsGuide.topAnchor ) }
                .add { $0.leadingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.nameLabel.topAnchor ) }
                .activate()

        ViewConfiguration( view: self.nameLabel )
                .add { $0.leadingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.leadingAnchor ) }
                .add { $0.trailingAnchor.constraint( equalTo: self.view.layoutMarginsGuide.trailingAnchor ) }
                .add { $0.bottomAnchor.constraint( equalTo: self.view.layoutMarginsGuide.bottomAnchor ) }
                .activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.nameLabel.text = self.user.fullName
        self.sitesView.user = self.user
    }
}
