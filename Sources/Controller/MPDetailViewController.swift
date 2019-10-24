//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class AnyMPDetailsViewController: UIViewController {
}

class MPDetailsViewController<M>: AnyMPDetailsViewController {
    public let model: M

    let backgroundView = MPTintView()
    let imageView      = UIImageView()
    let itemsView      = UIStackView()
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

        self.items.forEach { $0.model = self.model }
    }

    override func viewDidLoad() {

        // - View
        self.imageGradient.colors = [
            UIColor.black.withAlphaComponent( 0.382 ).cgColor,
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
            item.viewController = self
            self.itemsView.addArrangedSubview( item.view )
        }

        // - Hierarchy
        self.backgroundView.addSubview( self.imageView )
        self.backgroundView.addSubview( self.itemsView )
        self.view.addSubview( self.backgroundView )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrainToOwner()
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.items.forEach { $0.doUpdate() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.imageGradient.frame = self.imageView.bounds
    }
}
