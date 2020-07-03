//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDetailsHostController: MPViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public let scrollView  = UIScrollView()
    public let contentView = MPUntouchableView()
    public var isShowing: Bool {
        self.detailsController != nil
    }

    private lazy var detailRecognizer    = UITapGestureRecognizer( target: self, action: #selector( hideAction ) )
    private lazy var popupConfiguration  = LayoutConfiguration( view: self.view )
    private lazy var keyboardLayoutGuide = KeyboardLayoutGuide( in: self.view )
    private let closeButton = MPButton.close( for: "details" )
    private var detailsController:      AnyMPDetailsViewController?
    private var contentSizeObservation: NSKeyValueObservation?

    // MARK: --- Life ---

    override var next:                                       UIResponder? {
        self.parent?.view.superview
    }
    private var  activeChild:                                UIViewController? {
        self.detailsController
    }
    override var childForStatusBarStyle:                     UIViewController? {
        self.activeChild
    }
    override var childForStatusBarHidden:                    UIViewController? {
        self.activeChild
    }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        self.activeChild
    }
    override var childForHomeIndicatorAutoHidden:            UIViewController? {
        self.activeChild
    }

    override func loadView() {
        self.view = MPUntouchableView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.trackScreen = false

        // - View
        self.detailRecognizer.delegate = self
        self.scrollView.delegate = self
        self.scrollView.keyboardDismissMode = .onDrag
        self.scrollView.contentInsetAdjustmentBehavior = .always
        self.scrollView.addGestureRecognizer( self.detailRecognizer )

        self.closeButton.button.addTarget( self, action: #selector( hideAction ), for: .primaryActionTriggered )

        self.contentSizeObservation = self.scrollView.observe( \.contentSize ) { _, _ in
            // Inset top to push content to the bottom of the host.
            self.scrollView.contentInset = UIEdgeInsets(
                    top: max( 0, self.scrollView.layoutMarginsGuide.layoutFrame.height - self.scrollView.contentSize.height ),
                    left: 0, bottom: 0, right: 0 )

            // Inset bottom to ensure content is large enough to enable scrolling.
            self.scrollView.contentInset.bottom = max( 0, self.scrollView.frame.height - self.scrollView.contentSize.height
                    - self.scrollView.adjustedContentInset.top - self.scrollView.adjustedContentInset.bottom + 1 )
        }

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.scrollView.addSubview( self.contentView )
        self.contentView.addSubview( self.closeButton )

        // - Layout
        LayoutConfiguration( view: self.scrollView )
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrainTo { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ) }
                .activate()

        LayoutConfiguration( view: self.contentView )
                .constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor, constant: 8 ) }
                .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor, constant: 8 ) }
                .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor, constant: -8 ) }
                .constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor, constant: -8 ) }
                .constrainTo { $1.widthAnchor.constraint( equalTo: $0.widthAnchor, constant: -16 ) }
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).with( priority: .fittingSizeLevel ) }
                .activate()

        LayoutConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.contentView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.contentView.bottomAnchor ).with( priority: .fittingSizeLevel ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: self.view.bottomAnchor, constant: -8 ) }
                .activate()

        self.popupConfiguration
                .apply { active, inactive in
                    active.set( Theme.current.color.shade.get(), forKey: "backgroundColor" )
                    inactive.set( Theme.current.color.shade.get( alpha: 0 ), forKey: "backgroundColor" )
                }
                .apply( LayoutConfiguration( view: self.scrollView ) { active, inactive in
                    active.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    inactive.constrainTo { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
                } )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear( animated )

        self.keyboardLayoutGuide.install( observer: { keyboardFrame in
            self.additionalSafeAreaInsets.bottom = keyboardFrame.height
        } )
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.keyboardLayoutGuide.uninstall()

        super.viewWillDisappear( animated )
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            trc( "Shake motion, opening log details." )
            self.show( MPLogDetailsViewController() )
        }
        else {
            super.motionEnded( motion, with: event )
        }
    }

    // MARK: --- Private ---

    @objc
    private func hideAction() {
        self.hide()
    }

    // MARK: --- Interface ---

    public func show(_ detailsController: AnyMPDetailsViewController) {
        self.hide {
            self.detailsController = detailsController

            if let detailsController = self.detailsController {
                self.addChild( detailsController )
                detailsController.beginAppearanceTransition( true, animated: true )
                self.contentView.insertSubview( detailsController.view, belowSubview: self.closeButton )
                LayoutConfiguration( view: detailsController.view ).constrain().activate()
                UIView.animate( withDuration: .short, animations: {
                    detailsController.view.window?.endEditing( true )
                    self.popupConfiguration.activate()
                }, completion: { finished in
                    detailsController.endAppearanceTransition()
                    detailsController.didMove( toParent: self )
                } )
            }
        }
    }

    @discardableResult
    public func hide(completion: (() -> Void)? = nil) -> Bool {
        if let detailsController = self.detailsController {
            DispatchQueue.main.perform {
                detailsController.willMove( toParent: nil )
                detailsController.beginAppearanceTransition( false, animated: true )
                UIView.animate( withDuration: .short, animations: {
                    self.popupConfiguration.deactivate()
                }, completion: { finished in
                    detailsController.view.removeFromSuperview()
                    detailsController.endAppearanceTransition()
                    detailsController.removeFromParent()
                    self.detailsController = nil
                    completion?()
                } )
            }
            return true
        }
        else {
            completion?()
            return false
        }
    }

    // MARK: --- UIGestureRecognizerDelegate ---

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // siteDetailRecognizer shouldn't trigger on subviews
        if gestureRecognizer == self.detailRecognizer {
            return touch.view == gestureRecognizer.view
        }

        return true
    }

    // MARK: --- UIScrollViewDelegate ---

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == self.scrollView, scrollView.adjustedContentInset.top + scrollView.contentOffset.y < -44 {
            self.hide()
        }
    }
}
