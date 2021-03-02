//
// Created by Maarten Billemont on 2019-10-30.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class BaseViewController: UIViewController, Updatable, KeyboardLayoutObserver {
    var trackScreen = true
    lazy var screen = Tracker.shared.screen( named: Self.self.description() )

    internal let keyboardLayoutGuide = KeyboardLayoutGuide()
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

    var updatesPostponed: Bool {
        !self.isViewLoaded || self.view.superview == nil
    }
    private lazy var updateTask = DispatchTask( deadline: .now() + .milliseconds( 100 ), update: self, animated: true )
    private var notificationObservers = [ NSObjectProtocol ]()

    // MARK: --- Life ---

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init() {
        super.init( nibName: nil, bundle: nil )
    }

    override func loadView() {
        self.view = self.backgroundView
    }

    override func viewWillAppear(_ animated: Bool) {
        if self.trackScreen {
            self.screen.open()
        }

        super.viewWillAppear( animated )

        UIView.performWithoutAnimation { self.update() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )

        self.keyboardLayoutGuide.install( in: self.view, observer: self )
        self.notificationObservers = [
            NotificationCenter.default.addObserver(
                    forName: UIApplication.willResignActiveNotification, object: nil, queue: .main ) { [weak self] _ in self?.willResignActive() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main ) { [weak self] _ in self?.didEnterBackground() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main ) { [weak self] _ in self?.willEnterForeground() },
            NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main ) { [weak self] _ in self?.didBecomeActive() },
        ]
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.notificationObservers.forEach { NotificationCenter.default.removeObserver( $0 ) }
        self.keyboardLayoutGuide.uninstall()
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

    // MARK: --- KeyboardLayoutObserver ---

    func keyboardDidChange(showing: Bool, layoutGuide: KeyboardLayoutGuide) {
        self.additionalSafeAreaInsets = layoutGuide.keyboardInsets
    }

    // MARK: --- Updatable ---

    func setNeedsUpdate() {
        self.updateTask.request()
    }

    func update() {
        self.updateTask.cancel()
    }
}