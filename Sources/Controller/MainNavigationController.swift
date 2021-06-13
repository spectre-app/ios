//==============================================================================
// Created by Maarten Billemont on 2018-01-21.
// Copyright (c) 2018 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import UIKit

class MainNavigationController: UINavigationController, UINavigationControllerDelegate {
    private let backgroundView = BackgroundView( mode: .backdrop )
    private let transition     = NavigationTransition()

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.isNavigationBarHidden = true

        // - Hierarchy
        self.view.insertSubview( self.backgroundView, at: 0 )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrain( as: .box ).activate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        Theme.current.updateTask.request()
    }

    // MARK: --- UINavigationControllerDelegate ---

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController)
                    -> UIViewControllerAnimatedTransitioning? {
        self.transition
    }

    class NavigationTransition: NSObject, UIViewControllerAnimatedTransitioning {

        // MARK: --- Life ---

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            .long
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {

            guard let fromView = transitionContext.view( forKey: .from ),
                  let toView = transitionContext.view( forKey: .to )
            else {
                transitionContext.completeTransition( false )
                return
            }

            if transitionContext.isAnimated {
                toView.alpha = .off
                toView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
                transitionContext.containerView.addSubview( toView )

                UIView.animate( withDuration: .seconds( 1 ), delay: .immediate, usingSpringWithDamping: .long, initialSpringVelocity: .off,
                                options: .curveEaseOut, animations: {
                    fromView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
                    fromView.alpha = .off
                }, completion: { finished in
                    fromView.transform = .identity
                } )
                UIView.animate( withDuration: .seconds( 1.5 ), delay: .immediate, usingSpringWithDamping: .long, initialSpringVelocity: .off,
                                options: .curveEaseOut, animations: {
                    toView.alpha = .on
                    toView.transform = .identity
                }, completion: { finished in
                    transitionContext.completeTransition( finished )
                } )
            }

            else {
                transitionContext.containerView.addSubview( toView )
                transitionContext.completeTransition( true )
            }
        }
    }
}
