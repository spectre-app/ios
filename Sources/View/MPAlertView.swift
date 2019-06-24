//
// Created by Maarten Billemont on 2018-09-22.
// Copyright (c) 2018 Lyndir. All rights reserved.
//

import Foundation

class MPAlertView: MPButton {
    private let titleLabel   = UILabel()
    private let messageLabel = UILabel()
    private let detailLabel  = UILabel()

    private lazy var appearanceConfiguration = LayoutConfiguration( view: self ) { active, inactive in
        active.constrainTo { $1.topAnchor.constraint( equalTo: $0.topAnchor ) }
        inactive.constrainTo { $1.bottomAnchor.constraint( equalTo: $0.topAnchor ) }
    }
    private lazy var activationConfiguration = LayoutConfiguration( view: self ) { (active, inactive) in
        active.apply( LayoutConfiguration( view: self.titleLabel ).set( MPTheme.global.font.title1.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.messageLabel ).set( MPTheme.global.font.title2.get(), forKey: "font" ) )
        active.apply( LayoutConfiguration( view: self.detailLabel ).set( false, forKey: "hidden" ) )
        inactive.apply( LayoutConfiguration( view: self.titleLabel ).set( MPTheme.global.font.headline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.messageLabel ).set( MPTheme.global.font.subheadline.get(), forKey: "font" ) )
        inactive.apply( LayoutConfiguration( view: self.detailLabel ).set( true, forKey: "hidden" ) )
    }
    private var dismissItem: DispatchWorkItem? {
        willSet {
            self.dismissItem?.cancel()
        }
        didSet {
            if let appearanceItem = self.dismissItem {
                DispatchQueue.main.asyncAfter( wallDeadline: .now() + .seconds( 3 ), execute: appearanceItem )
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError( "init(coder:) is not supported for this class" )
    }

    init(title: String?, message: String?, details: String? = nil) {
        let contentStack = UIStackView( arrangedSubviews: [ self.titleLabel, self.messageLabel, self.detailLabel ] )
        super.init( content: contentStack )

        // - View
        self.darkBackground = true
        if #available( iOS 11.0, * ) {
            self.insetsLayoutMarginsFromSafeArea = true
        }

        self.titleLabel.text = title
        self.titleLabel.textColor = MPTheme.global.color.body.get()
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0

        self.messageLabel.text = message
        self.messageLabel.textColor = MPTheme.global.color.secondary.get()
        self.messageLabel.textAlignment = .center
        self.messageLabel.numberOfLines = 0

        self.detailLabel.text = details
        self.detailLabel.textColor = MPTheme.global.color.glow.get()
        self.detailLabel.textAlignment = .center
        self.detailLabel.numberOfLines = 0
        self.detailLabel.font = MPTheme.global.font.footnote.get()

        self.addGestureRecognizer( UITapGestureRecognizer( target: self, action: #selector( didTap ) ) )
        self.addGestureRecognizer( UISwipeGestureRecognizer( target: self, action: #selector( didSwipe ) ) )

        contentStack.axis = .vertical
        contentStack.spacing = 8
    }

    public func show(in view: UIView) {
        if let root = view.window?.rootViewController?.view {
            root.addSubview( self )

            LayoutConfiguration( view: self )
                    .constrainTo { $1.leadingAnchor.constraint( equalTo: $0.leadingAnchor ) }
                    .constrainTo { $1.trailingAnchor.constraint( equalTo: $0.trailingAnchor ) }
                    .activate()

            self.appearanceConfiguration.deactivate()
            self.activationConfiguration.deactivate()
            UIView.animate( withDuration: 0.618, animations: { self.appearanceConfiguration.activate() }, completion: { finished in
                self.dismissItem = DispatchWorkItem( qos: .utility ) { self.dismiss() }
            } )
        }
    }

    public func dismiss() {
        self.dismissItem = nil
        UIView.animate( withDuration: 0.618, animations: { self.appearanceConfiguration.deactivate() }, completion: { finished in
            self.removeFromSuperview()
        } )
    }

    @objc
    func didTap(_ recognizer: UITapGestureRecognizer) {
        self.dismissItem = nil
        UIView.animate( withDuration: 0.618 ) { self.activationConfiguration.activate() }
    }

    @objc
    func didSwipe(_ recognizer: UISwipeGestureRecognizer) {
        self.dismiss()
    }
}
