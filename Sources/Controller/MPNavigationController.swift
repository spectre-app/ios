//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit

class MPNavigationController: UINavigationController, UINavigationControllerDelegate {
    private let backgroundView = MPBackgroundView( mode: .backdrop )
    private let transition     = MPNavigationTransition()

    // MARK: --- Life ---

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.isNavigationBarHidden = true

        // - Hierarchy
        self.view.insertSubview( self.backgroundView, at: 0 )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrain()
                .activate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange( previousTraitCollection )

        Theme.current.update()
    }

    // MARK: --- UINavigationControllerDelegate ---

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController)
                    -> UIViewControllerAnimatedTransitioning? {
        self.transition
    }

    class MPNavigationTransition: NSObject, UIViewControllerAnimatedTransitioning {

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
                toView.alpha = 0
                toView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
                transitionContext.containerView.addSubview( toView )

                UIView.animate( withDuration: 1, delay: 0, usingSpringWithDamping: .long, initialSpringVelocity: 0,
                                options: .curveEaseOut, animations: {
                    fromView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
                    fromView.alpha = 0
                }, completion: { finished in
                    fromView.transform = .identity
                } )
                UIView.animate( withDuration: 1.5, delay: 0, usingSpringWithDamping: .long, initialSpringVelocity: 0,
                                options: .curveEaseOut, animations: {
                    toView.alpha = 1
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
