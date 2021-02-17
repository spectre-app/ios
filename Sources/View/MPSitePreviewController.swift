//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPSitePreviewController: UIViewController, MPSiteObserver {
    private let siteButton = UIButton( type: .custom )

    // MARK: --- Life ---

    init(site: MPSite) {
        super.init( nibName: nil, bundle: nil )

        site.observers.register( observer: self ).siteDidChange( site )
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
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
    }

    // MARK: --- MPSiteObserver ---

    func siteDidChange(_ site: MPSite) {
        DispatchQueue.main.perform {
            self.view.backgroundColor = site.preview.color
            self.siteButton.setImage( site.preview.image, for: .normal )
            self.siteButton.setTitle( site.preview.image == nil ? site.siteName: nil, for: .normal )
            self.preferredContentSize = site.preview.image?.size ?? CGSize( width: 0, height: 200 )
        }
    }
}
