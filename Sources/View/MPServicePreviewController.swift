//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPServicePreviewController: UIViewController, MPServiceObserver {
    private let serviceButton = UIButton( type: .custom )

    // MARK: --- Life ---

    init(service: MPService) {
        super.init( nibName: nil, bundle: nil )

        service.observers.register( observer: self ).serviceDidChange( service )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.serviceButton.imageView?.contentMode = .scaleAspectFill
        self.serviceButton.titleLabel! => \.font => Theme.current.font.largeTitle

        // - Hierarchy
        self.view.addSubview( self.serviceButton )

        // - Layout
        LayoutConfiguration( view: self.serviceButton )
                .constrainTo { $1.topAnchor.constraint( greaterThanOrEqualTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( greaterThanOrEqualTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( lessThanOrEqualTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .constrainTo { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: $0.centerYAnchor ) }
                .activate()
    }

    // MARK: --- MPServiceObserver ---

    func serviceDidChange(_ service: MPService) {
        DispatchQueue.main.perform {
            self.view.backgroundColor = service.color
            self.serviceButton.setImage( service.image, for: .normal )
            self.serviceButton.setTitle( service.image == nil ? service.serviceName: nil, for: .normal )
            self.preferredContentSize = service.image?.size ?? CGSize( width: 0, height: 200 )
        }
    }
}
