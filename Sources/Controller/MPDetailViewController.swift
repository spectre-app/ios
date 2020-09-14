//
// Created by Maarten Billemont on 2018-10-15.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation
import UIKit

class AnyMPDetailsViewController: MPViewController, Updatable {
    var hostController: MPDetailsHostController?

    var updatesPostponed: Bool {
        !self.isViewLoaded || self.view.superview == nil
    }
    private lazy var updateTask = DispatchTask( queue: .main, deadline: .now() + .milliseconds( 100 ),
                                                qos: .userInitiated, update: self, animated: true )
    private var willEnterForegroundObserver: NSObjectProtocol?

    // MARK: --- Interface ---

    func setNeedsUpdate() {
        self.updateTask.request()
    }

    // MARK: --- Life ---

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        UIView.performWithoutAnimation { self.update() }
        self.willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main ) { [unowned self] _ in
            self.setNeedsUpdate()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.update()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.willEnterForegroundObserver.flatMap { NotificationCenter.default.removeObserver( $0 ) }
        self.updateTask.cancel()

        super.viewWillDisappear( animated )
    }

    // MARK: --- Updatable ---

    func update() {
        self.updateTask.cancel()
    }
}

class MPDetailsViewController<M>: AnyMPDetailsViewController {
    public let model: M
    public var color: UIColor? {
        didSet {
            self.backgroundView => \.backgroundColor => Theme.current.color.panel
                    .transform { [unowned self] in $0?.with( hue: self.color?.hue ) }
        }
    }
    public var image: UIImage? {
        didSet {
            self.backgroundView.image = self.image
            self.backgroundView.layoutMargins.top = self.image == nil ? 40: 108
        }
    }

    private let focus: Item<M>.Type?
    private let backgroundView = MPBackgroundView()
    private let itemsView      = UIStackView()
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

        // - View
        self.backgroundView.layoutMargins.bottom = 40
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
        self.backgroundView.addSubview( self.itemsView )
        self.view.addSubview( self.backgroundView )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrain()
                .activate()
        LayoutConfiguration( view: self.itemsView )
                .constrain( margins: true, anchors: .vertically )
                .constrain( anchors: .horizontally )
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                .activate()

        self.items.forEach { $0.view.didLoad() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        if let focus = self.focus, let scrollView = self.hostController?.scrollView,
           let focusItem = self.items.first( where: { $0.isKind( of: focus ) } ),
           let focusRect = self.hostController?.scrollView.convert( focusItem.view.bounds, from: focusItem.view ) {
            scrollView.contentOffset.y = focusRect.center.y - scrollView.bounds.size.height / 2
        }
    }

    // MARK: --- Updatable ---

    override func update() {
        super.update()

        self.items.forEach { $0.update() }
    }
}
