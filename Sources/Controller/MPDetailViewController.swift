//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class AnyMPDetailsViewController: MPViewController {
}

class MPDetailsViewController<M>: AnyMPDetailsViewController {
    public let model: M

    let backgroundView = MPBackgroundView()
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
        super.init()

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
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = 1
        self.backgroundView.layer => \.shadowColor => Theme.current.color.shadow
        self.backgroundView.layer.shadowOffset = .zero
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.masksToBounds = true

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
        for item in self.items {
            item.view.didLoad()
        }

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrain()
                .activate()
        LayoutConfiguration( view: self.imageView )
                .constrain( anchors: .topBox )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 200 ) }
                .activate()
        LayoutConfiguration( view: self.itemsView )
                .constrain( margins: true, anchors: .vertically )
                .constrain( anchors: .horizontally )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                .activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        UIView.performWithoutAnimation {
            self.items.forEach { $0.doUpdate() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.imageGradient.frame = self.imageView.bounds
    }
}
