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

    let backgroundView = UIView()
    let itemsView      = UIStackView()
    let closeButton    = MPButton.closeButton()
    lazy var items = self.loadItems()

    // MARK: --- Interface ---

    func loadItems() -> [Item<M>] {
        return []
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
            item.model = self.model
        }
    }

    override func viewDidLoad() {

        // - View
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = 0.382

        self.itemsView.axis = .vertical
        self.itemsView.spacing = 20
        for item in self.items {
            self.itemsView.addArrangedSubview( item.view )
        }

        self.closeButton.button.addAction( for: .touchUpInside ) { _, _ in
            self.observers.notify { $0.shouldDismissDetails() }
        }

        // - Hierarchy
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
        LayoutConfiguration( view: self.itemsView )
                .constrainToOwner( withMargins: true, anchor: .vertically )
                .constrainToOwner( withMargins: false, anchor: .horizontally )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ) }
                .activate()
        LayoutConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.backgroundView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.backgroundView.bottomAnchor ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                .activate()
    }
}

@objc
protocol MPDetailsObserver {
    func shouldDismissDetails()
}
