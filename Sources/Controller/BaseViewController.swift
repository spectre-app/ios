// =============================================================================
// Created by Maarten Billemont on 2019-10-30.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit
import SafariServices

class BaseViewController: UIViewController, Updatable, KeyboardMonitorObserver {
    var trackScreen = true
    lazy var screen = Tracker.shared.screen( named: Self.self.description() )

    internal let keyboardLayoutGuide = KeyboardLayoutGuide()
    internal let inputLayoutGuide    = UILayoutGuide()
    internal var backgroundView      = BackgroundView( mode: .clear )
    internal var activeChildController: UIViewController? {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
            self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }

    override var next:                                       UIResponder? {
        self.activeChildController ?? super.next
    }
    override var childForStatusBarStyle:                     UIViewController? {
        self.activeChildController ?? super.childForStatusBarStyle
    }
    override var childForStatusBarHidden:                    UIViewController? {
        self.activeChildController ?? super.childForStatusBarHidden
    }
    override var childForHomeIndicatorAutoHidden:            UIViewController? {
        self.activeChildController ?? super.childForHomeIndicatorAutoHidden
    }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        self.activeChildController ?? super.childForScreenEdgesDeferringSystemGestures
    }

    private var notificationObservers = [ NSObjectProtocol ]()

    private var closeButton: EffectButton? {
        didSet {
            if let oldValue = oldValue {
                oldValue.removeFromSuperview()
            }
            if let newValue = self.closeButton {
                self.view.addSubview( newValue )

                LayoutConfiguration( view: newValue )
                    .constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: -8 ) }
                    .constrain { $1.centerXAnchor.constraint( equalTo: $0.centerXAnchor ) }
                    .activate()
            }
        }
    }

    // MARK: - Interface

    func showCloseButton(track: Tracking?, primaryAction action: @escaping () -> (), longPressAction: (() -> ())? = nil) {
        self.closeButton = EffectButton( track: track, image: .icon( "xmark", style: .regular ) ) { _ in action() }

        if let longPressAction = longPressAction {
            self.closeButton?.addGestureRecognizer( UILongPressGestureRecognizer {
                guard case .began = $0.state
                else { return }

                longPressAction()
            } )
        }
    }

    // MARK: - Life

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )
        LeakRegistry.shared.register( self )
    }

    override func loadView() {
        self.view = self.backgroundView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addLayoutGuide( self.keyboardLayoutGuide )
    }

    override func viewWillAppear(_ animated: Bool) {
        if self.trackScreen {
            self.screen.open()
        }

        super.viewWillAppear( animated )

        Task {
            await UIView.performWithoutAnimation {
                try? await self.updateTask.requestNow()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.keyboardLayoutGuide.didAppear( observer: self )
        self.notificationObservers = [
            NotificationCenter.default.addObserver(
                    forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.willResignActive() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.didEnterBackground() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.willEnterForeground() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.didBecomeActive() },
        ]

        self.willEnterForeground()
        self.didBecomeActive()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.notificationObservers.forEach { NotificationCenter.default.removeObserver( $0 ) }
        self.keyboardLayoutGuide.willDisappear( observer: self )
        self.updateTask.cancel()

        super.viewWillDisappear( animated )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear( animated )

        if self.trackScreen {
            self.screen.dismiss()
        }
    }

    func willResignActive() {
    }

    func didEnterBackground() {
    }

    func willEnterForeground() {
    }

    func didBecomeActive() {
    }

    // MARK: - KeyboardMonitorObserver

    var changingScrollViews = [ UIScrollView ]()

    func didChange(keyboard: KeyboardMonitor, showing: Bool, changing: Bool,
                   fromScreenFrame: CGRect, toScreenFrame: CGRect, animated: Bool) {
        if nil != self.view.findSuperview( ofType: UIScrollView.self, where: { $0.isScrollEnabled } ) {
            self.additionalSafeAreaInsets = .zero

            // When inside a scrolling container, need to temporarily disable all inner scrolling.
            // This is necessary to allow correct keyboard inset adjustment of the outer scroller when first responder is inside an inner scroller.
            if changing {
                self.view.enumerateSubviews( ofType: UIScrollView.self ) { $0.isScrollEnabled } execute: { view in
                    self.changingScrollViews.append( view )
                    view.isScrollEnabled = false
                }
            }
            else {
                self.changingScrollViews.forEach { $0.isScrollEnabled = true }
                self.changingScrollViews.removeAll()
            }
            return
        }

        self.additionalSafeAreaInsets =
        max( .zero, self.keyboardLayoutGuide.keyboardInsets - (self.view.safeAreaInsets - self.additionalSafeAreaInsets) )
    }

    // MARK: - Updatable

    func setNeedsUpdate() {
        self.updateTask.request()
    }

    var updatesPostponed: Bool {
        !self.isViewLoaded// || self.view.superview == nil
    }

    lazy var updateTask = DispatchTask.update( self, animated: true ) { [weak self] in
        guard let self = self
        else { return }

        await self.doUpdate()
    }

    func doUpdate() async {
    }
}
