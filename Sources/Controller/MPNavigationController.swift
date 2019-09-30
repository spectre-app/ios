//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import Stellar

class MPNavigationController: UINavigationController, UINavigationControllerDelegate {
    private let backgroundView = MPBackgroundView()
    private let transition = MPNavigationTransition()

    // MARK: --- Life ---

    override init(rootViewController: UIViewController) {
        super.init( rootViewController: rootViewController )
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init( nibName: nibNameOrNil, bundle: nibBundleOrNil )

        self.isNavigationBarHidden = true
        self.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        // - Hierarchy
        self.view.insertSubview( self.backgroundView, at: 0 )

        // - Layout
        LayoutConfiguration( view: self.backgroundView )
                .constrainToOwner()
                .activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.visibleViewController?.view.scaleXY( 1 / 1000, 1 / 1000 ).makeAlpha( 0 ).duration( 0 ).then()
                                        .scaleXY( 1000, 1000 ).makeAlpha( 1 ).easing( .easeOut ).duration( 1 ).animate()

        super.viewWillAppear( animated )
    }

    override func viewWillDisappear(_ animated: Bool) {
        //self.visibleViewController?.view?.scaleXY( 1 / 1000, 1 / 1000 ).makeAlpha( 0 ).duration( 0.382 ).animate()

        super.viewWillDisappear( animated )
    }

    // MARK: --- UINavigationControllerDelegate ---

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController)
                    -> UIViewControllerAnimatedTransitioning? {
        self.transition
    }

    class MPNavigationTransition: NSObject, UIViewControllerAnimatedTransitioning {

        // MARK: --- Life ---

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            0.618;
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

                UIView.animate( withDuration: 1, delay: 0, usingSpringWithDamping: 0.618, initialSpringVelocity: 0,
                                options: .curveEaseOut, animations: {
                    fromView.transform = CGAffineTransform( scaleX: 1 / 1000, y: 1 / 1000 )
                    fromView.alpha = 0
                }, completion: { finished in
                    fromView.transform = .identity
                } )
                UIView.animate( withDuration: 2, delay: 0, usingSpringWithDamping: 0.618, initialSpringVelocity: 0,
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
