//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDetailsHostController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public let scrollView  = UIScrollView()
    public let contentView = MPUntouchableView()
    let closeButton = MPButton.closeButton()

    private lazy var detailRecognizer = UITapGestureRecognizer( target: self, action: #selector( didTapBackground ) )
    private lazy var configuration    = LayoutConfiguration( view: self.view )
    private var detailsController:      AnyMPDetailsViewController?
    private var contentSizeObservation: NSKeyValueObservation?

    override func loadView() {
        self.view = MPUntouchableView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // - View
        self.detailRecognizer.delegate = self
        self.scrollView.addGestureRecognizer( self.detailRecognizer )
        self.scrollView.delegate = self
        if #available( iOS 11.0, * ) {
            self.scrollView.contentInsetAdjustmentBehavior = .always
        }

        self.closeButton.button.addAction( for: .touchUpInside ) { _, _ in self.hideDetails() }

        // Keep sufficient inset to keep content at the bottom of the host.
        self.contentSizeObservation = self.scrollView.observe( \.contentSize ) { _, _ in
            self.scrollView.contentInset = UIEdgeInsets(
                    top: max( 0, self.scrollView.layoutMarginsGuide.layoutFrame.height - self.scrollView.contentSize.height ),
                    left: 0, bottom: 0, right: 0 )
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
                .constrainTo { $1.heightAnchor.constraint( equalToConstant: 0 ).withPriority( .fittingSizeLevel ) }
                .activate()

        LayoutConfiguration( view: self.closeButton )
                .constrainTo { $1.centerXAnchor.constraint( equalTo: self.contentView.centerXAnchor ) }
                .constrainTo { $1.centerYAnchor.constraint( equalTo: self.contentView.bottomAnchor ).withPriority( .fittingSizeLevel ) }
                .constrainTo { $1.bottomAnchor.constraint( lessThanOrEqualTo: self.view.bottomAnchor, constant: -8 ) }
                .activate()

        self.configuration
                .apply( LayoutConfiguration( view: self.scrollView ) { active, inactive in
                    active.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.bottomAnchor ) }
                    inactive.constrainTo { $1.topAnchor.constraint( equalTo: $0.bottomAnchor ) }
                } )
                .applyLayoutConfigurations { active, inactive in
                    active.set( MPTheme.global.color.shade.get(), forKey: "backgroundColor" )
                    inactive.set( MPTheme.global.color.shade.get()?.withAlphaComponent( 0 ), forKey: "backgroundColor" )
                }
    }

    @objc
    func didTapBackground() {
        self.hideDetails()
    }

    // MARK: --- Interface ---

    public func showDetails(_ detailsController: AnyMPDetailsViewController) {
        self.hideDetails {
            self.detailsController = detailsController

            if let detailsController = self.detailsController {
                self.addChild( detailsController )
                detailsController.beginAppearanceTransition( false, animated: true )
                self.contentView.insertSubview( detailsController.view, belowSubview: self.closeButton )
                LayoutConfiguration( view: detailsController.view ).constrainToOwner().activate()
                UIView.animate( withDuration: 0.382, animations: {
                    detailsController.view.window?.endEditing( true )
                    self.configuration.activate()
                }, completion: { finished in
                    detailsController.endAppearanceTransition()
                    detailsController.didMove( toParent: self )
                } )
            }
        }
    }

    @discardableResult
    public func hideDetails(completion: (() -> Void)? = nil) -> Bool {
        if let detailsController = self.detailsController {
            DispatchQueue.main.perform {
                detailsController.willMove( toParent: nil )
                detailsController.beginAppearanceTransition( false, animated: true )
                UIView.animate( withDuration: 0.382, animations: {
                    self.configuration.deactivate()
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
        if #available( iOS 11, * ) {
            if scrollView == self.scrollView, scrollView.adjustedContentInset.top + scrollView.contentOffset.y < -80 {
                self.hideDetails()
            }
        }
    }
}
