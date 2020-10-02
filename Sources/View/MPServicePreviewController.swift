//
// Created by Maarten Billemont on 2018-09-16.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import UIKit

class MPServicePreviewController: UIViewController, MPServiceObserver {
    public var service: MPService? {
        willSet {
            self.service?.observers.unregister( observer: self )
        }
        didSet {
            if let service = self.service {
                service.observers.register( observer: self ).serviceDidChange( service )
            }

            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    private let serviceButton = UIButton( type: .custom )

    // MARK: --- Life ---

    init(service: MPService? = nil) {
        super.init( nibName: nil, bundle: nil )

        defer {
            self.service = service
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = UIEdgeInsets( top: 12, left: 12, bottom: 20, right: 12 )
        self.view.layer.shadowRadius = 40
        self.view.layer.shadowOpacity = .on
        self.view.layer => \.shadowColor => Theme.current.color.shadow
        self.view.layer.shadowOffset = .zero

        self.serviceButton.imageView?.contentMode = .scaleAspectFill
        self.serviceButton.imageView?.layer.cornerRadius = 4
        self.serviceButton.imageView?.layer.masksToBounds = true
        self.serviceButton.titleLabel! => \.font => Theme.current.font.largeTitle
        self.serviceButton.layer.shadowRadius = 20
        self.serviceButton.layer.shadowOpacity = .on
        self.serviceButton.layer => \.shadowColor => Theme.current.color.shadow
        self.serviceButton.layer.shadowOffset = .zero

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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available( iOS 13, * ) {
            return self.service?.color?.brightness ?? 0 > 0.8 ? .darkContent: .lightContent
        }
        else {
            return self.service?.color?.brightness ?? 0 > 0.8 ? .default: .lightContent
        }
    }

    // MARK: --- MPServiceObserver ---

    func serviceDidChange(_ service: MPService) {
        DispatchQueue.main.perform {
            UIView.performWithoutAnimation {
                self.view.backgroundColor = self.service?.color
                self.serviceButton.setImage( self.service?.image, for: .normal )
                self.serviceButton.setTitle( self.service?.image == nil ? self.service?.serviceName: nil, for: .normal )
                self.preferredContentSize = self.service?.image?.size ?? CGSize( width: 0, height: 200 )

                if let brightness = self.service?.color?.brightness, brightness > 0.8 {
                    self.serviceButton.layer.shadowColor = UIColor.darkGray.cgColor
                }
                else {
                    self.serviceButton.layer.shadowColor = UIColor.lightGray.cgColor
                }

                self.view.layoutIfNeeded()
            }
        }
    }
}
