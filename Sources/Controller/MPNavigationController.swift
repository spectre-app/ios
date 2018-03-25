//
//  MPUsersViewController.swift
//  Master Password
//
//  Created by Maarten Billemont on 2018-01-21.
//  Copyright © 2018 Maarten Billemont. All rights reserved.
//

import UIKit
import pop

class MPNavigationController: UINavigationController, UINavigationControllerDelegate {
    private let starsView  = MPStarView()
    private let transition = MPNavigationTransition()

    // MARK: - Life

    override init(rootViewController: UIViewController) {
        super.init( nibName: nil, bundle: nil )

        self.delegate = self
        self.isNavigationBarHidden = true
        self.pushViewController( rootViewController, animated: true )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    override func viewDidLoad() {
        self.view.insertSubview( self.starsView, at: 0 )

        self.starsView.translatesAutoresizingMaskIntoConstraints = false
        self.starsView.topAnchor.constraint( equalTo: self.view.topAnchor ).activate()
        self.starsView.leadingAnchor.constraint( equalTo: self.view.leadingAnchor ).activate()
        self.starsView.trailingAnchor.constraint( equalTo: self.view.trailingAnchor ).activate()
        self.starsView.bottomAnchor.constraint( equalTo: self.view.bottomAnchor ).activate()
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // rootViewController animation
        if self.viewControllers.first == viewController,
           let animation = POPSpringAnimation( propertyNamed: kPOPViewScaleXY ) {
            animation.fromValue = CGPoint( x: 0, y: 0 )
            animation.toValue = CGPoint( x: 1, y: 1 )
            animation.springSpeed = 1
            viewController.view.pop_add( animation, forKey: "pop.scale" )
        }
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController)
                    -> UIViewControllerAnimatedTransitioning? {
        return self.transition
    }

    class MPNavigationTransition: NSObject, UIViewControllerAnimatedTransitioning {

        // MARK: - Life

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 1;
        }

        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        }
    }
}
