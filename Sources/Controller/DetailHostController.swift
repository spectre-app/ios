//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

protocol DetailViewController: UIViewController {
    var isContentScrollable: Bool { get }
    var isCloseHidden:       Bool { get }

    func hide(completion: (() -> Void)?)
}

extension DetailViewController {
    var isContentScrollable: Bool {
        false
    }
    var isCloseHidden:       Bool {
        false
    }

    func hide(completion: (() -> Void)? = nil) {
        (self.parent as? DetailHostController)?.hide( completion: completion )
    }
}

class DetailHostController: BaseViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public let scrollView  = UIScrollView()
    public let contentView = UntouchableView()
    public var isShowing: Bool {
        self.activeController != nil
    }

    private var activeController: UIViewController? {
        didSet {
            self.activeChildController = self.activeController
        }
    }

    private lazy var detailRecognizer = UITapGestureRecognizer( target: self, action: #selector( hideAction ) )
    private lazy var closeButton = EffectButton( track: .subject( "details", action: "close" ),
                                                 attributedTitle: .icon( "" ) ) { _, _ in self.hide() }
    private var popupConfiguration:        LayoutConfiguration<UIView>!
    private var fixedContentConfiguration: LayoutConfiguration<UIView>!
    private var contentSizeObservation:    NSKeyValueObservation?

    // MARK: --- Life ---

    override var next: UIResponder? {
        self.parent?.view.superview
    }

    override func loadView() {
        self.view = UntouchableView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.trackScreen = false

        // - View
        self.detailRecognizer.delegate = self
        self.scrollView.delegate = self
        self.scrollView.keyboardDismissMode = .interactive
        self.scrollView.contentInsetAdjustmentBehavior = .always
        self.scrollView.addGestureRecognizer( self.detailRecognizer )

        self.closeButton.alpha = .off

        self.contentSizeObservation = self.scrollView.observe( \.contentSize ) { [unowned self] _, _ in
            // Inset top to push content to the bottom of the host.
            self.scrollView.contentInset.top = max( 0, self.scrollView.layoutMarginsGuide.layoutFrame.height - self.scrollView.contentSize.height )

            // Inset bottom to ensure content is large enough to enable scrolling.
            self.scrollView.contentInset.bottom = max( 0, self.scrollView.frame.height - self.scrollView.contentSize.height
                    - self.scrollView.adjustedContentInset.top - self.scrollView.adjustedContentInset.bottom + 1 )
        }

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.view.addSubview( self.closeButton )
        self.scrollView.addSubview( self.contentView )

        // - Layout
        LayoutConfiguration( view: self.scrollView )
                .constrain { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                .constrain { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                .constrain { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ) }
                .activate()

        LayoutConfiguration( view: self.contentView )
                .constrain { $1.widthAnchor.constraint( equalTo: $0.widthAnchor ) }
                .constrain( as: .box )
                .activate()

        self.fixedContentConfiguration = LayoutConfiguration( view: self.contentView )
                .constrain { $1.heightAnchor.constraint( equalTo: $0.heightAnchor ) }
                .apply( LayoutConfiguration( view: self.scrollView )
                                .set( false, keyPath: \.isScrollEnabled, reverses: true ) )

        LayoutConfiguration( view: self.closeButton )
                .constrain { $1.centerXAnchor.constraint( equalTo: self.contentView.centerXAnchor ) }
                .constrain { $1.centerYAnchor.constraint( equalTo: self.contentView.bottomAnchor ).with( priority: .fittingSizeLevel ) }
                .constrain { $1.bottomAnchor.constraint( lessThanOrEqualTo: self.view.bottomAnchor, constant: -8 ) }
                .activate()

        self.popupConfiguration = LayoutConfiguration( view: self.view )
                .apply { active, inactive in
                    active.set( Theme.current.color.shade.get(), keyPath: \.backgroundColor )
                    inactive.set( Theme.current.color.shade.get( alpha: .off ), keyPath: \.backgroundColor )
                }
                .apply( LayoutConfiguration( view: self.scrollView ) { active, inactive in
                    active.constrain { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    inactive.constrain { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
                } )
    }

    #if TARGET_APP
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            self.show( DetailLogViewController(), sender: self )
        }
        else {
            super.motionEnded( motion, with: event )
        }
    }
    #endif

    // MARK: --- Private ---

    @objc
    private func hideAction() {
        self.hide()
    }

    // MARK: --- Interface ---

    override func show(_ vc: UIViewController, sender: Any?) {
        self.hide {
            self.activeController = vc

            if let activeController = self.activeController {
                let detailController = activeController as? DetailViewController
                UIView.performWithoutAnimation {
                    self.addChild( activeController )
                    activeController.view.frame.size = self.contentView.bounds.size.union(
                            activeController.view.systemLayoutSizeFitting( self.contentView.bounds.size ) )
                    activeController.beginAppearanceTransition( true, animated: true )
                    self.fixedContentConfiguration.isActive = detailController?.isContentScrollable ?? false
                    self.contentView.addSubview( activeController.view )
                    LayoutConfiguration( view: activeController.view )
                            .constrain( as: .box, margin: true ).activate()
                }
                UIView.animate( withDuration: .short, animations: {
                    self.closeButton.alpha = detailController?.isCloseHidden ?? false ? .off: .on
                    activeController.view.window?.endEditing( true )
                    self.popupConfiguration.activate()
                }, completion: { finished in
                    activeController.endAppearanceTransition()
                    activeController.didMove( toParent: self )
                } )
            }
        }
    }

    @discardableResult
    public func hide(completion: (() -> Void)? = nil) -> Bool {
        if let detailsController = self.activeController {
            DispatchQueue.main.perform {
                detailsController.willMove( toParent: nil )
                detailsController.beginAppearanceTransition( false, animated: true )
                UIView.animate( withDuration: .short, animations: {
                    self.scrollView.contentOffset = CGPoint( x: 0, y: -self.scrollView.adjustedContentInset.top )
                    self.popupConfiguration.deactivate()
                    self.closeButton.alpha = .off
                }, completion: { finished in
                    detailsController.view.removeFromSuperview()
                    detailsController.endAppearanceTransition()
                    detailsController.removeFromParent()
                    self.contentView.layoutIfNeeded()
                    self.activeController = nil
                    completion?()
                } )
            }
            return true
        }
        else {
            DispatchQueue.main.perform {
                self.scrollView.contentOffset = CGPoint( x: 0, y: -self.scrollView.adjustedContentInset.top )
                completion?()
            }
            return false
        }
    }

    override func keyboardDidChange(showing: Bool, layoutGuide: KeyboardLayoutGuide) {
        if !self.fixedContentConfiguration.isActive {
            super.keyboardDidChange( showing: showing, layoutGuide: layoutGuide )
        }
    }

    // MARK: --- UIGestureRecognizerDelegate ---

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // detailRecognizer shouldn't trigger on subviews
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