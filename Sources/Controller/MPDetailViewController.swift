//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class AnyMPDetailsViewController: UIViewController, Observable {
    public let observers = Observers<MPDetailsObserver>()
}

class MPDetailsViewController<M>: AnyMPDetailsViewController {
    public let model: M

    let backgroundView = MPTintView()
    let imageView      = UIImageView()
    let itemsView      = UIStackView()
    let closeButton    = MPButton.closeButton()
    lazy var items         = self.loadItems()
    lazy var imageGradient = CAGradientLayer( layer: self.imageView.layer )

    // MARK: --- Interface ---

    func loadItems() -> [Item<M>] {
        []
    }

    func setNeedsUpdate() {
        self.items.forEach { $0.setNeedsUpdate() }
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(model: M) {
        self.model = model
        super.init( nibName: nil, bundle: nil )

        for item in self.items {
            item.viewController = self
            item.model = self.model
        }
    }

    override func viewDidLoad() {

        // - View
        self.imageGradient.colors = [
            UIColor.black.withAlphaComponent( 0.2 ).cgColor,
            UIColor.black.withAlphaComponent( 0.05 ).cgColor,
            UIColor.clear.cgColor ]
        self.imageGradient.needsDisplayOnBoundsChange = true
        self.imageView.layer.mask = self.imageGradient
        self.imageView.contentMode = .scaleAspectFill
        self.imageView.clipsToBounds = true

        self.backgroundView.layoutMargins = UIEdgeInsets( top: 20, left: 8, bottom: 20, right: 8 )
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = 1
        self.backgroundView.layer.shadowColor = MPTheme.global.color.shadow.get()?.cgColor
        self.backgroundView.layer.shadowOffset = .zero

        self.itemsView.axis = .vertical
        self.itemsView.spacing = 20
        for item in self.items {
            self.itemsView.addArrangedSubview( item.view )
        }

        self.closeButton.button.addAction( for: .touchUpInside ) { _, _ in
            self.observers.notify { $0.shouldDismissDetails() }
        }

        // - Hierarchy
        self.backgroundView.addSubview( self.imageView )
        self.backgroundView.addSubview( self.itemsView )
        self.view.addSubview( self.backgroundView )
        self.view.addSubview( self.closeButton )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: $0.bottomAnchor ) }
                .activate()
        LayoutConfiguration( view: self.imageView )
                .constrainToOwner( withAnchors: .topBox )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 200 ) }
                .activate()
        LayoutConfiguration( view: self.itemsView )
                .constrainToMarginsOfOwner( withAnchors: .vertically )
                .constrainToOwner( withAnchors: .horizontally )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ) }
                .activate()
        LayoutConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.backgroundView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.backgroundView.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.imageGradient.frame = self.imageView.bounds
    }
}

protocol MPDetailsObserver {
    func shouldDismissDetails()
}
