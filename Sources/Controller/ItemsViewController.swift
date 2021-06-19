//==============================================================================
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import Foundation
import UIKit

class ItemsViewController<M>: BaseViewController {
    public let model: M
    public var color: UIColor? {
        didSet {
            self.setNeedsUpdate()
        }
    }
    public var image: UIImage? {
        didSet {
            self.setNeedsUpdate()
        }
    }

    private let focus: Item<M>.Type?
    private let imageSpacer = UIView()
    private let itemsView   = UIStackView()
    private lazy var items = self.loadItems()

    // MARK: --- Interface ---

    func loadItems() -> [Item<M>] {
        []
    }

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(model: M, focus: Item<M>.Type? = nil) {
        self.model = model
        self.focus = focus
        super.init()

        self.items.forEach { $0.model = self.model }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.view.layoutMargins = .vertical( 40 )
        self.view.insetsLayoutMarginsFromSafeArea = false
        self.backgroundView.layer => \.shadowColor => Theme.current.color.shadow
        self.backgroundView.layer.shadowRadius = 8
        self.backgroundView.layer.shadowOpacity = .on
        self.backgroundView.layer.shadowOffset = .zero
        self.backgroundView.layer.cornerRadius = 8
        self.backgroundView.layer.masksToBounds = true

        self.itemsView.axis = .vertical
        self.itemsView.spacing = 40
        self.itemsView.addArrangedSubview( self.imageSpacer )
        for item in self.items {
            item.viewController = self
            self.itemsView.addArrangedSubview( item.view )
        }

        // - Hierarchy
        self.view.addSubview( self.itemsView )

        // - Layout
        LayoutConfiguration( view: self.imageSpacer )
                .constrain { $1.heightAnchor.constraint( equalTo: self.backgroundView.imageView.heightAnchor, multiplier: .long, constant: -40 ) }
                .activate()
        LayoutConfiguration( view: self.itemsView )
                .constrain( as: .box, margin: true )
                .constrain { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                .activate()

        self.items.forEach { $0.view.didLoad() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        // TODO: Move to DetailHostController?
        if let focus = self.focus, let scrollView = (self.parent as? DetailHostController)?.scrollView,
           let focusItem = self.items.first( where: { $0.isKind( of: focus ) } ) {
            let focusRect = scrollView.convert( focusItem.view.bounds, from: focusItem.view )
            scrollView.setContentOffset( CGPoint( x: 0, y: focusRect.center.y - scrollView.bounds.size.height / 2 ), animated: animated )

            let colorOn = Theme.current.color.selection.get(), colorOff = colorOn?.with( alpha: .off )
            focusItem.view.backgroundColor = colorOff
            UIView.animate( withDuration: .long, animations: {
                focusItem.view.backgroundColor = colorOn
            }, completion: {
                UIView.animate( withDuration: $0 ? .long: .off ) {
                    focusItem.view.backgroundColor = colorOff
                }
            } )
        }
    }

    // MARK: --- Updatable ---

    override func doUpdate() {
        super.doUpdate()

        if let color = self.color {
            self.backgroundView.mode = .custom( color: { Theme.current.color.panel.get()?.with( hue: color.hue ) } )
            self.view.tintColor = Theme.current.color.tint.get()?.with( hue: color.hue )
        }
        else {
            self.backgroundView.mode = .panel
            self.view.tintColor = nil
        }
        self.backgroundView.image = self.image
        self.backgroundView.imageColor = self.color
        self.imageSpacer.isHidden = self.image == nil

        self.items.forEach { $0.updateTask.request( now: true ) }
    }
}
