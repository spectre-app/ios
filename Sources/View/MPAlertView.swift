//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPAlertView: MPButton {
    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(title: String?, message: String?) {
        let titleLabel   = UILabel(), messageLabel = UILabel()
        let contentStack = UIStackView( arrangedSubviews: [ titleLabel, messageLabel ] )
        super.init( content: contentStack )

        // - View
        self.darkBackground = true
        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = true
        }

        titleLabel.text = title
        titleLabel.textColor = MPTheme.global.color.body.get()
        titleLabel.textAlignment = .center
        titleLabel.font = MPTheme.global.font.headline.get()

        messageLabel.text = message
        messageLabel.textColor = MPTheme.global.color.secondary.get()
        messageLabel.textAlignment = .center
        messageLabel.font = MPTheme.global.font.callout.get()

        contentStack.axis = .vertical
        contentStack.spacing = 8
    }

    func show(in view: UIView) {
        if let root = view.window?.rootViewController?.view {
            root.addSubview( self )

            LayoutConfiguration( view: self )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .activate()

            let alertConfiguration = LayoutConfiguration( view: self ) { active, inactive in
                active.constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
                inactive.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.topAnchor ) }
            }

            UIView.animate( withDuration: 0.618, animations: { alertConfiguration.activate() }, completion: { finished in
                UIView.animate( withDuration: 0.618, delay: 3, animations: { alertConfiguration.deactivate() }, completion: { finished in
                    self.removeFromSuperview()
                } )
            } )
        }
    }
}
