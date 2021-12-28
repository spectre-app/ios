// =============================================================================
// Created by Maarten Billemont on 2018-09-16.
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

class SitePreviewController: UIViewController, SiteObserver {
    private let siteButton = UIButton( type: .custom )

    // MARK: - Life

    init(site: Site) {
        super.init( nibName: nil, bundle: nil )

        site.observers.register( observer: self ).didChange( site: site, at: \Site.preview )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.siteButton.imageView?.contentMode = .scaleAspectFill
        self.siteButton.titleLabel! => \.font => Theme.current.font.largeTitle

        // - Hierarchy
        self.view.addSubview( self.siteButton )

        // - Layout
        LayoutConfiguration( view: self.siteButton )
                .constrain { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrain { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrain { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrain { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
    }

    // MARK: - SiteObserver

    func didChange(site: Site, at change: PartialKeyPath<Site>) {
        guard change == \Site.preview || change == \Site.siteName
        else { return }

        DispatchQueue.main.perform {
            self.view.backgroundColor = site.preview.color
            self.siteButton.setImage( site.preview.image, for: .normal )
            self.siteButton.setTitle( site.preview.image == nil ? site.siteName : nil, for: .normal )
            self.preferredContentSize = site.preview.image?.size ?? CGSize( width: 0, height: 200 )
        }
    }
}
