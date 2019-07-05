//
// Created by Maarten Billemont on 2019-07-05.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

class MPDetailsHostController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate, MPDetailsObserver {
    public let scrollView  = UIScrollView()
    public let contentView = MPUntouchableView()

    private lazy var detailRecognizer = UITapGestureRecognizer( target: self, action: #selector( shouldDismissDetails ) )
    private lazy var configuration    = LayoutConfiguration( view: self.view )
    private var detailsController: AnyMPDetailsViewController?

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

        // - Hierarchy
        self.view.addSubview( self.scrollView )
        self.scrollView.addSubview( self.contentView )

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

    // MARK: --- Interface ---

    public func showDetails(_ detailsController: AnyMPDetailsViewController) {
        self.hideDetails {
            self.detailsController = detailsController

            if let detailsController = self.detailsController {
                detailsController.observers.register( observer: self )
                self.addChildViewController( detailsController )
                detailsController.beginAppearanceTransition( false, animated: true )
                self.contentView.addSubview( detailsController.view )
                LayoutConfiguration( view: detailsController.view ).constrainToOwner().activate()
                UIView.animate( withDuration: 0.382, animations: {
                    detailsController.view.becomeFirstResponder()
                    self.configuration.activate()
                }, completion: { finished in
                    detailsController.endAppearanceTransition()
                    detailsController.didMove( toParentViewController: self )
                } )
            }
        }
    }

    public func hideDetails(completion: (() -> Void)? = nil) {
        DispatchQueue.main.perform {
            if let detailsController = self.detailsController {
                detailsController.willMove( toParentViewController: nil )
                detailsController.beginAppearanceTransition( false, animated: true )
                UIView.animate( withDuration: 0.382, animations: {
                    self.configuration.deactivate()
                }, completion: { finished in
                    detailsController.view.removeFromSuperview()
                    detailsController.endAppearanceTransition()
                    detailsController.removeFromParentViewController()
                    detailsController.observers.unregister( observer: self )
                    self.detailsController = nil
                    completion?()
                } )
            }
            else {
                completion?()
            }
        }
    }

    // MARK: --- MPDetailsObserver ---

    @objc
    public func shouldDismissDetails() {
        self.hideDetails()
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
        if scrollView == self.scrollView, scrollView.contentInset.top + scrollView.contentOffset.y < -80 {
            self.shouldDismissDetails()
        }
    }
}
